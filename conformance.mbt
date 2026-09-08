///|
/// Post-request storage assertion attached to a conformance vector.
pub(all) enum StoreExpectation {
  IgnoreStore
  ResourceMissing(String)
  ResourceState(String, Int64, UploadLength, UploadLifecycle, Bytes)
} derive(Debug, Eq)

///|
pub(all) struct ConformanceExpectation {
  status : Int
  error_code : String?
  response_offset : Int64?
  store : StoreExpectation
} derive(Debug, Eq)

///|
pub(all) struct ConformanceVector {
  name : String
  initial_records : Array[UploadRecord]
  request : TusRequest
  expected : ConformanceExpectation
} derive(Debug, Eq)

///|
pub(all) struct ConformanceResult {
  name : String
  passed : Bool
  response : TusResponse
  findings : Array[String]
} derive(Debug, Eq)

///|
pub(all) struct ConformanceReport {
  results : Array[ConformanceResult]
  passed : Int
  failed : Int
} derive(Debug, Eq)

///|
pub fn run_conformance_vector(
  vector : ConformanceVector,
  config? : TusConfig = config(limits=TusLimits::strict_test()),
) -> Result[ConformanceResult, TusError] {
  let store = MemoryStore::new()
  for record in vector.initial_records {
    match store.import_record(record, config.limits) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  let engine = match TusEngine::new(config~, store~) {
    Err(error) => return Err(error)
    Ok(engine) => engine
  }
  let response = engine.handle(vector.request)
  let findings : Array[String] = []
  if response.status != vector.expected.status {
    findings.push(
      "status expected " +
      vector.expected.status.to_string() +
      " but received " +
      response.status.to_string(),
    )
  }
  let actual_error = response_error_code(response)
  if actual_error != vector.expected.error_code {
    findings.push(
      "error code expected " +
      optional_text(vector.expected.error_code) +
      " but received " +
      optional_text(actual_error),
    )
  }
  let actual_offset = response_offset(response)
  if actual_offset != vector.expected.response_offset {
    findings.push(
      "response offset expected " +
      optional_offset(vector.expected.response_offset) +
      " but received " +
      optional_offset(actual_offset),
    )
  }
  check_store_expectation(engine, vector.expected.store, findings)
  Ok({ name: vector.name, passed: findings.length() == 0, response, findings, })
}

///|
pub fn run_conformance_suite(
  vectors : Array[ConformanceVector],
  config? : TusConfig = config(limits=TusLimits::strict_test()),
) -> Result[ConformanceReport, TusError] {
  let results : Array[ConformanceResult] = []
  let mut passed = 0
  let mut failed = 0
  for vector in vectors {
    let result = match run_conformance_vector(vector, config~) {
      Err(error) => return Err(error)
      Ok(result) => result
    }
    if result.passed {
      passed = passed + 1
    } else {
      failed = failed + 1
    }
    results.push(result)
  }
  Ok({ results, passed, failed, })
}

///|
pub fn core_conformance_vectors() -> Array[ConformanceVector] {
  let version = version_response_headers()
  let patch_base = version
    .add("Content-Type", "application/offset+octet-stream")
    .add("Content-Length", "3")
  [
    {
      name: "options-discovery",
      initial_records: [],
      request: options_request(),
      expected: {
        status: 204,
        error_code: None,
        response_offset: None,
        store: IgnoreStore,
      },
    },
    {
      name: "create-known-length",
      initial_records: [],
      request: request(
        "POST",
        "/files",
        headers=version.add("Upload-Length", "3"),
      ),
      expected: {
        status: 201,
        error_code: None,
        response_offset: Some(0L),
        store: ResourceState("u000000000001", 0L, Known(3L), Active, b""),
      },
    },
    {
      name: "create-missing-length",
      initial_records: [],
      request: request("POST", "/files", headers=version),
      expected: {
        status: 400,
        error_code: Some("TUS_REQUIRED_HEADER_MISSING"),
        response_offset: None,
        store: ResourceMissing("u000000000001"),
      },
    },
    {
      name: "head-known-resource",
      initial_records: [upload_record("seed", Known(3L))],
      request: request("HEAD", "/files/seed", headers=version),
      expected: {
        status: 200,
        error_code: None,
        response_offset: Some(0L),
        store: ResourceState("seed", 0L, Known(3L), Active, b""),
      },
    },
    {
      name: "head-missing-resource",
      initial_records: [],
      request: request("HEAD", "/files/missing", headers=version),
      expected: {
        status: 404,
        error_code: Some("TUS_UPLOAD_NOT_FOUND"),
        response_offset: None,
        store: ResourceMissing("missing"),
      },
    },
    {
      name: "patch-completes-resource",
      initial_records: [upload_record("seed", Known(3L))],
      request: request(
        "PATCH",
        "/files/seed",
        headers=patch_base.add("Upload-Offset", "0"),
        body=b"abc",
      ),
      expected: {
        status: 204,
        error_code: None,
        response_offset: Some(3L),
        store: ResourceState("seed", 3L, Known(3L), Complete, b"abc"),
      },
    },
    {
      name: "patch-rejects-stale-offset",
      initial_records: [seeded_record("seed", 3L, Known(6L), b"abc")],
      request: request(
        "PATCH",
        "/files/seed",
        headers=patch_base.add("Upload-Offset", "0"),
        body=b"bad",
      ),
      expected: {
        status: 409,
        error_code: Some("TUS_OFFSET_MISMATCH"),
        response_offset: None,
        store: ResourceState("seed", 3L, Known(6L), Active, b"abc"),
      },
    },
    {
      name: "patch-rejects-wrong-content-type",
      initial_records: [upload_record("seed", Known(3L))],
      request: request(
        "PATCH",
        "/files/seed",
        headers=version
          .add("Content-Type", "text/plain")
          .add("Content-Length", "3")
          .add("Upload-Offset", "0"),
        body=b"abc",
      ),
      expected: {
        status: 415,
        error_code: Some("TUS_PATCH_CONTENT_TYPE_INVALID"),
        response_offset: None,
        store: ResourceState("seed", 0L, Known(3L), Active, b""),
      },
    },
    {
      name: "patch-declares-deferred-length",
      initial_records: [upload_record("seed", Deferred)],
      request: request(
        "PATCH",
        "/files/seed",
        headers=patch_base.add("Upload-Offset", "0").add("Upload-Length", "3"),
        body=b"abc",
      ),
      expected: {
        status: 204,
        error_code: None,
        response_offset: Some(3L),
        store: ResourceState("seed", 3L, Known(3L), Complete, b"abc"),
      },
    },
    {
      name: "unsupported-version-before-mutation",
      initial_records: [upload_record("seed", Known(3L))],
      request: request(
        "PATCH",
        "/files/seed",
        headers=Headers::empty()
          .add("Tus-Resumable", "0.2.2")
          .add("Content-Type", "application/offset+octet-stream")
          .add("Content-Length", "3")
          .add("Upload-Offset", "0"),
        body=b"abc",
      ),
      expected: {
        status: 412,
        error_code: Some("TUS_VERSION_UNSUPPORTED"),
        response_offset: None,
        store: ResourceState("seed", 0L, Known(3L), Active, b""),
      },
    },
  ]
}

///|
fn check_store_expectation(
  engine : TusEngine,
  expectation : StoreExpectation,
  findings : Array[String],
) -> Unit {
  match expectation {
    IgnoreStore => ()
    ResourceMissing(identifier) =>
      if engine.snapshot(identifier) is Ok(_) {
        findings.push("resource " + identifier + " should not exist")
      }
    ResourceState(identifier, offset, length, state, data) =>
      match engine.snapshot(identifier) {
        Err(_) => findings.push("resource " + identifier + " is missing")
        Ok(record) => {
          if record.offset != offset {
            findings.push("stored offset differs for " + identifier)
          }
          if record.length != length {
            findings.push("stored length differs for " + identifier)
          }
          if record.lifecycle != state {
            findings.push("stored lifecycle differs for " + identifier)
          }
          if record.data != data {
            findings.push("stored bytes differ for " + identifier)
          }
        }
      }
  }
}

///|
fn seeded_record(
  identifier : String,
  offset : Int64,
  length : UploadLength,
  data : Bytes,
) -> UploadRecord {
  {
    ..upload_record(identifier, length),
    offset,
    revision: if offset == 0L {
      0L
    } else {
      1L
    },
    lifecycle: lifecycle(offset, length),
    data,
  }
}

///|
fn optional_text(value : String?) -> String {
  match value {
    None => "<none>"
    Some(text) => text
  }
}

///|
fn optional_offset(value : Int64?) -> String {
  match value {
    None => "<none>"
    Some(offset) => offset.to_string()
  }
}
