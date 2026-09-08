# MoonTusCore

Framework-neutral tus 1.0 request validation and atomic resumable-upload state
transitions for MoonBit.

~~~moonbit nocheck
let engine = @tus.TusEngine::new().unwrap()
let response = engine.handle(@tus.options_request())
assert_eq!(response.status, 204)
~~~

Persistent adapters call plan_creation and plan_append, then apply the returned
plan atomically using both expected_revision and old_offset.
