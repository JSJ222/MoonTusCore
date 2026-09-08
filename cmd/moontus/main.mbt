///|
extern "C" fn process_exit(code : Int) = "exit"

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println(@tus.demo_help())
    return
  }
  match args[1] {
    "demo" => run_demo_command(args)
    "capabilities" => print_capabilities()
    "version" | "--version" | "-V" => println("moontus 0.1.0")
    "help" | "--help" | "-h" => println(@tus.demo_help())
    command => {
      println("MOONTUS_ARGUMENT: unknown command: " + command)
      println(@tus.demo_help())
      process_exit(2)
    }
  }
}

///|
fn run_demo_command(args : Array[String]) -> Unit {
  if args.length() > 4 {
    println("MOONTUS_ARGUMENT: too many demo arguments")
    process_exit(2)
    return
  }
  let mut name = "success"
  let mut name_selected = false
  let mut json = false
  for index in 2..<args.length() {
    if args[index] == "--json" {
      json = true
    } else if !name_selected {
      name = args[index]
      name_selected = true
    } else {
      println("MOONTUS_ARGUMENT: only one demo name is accepted")
      process_exit(2)
      return
    }
  }
  match @tus.run_named_demo(name) {
    Err(error) => {
      println(error.code + ": " + error.message)
      process_exit(2)
    }
    Ok(report) => {
      if json {
        println(@tus.render_scenario_json(report))
      } else {
        println(@tus.render_scenario_text(report))
      }
      if !report.succeeded && name != "conflict" && name != "limits" {
        process_exit(3)
      }
    }
  }
}

///|
fn print_capabilities() -> Unit {
  let engine = @tus.TusEngine::new().unwrap()
  let response = engine.handle(@tus.options_request())
  println(@tus.render_response_text(response))
}
