///|
fn sample_report() -> ScenarioReport {
  run_scenario(
    [
      Discover,
      CreateKnown("demo", 3L, [metadata_entry("name", b"a\"b").unwrap()]),
      Append("demo", 0L, b"abc", None),
      Inspect("demo"),
    ],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
}

///|
test "text report presents transitions and final upload" {
  inspect(
    render_scenario_text(sample_report()),
    content=(
      #|MoonTusCore scenario
      #|result: success
      #|events: 4
      #|uploads: 1
      #|#0 OPTIONS status=204
      #|#1 POST name=demo status=201 offset=0
      #|#2 PATCH name=demo status=204 offset=3
      #|#3 HEAD name=demo status=200 offset=3
      #|upload u000000000001 offset=3 length=3 state=complete revision=1
      #|
    ),
  )
}

///|
test "json report has stable schema and escaped metadata" {
  let rendered = render_scenario_json(sample_report())
  assert_eq(rendered.contains("\"schema\":\"moontuscore.scenario.v1\""), true)
  assert_eq(rendered.contains("\"succeeded\":true"), true)
  assert_eq(rendered.contains("\"base64\":\"YSJi\""), true)
  assert_eq(rendered.contains("\"storedBytes\":3"), true)
}

///|
test "response renderer includes structured error" {
  let response = failure_response(
    offset_mismatch(4L, 2L),
    headers=version_response_headers(),
    trace=[trace("offset.reject", "client is stale", "tus-1.0.0/core")],
  )
  inspect(
    render_response_text(response),
    content=(
      #|status 409
      #|tus-resumable: 1.0.0
      #|tus-version: 1.0.0
      #|error-code: TUS_OFFSET_MISMATCH
      #|error-message: Upload-Offset does not match the resource offset
      #|trace: offset.reject [tus-1.0.0/core] client is stale
      #|
    ),
  )
}

///|
test "json renderer writes null for deferred length" {
  let report = run_scenario(
    [CreateDeferred("later", [])],
    config=config(limits=TusLimits::strict_test()),
  ).unwrap()
  let rendered = render_scenario_json(report)
  assert_eq(rendered.contains("\"length\":null,\"deferred\":true"), true)
}
