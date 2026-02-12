// Mock async executor for testing without %async.run intrinsic

///|
/// State tracker for testing async execution
pub struct AsyncTestContext {
  executed : Array[String]
  errors : Array[String]
}

///|
/// Create a new test context
pub fn AsyncTestContext::new() -> AsyncTestContext {
  { executed: [], errors: [] }
}

///|
/// Get execution log
pub fn AsyncTestContext::get_executed(self : AsyncTestContext) -> Array[String] {
  self.executed
}

///|
/// Get error log
pub fn AsyncTestContext::get_errors(self : AsyncTestContext) -> Array[String] {
  self.errors
}

///|
/// Test helper: create async command for structure validation
pub fn test_async_command(name : String) -> AsyncCliCommand {
  async_command(name, handler=fn(_) { () })
}

///|
test "async command structure helper" {
  let cmd = test_async_command("deploy")

  // Validate command structure without executing
  inspect(cmd.spec.name, content="deploy")
  inspect(cmd.commands.length(), content="0")
}
