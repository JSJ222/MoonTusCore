///|
test "scenario runs a complete resumable flow" {
  let metadata = [metadata_entry("filename", b"demo.bin").unwrap()]
  let report = run_scenario(
    [
      Discover,
      CreateKnown("demo", 6L, metadata),
      Inspect("demo"),
      Append("demo", 0L, b"abc", None),
      Append("demo", 3L, b"def", None),
      Inspect("demo"),
    ],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(report.succeeded, true)
  assert_eq(report.events.length(), 6)
  assert_eq(report.events[1].status, 201)
  assert_eq(report.events[4].offset, Some(6L))
  assert_eq(report.uploads.length(), 1)
  assert_eq(report.uploads[0].data, b"abcdef")
  assert_eq(report.uploads[0].lifecycle, Complete)
}

///|
test "scenario captures protocol conflict and continues" {
  let report = run_scenario(
    [
      CreateKnown("demo", 4L, []),
      Append("demo", 0L, b"ab", None),
      Append("demo", 0L, b"xx", None),
      Inspect("demo"),
    ],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(report.succeeded, false)
  assert_eq(report.events[2].status, 409)
  assert_eq(report.events[2].error_code, Some("TUS_OFFSET_MISMATCH"))
  assert_eq(report.events[3].offset, Some(2L))
  assert_eq(report.uploads[0].data, b"ab")
}

///|
test "scenario resolves deferred length" {
  let report = run_scenario(
    [
      CreateDeferred("later", []),
      Append("later", 0L, b"data", Some(4L)),
      Inspect("later"),
    ],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(report.succeeded, true)
  assert_eq(report.uploads[0].length, Known(4L))
  assert_eq(report.uploads[0].lifecycle, Complete)
}

///|
test "scenario reports unknown and duplicate aliases" {
  let report = run_scenario(
    [
      Inspect("missing"),
      CreateKnown("same", 1L, []),
      CreateKnown("same", 1L, []),
    ],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(report.succeeded, false)
  assert_eq(report.events[0].error_code, Some("TUS_SCENARIO_INVALID"))
  assert_eq(report.events[2].error_code, Some("TUS_SCENARIO_INVALID"))
  assert_eq(report.uploads.length(), 1)
}

///|
test "scenario rejects invalid alias characters" {
  let report = run_scenario(
    [CreateKnown("bad alias", 1L, [])],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
  assert_eq(report.succeeded, false)
  assert_eq(report.events[0].status, 400)
  assert_eq(report.uploads.length(), 0)
}
