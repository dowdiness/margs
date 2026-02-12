// Test AsyncCli structure and configuration without executing async code
// These tests validate the API without triggering the Moon ICE

///|
test "async cli accepts commands" {
  let cli = create_async_cli("demo").add_command(
    async_command("run", handler=fn(_) { () }),
  )

  // Validate structure without calling parse()
  inspect(cli.commands.length(), content="1")
  inspect(cli.commands[0].spec.name, content="run")
}

///|
test "async cli accepts hooks" {
  let cli = create_async_cli("demo")
    .add_before_hook(hook=fn(_) { () })
    .add_after_hook(hook=fn(_) { () })

  inspect(cli.before_hooks.length(), content="1")
  inspect(cli.after_hooks.length(), content="1")
}

///|
test "async cli converts to parser" {
  let cli = create_async_cli("demo", description="Test CLI").add_command(
    async_command("run", handler=fn(_) { () }),
  )

  let parser = cli.to_parser()
  inspect(parser.name, content="demo")
  inspect(parser.description, content="Test CLI")
}

///|
test "async command accepts nested commands" {
  let nested = async_command("deploy", handler=fn(_) { () })
  let parent = async_command("app", handler=fn(_) { () }).add_command(
    nested,
  )

  inspect(parent.commands.length(), content="1")
  inspect(parent.commands[0].spec.name, content="deploy")
}
