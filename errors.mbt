///|
/// Stable categories returned by protocol parsing and state transitions.
/// Applications should branch on these values instead of matching messages.
pub(all) enum TusErrorKind {
  InvalidMethod
  InvalidPath
  InvalidHeaderName
  UnsafeHeaderValue
  MissingTusResumable
  UnsupportedVersion
  DuplicateSingletonHeader
  InvalidUnsignedInteger
  IntegerOverflow
  MissingUploadOffset
  OffsetMismatch
  MissingContentType
  InvalidContentType
  MissingContentLength
  BodyLengthMismatch
  MissingUploadLength
  ConflictingUploadLength
  InvalidDeferredLength
  UploadTooLarge
  UploadNotFound
  UploadAlreadyComplete
  UploadTerminated
  InvalidMetadata
  DuplicateMetadataKey
  MetadataTooLarge
  TooManyMetadataEntries
  InvalidBase64
  HeaderCountExceeded
  HeaderBytesExceeded
  BodyTooLarge
  IdentifierExhausted
  StorageConflict
  StorageFailure
  UnsupportedExtension
  InvalidScenario
  UnsupportedScenario
  InternalInvariant
} derive(Debug, Eq)

///|
/// Machine-stable protocol failure. `status` is the recommended HTTP response
/// status. It is data rather than an exception so adapters can translate it.
pub(all) struct TusError {
  kind : TusErrorKind
  code : String
  message : String
  status : Int
  header_name : String?
  expected : String?
  actual : String?
} derive(Debug, Eq)

///|
pub fn tus_error(
  kind : TusErrorKind,
  code : String,
  message : String,
  status? : Int = 400,
  header_name? : String? = None,
  expected? : String? = None,
  actual? : String? = None,
) -> TusError {
  { kind, code, message, status, header_name, expected, actual, }
}

///|
pub fn invalid_method(http_method : String) -> TusError {
  tus_error(
    InvalidMethod,
    "TUS_METHOD_UNSUPPORTED",
    "method is not supported by the configured tus endpoint",
    status=405,
    actual=Some(http_method),
  )
}

///|
pub fn invalid_path(path : String) -> TusError {
  tus_error(
    InvalidPath,
    "TUS_PATH_INVALID",
    "request path is not a valid upload collection or resource path",
    status=404,
    actual=Some(path),
  )
}

///|
pub fn missing_header(name : String, kind : TusErrorKind) -> TusError {
  tus_error(
    kind,
    "TUS_REQUIRED_HEADER_MISSING",
    "a required tus request header is missing",
    header_name=Some(name),
  )
}

///|
pub fn duplicate_header(name : String) -> TusError {
  tus_error(
    DuplicateSingletonHeader,
    "TUS_SINGLETON_HEADER_REPEATED",
    "a singleton tus header occurs more than once",
    header_name=Some(name),
  )
}

///|
pub fn unsupported_version(actual : String) -> TusError {
  tus_error(
    UnsupportedVersion,
    "TUS_VERSION_UNSUPPORTED",
    "Tus-Resumable does not name a supported protocol version",
    status=412,
    header_name=Some("tus-resumable"),
    expected=Some("1.0.0"),
    actual=Some(actual),
  )
}

///|
pub fn invalid_integer(name : String, actual : String) -> TusError {
  tus_error(
    InvalidUnsignedInteger,
    "TUS_INTEGER_INVALID",
    "header must contain one non-negative decimal integer",
    header_name=Some(name),
    actual=Some(actual),
  )
}

///|
pub fn integer_overflow(name : String, actual : String) -> TusError {
  tus_error(
    IntegerOverflow,
    "TUS_INTEGER_OVERFLOW",
    "header value exceeds the supported signed 64-bit range",
    header_name=Some(name),
    actual=Some(actual),
  )
}

