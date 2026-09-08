///|
/// Render a stable line-oriented report suitable for terminals and snapshots.
pub fn render_scenario_text(report : ScenarioReport) -> String {
  let output = StringBuilder()
  output.write_string("MoonTusCore scenario\n")
  output.write_string("result: ")
  output.write_string(if report.succeeded { "success" } else { "failure" })
  output.write_string("\nevents: ")
  output.write_string(report.events.length().to_string())
  output.write_string("\nuploads: ")
  output.write_string(report.uploads.length().to_string())
  output.write_char('\n')
  for event in report.events {
    output.write_char('#')
    output.write_string(event.index.to_string())
    output.write_char(' ')
    output.write_string(event.operation)
    match event.resource_name {
      None => ()
      Some(name) => {
        output.write_string(" name=")
        output.write_string(name)
      }
    }
    output.write_string(" status=")
    output.write_string(event.status.to_string())
    match event.offset {
      None => ()
      Some(offset) => {
        output.write_string(" offset=")
        output.write_string(offset.to_string())
      }
    }
    match event.error_code {
      None => ()
      Some(code) => {
        output.write_string(" error=")
        output.write_string(code)
      }
    }
    output.write_char('\n')
  }
  for upload in report.uploads {
    output.write_string("upload ")
    output.write_string(upload.identifier)
    output.write_string(" offset=")
    output.write_string(upload.offset.to_string())
    output.write_string(" length=")
    output.write_string(upload_length_name(upload.length))
    output.write_string(" state=")
    output.write_string(lifecycle_name(upload.lifecycle))
    output.write_string(" revision=")
    output.write_string(upload.revision.to_string())
    output.write_char('\n')
  }
  output.to_string()
}

///|
/// Render self-contained JSON without requiring a JSON dependency in the core
/// package. All dynamic strings pass through a conservative control escaper.
pub fn render_scenario_json(report : ScenarioReport) -> String {
  let output = StringBuilder()
  output.write_string("{\"schema\":\"moontuscore.scenario.v1\",\"succeeded\":")
  output.write_string(if report.succeeded { "true" } else { "false" })
  output.write_string(",\"events\":[")
  for index, event in report.events {
    if index > 0 {
      output.write_char(',')
    }
    render_event_json(output, event)
  }
  output.write_string("],\"uploads\":[")
  for index, upload in report.uploads {
    if index > 0 {
      output.write_char(',')
    }
    render_upload_json(output, upload)
  }
  output.write_string("]}")
  output.to_string()
}

///|
pub fn render_response_text(response : TusResponse) -> String {
  let output = StringBuilder()
  output.write_string("status ")
  output.write_string(response.status.to_string())
  output.write_char('\n')
  for field in response.headers.as_array() {
    output.write_string(field.name)
    output.write_string(": ")
    output.write_string(field.value)
    output.write_char('\n')
  }
  match response.error {
    None => ()
    Some(error) => {
      output.write_string("error-code: ")
      output.write_string(error.code)
      output.write_char('\n')
      output.write_string("error-message: ")
      output.write_string(error.message)
      output.write_char('\n')
    }
  }
  for step in response.trace {
    output.write_string("trace: ")
    output.write_string(step.code)
    output.write_string(" [")
    output.write_string(step.protocol_section)
    output.write_string("] ")
    output.write_string(step.message)
    output.write_char('\n')
  }
  output.to_string()
}

///|
fn render_event_json(output : StringBuilder, event : ScenarioEvent) -> Unit {
  output.write_string("{\"index\":")
  output.write_string(event.index.to_string())
  output.write_string(",\"operation\":")
  write_json_string(output, event.operation)
  output.write_string(",\"resourceName\":")
  write_optional_json_string(output, event.resource_name)
  output.write_string(",\"identifier\":")
  write_optional_json_string(output, event.identifier)
  output.write_string(",\"status\":")
  output.write_string(event.status.to_string())
  output.write_string(",\"offset\":")
  match event.offset {
    None => output.write_string("null")
    Some(offset) => output.write_string(offset.to_string())
  }
  output.write_string(",\"errorCode\":")
  write_optional_json_string(output, event.error_code)
  output.write_string(",\"trace\":[")
  for index, step in event.traces {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"code\":")
    write_json_string(output, step.code)
    output.write_string(",\"message\":")
    write_json_string(output, step.message)
    output.write_string(",\"section\":")
    write_json_string(output, step.protocol_section)
    output.write_char('}')
  }
  output.write_string("]}")
}

///|
fn render_upload_json(output : StringBuilder, upload : UploadRecord) -> Unit {
  output.write_string("{\"identifier\":")
  write_json_string(output, upload.identifier)
  output.write_string(",\"offset\":")
  output.write_string(upload.offset.to_string())
  output.write_string(",\"length\":")
  match upload.length {
    Deferred => output.write_string("null")
    Known(total) => output.write_string(total.to_string())
  }
  output.write_string(",\"deferred\":")
  output.write_string(if upload.length == Deferred { "true" } else { "false" })
  output.write_string(",\"lifecycle\":")
  write_json_string(output, lifecycle_name(upload.lifecycle))
  output.write_string(",\"revision\":")
  output.write_string(upload.revision.to_string())
  output.write_string(",\"storedBytes\":")
  output.write_string(upload.data.length().to_string())
  output.write_string(",\"metadata\":[")
  for index, entry in upload.metadata {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"key\":")
    write_json_string(output, entry.key)
    output.write_string(",\"base64\":")
    write_json_string(output, encode_base64(entry.value))
    output.write_char('}')
  }
  output.write_string("]}")
}

///|
fn write_optional_json_string(output : StringBuilder, value : String?) -> Unit {
  match value {
    None => output.write_string("null")
    Some(text) => write_json_string(output, text)
  }
}

///|
fn write_json_string(output : StringBuilder, value : String) -> Unit {
  output.write_char('"')
  for character in value {
    match character {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      _ => {
        let code = character.to_int()
        if code < 32 {
          output.write_string("\\u00")
          output.write_char(hex_digit((code >> 4) & 15))
          output.write_char(hex_digit(code & 15))
        } else {
          output.write_char(character)
        }
      }
    }
  }
  output.write_char('"')
}

///|
fn hex_digit(value : Int) -> Char {
  if value < 10 {
    (value + '0'.to_int()).unsafe_to_char()
  } else {
    (value - 10 + 'a'.to_int()).unsafe_to_char()
  }
}
