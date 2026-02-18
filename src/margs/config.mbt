// Configuration file loading and parsing

///|
/// Load a JSON config file from a path.
/// Returns a map of key-value pairs for option defaults.
pub fn load_config_file(path : String) -> Map[String, String]? {
  // Try to read the file
  match read_file_safe(path) {
    Some(content) => parse_json_config(content)
    None => None
  }
}

///|
/// Safely read a file, returning None if it doesn't exist or can't be read.
fn read_file_safe(path : String) -> String? {
  Some(@fs.read_file_to_string(path)) catch {
    _ => None
  }
}

///|
/// Parse JSON content into a simple key-value map.
/// Only extracts top-level string values for simplicity.
pub fn parse_json_config(content : String) -> Map[String, String]? {
  let json = @json.parse(content) catch { _ => return None }

  match json {
    Object(entries) => {
      let config : Map[String, String] = Map::new()
      entries.each(fn(key, value) {
        match value {
          String(s) => config.set(key, s)
          Number(n, ..) =>
            match format_json_number(n) {
              Some(value) => config.set(key, value)
              None => ()
            }
          True => config.set(key, "true")
          False => config.set(key, "false")
          _ => ()
        }
      })
      if config.length() > 0 {
        Some(config)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Extract all quoted strings from JSON content.
fn format_json_number(value : Double) -> String? {
  if value.is_nan() ||
    value == @double.infinity ||
    value == @double.neg_infinity {
    None
  } else if value == value.round() {
    Some(value.round().to_int().to_string())
  } else {
    Some(value.to_string())
  }
}

///|
/// Try to auto-discover a config file in common locations.
/// Returns the first config file found, or None.
pub fn discover_config_file(app_name : String) -> String? {
  let candidates = [
    // Current directory
    ".\{app_name}rc",
    ".\{app_name}rc.json",
  ]
  // Home directory (if available)
  // Note: @sys.get_env_var("HOME") might not work on Windows

  for path in candidates {
    match read_file_safe(path) {
      Some(_) => return Some(path)
      None => ()
    }
  }

  None
}
