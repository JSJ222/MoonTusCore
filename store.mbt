///|
/// Reference store for tests, examples and single-process adapters.
///
/// The protocol engine only needs snapshot, create and compare-and-swap append
/// operations. Production adapters can map those same operations to files,
/// object storage or a database without importing an HTTP framework.
pub struct MemoryStore {
  priv records : Array[UploadRecord]
  priv mut next_sequence : Int64
}

///|
pub fn MemoryStore::new(seed? : Int64 = 1L) -> MemoryStore {
  { records: [], next_sequence: seed, }
}

///|
pub fn MemoryStore::count(self : MemoryStore) -> Int {
  self.records.length()
}

///|
pub fn MemoryStore::is_empty(self : MemoryStore) -> Bool {
  self.records.length() == 0
}

///|
pub fn MemoryStore::contains(self : MemoryStore, identifier : String) -> Bool {
  self.index_of(identifier) is Some(_)
}

///|
pub fn MemoryStore::get(
  self : MemoryStore,
  identifier : String,
) -> Result[UploadRecord, TusError] {
  match self.index_of(identifier) {
    None => Err(upload_not_found(identifier))
    Some(index) => Ok(clone_record(self.records[index]))
  }
}

///|
pub fn MemoryStore::list(self : MemoryStore) -> Array[UploadRecord] {
  let output : Array[UploadRecord] = []
  for record in self.records {
    output.push(clone_record(record))
  }
  output
}

///|
pub fn MemoryStore::create(
  self : MemoryStore,
  plan : CreationPlan,
  limits : TusLimits,
) -> Result[UploadRecord, TusError] {
  let mut attempt = 0
  while attempt < limits.max_identifier_attempts {
    let identifier = sequence_identifier(self.next_sequence)
    match
      checked_add_i64(self.next_sequence, 1L, field_name="identifier-sequence") {
      Err(_) =>
        return Err(
          tus_error(
            IdentifierExhausted,
            "TUS_IDENTIFIER_EXHAUSTED",
            "reference store identifier sequence is exhausted",
            status=507,
          ),
        )
      Ok(next) => self.next_sequence = next
    }
    if !self.contains(identifier) {
      let record = upload_record(
        identifier,
        plan.length,
        metadata=plan.metadata,
      )
      match validate_record(record, limits) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      self.records.push(record)
      return Ok(clone_record(record))
    }
    attempt = attempt + 1
  }
  Err(
    tus_error(
      IdentifierExhausted,
      "TUS_IDENTIFIER_COLLISION_LIMIT",
      "reference store could not allocate a unique identifier",
      status=507,
      expected=Some(limits.max_identifier_attempts.to_string()),
    ),
  )
}

///|
/// Insert an explicit record for recovery/import workflows. It is also useful
/// to conformance tests that need precise revision and offset states.
pub fn MemoryStore::import_record(
  self : MemoryStore,
  record : UploadRecord,
  limits : TusLimits,
) -> Result[Unit, TusError] {
  if self.contains(record.identifier) {
    return Err(storage_conflict(record.identifier))
  }
  match validate_record(record, limits) {
    Err(error) => Err(error)
    Ok(_) => {
      self.records.push(clone_record(record))
      Ok(())
    }
  }
}

///|
pub fn validate_record(
  record : UploadRecord,
  limits : TusLimits,
) -> Result[Unit, TusError] {
  if !is_safe_identifier(record.identifier) {
    return Err(store_invariant("stored identifier is not a safe path segment"))
  }
  if record.offset < 0L || record.revision < 0L {
    return Err(
      store_invariant("stored offset and revision must be non-negative"),
    )
  }
  if record.data.length().to_int64() != record.offset {
    return Err(
      store_invariant("stored byte length does not equal Upload-Offset"),
    )
  }
  if record.offset > limits.max_upload_size {
    return Err(upload_too_large(limits.max_upload_size, record.offset))
  }
  match record.length {
    Deferred =>
      if record.lifecycle != Active {
        return Err(store_invariant("deferred upload cannot be complete"))
      }
    Known(total) => {
      if total < record.offset {
        return Err(store_invariant("stored offset exceeds Upload-Length"))
      }
      if total > limits.max_upload_size {
        return Err(upload_too_large(limits.max_upload_size, total))
      }
      if record.lifecycle != lifecycle(record.offset, record.length) {
        return Err(
          store_invariant("stored lifecycle disagrees with offset and length"),
        )
      }
    }
  }
  if record.metadata.length() > limits.max_metadata_entries ||
    metadata_decoded_size(record.metadata) > limits.max_metadata_bytes {
    return Err(store_invariant("stored metadata exceeds configured limits"))
  }
  Ok(())
}

///|
fn MemoryStore::index_of(self : MemoryStore, identifier : String) -> Int? {
  for index, record in self.records {
    if record.identifier == identifier {
      return Some(index)
    }
  }
  None
}

///|
fn clone_record(record : UploadRecord) -> UploadRecord {
  {
    identifier: record.identifier,
    offset: record.offset,
    length: record.length,
    metadata: record.metadata.copy(),
    revision: record.revision,
    lifecycle: record.lifecycle,
    data: record.data,
  }
}

///|
fn sequence_identifier(sequence : Int64) -> String {
  if sequence < 0L {
    return "u-invalid"
  }
  let alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
  let reversed = StringBuilder()
  let mut value = sequence
  if value == 0L {
    reversed.write_char('0')
  }
  while value > 0L {
    let digit = (value % 36L).to_int()
    reversed.write_char(alphabet[digit].to_int().unsafe_to_char())
    value = value / 36L
  }
  let body = reversed.to_string()
  let output = StringBuilder()
  output.write_char('u')
  let mut pad = body.length()
  while pad < 12 {
    output.write_char('0')
    pad = pad + 1
  }
  let mut index = body.length()
  while index > 0 {
    output.write_char(body[index - 1].to_int().unsafe_to_char())
    index = index - 1
  }
  output.to_string()
}

///|
fn store_invariant(message : String) -> TusError {
  tus_error(StorageFailure, "TUS_STORAGE_INVARIANT", message, status=500)
}
