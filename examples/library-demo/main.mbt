///|
fn main {
  let engine = @tus.TusEngine::new(
    config=@tus.config(limits=@tus.TusLimits::strict_test()),
  ).unwrap()
  let create = @tus.request(
    "POST",
    "/files",
    headers=@tus.Headers::empty()
      .add("Tus-Resumable", "1.0.0")
      .add("Upload-Length", "5")
      .add("Upload-Metadata", "filename aGVsbG8udHh0"),
  )
  let created = engine.handle(create)
  println(@tus.render_response_text(created))
  let location = created.headers.first("location").unwrap()
  let patch = @tus.request(
    "PATCH",
    location,
    headers=@tus.Headers::empty()
      .add("Tus-Resumable", "1.0.0")
      .add("Upload-Offset", "0")
      .add("Content-Type", "application/offset+octet-stream")
      .add("Content-Length", "5"),
    body=b"hello",
  )
  println(@tus.render_response_text(engine.handle(patch)))
  let head = @tus.request(
    "HEAD",
    location,
    headers=@tus.Headers::empty().add("Tus-Resumable", "1.0.0"),
  )
  println(@tus.render_response_text(engine.handle(head)))
}
