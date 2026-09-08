///|
/// Declarative actions for deterministic protocol demonstrations and adapter
/// conformance fixtures. Aliases avoid coupling scenarios to generated IDs.
pub(all) enum ScenarioAction {
  Discover
  CreateKnown(String, Int64, Array[MetadataEntry])
  CreateDeferred(String, Array[MetadataEntry])
  Inspect(String)
  Append(String, Int64, Bytes, Int64?)
} derive(Debug, Eq)

///|
pub(all) struct ScenarioEvent {
  index : Int
  operation : String
  resource_name : String?
  identifier : String?
  status : Int
  offset : Int64?
  error_code : String?
  traces : Array[TraceStep]
} derive(Debug, Eq)

///|
pub(all) struct ScenarioReport {
  events : Array[ScenarioEvent]
  uploads : Array[UploadRecord]
  succeeded : Bool
} derive(Debug, Eq)

///|
priv struct AliasBinding {
  resource_name : String
  identifier : String
}

///|
/// Execute every action in order. Protocol failures are captured as events and
/// later independent actions still run, making one report useful for teaching
/// both successful and rejected transitions.
pub fn run_scenario(
  actions : Array[ScenarioAction],
  config? : TusConfig = TusConfig::default(),
) -> Result[ScenarioReport, TusError] {
  let engine = match TusEngine::new(config~) {
    Err(error) => return Err(error)
    Ok(engine) => engine
  }
  let bindings : Array[AliasBinding] = []
  let events : Array[ScenarioEvent] = []
  let mut succeeded = true
  for index, action in actions {
    let event = execute_scenario_action(index, action, engine, bindings)
    if event.status >= 400 {
      succeeded = false
    }
    events.push(event)
  }
  Ok({ events, uploads: engine.uploads(), succeeded, })
}

///|
fn execute_scenario_action(
  index : Int,
  action : ScenarioAction,
  engine : TusEngine,
  bindings : Array[AliasBinding],
) -> ScenarioEvent {
  match action {
    Discover =>
      event_from_response(
        index,
        "OPTIONS",
        None,
        None,
        engine.handle(options_request()),
      )
    CreateKnown(resource_name, length, metadata) => {
      if !valid_resource_name(resource_name) ||
        find_binding(bindings, resource_name) is Some(_) {
        return invalid_scenario_event(
          index, "CREATE", resource_name, "resource name is invalid or already bound",
        )
      }
      let headers = version_response_headers()
        .add("Upload-Length", length.to_string())
        .add("Upload-Metadata", serialize_upload_metadata(metadata))
      let response = engine.handle(
        request("POST", engine.config.collection_path, headers~),
      )
      bind_created_resource(bindings, resource_name, response)
      event_from_response(
        index,
        "POST",
        Some(resource_name),
        created_identifier(response),
        response,
      )
    }
    CreateDeferred(resource_name, metadata) => {
      if !valid_resource_name(resource_name) ||
        find_binding(bindings, resource_name) is Some(_) {
        return invalid_scenario_event(
          index, "CREATE-DEFERRED", resource_name, "resource name is invalid or already bound",
        )
      }
      let headers = version_response_headers()
        .add("Upload-Defer-Length", "1")
        .add("Upload-Metadata", serialize_upload_metadata(metadata))
      let response = engine.handle(
        request("POST", engine.config.collection_path, headers~),
      )
      bind_created_resource(bindings, resource_name, response)
      event_from_response(
        index,
        "POST-DEFERRED",
        Some(resource_name),
        created_identifier(response),
        response,
      )
    }
    Inspect(resource_name) =>
      match find_binding(bindings, resource_name) {
        None =>
          invalid_scenario_event(
            index, "HEAD", resource_name, "resource name has not been created",
          )
        Some(identifier) => {
          let response = engine.handle(
            request(
              "HEAD",
              resource_path(engine.config.collection_path, identifier),
              headers=version_response_headers(),
            ),
          )
          event_from_response(
            index,
            "HEAD",
            Some(resource_name),
            Some(identifier),
            response,
          )
        }
      }
    Append(resource_name, offset, body, declared_length) =>
      match find_binding(bindings, resource_name) {
        None =>
          invalid_scenario_event(
            index, "PATCH", resource_name, "resource name has not been created",
          )
        Some(identifier) => {
          let headers = version_response_headers()
            .add("Upload-Offset", offset.to_string())
            .add("Content-Type", "application/offset+octet-stream")
            .add("Content-Length", body.length().to_string())
          let headers = match declared_length {
            None => headers
            Some(total) => headers.add("Upload-Length", total.to_string())
          }
          let response = engine.handle(
            request(
              "PATCH",
              resource_path(engine.config.collection_path, identifier),
              headers~,
              body~,
            ),
          )
          event_from_response(
            index,
            "PATCH",
            Some(resource_name),
            Some(identifier),
            response,
          )
        }
      }
  }
}

///|
fn event_from_response(
  index : Int,
  operation : String,
  resource_name : String?,
  identifier : String?,
  response : TusResponse,
) -> ScenarioEvent {
  {
    index,
    operation,
    resource_name,
    identifier,
    status: response.status,
    offset: response_offset(response),
    error_code: response_error_code(response),
    traces: response.trace.copy(),
  }
}

///|
fn invalid_scenario_event(
  index : Int,
  operation : String,
  resource_name : String,
  message : String,
) -> ScenarioEvent {
  let error = tus_error(InvalidScenario, "TUS_SCENARIO_INVALID", message)
  {
    index,
    operation,
    resource_name: Some(resource_name),
    identifier: None,
    status: error.status,
    offset: None,
    error_code: Some(error.code),
    traces: [],
  }
}

///|
fn bind_created_resource(
  bindings : Array[AliasBinding],
  resource_name : String,
  response : TusResponse,
) -> Unit {
  match created_identifier(response) {
    None => ()
    Some(identifier) => bindings.push({ resource_name, identifier, })
  }
}

///|
fn created_identifier(response : TusResponse) -> String? {
  if response.status != 201 {
    return None
  }
  match response.headers.first("location") {
    None => None
    Some(location) => {
      let mut slash = -1
      for index, character in location {
        if character == '/' {
          slash = index
        }
      }
      if slash < 0 || slash + 1 >= location.length() {
        None
      } else {
        Some(location[slash + 1:].to_owned())
      }
    }
  }
}

///|
fn find_binding(
  bindings : Array[AliasBinding],
  resource_name : String,
) -> String? {
  for binding in bindings {
    if binding.resource_name == resource_name {
      return Some(binding.identifier)
    }
  }
  None
}

///|
fn valid_resource_name(resource_name : String) -> Bool {
  if resource_name.length() == 0 || resource_name.length() > 64 {
    return false
  }
  for character in resource_name {
    if !(character >= 'a' && character <= 'z') &&
      !(character >= 'A' && character <= 'Z') &&
      !(character >= '0' && character <= '9') &&
      character != '-' &&
      character != '_' {
      return false
    }
  }
  true
}
