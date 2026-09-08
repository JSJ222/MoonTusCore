///|
fn create_request(length : String) -> TusRequest {
  request(
    "POST",
    "/files",
    headers=Headers::empty()
      .add("Tus-Resumable", "1.0.0")
      .add("Upload-Length", length),
  )
}

///|
test "creation handler persists and returns location" {
  let store = MemoryStore::new()
  let config = config(limits=TusLimits::strict_test())
  let response = handle_creation(create_request("5"), store, config)
  assert_eq(response.status, 201)
  assert_eq(response.headers.first("Location"), Some("/files/u000000000001"))
  assert_eq(response_offset(response), Some(0L))
  assert_eq(store.count(), 1)
  assert_eq(store.get("u000000000001").unwrap().length, Known(5L))
  assert_eq(response.trace.length(), 3)
}

///|
test "creation handler does not mutate on invalid request" {
  let store = MemoryStore::new()
  let response = handle_creation(
    request("POST", "/files"),
    store,
    TusConfig::default(),
  )
  assert_eq(response.status, 400)
  assert_eq(store.count(), 0)
  assert_eq(response_error_code(response), Some("TUS_REQUIRED_HEADER_MISSING"))
}

///|
test "patch handler persists bytes and reports offset" {
  let limits = TusLimits::strict_test()
  let config = config(limits~)
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(5L), metadata: [], }, limits)
    .unwrap()
  let response = handle_patch(
    patch_request(created.identifier, "0", b"hello"),
    store,
    config,
  )
  assert_eq(response.status, 204)
  assert_eq(response_offset(response), Some(5L))
  assert_eq(store.get(created.identifier).unwrap().data, b"hello")
  assert_eq(response.trace.length(), 5)
}

///|
test "patch handler preserves bytes after offset conflict" {
  let limits = TusLimits::strict_test()
  let config = config(limits~)
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(5L), metadata: [], }, limits)
    .unwrap()
  let first = handle_patch(
    patch_request(created.identifier, "0", b"he"),
    store,
    config,
  )
  assert_eq(first.status, 204)
  let stale = handle_patch(
    patch_request(created.identifier, "0", b"bad"),
    store,
    config,
  )
  assert_eq(stale.status, 409)
  assert_eq(response_error_code(stale), Some("TUS_OFFSET_MISMATCH"))
  assert_eq(store.get(created.identifier).unwrap().data, b"he")
}

///|
test "patch handler returns not found before append planning" {
  let response = handle_patch(
    patch_request("missing", "0", b"x"),
    MemoryStore::new(),
    config(limits=TusLimits::strict_test()),
  )
  assert_eq(response.status, 404)
  assert_eq(response_error_code(response), Some("TUS_UPLOAD_NOT_FOUND"))
}

///|
test "deferred creation and patch complete end to end" {
  let limits = TusLimits::strict_test()
  let config = config(limits~)
  let store = MemoryStore::new()
  let create_headers = Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Defer-Length", "1")
  let created = handle_creation(
    request("POST", "/files", headers=create_headers),
    store,
    config,
  )
  let location = created.headers.first("location").unwrap()
  let identifier = location[7:].to_owned()
  let extra = Headers::empty().add("Upload-Length", "4")
  let patched = handle_patch(
    patch_request(identifier, "0", b"data", extra~),
    store,
    config,
  )
  assert_eq(patched.status, 204)
  let record = store.get(identifier).unwrap()
  assert_eq(record.length, Known(4L))
  assert_eq(record.lifecycle, Complete)
}
