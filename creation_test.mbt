///|
fn creation_headers(length : String) -> Headers {
  Headers::empty().add("Tus-Resumable", "1.0.0").add("Upload-Length", length)
}

///|
test "creation accepts known zero and nonzero lengths" {
  for length in ["0", "42"] {
    let request = request("POST", "/files", headers=creation_headers(length))
    match plan_creation(request, TusConfig::default()) {
      Ok(plan) =>
        assert_eq(
          plan.length,
          Known(parse_non_negative_i64("x", length).unwrap()),
        )
      Err(_) => fail("known length should be accepted")
    }
  }
}

///|
test "creation accepts deferred length" {
  let headers = Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Defer-Length", "1")
  match
    plan_creation(request("POST", "/files", headers~), TusConfig::default()) {
    Ok(plan) => assert_eq(plan.length, Deferred)
    Err(_) => fail("deferred length should be accepted")
  }
}

///|
test "creation requires exactly one length form" {
  let base = Headers::empty().add("Tus-Resumable", "1.0.0")
  match
    plan_creation(request("POST", "/files", headers=base), TusConfig::default()) {
    Err(error) => assert_eq(error.kind, MissingUploadLength)
    Ok(_) => fail("missing length must fail")
  }
  let both = base.add("Upload-Length", "4").add("Upload-Defer-Length", "1")
  match
    plan_creation(request("POST", "/files", headers=both), TusConfig::default()) {
    Err(error) => assert_eq(error.kind, ConflictingUploadLength)
    Ok(_) => fail("conflicting length forms must fail")
  }
}

///|
test "creation applies upload size limit" {
  let limits = { ..TusLimits::strict_test(), max_upload_size: 10L, }
  match
    plan_creation(
      request("POST", "/files", headers=creation_headers("11")),
      config(limits~),
    ) {
    Err(error) => assert_eq(error.kind, UploadTooLarge)
    Ok(_) => fail("oversize creation must fail")
  }
}

///|
test "creation rejects extension when disabled" {
  match
    plan_creation(
      request("POST", "/files", headers=creation_headers("1")),
      config(allow_creation=false),
    ) {
    Err(error) => assert_eq(error.code, "TUS_CREATION_DISABLED")
    Ok(_) => fail("disabled creation must fail")
  }
}

///|
test "creation rejects deferred length when disabled" {
  let headers = Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Defer-Length", "1")
  match
    plan_creation(
      request("POST", "/files", headers~),
      config(allow_deferred_length=false),
    ) {
    Err(error) => assert_eq(error.code, "TUS_DEFER_LENGTH_DISABLED")
    Ok(_) => fail("disabled deferred length must fail")
  }
}

///|
test "creation parses metadata into plan" {
  let headers = creation_headers("5").add(
    "Upload-Metadata", "filename YS50eHQ=",
  )
  match
    plan_creation(request("POST", "/files", headers~), TusConfig::default()) {
    Err(_) => fail("valid metadata should parse")
    Ok(plan) => {
      assert_eq(plan.metadata.length(), 1)
      assert_eq(metadata_get(plan.metadata, "filename"), Some(b"a.txt"))
      assert_eq(creation_trace(plan).length(), 3)
    }
  }
}

///|
test "creation with body is intentionally outside v0.1" {
  let headers = creation_headers("4").add("Content-Length", "4")
  match
    plan_creation(
      request("POST", "/files", headers~, body=b"data"),
      TusConfig::default(),
    ) {
    Err(error) => assert_eq(error.code, "TUS_CREATION_WITH_UPLOAD_UNSUPPORTED")
    Ok(_) => fail("creation body must fail")
  }
}
