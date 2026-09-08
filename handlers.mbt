///|
/// Execute a validated Creation request against the reference store.
pub fn handle_creation(
  request : TusRequest,
  store : MemoryStore,
  config : TusConfig,
) -> TusResponse {
  let plan = match plan_creation(request, config) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(plan) => plan
  }
  let record = match store.create(plan, config.limits) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(record) => record
  }
  let headers = version_response_headers()
    .add("Location", resource_path(config.collection_path, record.identifier))
    .add("Upload-Offset", record.offset.to_string())
  let traces = creation_trace(plan)
  traces.push(
    trace(
      "creation.resource.committed",
      "storage created resource " + record.identifier,
      "moontuscore/storage-contract",
    ),
  )
  success_response(201, headers~, trace=traces)
}

///|
/// Execute one offset-checked PATCH as an atomic state transition.
pub fn handle_patch(
  request : TusRequest,
  store : MemoryStore,
  config : TusConfig,
) -> TusResponse {
  if request.http_method != Patch {
    return failure_response(
      invalid_method(request.http_method.name()),
      headers=version_response_headers(),
    )
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
  let plan = match plan_append(request, record, config) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(plan) => plan
  }
  let updated = match store.commit_append(plan, config.limits) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(updated) => updated
  }
  let headers = version_response_headers()
    .add("Upload-Offset", updated.offset.to_string())
    .add("Cache-Control", "no-store")
  let traces = append_trace(plan)
  traces.push(
    trace(
      "patch.commit.accepted",
      "storage committed revision " + updated.revision.to_string(),
      "moontuscore/storage-contract",
    ),
  )
  success_response(204, headers~, trace=traces)
}

///|
pub fn response_error_code(response : TusResponse) -> String? {
  match response.error {
    None => None
    Some(error) => Some(error.code)
  }
}

///|
pub fn response_offset(response : TusResponse) -> Int64? {
  match response.headers.first("upload-offset") {
    None => None
    Some(value) =>
      match parse_non_negative_i64("upload-offset", value) {
        Ok(offset) => Some(offset)
        Err(_) => None
      }
  }
}
