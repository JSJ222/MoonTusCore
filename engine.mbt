///|
/// Framework-neutral protocol façade. It accepts plain values and owns only a
/// reference store; network I/O, authentication and persistence stay outside.
pub struct TusEngine {
  priv store : MemoryStore
  config : TusConfig
}

///|
pub fn TusEngine::new(
  config? : TusConfig = TusConfig::default(),
  store? : MemoryStore = MemoryStore::new(),
) -> Result[TusEngine, TusError] {
  match validate_config(config) {
    Err(error) => Err(error)
    Ok(_) => Ok({ store, config, })
  }
}

///|
pub fn TusEngine::handle(self : TusEngine, request : TusRequest) -> TusResponse {
  let request = match apply_method_override(request) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(request) => request
  }
  match request.http_method {
    Options => self.handle_options(request)
    Post => handle_creation(request, self.store, self.config)
    Head => handle_head(request, self.store, self.config)
    Patch => handle_patch(request, self.store, self.config)
    Other(value) => unsupported_method_response(value)
  }
}

///|
pub fn TusEngine::snapshot(
  self : TusEngine,
  identifier : String,
) -> Result[UploadRecord, TusError] {
  self.store.get(identifier)
}

///|
pub fn TusEngine::uploads(self : TusEngine) -> Array[UploadRecord] {
  self.store.list()
}

///|
pub fn TusEngine::upload_count(self : TusEngine) -> Int {
  self.store.count()
}

///|
fn TusEngine::handle_options(
  self : TusEngine,
  request : TusRequest,
) -> TusResponse {
  match validate_request(request, self.config) {
    Err(error) =>
      return failure_response(error, headers=version_response_headers())
    Ok(_) => ()
  }
  let extensions = supported_extensions(self.config)
  let headers = Headers::empty()
    .add("Tus-Version", TUS_VERSION)
    .add("Tus-Resumable", TUS_VERSION)
    .add("Tus-Max-Size", self.config.limits.max_upload_size.to_string())
    .add("Allow", "OPTIONS, POST, HEAD, PATCH")
  let headers = if extensions.length() == 0 {
    headers
  } else {
    headers.add("Tus-Extension", join_ascii(extensions, ","))
  }
  success_response(204, headers~, trace=[
    trace(
      "options.capabilities.reported", "server capabilities were derived from active configuration",
      "tus-1.0.0/core",
    ),
  ])
}

///|
pub fn supported_extensions(config : TusConfig) -> Array[String] {
  let extensions : Array[String] = []
  if config.allow_creation {
    extensions.push("creation")
    if config.allow_deferred_length {
      extensions.push("creation-defer-length")
    }
  }
  extensions
}

///|
fn unsupported_method_response(http_method : String) -> TusResponse {
  failure_response(
    invalid_method(http_method),
    headers=version_response_headers().add(
      "Allow", "OPTIONS, POST, HEAD, PATCH",
    ),
  )
}

///|
fn join_ascii(values : Array[String], separator : String) -> String {
  let output = StringBuilder()
  for index, value in values {
    if index > 0 {
      output.write_string(separator)
    }
    output.write_string(value)
  }
  output.to_string()
}
