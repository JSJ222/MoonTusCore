///|
fn head_request(identifier : String) -> TusRequest {
  request(
    "HEAD",
    "/files/" + identifier,
    headers=Headers::empty().add("Tus-Resumable", "1.0.0"),
  )
}

///|
test "head reports known length and current offset" {
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(12L), metadata: [], }, TusLimits::strict_test())
    .unwrap()
  let response = handle_head(
    head_request(created.identifier),
    store,
    config(limits=TusLimits::strict_test()),
  )
  assert_eq(response.status, 200)
  assert_eq(response.headers.first("Tus-Resumable"), Some("1.0.0"))
  assert_eq(response.headers.first("Upload-Offset"), Some("0"))
  assert_eq(response.headers.first("Upload-Length"), Some("12"))
  assert_eq(response.headers.first("Cache-Control"), Some("no-store"))
  assert_eq(response.trace.length(), 3)
}

///|
test "head reports deferred length distinctly" {
  let store = MemoryStore::new()
  let created = store
    .create({ length: Deferred, metadata: [], }, TusLimits::strict_test())
    .unwrap()
  let response = handle_head(
    head_request(created.identifier),
    store,
    config(limits=TusLimits::strict_test()),
  )
  assert_eq(response.status, 200)
  assert_eq(response.headers.first("Upload-Length"), None)
  assert_eq(response.headers.first("Upload-Defer-Length"), Some("1"))
}

///|
test "head reports not found without leaking store details" {
  let response = handle_head(
    head_request("missing"),
    MemoryStore::new(),
    TusConfig::default(),
  )
  assert_eq(response.status, 404)
  match response.error {
    Some(error) => assert_eq(error.code, "TUS_UPLOAD_NOT_FOUND")
    None => fail("failure must carry structured error")
  }
  assert_eq(response.headers.first("Tus-Resumable"), Some("1.0.0"))
}

///|
test "head rejects collection path" {
  let request = request(
    "HEAD",
    "/files",
    headers=Headers::empty().add("Tus-Resumable", "1.0.0"),
  )
  let response = handle_head(request, MemoryStore::new(), TusConfig::default())
  assert_eq(response.status, 404)
  match response.error {
    Some(error) => assert_eq(error.kind, InvalidPath)
    None => fail("failure must carry error")
  }
}

///|
test "head validates version before store lookup" {
  let request = request("HEAD", "/files/missing")
  let response = handle_head(request, MemoryStore::new(), TusConfig::default())
  assert_eq(response.status, 400)
  match response.error {
    Some(error) => assert_eq(error.kind, MissingTusResumable)
    None => fail("failure must carry error")
  }
}
