///|
fn patch_request(
  identifier : String,
  offset : String,
  body : Bytes,
  extra? : Headers = Headers::empty(),
) -> TusRequest {
  let headers = extra
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Offset", offset)
    .add("Content-Type", "application/offset+octet-stream")
    .add("Content-Length", body.length().to_string())
  request("PATCH", "/files/" + identifier, headers~, body~)
}

///|
test "append plan advances known upload" {
  let record = upload_record("one", Known(6L))
  match
    plan_append(
      patch_request("one", "0", b"abc"),
      record,
      config(limits=TusLimits::strict_test()),
    ) {
    Err(_) => fail("valid append should plan")
    Ok(plan) => {
      assert_eq(plan.old_offset, 0L)
      assert_eq(plan.new_offset, 3L)
      assert_eq(plan.completes_upload, false)
      assert_eq(append_trace(plan).length(), 3)
    }
  }
}

///|
test "append plan marks exact completion" {
  let record = upload_record("one", Known(3L))
  let plan = plan_append(
    patch_request("one", "0", b"abc"),
    record,
    config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(plan.new_offset, 3L)
  assert_eq(plan.completes_upload, true)
  assert_eq(append_trace(plan).length(), 4)
}

///|
test "append plan detects stale client offset" {
  let record : UploadRecord = {
    ..upload_record("one", Known(8L)),
    offset: 3L,
    revision: 1L,
    data: b"abc",
  }
  match
    plan_append(
      patch_request("one", "0", b"d"),
      record,
      config(limits=TusLimits::strict_test()),
    ) {
    Err(error) => {
      assert_eq(error.kind, OffsetMismatch)
      assert_eq(error.status, 409)
    }
    Ok(_) => fail("stale offset must fail")
  }
}

///|
test "append plan rejects body beyond final length" {
  let record = upload_record("one", Known(2L))
  match
    plan_append(
      patch_request("one", "0", b"abc"),
      record,
      config(limits=TusLimits::strict_test()),
    ) {
    Err(error) => assert_eq(error.kind, UploadTooLarge)
    Ok(_) => fail("overshoot must fail")
  }
}

///|
test "append resolves a deferred final length" {
  let record = upload_record("one", Deferred)
  let extra = Headers::empty().add("Upload-Length", "3")
  let plan = plan_append(
    patch_request("one", "0", b"abc", extra~),
    record,
    config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(plan.resolved_length, Known(3L))
  assert_eq(plan.completes_upload, true)
}

///|
test "deferred declaration cannot trail resulting offset" {
  let extra = Headers::empty().add("Upload-Length", "2")
  match
    plan_append(
      patch_request("one", "0", b"abc", extra~),
      upload_record("one", Deferred),
      config(limits=TusLimits::strict_test()),
    ) {
    Err(error) => assert_eq(error.code, "TUS_DEFERRED_LENGTH_TOO_SMALL")
    Ok(_) => fail("too-small final length must fail")
  }
}

///|
test "append rejects wrong media type and body length" {
  let bad_type = Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Offset", "0")
    .add("Content-Type", "application/json")
    .add("Content-Length", "1")
  match
    plan_append(
      request("PATCH", "/files/one", headers=bad_type, body=b"x"),
      upload_record("one", Known(2L)),
      config(limits=TusLimits::strict_test()),
    ) {
    Err(error) => assert_eq(error.kind, InvalidContentType)
    Ok(_) => fail("wrong media type must fail")
  }
  let bad_length = Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Offset", "0")
    .add("Content-Type", "application/offset+octet-stream")
    .add("Content-Length", "2")
  match
    plan_append(
      request("PATCH", "/files/one", headers=bad_length, body=b"x"),
      upload_record("one", Known(2L)),
      config(limits=TusLimits::strict_test()),
    ) {
    Err(error) => assert_eq(error.kind, BodyLengthMismatch)
    Ok(_) => fail("body length mismatch must fail")
  }
}

///|
test "append rejects completed resource" {
  match
    plan_append(
      patch_request("one", "0", b""),
      upload_record("one", Known(0L)),
      config(limits=TusLimits::strict_test()),
    ) {
    Err(error) => assert_eq(error.kind, UploadAlreadyComplete)
    Ok(_) => fail("completed resource must fail")
  }
}
