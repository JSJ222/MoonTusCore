///|
/// Endpoint location resolved without depending on an HTTP framework router.
pub(all) enum TusRoute {
  Collection
  Resource(String)
} derive(Debug, Eq)

///|
/// Validate generic request constraints, protocol version and endpoint path.
pub fn validate_request(
  request : TusRequest,
  config : TusConfig,
) -> Result[TusRoute, TusError] {
  match validate_config(config) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match request.headers.validate(config.limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if request.path.length() > config.limits.max_path_bytes {
    return Err(
      tus_error(
        InvalidPath,
        "TUS_PATH_TOO_LARGE",
        "request path exceeds the configured byte budget",
        status=414,
        expected=Some(config.limits.max_path_bytes.to_string()),
        actual=Some(request.path.length().to_string()),
      ),
    )
  }
  match request.http_method {
    Options => ()
    Post | Head | Patch | Other(_) =>
      match require_tus_version(request.headers) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
  }
  classify_path(request.path, config.collection_path)
}

///|
pub fn require_tus_version(headers : Headers) -> Result[Unit, TusError] {
  match headers.required_singleton("tus-resumable", MissingTusResumable) {
    Err(error) => Err(error)
    Ok(value) => {
      let actual = trim_ows(value)
      if actual == TUS_VERSION {
        Ok(())
      } else {
        Err(unsupported_version(actual))
      }
    }
  }
}

///|
pub fn classify_path(
  path : String,
  collection_path : String,
) -> Result[TusRoute, TusError] {
  if path == collection_path {
    return Ok(Collection)
  }
  let prefix = if collection_path == "/" { "/" } else { collection_path + "/" }
  if path.length() <= prefix.length() ||
    path[:prefix.length()].to_owned() != prefix {
    return Err(invalid_path(path))
  }
  let identifier = path[prefix.length():].to_owned()
  if !is_safe_identifier(identifier) {
    return Err(invalid_path(path))
  }
  Ok(Resource(identifier))
}

///|
pub fn resource_path(collection_path : String, identifier : String) -> String {
  if collection_path == "/" {
    "/" + identifier
  } else {
    collection_path + "/" + identifier
  }
}

///|
pub fn is_safe_identifier(identifier : String) -> Bool {
  if identifier.length() == 0 || identifier.length() > 128 {
    return false
  }
  for character in identifier {
    if !is_identifier_character(character) {
      return false
    }
  }
  true
}

///|
fn is_identifier_character(character : Char) -> Bool {
  if character >= 'a' && character <= 'z' {
    return true
  }
  if character >= 'A' && character <= 'Z' {
    return true
  }
  if character >= '0' && character <= '9' {
    return true
  }
  character == '-' || character == '_' || character == '.' || character == '~'
}

///|
pub fn validate_config(config : TusConfig) -> Result[Unit, TusError] {
  let path = config.collection_path
  if path.length() == 0 || path[0] != '/' {
    return Err(config_error("collection path must start with a slash"))
  }
  if path.length() > 1 && path[path.length() - 1] == '/' {
    return Err(config_error("collection path must not end with a slash"))
  }
  for character in path {
    let code = character.to_int()
    if code < 33 || code > 126 || character == '?' || character == '#' {
      return Err(config_error("collection path contains an unsafe character"))
    }
  }
  let limits = config.limits
  if limits.max_upload_size < 0L ||
    limits.max_patch_bytes < 0 ||
    limits.max_header_count <= 0 ||
    limits.max_header_bytes <= 0 ||
    limits.max_metadata_bytes < 0 ||
    limits.max_metadata_entries < 0 ||
    limits.max_path_bytes <= 0 ||
    limits.max_identifier_attempts <= 0 {
    return Err(
      config_error(
        "all size limits must be non-negative and structural limits positive",
      ),
    )
  }
  Ok(())
}

///|
fn config_error(message : String) -> TusError {
  tus_error(InternalInvariant, "TUS_CONFIG_INVALID", message, status=500)
}
