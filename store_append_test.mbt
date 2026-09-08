///|
fn planned_append(
  record : UploadRecord,
  body : Bytes,
  length? : Int64? = None,
) -> AppendPlan {
  let resolved = match length {
    None => record.length
    Some(total) => Known(total)
  }
  let end = record.offset + body.length().to_int64()
  {
    identifier: record.identifier,
    expected_revision: record.revision,
    old_offset: record.offset,
    new_offset: end,
    resolved_length: resolved,
    body,
    completes_upload: match resolved {
      Known(total) => total == end
      Deferred => false
    },
  }
}

///|
test "store commits append and increments revision" {
  let limits = TusLimits::strict_test()
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(6L), metadata: [], }, limits)
    .unwrap()
  let first = store
    .commit_append(planned_append(created, b"abc"), limits)
    .unwrap()
  assert_eq(first.offset, 3L)
  assert_eq(first.revision, 1L)
  assert_eq(first.data, b"abc")
  let second = store
    .commit_append(planned_append(first, b"def"), limits)
    .unwrap()
  assert_eq(second.offset, 6L)
  assert_eq(second.revision, 2L)
  assert_eq(second.lifecycle, Complete)
  assert_eq(second.data, b"abcdef")
}

///|
test "store compare and swap rejects replayed plan" {
  let limits = TusLimits::strict_test()
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(4L), metadata: [], }, limits)
    .unwrap()
  let plan = planned_append(created, b"ab")
  let _ = store.commit_append(plan, limits).unwrap()
  match store.commit_append(plan, limits) {
    Err(error) => assert_eq(error.kind, StorageConflict)
    Ok(_) => fail("replayed plan must fail")
  }
  assert_eq(store.get(created.identifier).unwrap().data, b"ab")
}

///|
test "store rejects tampered new offset without mutation" {
  let limits = TusLimits::strict_test()
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(8L), metadata: [], }, limits)
    .unwrap()
  let invalid = { ..planned_append(created, b"abc"), new_offset: 7L, }
  match store.commit_append(invalid, limits) {
    Err(error) => assert_eq(error.code, "TUS_APPEND_PLAN_END_INVALID")
    Ok(_) => fail("tampered plan must fail")
  }
  let unchanged = store.get(created.identifier).unwrap()
  assert_eq(unchanged.offset, 0L)
  assert_eq(unchanged.data, b"")
}

///|
test "store rejects changed known length" {
  let limits = TusLimits::strict_test()
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(8L), metadata: [], }, limits)
    .unwrap()
  let invalid = {
    ..planned_append(created, b"abc"),
    resolved_length: Known(7L),
  }
  match store.commit_append(invalid, limits) {
    Err(error) => assert_eq(error.code, "TUS_APPEND_PLAN_LENGTH_CHANGED")
    Ok(_) => fail("known length mutation must fail")
  }
}

///|
test "store commits deferred length declaration atomically" {
  let limits = TusLimits::strict_test()
  let store = MemoryStore::new()
  let created = store
    .create({ length: Deferred, metadata: [], }, limits)
    .unwrap()
  let updated = store
    .commit_append(planned_append(created, b"abc", length=Some(3L)), limits)
    .unwrap()
  assert_eq(updated.length, Known(3L))
  assert_eq(updated.lifecycle, Complete)
}

///|
test "store leaves resource unchanged after stale revision" {
  let limits = TusLimits::strict_test()
  let store = MemoryStore::new()
  let created = store
    .create({ length: Known(2L), metadata: [], }, limits)
    .unwrap()
  let invalid = { ..planned_append(created, b"a"), expected_revision: 9L, }
  match store.commit_append(invalid, limits) {
    Err(error) => assert_eq(error.kind, StorageConflict)
    Ok(_) => fail("stale revision must fail")
  }
  assert_eq(store.get(created.identifier).unwrap(), created)
}
