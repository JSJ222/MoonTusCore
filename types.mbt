///|
/// Supported tus protocol version. v0.1 intentionally exposes one version so
/// adapters cannot accidentally negotiate behavior that is not implemented.
pub const TUS_VERSION : String = "1.0.0"

///|
pub(all) enum HttpMethod {
  Options
  Post
  Head
  Patch
  Other(String)
} derive(Debug, Eq)

///|
pub fn parse_http_method(value : String) -> HttpMethod {
  match ascii_upper(value) {
    "OPTIONS" => Options
    "POST" => Post
    "HEAD" => Head
    "PATCH" => Patch
    other => Other(other)
  }
}

///|
pub fn HttpMethod::name(self : HttpMethod) -> String {
  match self {
    Options => "OPTIONS"
    Post => "POST"
    Head => "HEAD"
    Patch => "PATCH"
    Other(value) => value
  }
}

///|
/// Immutable HTTP-shaped input accepted by the protocol engine. No socket or
/// framework type crosses this boundary.
pub(all) struct TusRequest {
  http_method : HttpMethod
  path : String
  headers : Headers
  body : Bytes
} derive(Debug, Eq)

///|
pub fn request(
  http_method : String,
  path : String,
  headers? : Headers = Headers::empty(),
  body? : Bytes = b"",
) -> TusRequest {
  { http_method: parse_http_method(http_method), path, headers, body, }
}

///|
pub fn options_request(path? : String = "/files") -> TusRequest {
  request("OPTIONS", path)
}

///|
/// HTTP-shaped output. Response bodies are small protocol diagnostics only;
/// uploaded bytes are owned by the configured store.
pub(all) struct TusResponse {
  status : Int
  headers : Headers
  body : Bytes
  trace : Array[TraceStep]
  error : TusError?
} derive(Debug, Eq)

///|
pub fn success_response(
  status : Int,
  headers? : Headers = Headers::empty(),
  trace? : Array[TraceStep] = [],
) -> TusResponse {
  { status, headers, body: b"", trace: trace.copy(), error: None, }
}

///|
pub fn failure_response(
  error : TusError,
  headers? : Headers = Headers::empty(),
  trace? : Array[TraceStep] = [],
) -> TusResponse {
  {
    status: error.status,
    headers,
    body: b"",
    trace: trace.copy(),
    error: Some(error),
  }
}

///|
/// Normative explanation attached to every decision.
pub(all) struct TraceStep {
  code : String
  message : String
  protocol_section : String
} derive(Debug, Eq)

///|
pub fn trace(
  code : String,
  message : String,
  protocol_section : String,
) -> TraceStep {
  { code, message, protocol_section, }
}

///|
/// Declared total size or a promise that a later PATCH will declare it once.
pub(all) enum UploadLength {
  Known(Int64)
  Deferred
} derive(Debug, Eq)

///|
pub fn UploadLength::known(self : UploadLength) -> Int64? {
  match self {
    Known(value) => Some(value)
    Deferred => None
  }
}

///|
pub fn UploadLength::is_deferred(self : UploadLength) -> Bool {
  self == Deferred
}

///|
pub(all) enum UploadLifecycle {
  Active
  Complete
} derive(Debug, Eq)

///|
pub fn lifecycle(offset : Int64, length : UploadLength) -> UploadLifecycle {
  match length {
    Known(total) if offset == total => Complete
    _ => Active
  }
}

///|
/// One decoded Upload-Metadata member. `value` contains decoded bytes and
/// `encoded_value` retains the canonical wire representation.
pub(all) struct MetadataEntry {
  key : String
  value : Bytes
  encoded_value : String
} derive(Debug, Eq)

///|
/// Stored protocol state. The body is retained by the in-memory reference
/// store only; external stores may persist it elsewhere behind the same seam.
pub(all) struct UploadRecord {
  identifier : String
  offset : Int64
  length : UploadLength
  metadata : Array[MetadataEntry]
  revision : Int64
  lifecycle : UploadLifecycle
  data : Bytes
} derive(Debug, Eq)

