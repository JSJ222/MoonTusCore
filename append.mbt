///|
/// Validate PATCH headers and current snapshot, then produce a compare-and-swap
/// plan. No bytes are mutated until a storage adapter commits this value.
pub fn plan_append(
  request : TusRequest,
  record : UploadRecord,
  config : TusConfig,
) -> Result[AppendPlan, TusError] {
  if request.http_method != Patch {
    return Err(invalid_method(request.http_method.name()))
  }
  let identifier = match validate_request(request, config) {
    Err(error) => return Err(error)
    Ok(Collection) => return Err(invalid_path(request.path))
    Ok(Resource(identifier)) => identifier
  }
  if identifier != record.identifier {
    return Err(upload_not_found(identifier))
  }
  match validate_record(record, config.limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if record.is_complete() {
    return Err(upload_complete(record.identifier))
  }
  let content_type = match
    request.headers.required_singleton("content-type", MissingContentType) {
    Err(error) => return Err(error)
    Ok(value) => trim_ows(value)
  }
  if !ascii_equal_ignore_case(content_type, "application/offset+octet-stream") {
    return Err(
      tus_error(
        InvalidContentType,
        "TUS_PATCH_CONTENT_TYPE_INVALID",
        "PATCH Content-Type must be application/offset+octet-stream",
        status=415,
        header_name=Some("content-type"),
        expected=Some("application/offset+octet-stream"),
        actual=Some(content_type),
      ),
    )
  }
  match require_content_length(request) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match validate_patch_size(request.body, config.limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let supplied_offset = match required_upload_offset(request.headers) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  if supplied_offset != record.offset {
    return Err(offset_mismatch(record.offset, supplied_offset))
  }
  let new_offset = match
    checked_body_end(record.offset, request.body.length()) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  if new_offset > config.limits.max_upload_size {
    return Err(upload_too_large(config.limits.max_upload_size, new_offset))
  }
  let patch_length = match optional_upload_length(request.headers) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let resolved_length = match record.length {
    Known(total) => {
      if patch_length is Some(_) {
        return Err(
          tus_error(
            ConflictingUploadLength,
            "TUS_LENGTH_ALREADY_DECLARED",
            "Upload-Length cannot change after creation",
            header_name=Some("upload-length"),
          ),
        )
      }
      if new_offset > total {
        return Err(upload_too_large(total, new_offset))
      }
      Known(total)
    }
    Deferred =>
      match patch_length {
        None => Deferred
        Some(total) => {
          if total < new_offset {
            return Err(
              tus_error(
                ConflictingUploadLength,
                "TUS_DEFERRED_LENGTH_TOO_SMALL",
                "declared Upload-Length is smaller than the resulting offset",
                header_name=Some("upload-length"),
                expected=Some(new_offset.to_string()),
                actual=Some(total.to_string()),
              ),
            )
          }
          match validate_declared_size(total, config.limits) {
            Err(error) => return Err(error)
            Ok(_) => Known(total)
          }
        }
      }
  }
  let completes = match resolved_length {
    Known(total) => new_offset == total
    Deferred => false
  }
  Ok({
    identifier: record.identifier,
    expected_revision: record.revision,
    old_offset: record.offset,
    new_offset,
    resolved_length,
    body: request.body,
    completes_upload: completes,
  })
}

///|
pub fn append_trace(plan : AppendPlan) -> Array[TraceStep] {
  let steps = [
    trace(
      "patch.offset.matched", "request Upload-Offset matches the committed resource offset",
      "tus-1.0.0/core",
    ),
    trace(
      "patch.body.bounded",
      plan.body.length().to_string() + " request bytes passed configured limits",
      "moontuscore/resource-limits",
    ),
    trace(
      "patch.cas.prepared",
      "storage must compare revision " + plan.expected_revision.to_string(),
      "moontuscore/storage-contract",
    ),
  ]
  if plan.completes_upload {
    steps.push(
      trace(
        "patch.upload.complete", "the resulting offset reaches Upload-Length", "tus-1.0.0/core",
      ),
    )
  }
  steps
}
