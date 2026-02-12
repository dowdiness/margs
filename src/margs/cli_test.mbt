// High-level CLI wrapper tests

///|
test "cli dispatches command handler" {
  let called = Ref::new(false)
  let seen_port = Ref::new(0)

  let cli = create_cli("demo").add_command(
    command("serve", handler=fn(args) {
      called.val = true
      seen_port.val = args.get_int("port").unwrap_or(0)
    }).add_option(port_option()),
  )

  cli.parse(["serve", "--port", "8080"])
  inspect(called.val, content="true")
  inspect(seen_port.val, content="8080")
}

///|
test "global option is visible in command handler" {
  let seen_verbose = Ref::new(false)

  let cli = create_cli("demo")
    .add_option(verbose_flag())
    .add_command(
      command("serve", handler=fn(args) {
        seen_verbose.val = args.get_bool("verbose")
      }),
    )

  cli.parse(["-v", "serve"])
  inspect(seen_verbose.val, content="true")
}

///|
test "command aliases dispatch to canonical handler" {
  let called = Ref::new(false)

  let cli = create_cli("demo").add_command(
    command("serve", aliases=["s"], handler=fn(_) { called.val = true }),
  )

  cli.parse(["s"])
  inspect(called.val, content="true")
}

///|
test "nested command handlers dispatch by full path" {
  let called = Ref::new(false)

  let deploy = command("deploy", aliases=["d"], handler=fn(_) {
    called.val = true
  })

  let cli = create_cli("demo").add_command(
    command("app", handler=fn(_) { () }).add_command(deploy),
  )

  cli.parse(["app", "d"])
  inspect(called.val, content="true")
}

///|
test "commands without root handler raise help" {
  let cli = create_cli("demo").add_command(
    command("serve", handler=fn(_) { () }),
  )

  let result : Result[Unit, Error] = Ok(cli.parse([])) catch { e => Err(e) }
  inspect(result is Err(_), content="true")
}

///|
test "root handler runs when no subcommand is provided" {
  let called = Ref::new(false)

  let cli = create_cli("demo").set_handler(handler=fn(_) { called.val = true })

  cli.parse([])
  inspect(called.val, content="true")
}

///|
test "cli version appears in generated help" {
  let cli = create_cli("demo", version="1.2.3")
  let help = generate_help(cli.to_parser())
  inspect(help.contains("Version: 1.2.3"), content="true")
}

///|
test "cli raises general error on handler failure" {
  let cli = create_cli("demo").add_command(
    command("deploy", handler=fn(_) raise { raise Failure::Failure("boom") }),
  )

  let result : Result[Unit, Error] = Ok(cli.parse(["deploy"])) catch {
    e => Err(e)
  }
  match result {
    Ok(_) => inspect(false, content="true")
    Err(ParseError::HandlerError(msg)) =>
      inspect(msg, content="Failure(\"boom\")")
    Err(_) => inspect(false, content="true")
  }
}
