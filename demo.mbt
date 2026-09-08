///|
/// A successful two-chunk upload used by the CLI, README and smoke tests.
pub fn successful_demo_actions() -> Array[ScenarioAction] {
  [
    Discover,
    CreateKnown("artifact", 11L, [
      metadata_entry("filename", b"hello.txt").unwrap(),
      metadata_entry("content-type", b"text/plain").unwrap(),
    ]),
    Inspect("artifact"),
    Append("artifact", 0L, b"hello ", None),
    Inspect("artifact"),
    Append("artifact", 6L, b"world", None),
    Inspect("artifact"),
  ]
}

///|
/// A stale-offset flow proving that rejected data is never committed.
pub fn conflict_demo_actions() -> Array[ScenarioAction] {
  [
    Discover,
    CreateKnown("conflict", 6L, [
      metadata_entry("filename", b"conflict.bin").unwrap(),
    ]),
    Append("conflict", 0L, b"abc", None),
    Append("conflict", 0L, b"bad", None),
    Inspect("conflict"),
    Append("conflict", 3L, b"def", None),
    Inspect("conflict"),
  ]
}

///|
/// A Creation-Defer-Length flow declaring its final size in PATCH.
pub fn deferred_demo_actions() -> Array[ScenarioAction] {
  [
    Discover,
    CreateDeferred("stream", [
      metadata_entry("filename", b"stream.dat").unwrap(),
    ]),
    Inspect("stream"),
    Append("stream", 0L, b"first-", None),
    Inspect("stream"),
    Append("stream", 6L, b"last", Some(10L)),
    Inspect("stream"),
  ]
}

///|
/// A size-limit flow showing deterministic rejection without allocation.
pub fn limit_demo_actions() -> Array[ScenarioAction] {
  [
    Discover,
    CreateKnown("too-large", 2048L, []),
    CreateKnown("valid", 4L, []),
    Append("valid", 0L, b"12345", None),
    Inspect("valid"),
  ]
}

///|
pub fn available_demos() -> Array[String] {
  ["success", "conflict", "deferred", "limits"]
}

///|
pub fn run_named_demo(
  name : String,
  config? : TusConfig = config(limits=TusLimits::strict_test()),
) -> Result[ScenarioReport, TusError] {
  let actions = match name {
    "success" => successful_demo_actions()
    "conflict" => conflict_demo_actions()
    "deferred" => deferred_demo_actions()
    "limits" => limit_demo_actions()
    _ =>
      return Err(
        tus_error(
          UnsupportedScenario,
          "TUS_DEMO_UNKNOWN",
          "unknown built-in demo: " + name,
          status=400,
          expected=Some(join_demo_names()),
          actual=Some(name),
        ),
      )
  }
  run_scenario(actions, config~)
}

///|
pub fn demo_help() -> String {
  (
    #|MoonTusCore deterministic protocol tool
    #|
    #|Usage:
    #|  moontus demo [success|conflict|deferred|limits] [--json]
    #|  moontus capabilities
    #|  moontus version
    #|  moontus help
    #|
    #|The tool performs no network or filesystem I/O. It executes the same
    #|framework-neutral state machine that library adapters call.
    #|
  )
}

///|
fn join_demo_names() -> String {
  let output = StringBuilder()
  for index, name in available_demos() {
    if index > 0 {
      output.write_string(", ")
    }
    output.write_string(name)
  }
  output.to_string()
}
