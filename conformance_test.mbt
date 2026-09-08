///|
test "built in core conformance vectors all pass" {
  let report = run_conformance_suite(core_conformance_vectors()).unwrap()
  assert_eq(report.results.length(), 10)
  assert_eq(report.passed, 10)
  assert_eq(report.failed, 0)
  for result in report.results {
    assert_eq(result.passed, true)
    assert_eq(result.findings.length(), 0)
  }
}

///|
test "conformance runner explains status mismatch" {
  let vector : ConformanceVector = {
    name: "intentional-mismatch",
    initial_records: [],
    request: options_request(),
    expected: {
      status: 200,
      error_code: None,
      response_offset: None,
      store: IgnoreStore,
    },
  }
  let result = run_conformance_vector(vector).unwrap()
  assert_eq(result.passed, false)
  assert_eq(result.findings.length(), 1)
  inspect(result.findings[0], content="status expected 200 but received 204")
}

///|
test "conformance runner detects byte mutation" {
  let vector : ConformanceVector = {
    name: "wrong-bytes",
    initial_records: [upload_record("seed", Known(3L))],
    request: request("HEAD", "/files/seed", headers=version_response_headers()),
    expected: {
      status: 200,
      error_code: None,
      response_offset: Some(0L),
      store: ResourceState("seed", 0L, Known(3L), Active, b"wrong"),
    },
  }
  let result = run_conformance_vector(vector).unwrap()
  assert_eq(result.passed, false)
  assert_eq(result.findings[0], "stored bytes differ for seed")
}

///|
test "conformance runner validates initial snapshots" {
  let invalid : UploadRecord = {
    ..upload_record("seed", Known(1L)),
    offset: 1L,
    data: b"",
  }
  let vector : ConformanceVector = {
    name: "invalid-seed",
    initial_records: [invalid],
    request: options_request(),
    expected: {
      status: 204,
      error_code: None,
      response_offset: None,
      store: IgnoreStore,
    },
  }
  match run_conformance_vector(vector) {
    Err(error) => assert_eq(error.code, "TUS_STORAGE_INVARIANT")
    Ok(_) => fail("invalid seed must fail before request execution")
  }
}
