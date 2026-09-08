///|
/// Evaluate a HEAD request against a stable upload snapshot.
pub fn handle_head(
  request : TusRequest,
  store : MemoryStore,
  config : TusConfig,
) -> TusResponse {
  if request.http_method != Head {
    return failure_response(invalid_method(request.http_method.name()))
  }
  let identifier = match validate_request(request, config) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(Collection) =>
      return failure_response(
        invalid_path(request.path),
        headers=version_response_headers(),
      )
    Ok(Resource(identifier)) => identifier
  }
  let record = match store.get(identifier) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(record) => record
  }
  let headers = head_headers(record)
  let trace = head_trace(record)
  success_response(200, headers~, trace~)
}

///|
pub fn head_headers(record : UploadRecord) -> Headers {
  let headers = version_response_headers()
    .add("Upload-Offset", record.offset.to_string())
    .add("Cache-Control", "no-store")
  let headers = match record.length {
    Known(total) => headers.add("Upload-Length", total.to_string())
    Deferred => headers.add("Upload-Defer-Length", "1")
  }
  if record.metadata.length() == 0 {
    headers
  } else {
    headers.add("Upload-Metadata", serialize_upload_metadata(record.metadata))
  }
}

///|
pub fn head_trace(record : UploadRecord) -> Array[TraceStep] {
  let steps = [
    trace(
      "head.resource.found", "upload resource snapshot was loaded", "tus-1.0.0/core",
    ),
    trace(
      "head.offset.reported",
      "Upload-Offset reports " + record.offset.to_string() + " committed bytes",
      "tus-1.0.0/core",
    ),
  ]
  match record.length {
    Known(total) =>
      steps.push(
        trace(
          "head.length.known",
          "Upload-Length reports the final size " + total.to_string(),
          "tus-1.0.0/creation",
        ),
      )
    Deferred =>
      steps.push(
        trace(
          "head.length.deferred", "Upload-Defer-Length confirms that the final size is not declared",
          "tus-1.0.0/creation-defer-length",
        ),
      )
  }
  steps
}

///|
pub fn version_response_headers() -> Headers {
  Headers::empty()
  .add("Tus-Resumable", TUS_VERSION)
  .add("Tus-Version", TUS_VERSION)
}
