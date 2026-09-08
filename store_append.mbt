///|
/// Commit a previously validated append using revision and offset as the
/// compare-and-swap precondition. Validation happens before the record array is
/// touched, so every failure leaves the store unchanged.
pub fn MemoryStore::commit_append(
  self : MemoryStore,
  plan : AppendPlan,
  limits : TusLimits,
) -> Result[UploadRecord, TusError] {
  let index = match self.index_of(plan.identifier) {
    None => return Err(upload_not_found(plan.identifier))
    Some(index) => index
  }
  let current = self.records[index]
  if current.revision != plan.expected_revision ||
    current.offset != plan.old_offset {
    return Err(storage_conflict(plan.identifier))
  }
  if current.is_complete() {
    return Err(upload_complete(plan.identifier))
  }
  match validate_append_plan(current, plan, limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let next_revision = match
    checked_add_i64(current.revision, 1L, field_name="storage-revision") {
    Err(_) => return Err(store_revision_exhausted(plan.identifier))
    Ok(value) => value
  }
  let bytes = current.data.to_array()
  for byte in plan.body {
    bytes.push(byte)
  }
  let updated : UploadRecord = {
    identifier: current.identifier,
    offset: plan.new_offset,
    length: plan.resolved_length,
    metadata: current.metadata.copy(),
    revision: next_revision,
    lifecycle: lifecycle(plan.new_offset, plan.resolved_length),
    data: Bytes::from_array(bytes),
  }
  match validate_record(updated, limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  self.records[index] = updated
  Ok(clone_record(updated))
}

///|
pub fn validate_append_plan(
  current : UploadRecord,
  plan : AppendPlan,
  limits : TusLimits,
) -> Result[Unit, TusError] {
  if current.identifier != plan.identifier {
    return Err(storage_conflict(plan.identifier))
  }
  let computed_end = match
    checked_body_end(plan.old_offset, plan.body.length()) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  if computed_end != plan.new_offset {
    return Err(
      tus_error(
        InternalInvariant,
        "TUS_APPEND_PLAN_END_INVALID",
        "append plan new offset does not equal old offset plus body size",
        status=500,
        expected=Some(computed_end.to_string()),
        actual=Some(plan.new_offset.to_string()),
      ),
    )
  }
  match validate_patch_size(plan.body, limits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if plan.new_offset > limits.max_upload_size {
    return Err(upload_too_large(limits.max_upload_size, plan.new_offset))
  }
  match (current.length, plan.resolved_length) {
    (Known(before), Known(after)) if before == after => ()
    (Deferred, Deferred) => ()
    (Deferred, Known(after)) => {
      if after < plan.new_offset {
        return Err(
          tus_error(
            InternalInvariant,
            "TUS_APPEND_PLAN_LENGTH_INVALID",
            "resolved length is smaller than the new offset",
            status=500,
          ),
        )
      }
      match validate_declared_size(after, limits) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
    _ =>
      return Err(
        tus_error(
          InternalInvariant,
          "TUS_APPEND_PLAN_LENGTH_CHANGED",
          "append plan changes an already declared length",
          status=500,
        ),
      )
  }
  let expected_complete = match plan.resolved_length {
    Known(total) => plan.new_offset == total
    Deferred => false
  }
  if expected_complete != plan.completes_upload {
    return Err(
      tus_error(
        InternalInvariant,
        "TUS_APPEND_PLAN_COMPLETION_INVALID",
        "append plan completion flag disagrees with offset and length",
        status=500,
      ),
    )
  }
  Ok(())
}

///|
fn store_revision_exhausted(identifier : String) -> TusError {
  tus_error(
    StorageFailure,
    "TUS_STORAGE_REVISION_EXHAUSTED",
    "storage revision counter cannot be incremented",
    status=507,
    actual=Some(identifier),
  )
}
