///|
/// Parse Upload-Metadata using the grammar from the tus Creation extension.
/// Entry order is preserved because applications may use it for display.
pub fn parse_upload_metadata(
  value : String,
  limits : TusLimits,
) -> Result[Array[MetadataEntry], TusError] {
  if value.length() > limits.max_metadata_bytes {
    return Err(metadata_size_error(limits.max_metadata_bytes, value.length()))
  }
  if value.length() == 0 {
    return Ok([])
  }
  let entries : Array[MetadataEntry] = []
  let mut decoded_bytes = 0
  for raw_entry in value.split(",") {
    if entries.length() >= limits.max_metadata_entries {
      return Err(
        tus_error(
          TooManyMetadataEntries,
          "TUS_METADATA_ENTRY_LIMIT",
          "Upload-Metadata contains more entries than configured",
          status=413,
          header_name=Some("upload-metadata"),
          expected=Some(limits.max_metadata_entries.to_string()),
          actual=Some((entries.length() + 1).to_string()),
        ),
      )
    }
    match
      parse_metadata_entry(raw_entry, limits.max_metadata_bytes - decoded_bytes) {
      Err(error) => return Err(error)
      Ok(entry) => {
        if metadata_contains_key(entries, entry.key) {
          return Err(
            tus_error(
              DuplicateMetadataKey,
              "TUS_METADATA_KEY_REPEATED",
              "Upload-Metadata repeats a key",
              header_name=Some("upload-metadata"),
              actual=Some(entry.key),
            ),
          )
        }
        decoded_bytes = decoded_bytes + entry.value.length()
        entries.push(entry)
      }
    }
  }
  Ok(entries)
}

///|
fn parse_metadata_entry(
  raw_entry : StringView,
  remaining_budget : Int,
) -> Result[MetadataEntry, TusError] {
  let entry = raw_entry.to_owned()
  if entry.length() == 0 {
    return Err(invalid_metadata("Upload-Metadata contains an empty entry"))
  }
  let mut separator : Int? = None
  for index, character in entry {
    if character == ' ' {
      if separator is Some(_) {
        return Err(
          invalid_metadata("metadata entry contains more than one separator"),
        )
      }
      separator = Some(index)
    }
  }
  let key = match separator {
    None => entry
    Some(index) => entry[:index].to_owned()
  }
  if !is_metadata_key(key) {
    return Err(
      invalid_metadata(
        "metadata key must be visible ASCII without comma or space",
      ),
    )
  }
  let encoded = match separator {
    None => ""
    Some(index) => entry[index + 1:].to_owned()
  }
  match decode_base64(encoded, remaining_budget) {
    Err(error) => Err(error)
    Ok(decoded) => Ok({ key, value: decoded, encoded_value: encoded, })
  }
}

///|
pub fn serialize_upload_metadata(entries : Array[MetadataEntry]) -> String {
  let output = StringBuilder()
  for index, entry in entries {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(entry.key)
    if entry.value.length() > 0 {
      output.write_char(' ')
      output.write_string(encode_base64(entry.value))
    }
  }
  output.to_string()
}

///|
/// Serialize application-provided metadata with the same wire and entry
/// budgets enforced for incoming Upload-Metadata. Values are re-encoded from
/// bytes rather than trusting a caller-supplied encoded_value field.
pub fn serialize_upload_metadata_checked(
  entries : Array[MetadataEntry],
  limits : TusLimits,
) -> Result[String, TusError] {
  if limits.max_metadata_bytes < 0 {
    return Err(metadata_size_error(limits.max_metadata_bytes, 0))
  }
  if entries.length() > limits.max_metadata_entries {
    return Err(
      tus_error(
        TooManyMetadataEntries,
        "TUS_METADATA_ENTRY_LIMIT",
        "Upload-Metadata contains more entries than configured",
        status=413,
        header_name=Some("upload-metadata"),
        expected=Some(limits.max_metadata_entries.to_string()),
        actual=Some(entries.length().to_string()),
      ),
    )
  }
  let output = StringBuilder()
  let seen : Array[MetadataEntry] = []
  let mut used = 0
  for index, entry in entries {
    if !is_metadata_key(entry.key) {
      return Err(
        invalid_metadata(
          "metadata key must be visible ASCII without comma or space",
        ),
      )
    }
    if metadata_contains_key(seen, entry.key) {
      return Err(
        tus_error(
          DuplicateMetadataKey,
          "TUS_METADATA_KEY_REPEATED",
          "Upload-Metadata repeats a key",
          header_name=Some("upload-metadata"),
          actual=Some(entry.key),
        ),
      )
    }
    let separator = if index > 0 { 1 } else { 0 }
    let remaining = limits.max_metadata_bytes - used
    if separator > remaining || entry.key.length() > remaining - separator {
      return Err(
        metadata_size_error(
          limits.max_metadata_bytes,
          used + separator + entry.key.length(),
        ),
      )
    }
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(entry.key)
    used = used + separator + entry.key.length()
    if entry.value.length() > 0 {
      let remaining = limits.max_metadata_bytes - used
      if remaining < 1 || entry.value.length() > remaining - 1 {
        return Err(
          metadata_size_error(
            limits.max_metadata_bytes,
            used + 1 + entry.value.length(),
          ),
        )
      }
      let encoded = encode_base64(entry.value)
      if encoded.length() > remaining - 1 {
        return Err(
          metadata_size_error(
            limits.max_metadata_bytes,
            used + 1 + encoded.length(),
          ),
        )
      }
      output.write_char(' ')
      output.write_string(encoded)
      used = used + 1 + encoded.length()
    }
    seen.push(entry)
  }
  Ok(output.to_string())
}

///|
pub fn metadata_entry(
  key : String,
  value : Bytes,
) -> Result[MetadataEntry, TusError] {
  if !is_metadata_key(key) {
    return Err(
      invalid_metadata(
        "metadata key must be visible ASCII without comma or space",
      ),
    )
  }
  Ok({ key, value, encoded_value: encode_base64(value), })
}

///|
pub fn metadata_get(entries : Array[MetadataEntry], key : String) -> Bytes? {
  for entry in entries {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
pub fn metadata_encoded_get(
  entries : Array[MetadataEntry],
  key : String,
) -> String? {
  for entry in entries {
    if entry.key == key {
      return Some(entry.encoded_value)
    }
  }
  None
}

///|
pub fn metadata_decoded_size(entries : Array[MetadataEntry]) -> Int {
  let mut total = 0
  for entry in entries {
    total = total + entry.value.length()
  }
  total
}

///|
pub fn is_metadata_key(key : String) -> Bool {
  if key.length() == 0 {
    return false
  }
  for character in key {
    let code = character.to_int()
    if code < 33 || code > 126 || character == ',' {
      return false
    }
  }
  true
}

///|
fn metadata_contains_key(entries : Array[MetadataEntry], key : String) -> Bool {
  for entry in entries {
    if entry.key == key {
      return true
    }
  }
  false
}

///|
fn metadata_size_error(limit : Int, actual : Int) -> TusError {
  tus_error(
    MetadataTooLarge,
    "TUS_METADATA_TOO_LARGE",
    "Upload-Metadata exceeds the configured byte budget",
    status=413,
    header_name=Some("upload-metadata"),
    expected=Some(limit.to_string()),
    actual=Some(actual.to_string()),
  )
}
