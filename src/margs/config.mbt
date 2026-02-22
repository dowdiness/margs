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
/// Extracts top-level string, number, and boolean values.
/// Numbers are formatted via `format_json_number`, booleans map to "true"/"false".
/// Non-primitive values are ignored.
pub fn parse_json_config(content : String) -> Map[String, String]? {
  let json = @json.parse(content) catch { _ => return None }

  match json {
    Object(entries) => {
      let config : Map[String, String] = Map::new()
      entries.each(fn(key, value) {
        match value {
          String(s) => config.set(key, s)
          Number(n, repr~) =>
            match format_json_number(n, repr) {
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
/// Format a JSON numeric value as a String, preserving integer formatting when possible.
/// Returns None for NaN or Infinity. When repr is available, returns it directly
/// to preserve the original textual representation (avoids 32-bit Int overflow for
/// large integers). Falls back to value.to_string() when repr is None.
fn format_json_number(value : Double, repr : String?) -> String? {
  if value.is_nan() ||
    value == @double.infinity ||
    value == @double.neg_infinity {
    None
  } else {
    match repr {
      Some(raw) => Some(raw)
      None => Some(value.to_string())
    }
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
