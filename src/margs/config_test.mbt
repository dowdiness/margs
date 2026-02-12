// Tests for config file loading

///|
test "parse simple JSON config" {
  let json = "{\"host\": \"example.com\", \"port\": \"8080\"}"
  match parse_json_config(json) {
    Some(config) => {
      inspect(config.get("host"), content="Some(\"example.com\")")
      inspect(config.get("port"), content="Some(\"8080\")")
    }
    None => inspect(false, content="true")
  }
}

///|
test "parse JSON config with whitespace" {
  let json = "{\n  \"host\": \"example.com\",\n  \"port\": \"8080\"\n}"
  match parse_json_config(json) {
    Some(config) => {
      inspect(config.get("host"), content="Some(\"example.com\")")
      inspect(config.get("port"), content="Some(\"8080\")")
    }
    None => inspect(false, content="true")
  }
}

///|
test "parse empty JSON returns None" {
  let json = "{}"
  match parse_json_config(json) {
    Some(_) => inspect(false, content="true")
    None => inspect(true, content="true")
  }
}

// TODO: Add support for escaped quotes in JSON values
// ///|
// test "parse JSON with escaped quotes" {
//   let json = "{\"message\": \"Hello \\\"World\\\"\"}"
//   match parse_json_config(json) {
//     Some(config) => {
//       inspect(config.get("message"), content="Some(\"Hello \\\"World\\\"\")")
//     }
//     None => inspect(false, content="true")
//   }
// }

///|
test "load nonexistent config file returns None" {
  match load_config_file("/nonexistent/path/config.json") {
    Some(_) => inspect(false, content="true")
    None => inspect(true, content="true")
  }
}
