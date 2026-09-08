///|
/// Encode arbitrary metadata bytes using the RFC 4648 basic alphabet.
/// The result is always padded and therefore has one canonical spelling.
pub fn encode_base64(input : Bytes) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let output = StringBuilder()
  let mut index = 0
  while index + 3 <= input.length() {
    let a = input[index].to_int()
    let b = input[index + 1].to_int()
    let c = input[index + 2].to_int()
    output.write_char(alphabet[a >> 2].to_int().unsafe_to_char())
    output.write_char(
      alphabet[((a & 3) << 4) | (b >> 4)].to_int().unsafe_to_char(),
    )
    output.write_char(
      alphabet[((b & 15) << 2) | (c >> 6)].to_int().unsafe_to_char(),
    )
    output.write_char(alphabet[c & 63].to_int().unsafe_to_char())
    index = index + 3
  }
  let remaining = input.length() - index
  if remaining == 1 {
    let a = input[index].to_int()
    output.write_char(alphabet[a >> 2].to_int().unsafe_to_char())
    output.write_char(alphabet[(a & 3) << 4].to_int().unsafe_to_char())
    output.write_string("==")
  } else if remaining == 2 {
    let a = input[index].to_int()
    let b = input[index + 1].to_int()
    output.write_char(alphabet[a >> 2].to_int().unsafe_to_char())
    output.write_char(
      alphabet[((a & 3) << 4) | (b >> 4)].to_int().unsafe_to_char(),
    )
    output.write_char(alphabet[(b & 15) << 2].to_int().unsafe_to_char())
    output.write_char('=')
  }
  output.to_string()
}

///|
/// Decode one strict RFC 4648 value from Upload-Metadata.
///
/// Whitespace, URL-safe symbols, missing padding and non-zero unused bits are
/// rejected. Strictness is intentional: adapters receive a single portable
/// interpretation rather than framework-dependent cleanup behavior.
pub fn decode_base64(
  input : String,
  max_output : Int,
) -> Result[Bytes, TusError] {
  if max_output < 0 {
    return Err(invalid_base64("decoded byte limit cannot be negative", input))
  }
  if input.length() == 0 {
    return Ok(b"")
  }
  if input.length() % 4 != 0 {
    return Err(
      invalid_base64(
        "encoded value must contain complete four-symbol quanta", input,
      ),
    )
  }
  let output : Array[Byte] = []
  let symbols : Array[Int] = []
  for character in input {
    match base64_symbol(character) {
      Some(value) => symbols.push(value)
      None =>
        return Err(
          invalid_base64(
            "encoded value contains a symbol outside the basic alphabet", input,
          ),
        )
    }
  }
  let mut index = 0
  while index < symbols.length() {
    let a = symbols[index]
    let b = symbols[index + 1]
    let c = symbols[index + 2]
    let d = symbols[index + 3]
    let last = index + 4 == symbols.length()
    if a < 0 || b < 0 {
      return Err(
        invalid_base64("padding cannot occur in the first two positions", input),
      )
    }
    if c < 0 {
      if !last || d >= 0 {
        return Err(
          invalid_base64(
            "double padding is only valid in the final quantum", input,
          ),
        )
      }
      if (b & 15) != 0 {
        return Err(
          invalid_base64("one-byte tail has non-zero unused bits", input),
        )
      }
      if output.length() + 1 > max_output {
        return Err(base64_too_large(max_output, output.length() + 1))
      }
      output.push(((a << 2) | (b >> 4)).to_byte())
    } else if d < 0 {
      if !last {
        return Err(
          invalid_base64("padding is only valid in the final quantum", input),
        )
      }
      if (c & 3) != 0 {
        return Err(
          invalid_base64("two-byte tail has non-zero unused bits", input),
        )
      }
      if output.length() + 2 > max_output {
        return Err(base64_too_large(max_output, output.length() + 2))
      }
      output.push(((a << 2) | (b >> 4)).to_byte())
      output.push((((b & 15) << 4) | (c >> 2)).to_byte())
    } else {
      if output.length() + 3 > max_output {
        return Err(base64_too_large(max_output, output.length() + 3))
      }
      output.push(((a << 2) | (b >> 4)).to_byte())
      output.push((((b & 15) << 4) | (c >> 2)).to_byte())
      output.push((((c & 3) << 6) | d).to_byte())
    }
    index = index + 4
  }
  Ok(Bytes::from_array(output))
}

///|
fn base64_symbol(character : Char) -> Int? {
  if character >= 'A' && character <= 'Z' {
    Some(character.to_int() - 'A'.to_int())
  } else if character >= 'a' && character <= 'z' {
    Some(character.to_int() - 'a'.to_int() + 26)
  } else if character >= '0' && character <= '9' {
    Some(character.to_int() - '0'.to_int() + 52)
  } else if character == '+' {
    Some(62)
  } else if character == '/' {
    Some(63)
  } else if character == '=' {
    Some(-1)
  } else {
    None
  }
}

///|
fn invalid_base64(message : String, actual : String) -> TusError {
  tus_error(
    InvalidBase64,
    "TUS_METADATA_BASE64_INVALID",
    message,
    header_name=Some("upload-metadata"),
    actual=Some(actual),
  )
}

///|
fn base64_too_large(limit : Int, actual : Int) -> TusError {
  tus_error(
    MetadataTooLarge,
    "TUS_METADATA_VALUE_TOO_LARGE",
    "decoded metadata value exceeds the configured byte budget",
    status=413,
    header_name=Some("upload-metadata"),
    expected=Some(limit.to_string()),
    actual=Some(actual.to_string()),
  )
}
