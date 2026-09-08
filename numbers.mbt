///|
/// Parse a non-negative decimal integer without accepting signs, whitespace,
/// alternate bases, or overflow. tus integer fields use this restricted form.
pub fn parse_non_negative_i64(
  field_name : String,
  input : String,
) -> Result[Int64, TusError] {
  let value = trim_ows(input)
  if value.length() == 0 {
    return Err(invalid_integer(field_name, input))
  }
  let mut result = 0L
  for character in value {
    if character < '0' || character > '9' {
      return Err(invalid_integer(field_name, input))
    }
    let digit = character.to_int() - '0'.to_int()
    if result > (9223372036854775807L - digit.to_int64()) / 10L {
      return Err(integer_overflow(field_name, input))
    }
    result = result * 10L + digit.to_int64()
  }
  Ok(result)
}

///|
pub fn parse_non_negative_int(
  field_name : String,
  input : String,
) -> Result[Int, TusError] {
  match parse_non_negative_i64(field_name, input) {
    Err(error) => Err(error)
    Ok(value) =>
      if value > 2147483647L {
        Err(integer_overflow(field_name, input))
      } else {
        Ok(value.to_int())
      }
  }
}

///|
pub fn checked_add_i64(
  left : Int64,
  right : Int64,
  field_name? : String = "upload-offset",
) -> Result[Int64, TusError] {
  if left < 0L || right < 0L {
    return Err(
      invalid_integer(field_name, left.to_string() + "+" + right.to_string()),
    )
  }
  if left > 9223372036854775807L - right {
    return Err(
      integer_overflow(field_name, left.to_string() + "+" + right.to_string()),
    )
  }
  Ok(left + right)
}

///|
pub fn checked_body_end(
  offset : Int64,
  body_length : Int,
) -> Result[Int64, TusError] {
  checked_add_i64(offset, body_length.to_int64(), field_name="upload-offset")
}

///|
pub fn decimal(value : Int64) -> String {
  value.to_string()
}

///|
pub fn is_canonical_decimal(value : String) -> Bool {
  if value == "0" {
    return true
  }
  if value.length() == 0 || value[0].to_int() == '0'.to_int() {
    return false
  }
  for character in value {
    if character < '0' || character > '9' {
      return false
    }
  }
  true
}

///|
pub fn require_content_length(request : TusRequest) -> Result[Int, TusError] {
  match
    request.headers.required_singleton("content-length", MissingContentLength) {
    Err(error) => Err(error)
    Ok(value) =>
      match parse_non_negative_int("content-length", value) {
        Err(error) => Err(error)
        Ok(declared) =>
          if declared != request.body.length() {
            Err(body_length_mismatch(declared, request.body.length()))
          } else {
            Ok(declared)
          }
      }
  }
}

///|
pub fn optional_upload_length(headers : Headers) -> Result[Int64?, TusError] {
  match headers.singleton("upload-length") {
    Err(error) => Err(error)
    Ok(None) => Ok(None)
    Ok(Some(value)) =>
      match parse_non_negative_i64("upload-length", value) {
        Ok(length) => Ok(Some(length))
        Err(error) => Err(error)
      }
  }
}

///|
pub fn required_upload_offset(headers : Headers) -> Result[Int64, TusError] {
  match headers.required_singleton("upload-offset", MissingUploadOffset) {
    Err(error) => Err(error)
    Ok(value) => parse_non_negative_i64("upload-offset", value)
  }
}

///|
pub fn optional_defer_length(headers : Headers) -> Result[Bool, TusError] {
  match headers.singleton("upload-defer-length") {
    Err(error) => Err(error)
    Ok(None) => Ok(false)
    Ok(Some(value)) =>
      if trim_ows(value) == "1" {
        Ok(true)
      } else {
        Err(
          tus_error(
            InvalidDeferredLength,
            "TUS_DEFER_LENGTH_INVALID",
            "Upload-Defer-Length must be exactly 1",
            header_name=Some("upload-defer-length"),
            expected=Some("1"),
            actual=Some(value),
          ),
        )
      }
  }
}

///|
pub fn validate_declared_size(
  length : Int64,
  limits : TusLimits,
) -> Result[Unit, TusError] {
  if length > limits.max_upload_size {
    Err(upload_too_large(limits.max_upload_size, length))
  } else {
    Ok(())
  }
}

///|
pub fn validate_patch_size(
  body : Bytes,
  limits : TusLimits,
) -> Result[Unit, TusError] {
  if body.length() > limits.max_patch_bytes {
    Err(
      tus_error(
        BodyTooLarge,
        "TUS_PATCH_BODY_TOO_LARGE",
        "PATCH body exceeds the configured per-request byte limit",
        status=413,
        expected=Some(limits.max_patch_bytes.to_string()),
        actual=Some(body.length().to_string()),
      ),
    )
  } else {
    Ok(())
  }
}
