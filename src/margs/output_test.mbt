// Tests for structured output helpers
// Note: These tests don't capture stdout, so they verify the functions run without errors

///|
test "log functions execute without error" {
  log_info("test info message")
  log_warn("test warn message")
  log_error("test error message")
  log_debug("test debug message")
  inspect(true, content="true")
}

///|
test "formatting helpers execute without error" {
  success("operation completed")
  failure("operation failed")
  step("processing item")
  section("Test Section")
  kv("key", "value")
  inspect(true, content="true")
}