///|
pub fn upload_record(
  identifier : String,
  length : UploadLength,
  metadata? : Array[MetadataEntry] = [],
) -> UploadRecord {
  {
    identifier,
    offset: 0L,
    length,
    metadata: metadata.copy(),
    revision: 0L,
    lifecycle: lifecycle(0L, length),
    data: b"",
  }
}

///|
pub fn UploadRecord::is_complete(self : UploadRecord) -> Bool {
  self.lifecycle == Complete
}

///|
pub fn UploadRecord::remaining(self : UploadRecord) -> Int64? {
  match self.length {
    Known(total) => Some(total - self.offset)
    Deferred => None
  }
}

///|
/// Limits are checked before mutation. Defaults are conservative enough for a
/// protocol adapter while remaining useful in tests and local tools.
pub(all) struct TusLimits {
  max_upload_size : Int64
  max_patch_bytes : Int
  max_header_count : Int
  max_header_bytes : Int
  max_metadata_bytes : Int
  max_metadata_entries : Int
  max_path_bytes : Int
  max_identifier_attempts : Int
} derive(Debug, Eq)

///|
pub fn TusLimits::default() -> TusLimits {
  {
    max_upload_size: 1024L * 1024L * 1024L,
    max_patch_bytes: 16 * 1024 * 1024,
    max_header_count: 128,
    max_header_bytes: 64 * 1024,
    max_metadata_bytes: 16 * 1024,
    max_metadata_entries: 64,
    max_path_bytes: 4096,
    max_identifier_attempts: 1024,
  }
}

///|
pub fn TusLimits::strict_test() -> TusLimits {
  {
    max_upload_size: 1024L,
    max_patch_bytes: 256,
    max_header_count: 32,
    max_header_bytes: 4096,
    max_metadata_bytes: 512,
    max_metadata_entries: 8,
    max_path_bytes: 256,
    max_identifier_attempts: 16,
  }
}

///|
pub(all) struct TusConfig {
  collection_path : String
  limits : TusLimits
  allow_creation : Bool
  allow_deferred_length : Bool
} derive(Debug, Eq)

///|
pub fn TusConfig::default() -> TusConfig {
  {
    collection_path: "/files",
    limits: TusLimits::default(),
    allow_creation: true,
    allow_deferred_length: true,
  }
}

///|
pub fn config(
  collection_path? : String = "/files",
  limits? : TusLimits = TusLimits::default(),
  allow_creation? : Bool = true,
  allow_deferred_length? : Bool = true,
) -> TusConfig {
  { collection_path, limits, allow_creation, allow_deferred_length, }
}

///|
/// Result of a validated append before it is committed to storage.
pub(all) struct AppendPlan {
  identifier : String
  expected_revision : Int64
  old_offset : Int64
  new_offset : Int64
  resolved_length : UploadLength
  body : Bytes
  completes_upload : Bool
} derive(Debug, Eq)

///|
/// Minimal creation plan produced after header validation.
pub(all) struct CreationPlan {
  length : UploadLength
  metadata : Array[MetadataEntry]
} derive(Debug, Eq)

///|
pub fn lifecycle_name(value : UploadLifecycle) -> String {
  match value {
    Active => "active"
    Complete => "complete"
  }
}

///|
pub fn upload_length_name(value : UploadLength) -> String {
  match value {
    Known(total) => total.to_string()
    Deferred => "deferred"
  }
}

///|
fn ascii_upper(value : String) -> String {
  let output = StringBuilder()
  for byte in value.iter() {
    if byte >= 'a' && byte <= 'z' {
      output.write_char((byte.to_int() - 32).unsafe_to_char())
    } else {
      output.write_char(byte)
    }
  }
  output.to_string()
}
