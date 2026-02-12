// Structured output and logging helpers for CLI applications

///|
/// Log level for structured logging.
pub enum LogLevel {
  Info
  Warn
  Error
  Debug
} derive(Show)

///|
/// Format a structured log message with level prefix.
fn format_log(level : LogLevel, message : String) -> String {
  let level_str = match level {
    Info => "INFO"
    Warn => "WARN"
    Error => "ERROR"
    Debug => "DEBUG"
  }
  "[\{level_str}] \{message}"
}

///|
/// Log an informational message.
///
/// Example:
/// ```moonbit nocheck
/// log_info("Server started on port 8080")
/// // Output: [INFO] Server started on port 8080
/// ```
pub fn log_info(message : String) -> Unit {
  println(format_log(Info, message))
}

///|
/// Log a warning message.
///
/// Example:
/// ```moonbit nocheck
/// log_warn("Deprecated flag --old-format used")
/// // Output: [WARN] Deprecated flag --old-format used
/// ```
pub fn log_warn(message : String) -> Unit {
  println(format_log(Warn, message))
}

///|
/// Log an error message to stdout.
/// Note: For stderr output, use @sys.eprint directly.
///
/// Example:
/// ```moonbit nocheck
/// log_error("Failed to connect to database")
/// // Output: [ERROR] Failed to connect to database
/// ```
pub fn log_error(message : String) -> Unit {
  println(format_log(Error, message))
}

///|
/// Log a debug message.
///
/// Example:
/// ```moonbit nocheck
/// log_debug("Request payload: {\"id\": 123}")
/// // Output: [DEBUG] Request payload: {"id": 123}
/// ```
pub fn log_debug(message : String) -> Unit {
  println(format_log(Debug, message))
}

///|
/// Format a success message with a checkmark prefix.
///
/// Example:
/// ```moonbit nocheck
/// success("Deployment completed")
/// // Output: ✓ Deployment completed
/// ```
pub fn success(message : String) -> Unit {
  println("✓ \{message}")
}

///|
/// Format a failure message with a cross prefix.
///
/// Example:
/// ```moonbit nocheck
/// failure("Build failed")
/// // Output: ✗ Build failed
/// ```
pub fn failure(message : String) -> Unit {
  println("✗ \{message}")
}

///|
/// Format a step message with a bullet prefix.
/// Useful for showing progress in multi-step operations.
///
/// Example:
/// ```moonbit nocheck
/// step("Compiling sources...")
/// // Output: • Compiling sources...
/// ```
pub fn step(message : String) -> Unit {
  println("• \{message}")
}

///|
/// Print a section header with emphasis.
///
/// Example:
/// ```moonbit nocheck
/// section("Build Results")
/// // Output:
/// // === Build Results ===
/// ```
pub fn section(title : String) -> Unit {
  println("=== \{title} ===")
}

///|
/// Print a key-value pair formatted for output.
///
/// Example:
/// ```moonbit nocheck
/// kv("Status", "running")
/// kv("Port", "8080")
/// // Output:
/// //   Status: running
/// //   Port:   8080
/// ```
pub fn kv(key : String, value : String) -> Unit {
  println("  \{key}: \{value}")
}
