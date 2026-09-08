///|
fn version_headers() -> Headers {
  Headers::empty().add("Tus-Resumable", "1.0.0")
}

///|
test "router distinguishes collection and resource" {
  assert_eq(classify_path("/files", "/files"), Ok(Collection))
  assert_eq(
    classify_path("/files/upload-01", "/files"),
    Ok(Resource("upload-01")),
  )
  assert_eq(classify_path("/abc", "/"), Ok(Resource("abc")))
}

///|
test "router rejects ambiguous resource identifiers" {
  for path in ["/files/", "/files/a/b", "/files/a?x=1", "/other/a"] {
    match classify_path(path, "/files") {
      Err(error) => assert_eq(error.kind, InvalidPath)
      Ok(_) => fail("ambiguous path must fail")
    }
  }
}

///|
test "non options requests require tus version" {
  match validate_request(request("HEAD", "/files/a"), TusConfig::default()) {
    Err(error) => assert_eq(error.kind, MissingTusResumable)
    Ok(_) => fail("missing version must fail")
  }
}

///|
test "unsupported tus version returns precondition failed" {
  let headers = Headers::empty().add("Tus-Resumable", "0.2.2")
  match
    validate_request(
      request("PATCH", "/files/a", headers~),
      TusConfig::default(),
    ) {
    Err(error) => {
      assert_eq(error.kind, UnsupportedVersion)
      assert_eq(error.status, 412)
    }
    Ok(_) => fail("unsupported version must fail")
  }
}

///|
test "options can discover protocol without version" {
  assert_eq(
    validate_request(options_request(), TusConfig::default()),
    Ok(Collection),
  )
}

///|
test "valid request accepts mixed case field name" {
  assert_eq(
    validate_request(
      request("HEAD", "/files/a", headers=version_headers()),
      TusConfig::default(),
    ),
    Ok(Resource("a")),
  )
}

///|
test "configuration rejects non-canonical collection path" {
  for path in ["files", "/files/", "/files?x"] {
    match validate_config(config(collection_path=path)) {
      Err(error) => assert_eq(error.code, "TUS_CONFIG_INVALID")
      Ok(_) => fail("invalid configuration must fail")
    }
  }
}
