///|
test "memory store creates deterministic unique resources" {
  let store = MemoryStore::new()
  let limits = TusLimits::strict_test()
  let first = store
    .create({ length: Known(4L), metadata: [], }, limits)
    .unwrap()
  let second = store
    .create({ length: Deferred, metadata: [], }, limits)
    .unwrap()
  inspect(first.identifier, content="u000000000001")
  inspect(second.identifier, content="u000000000002")
  assert_eq(store.count(), 2)
  assert_eq(store.get(first.identifier).unwrap(), first)
}

///|
test "memory store returns snapshots rather than record array" {
  let store = MemoryStore::new()
  let record = store
    .create({ length: Known(1L), metadata: [], }, TusLimits::strict_test())
    .unwrap()
  let snapshot = store.list()
  snapshot.clear()
  assert_eq(store.count(), 1)
  assert_eq(store.contains(record.identifier), true)
}

///|
test "memory store reports missing resource" {
  match MemoryStore::new().get("absent") {
    Err(error) => {
      assert_eq(error.kind, UploadNotFound)
      assert_eq(error.status, 404)
    }
    Ok(_) => fail("missing resource must fail")
  }
}

///|
test "memory store imports a valid recovery snapshot" {
  let store = MemoryStore::new()
  let record : UploadRecord = {
    identifier: "recovered-1",
    offset: 3L,
    length: Known(5L),
    metadata: [],
    revision: 2L,
    lifecycle: Active,
    data: b"abc",
  }
  assert_eq(store.import_record(record, TusLimits::strict_test()), Ok(()))
  assert_eq(store.get("recovered-1").unwrap().offset, 3L)
}

///|
test "memory store rejects duplicate import" {
  let store = MemoryStore::new()
  let record = upload_record("same", Known(0L))
  assert_eq(store.import_record(record, TusLimits::strict_test()), Ok(()))
  match store.import_record(record, TusLimits::strict_test()) {
    Err(error) => assert_eq(error.kind, StorageConflict)
    Ok(_) => fail("duplicate identifier must fail")
  }
}

///|
test "record invariant checks data offset and lifecycle" {
  let invalid_offset = {
    ..upload_record("bad-offset", Known(4L)),
    offset: 2L,
    data: b"x",
  }
  match validate_record(invalid_offset, TusLimits::strict_test()) {
    Err(error) => assert_eq(error.code, "TUS_STORAGE_INVARIANT")
    Ok(_) => fail("data and offset mismatch must fail")
  }
  let invalid_lifecycle = {
    ..upload_record("bad-state", Known(0L)),
    lifecycle: Active,
  }
  match validate_record(invalid_lifecycle, TusLimits::strict_test()) {
    Err(error) => assert_eq(error.kind, StorageFailure)
    Ok(_) => fail("lifecycle mismatch must fail")
  }
}
