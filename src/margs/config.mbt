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
  // Simple JSON parsing for flat key-value pairs
  // Format: { "key": "value", "port": "8080" }

  let config : Map[String, String] = Map::new()
  let strings = extract_strings(content)

  // Pair up strings: [key, value, key, value, ...]
  let mut i = 0
  while i + 1 < strings.length() {
    config.set(strings[i], strings[i + 1])
    i = i + 2
  }

  if config.length() > 0 {
    Some(config)
  } else {
    None
  }
}

///|
/// Extract all quoted strings from JSON content.
fn extract_strings(content : String) -> Array[String] {
  let strings : Array[String] = []
  let mut i = 0
  let mut in_string = false
  let mut start_pos = 0
  let mut escape = false

  while i < content.length() {
    let ch = content[i]

    if escape {
      escape = false
      i = i + 1
      continue
    }

    if ch == '\\' && in_string {
      escape = true
      i = i + 1
      continue
    }

    if ch == '"' {
      if in_string {
        // End of string - extract substring
        // Note: Using substring() despite deprecation warning because the recommended
        // slice syntax str[start:end] returns StringView, and StringView.to_string()
        // requires error handling that complicates this internal function.
        // TODO: Migrate to slice syntax when error handling patterns are clearer.
        let str_content = content.substring(start=start_pos, end=i)
        strings.push(str_content)
        in_string = false
      } else {
        // Start of new string
        in_string = true
        start_pos = i + 1
      }
    }

    i = i + 1
  }

  strings
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