///|
pub fn offset_mismatch(expected : Int64, actual : Int64) -> TusError {
  tus_error(
    OffsetMismatch,
    "TUS_OFFSET_MISMATCH",
    "Upload-Offset does not match the resource offset",
    status=409,
    header_name=Some("upload-offset"),
    expected=Some(expected.to_string()),
    actual=Some(actual.to_string()),
  )
}

///|
pub fn body_length_mismatch(expected : Int, actual : Int) -> TusError {
  tus_error(
    BodyLengthMismatch,
    "TUS_BODY_LENGTH_MISMATCH",
    "Content-Length does not equal the supplied body length",
    status=400,
    header_name=Some("content-length"),
    expected=Some(expected.to_string()),
    actual=Some(actual.to_string()),
  )
}

///|
pub fn upload_not_found(identifier : String) -> TusError {
  tus_error(
    UploadNotFound,
    "TUS_UPLOAD_NOT_FOUND",
    "the upload resource does not exist",
    status=404,
    actual=Some(identifier),
  )
}

///|
pub fn upload_complete(identifier : String) -> TusError {
  tus_error(
    UploadAlreadyComplete,
    "TUS_UPLOAD_ALREADY_COMPLETE",
    "the upload resource has already reached its declared length",
    status=409,
    actual=Some(identifier),
  )
}

///|
pub fn upload_too_large(limit : Int64, actual : Int64) -> TusError {
  tus_error(
    UploadTooLarge,
    "TUS_UPLOAD_TOO_LARGE",
    "declared or resulting upload size exceeds the configured limit",
    status=413,
    expected=Some(limit.to_string()),
    actual=Some(actual.to_string()),
  )
}

///|
pub fn invalid_metadata(message : String) -> TusError {
  tus_error(InvalidMetadata, "TUS_METADATA_INVALID", message)
}

///|
pub fn storage_conflict(identifier : String) -> TusError {
  tus_error(
    StorageConflict,
    "TUS_STORAGE_CONFLICT",
    "upload state changed before the transition could be committed",
    status=409,
    actual=Some(identifier),
  )
}

///|
pub fn error_kind_name(kind : TusErrorKind) -> String {
  match kind {
    InvalidMethod => "invalid-method"
    InvalidPath => "invalid-path"
    InvalidHeaderName => "invalid-header-name"
    UnsafeHeaderValue => "unsafe-header-value"
    MissingTusResumable => "missing-tus-resumable"
    UnsupportedVersion => "unsupported-version"
    DuplicateSingletonHeader => "duplicate-singleton-header"
    InvalidUnsignedInteger => "invalid-unsigned-integer"
    IntegerOverflow => "integer-overflow"
    MissingUploadOffset => "missing-upload-offset"
    OffsetMismatch => "offset-mismatch"
    MissingContentType => "missing-content-type"
    InvalidContentType => "invalid-content-type"
    MissingContentLength => "missing-content-length"
    BodyLengthMismatch => "body-length-mismatch"
    MissingUploadLength => "missing-upload-length"
    ConflictingUploadLength => "conflicting-upload-length"
    InvalidDeferredLength => "invalid-deferred-length"
    UploadTooLarge => "upload-too-large"
    UploadNotFound => "upload-not-found"
    UploadAlreadyComplete => "upload-already-complete"
    UploadTerminated => "upload-terminated"
    InvalidMetadata => "invalid-metadata"
    DuplicateMetadataKey => "duplicate-metadata-key"
    MetadataTooLarge => "metadata-too-large"
    TooManyMetadataEntries => "too-many-metadata-entries"
    InvalidBase64 => "invalid-base64"
    HeaderCountExceeded => "header-count-exceeded"
    HeaderBytesExceeded => "header-bytes-exceeded"
    BodyTooLarge => "body-too-large"
    IdentifierExhausted => "identifier-exhausted"
    StorageConflict => "storage-conflict"
    StorageFailure => "storage-failure"
    UnsupportedExtension => "unsupported-extension"
    InvalidScenario => "invalid-scenario"
    UnsupportedScenario => "unsupported-scenario"
    InternalInvariant => "internal-invariant"
  }
}
