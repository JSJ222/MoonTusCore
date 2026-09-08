///|
test "engine advertises configured capabilities" {
  let engine = TusEngine::new(config=config(limits=TusLimits::strict_test())).unwrap()
  let response = engine.handle(options_request())
  assert_eq(response.status, 204)
  assert_eq(response.headers.first("Tus-Version"), Some("1.0.0"))
  assert_eq(
    response.headers.first("Tus-Extension"),
    Some("creation,creation-defer-length"),
  )
  assert_eq(response.headers.first("Tus-Max-Size"), Some("1024"))
}

///|
test "engine omits disabled extension advertisement" {
  let engine = TusEngine::new(
    config=config(allow_creation=false, allow_deferred_length=false),
  ).unwrap()
  let response = engine.handle(options_request())
  assert_eq(response.headers.first("Tus-Extension"), None)
}

///|
test "engine drives create head patch head flow" {
  let engine = TusEngine::new(config=config(limits=TusLimits::strict_test())).unwrap()
  let created = engine.handle(create_request("5"))
  assert_eq(created.status, 201)
  let location = created.headers.first("location").unwrap()
  let identifier = location[7:].to_owned()
  let first_head = engine.handle(head_request(identifier))
  assert_eq(response_offset(first_head), Some(0L))
  let patched = engine.handle(patch_request(identifier, "0", b"hello"))
  assert_eq(patched.status, 204)
  assert_eq(response_offset(patched), Some(5L))
  let last_head = engine.handle(head_request(identifier))
  assert_eq(response_offset(last_head), Some(5L))
  assert_eq(engine.snapshot(identifier).unwrap().data, b"hello")
}

///|
test "engine rejects unknown method with allow header" {
  let engine = TusEngine::new().unwrap()
  let response = engine.handle(request("DELETE", "/files/a"))
  assert_eq(response.status, 405)
  assert_eq(response.headers.first("Allow"), Some("OPTIONS, POST, HEAD, PATCH"))
  assert_eq(response_error_code(response), Some("TUS_METHOD_UNSUPPORTED"))
}

///|
test "engine constructor validates configuration once" {
  match TusEngine::new(config=config(collection_path="files")) {
    Err(error) => assert_eq(error.code, "TUS_CONFIG_INVALID")
    Ok(_) => fail("invalid engine configuration must fail")
  }
}

///|
test "engine never mutates after rejected overshoot" {
  let engine = TusEngine::new(config=config(limits=TusLimits::strict_test())).unwrap()
  let created = engine.handle(create_request("2"))
  let identifier = created.headers.first("location").unwrap()[7:].to_owned()
  let rejected = engine.handle(patch_request(identifier, "0", b"abc"))
  assert_eq(rejected.status, 413)
  assert_eq(engine.snapshot(identifier).unwrap().offset, 0L)
}
