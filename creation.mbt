///|
/// Validate a collection POST and produce an immutable creation plan.
/// v0.1 deliberately creates metadata and length state only; bytes are sent by
/// PATCH so an adapter never needs to buffer two request semantics at once.
pub fn plan_creation(
  request : TusRequest,
  config : TusConfig,
) -> Result[CreationPlan, TusError] {
  if request.http_method != Post {
    return Err(invalid_method(request.http_method.name()))
  }
  if !config.allow_creation {
    return Err(
      tus_error(
        UnsupportedExtension,
        "TUS_CREATION_DISABLED",
        "the Creation extension is disabled",
        status=405,
      ),
    )
  }
  match validate_request(request, config) {
    Err(error) => return Err(error)
    Ok(Resource(_)) => return Err(invalid_path(request.path))
    Ok(Collection) => ()
  }
  if request.body.length() != 0 {
    return Err(
      tus_error(
        UnsupportedExtension,
        "TUS_CREATION_WITH_UPLOAD_UNSUPPORTED",
        "v0.1 accepts upload bytes through PATCH only",
        status=415,
        actual=Some(request.body.length().to_string()),
      ),
    )
  }
  match request.headers.singleton("content-length") {
    Err(error) => return Err(error)
    Ok(Some(value)) =>
      match parse_non_negative_int("content-length", value) {
        Err(error) => return Err(error)
        Ok(length) =>
          if length != 0 {
            return Err(body_length_mismatch(length, 0))
          }
      }
    Ok(None) => ()
  }
  let declared = match optional_upload_length(request.headers) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let deferred = match optional_defer_length(request.headers) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let length = match (declared, deferred) {
    (Some(_), true) =>
      return Err(
        tus_error(
          ConflictingUploadLength,
          "TUS_LENGTH_HEADERS_CONFLICT",
          "Upload-Length and Upload-Defer-Length cannot occur together",
          header_name=Some("upload-length"),
        ),
      )
    (None, false) =>
      return Err(missing_header("upload-length", MissingUploadLength))
    (None, true) => {
      if !config.allow_deferred_length {
        return Err(
          tus_error(
            UnsupportedExtension,
            "TUS_DEFER_LENGTH_DISABLED",
            "Creation-Defer-Length is disabled",
            status=400,
          ),
        )
      }
      Deferred
    }
    (Some(value), false) => {
      match validate_declared_size(value, config.limits) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      Known(value)
    }
  }
  let metadata = match request.headers.singleton("upload-metadata") {
    Err(error) => return Err(error)
    Ok(None) => []
    Ok(Some(value)) =>
      match parse_upload_metadata(value, config.limits) {
        Err(error) => return Err(error)
        Ok(entries) => entries
      }
  }
  Ok({ length, metadata, })
}

///|
pub fn creation_trace(plan : CreationPlan) -> Array[TraceStep] {
  let steps = [
    trace(
      "creation.headers.valid", "Creation headers are syntactically valid and mutually consistent",
      "tus-1.0.0/creation",
    ),
  ]
  match plan.length {
    Known(total) =>
      steps.push(
        trace(
          "creation.length.known",
          "Upload-Length fixes the resource size at " + total.to_string(),
          "tus-1.0.0/creation",
        ),
      )
    Deferred =>
      steps.push(
        trace(
          "creation.length.deferred", "Upload-Defer-Length postpones the final size declaration",
          "tus-1.0.0/creation-defer-length",
        ),
      )
  }
  if plan.metadata.length() > 0 {
    steps.push(
      trace(
        "creation.metadata.decoded",
        plan.metadata.length().to_string() + " metadata entries were decoded",
        "tus-1.0.0/creation",
      ),
    )
  }
  steps
}
