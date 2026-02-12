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

///|
test "global hooks run around command handler" {
  let order : Array[String] = []
  let cli = create_cli("demo")
    .add_before_hook(hook=fn(_) { order.push("before") })
    .add_after_hook(hook=fn(_) { order.push("after") })
    .add_command(command("run", handler=fn(_) { order.push("handler") }))

  cli.parse(["run"])
  inspect(order[0], content="before")
  inspect(order[1], content="handler")
  inspect(order[2], content="after")
}

///|
test "nested command hooks compose in expected order" {
  let order : Array[String] = []
  let cli = create_cli("demo")
    .add_before_hook(hook=fn(_) { order.push("global_before") })
    .add_after_hook(hook=fn(_) { order.push("global_after") })
    .add_command(
      command("project", handler=fn(_) { () })
      .add_before_hook(hook=fn(_) { order.push("project_before") })
      .add_after_hook(hook=fn(_) { order.push("project_after") })
      .add_command(
        command("deploy", handler=fn(_) { order.push("handler") })
        .add_before_hook(hook=fn(_) { order.push("deploy_before") })
        .add_after_hook(hook=fn(_) { order.push("deploy_after") }),
      ),
    )

  cli.parse(["project", "deploy"])
  inspect(order[0], content="global_before")
  inspect(order[1], content="project_before")
  inspect(order[2], content="deploy_before")
  inspect(order[3], content="handler")
  inspect(order[4], content="deploy_after")
  inspect(order[5], content="project_after")
  inspect(order[6], content="global_after")
}

///|
test "hook failures convert to handler error" {
  let cli = create_cli("demo")
    .add_before_hook(hook=fn(_) raise { raise Failure::Failure("hook_fail") })
    .add_command(command("run", handler=fn(_) { () }))

  let result : Result[Unit, Error] = Ok(cli.parse(["run"])) catch {
    e => Err(e)
  }
  match result {
    Ok(_) => inspect(false, content="true")
    Err(ParseError::HandlerError(msg)) =>
      inspect(msg, content="Failure(\"hook_fail\")")
    Err(_) => inspect(false, content="true")
  }
}

///|
test "run_for_test returns success on successful command" {
  let cli = create_cli("demo").add_command(command("run", handler=fn(_) { () }))
  let result = cli.run_for_test(["run"])
  inspect(result.exit_code.code(), content="0")
  inspect(result.output is None, content="true")
  inspect(result.error is None, content="true")
}

///|
test "run_for_test returns root help output without error on empty args" {
  let cli = create_cli("demo").add_command(command("run", handler=fn(_) { () }))
  let result = cli.run_for_test([])
  inspect(result.exit_code.code(), content="0")
  inspect(result.error is None, content="true")
  inspect(result.output.unwrap_or("").contains("Usage: demo"), content="true")
}

///|
test "run_for_test returns version output" {
  let cli = create_cli("demo", version="9.9.9")
  let result = cli.run_for_test(["--version"])
  inspect(result.exit_code.code(), content="0")
  inspect(result.output, content="Some(\"9.9.9\")")
  inspect(result.error is None, content="true")
}

///|
test "run_for_test returns command help with success exit" {
  let cli = create_cli("demo").add_command(
    command("deploy", description="Deploy app", handler=fn(_) { () }),
  )
  let result = cli.run_for_test(["deploy", "--help"])
  inspect(result.exit_code.code(), content="0")
  inspect(result.output.unwrap_or("").contains("Usage: deploy"), content="true")
  match result.error {
    Some(ParseError::HelpRequested(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}

///|
test "run_for_test maps parse failures to exit code and output" {
  let cli = create_cli("demo").add_command(
    command("serve", handler=fn(_) { () }).add_option(port_option()),
  )
  let result = cli.run_for_test(["serve", "--port", "abc"])
  inspect(result.exit_code.code(), content="3")
  inspect(
    result.output.unwrap_or("").contains("expected integer for option"),
    content="true",
  )
  match result.error {
    Some(ParseError::InvalidValue(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}

///|
async test "async cli dispatches command handler" {
  let called = Ref::new(false)
  let cli = create_async_cli("demo").add_command(
    async_command("run", handler=fn(_) { called.val = true }),
  )

  cli.parse(["run"])
  inspect(called.val, content="true")
}

///|
async test "async cli exposes in-process test helper" {
  let cli = create_async_cli("demo").add_command(
    async_command("run", handler=fn(_) { () }),
  )
  let result = cli.run_for_test(["run"])
  inspect(result.exit_code.code(), content="0")
  inspect(result.error is None, content="true")
}

///|
async test "async cli runs hooks around command handler" {
  let order : Array[String] = []
  let cli = create_async_cli("demo")
    .add_before_hook(hook=fn(_) { order.push("before") })
    .add_after_hook(hook=fn(_) { order.push("after") })
    .add_command(async_command("run", handler=fn(_) { order.push("handler") }))
  cli.parse(["run"])
  inspect(order[0], content="before")
  inspect(order[1], content="handler")
  inspect(order[2], content="after")
}
