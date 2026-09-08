///|
test "successful demo stores expected bytes" {
  let report = run_named_demo("success").unwrap()
  assert_eq(report.succeeded, true)
  assert_eq(report.uploads.length(), 1)
  assert_eq(report.uploads[0].data, b"hello world")
  assert_eq(report.uploads[0].lifecycle, Complete)
  assert_eq(report.events.length(), 7)
}

///|
test "conflict demo exposes rejection and recovery" {
  let report = run_named_demo("conflict").unwrap()
  assert_eq(report.succeeded, false)
  assert_eq(report.events[3].status, 409)
  assert_eq(report.events[3].error_code, Some("TUS_OFFSET_MISMATCH"))
  assert_eq(report.uploads[0].data, b"abcdef")
  assert_eq(report.uploads[0].lifecycle, Complete)
}

///|
test "deferred demo declares length once" {
  let report = run_named_demo("deferred").unwrap()
  assert_eq(report.succeeded, true)
  assert_eq(report.uploads[0].length, Known(10L))
  assert_eq(report.uploads[0].data, b"first-last")
}

///|
test "limit demo captures independent failures" {
  let report = run_named_demo("limits").unwrap()
  assert_eq(report.succeeded, false)
  assert_eq(report.events[1].status, 413)
  assert_eq(report.events[3].status, 413)
  assert_eq(report.uploads.length(), 1)
  assert_eq(report.uploads[0].data, b"")
}

///|
test "unknown demo returns structured error" {
  match run_named_demo("absent") {
    Err(error) => {
      assert_eq(error.kind, UnsupportedScenario)
      assert_eq(error.code, "TUS_DEMO_UNKNOWN")
      assert_eq(error.expected, Some("success, conflict, deferred, limits"))
    }
    Ok(_) => fail("unknown demo must fail")
  }
}
