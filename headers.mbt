///|
/// One HTTP field line. Names are normalized to lowercase ASCII while values
/// remain byte-for-byte equivalent as MoonBit strings.
pub(all) struct HeaderField {
  name : String
  value : String
} derive(Debug, Eq)

///|
/// Ordered and duplicate-preserving field collection. Protocol validation can
/// therefore reject repeated singleton fields without a framework hiding them.
pub(all) struct Headers {
  entries : Array[HeaderField]
} derive(Debug, Eq)

///|
pub fn header(name : String, value : String) -> HeaderField {
  { name: ascii_lower(name), value, }
}

///|
pub fn Headers::empty() -> Headers {
  { entries: [], }
}

///|
pub fn Headers::from_array(entries : Array[HeaderField]) -> Headers {
  let copied : Array[HeaderField] = []
  for entry in entries {
    copied.push(header(entry.name, entry.value))
  }
  { entries: copied, }
}

///|
pub fn Headers::add(self : Headers, name : String, value : String) -> Headers {
  let entries = self.entries.copy()
  entries.push(header(name, value))
  { entries, }
}

///|
pub fn Headers::replace(
  self : Headers,
  name : String,
  value : String,
) -> Headers {
  self.without(name).add(name, value)
}

///|
pub fn Headers::without(self : Headers, name : String) -> Headers {
  let normalized = ascii_lower(name)
  let entries : Array[HeaderField] = []
  for entry in self.entries {
    if entry.name != normalized {
      entries.push(entry)
    }
  }
  { entries, }
}

///|
pub fn Headers::values(self : Headers, name : String) -> Array[String] {
  let normalized = ascii_lower(name)
  let values : Array[String] = []
  for entry in self.entries {
    if entry.name == normalized {
      values.push(entry.value)
    }
  }
  values
}

///|
pub fn Headers::first(self : Headers, name : String) -> String? {
  let normalized = ascii_lower(name)
  for entry in self.entries {
    if entry.name == normalized {
      return Some(entry.value)
    }
  }
  None
}

///|
pub fn Headers::last(self : Headers, name : String) -> String? {
  let normalized = ascii_lower(name)
  let mut found : String? = None
  for entry in self.entries {
    if entry.name == normalized {
      found = Some(entry.value)
    }
  }
  found
}

///|
pub fn Headers::count(self : Headers, name : String) -> Int {
  self.values(name).length()
}

///|
pub fn Headers::contains(self : Headers, name : String) -> Bool {
  self.first(name) is Some(_)
}

///|
pub fn Headers::singleton(
  self : Headers,
  name : String,
) -> Result[String?, TusError] {
  let values = self.values(name)
  match values.length() {
    0 => Ok(None)
    1 => Ok(Some(values[0]))
    _ => Err(duplicate_header(ascii_lower(name)))
  }
}

///|
pub fn Headers::required_singleton(
  self : Headers,
  name : String,
  missing_kind : TusErrorKind,
) -> Result[String, TusError] {
  match self.singleton(name) {
    Err(error) => Err(error)
    Ok(None) => Err(missing_header(ascii_lower(name), missing_kind))
    Ok(Some(value)) => Ok(value)
  }
}

///|
pub fn Headers::combined(self : Headers, name : String) -> String? {
  let values = self.values(name)
  if values.is_empty() {
    return None
  }
  let builder = StringBuilder()
  for index, value in values {
    if index > 0 {
      builder.write_string(", ")
    }
    builder.write_string(value)
  }
  Some(builder.to_string())
}

///|
pub fn Headers::len(self : Headers) -> Int {
  self.entries.length()
}

///|
pub fn Headers::as_array(self : Headers) -> Array[HeaderField] {
  self.entries.copy()
}

///|
pub fn Headers::wire_size(self : Headers) -> Int {
  let mut size = 0
  for entry in self.entries {
    size = size + entry.name.length() + 2 + entry.value.length() + 2
  }
  size
}

///|
/// Validate generic HTTP field safety before tus-specific interpretation.
pub fn Headers::validate(
  self : Headers,
  limits : TusLimits,
) -> Result[Unit, TusError] {
  if self.entries.length() > limits.max_header_count {
    return Err(
      tus_error(
        HeaderCountExceeded,
        "TUS_HEADER_COUNT_EXCEEDED",
        "request contains more field lines than configured",
        status=431,
        expected=Some(limits.max_header_count.to_string()),
        actual=Some(self.entries.length().to_string()),
      ),
    )
  }
  let bytes = self.wire_size()
  if bytes > limits.max_header_bytes {
    return Err(
      tus_error(
        HeaderBytesExceeded,
        "TUS_HEADER_BYTES_EXCEEDED",
        "request field section exceeds the configured byte budget",
        status=431,
        expected=Some(limits.max_header_bytes.to_string()),
        actual=Some(bytes.to_string()),
      ),
    )
  }
  for entry in self.entries {
    if !is_http_token(entry.name) {
      return Err(
        tus_error(
          InvalidHeaderName,
          "TUS_HEADER_NAME_INVALID",
          "HTTP field name is not a token",
          header_name=Some(entry.name),
        ),
      )
    }
    if contains_unsafe_field_byte(entry.value) {
      return Err(
        tus_error(
          UnsafeHeaderValue,
          "TUS_HEADER_VALUE_UNSAFE",
          "HTTP field value contains a line break, NUL, or control byte",
          header_name=Some(entry.name),
        ),
      )
    }
  }
  Ok(())
}

///|
pub fn trim_ows(value : String) -> String {
  value.trim(chars=" \t").to_owned()
}

///|
pub fn ascii_equal_ignore_case(left : String, right : String) -> Bool {
  ascii_lower(left) == ascii_lower(right)
}

///|
pub fn ascii_lower(value : String) -> String {
  let builder = StringBuilder()
  for character in value {
    if character >= 'A' && character <= 'Z' {
      builder.write_char((character.to_int() + 32).unsafe_to_char())
    } else {
      builder.write_char(character)
    }
  }
  builder.to_string()
}

///|
pub fn is_http_token(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  for character in value {
    if !is_token_character(character) {
      return false
    }
  }
  true
}

///|
fn is_token_character(character : Char) -> Bool {
  if character >= 'a' && character <= 'z' {
    return true
  }
  if character >= 'A' && character <= 'Z' {
    return true
  }
  if character >= '0' && character <= '9' {
    return true
  }
  match character {
    '!'
    | '#'
    | '$'
    | '%'
    | '&'
    | '\''
    | '*'
    | '+'
    | '-'
    | '.'
    | '^'
    | '_'
    | '`'
    | '|'
    | '~' => true
    _ => false
  }
}

///|
fn contains_unsafe_field_byte(value : String) -> Bool {
  for character in value {
    let code = character.to_int()
    if code == 0 ||
      code == 10 ||
      code == 13 ||
      (code < 32 && code != 9) ||
      code == 127 {
      return true
    }
  }
  false
}
