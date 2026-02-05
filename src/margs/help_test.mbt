// Help text generation tests for margs

///|
test "simple parser help output" {
  let p : Parser[ParsedArgs] = parser(
      "myapp",
      description="A sample application",
      builder=fn(args) { args },
    )
    |> Parser::with_options([
      str_option("output", short='o', long="output", help="Output file"),
      flag("verbose", short='v', long="verbose", help="Enable verbose output"),
    ])
  let help = generate_help(p)
  // Check description is present
  inspect(help.contains("A sample application"), content="true")
  // Check usage line
  inspect(help.contains("Usage: myapp [OPTIONS]"), content="true")
  // Check options section
  inspect(help.contains("Options:"), content="true")
  // Check option flags
  inspect(help.contains("-o, --output"), content="true")
  inspect(help.contains("-v, --verbose"), content="true")
  // Check help text
  inspect(help.contains("Output file"), content="true")
  inspect(help.contains("Enable verbose output"), content="true")
  // Check built-in help option
  inspect(help.contains("-h, --help"), content="true")
  inspect(help.contains("Print help"), content="true")
}

///|
test "help with positionals" {
  let p : Parser[ParsedArgs] = parser("cp", description="Copy files", builder=fn(
      args,
    ) {
      args
    })
    |> Parser::add_positional(positional("src", help="Source file"))
    |> Parser::add_positional(
      positional("dest", help="Destination", required=false),
    )
  let help = generate_help(p)
  // Required positional shown with <> in usage
  inspect(help.contains("Usage: cp <src> [dest]"), content="true")
  // Arguments section
  inspect(help.contains("Arguments:"), content="true")
  inspect(help.contains("Source file"), content="true")
  inspect(help.contains("Destination"), content="true")
}

///|
test "help with subcommands" {
  let p : Parser[ParsedArgs] = parser("cargo", description="Package manager", builder=fn(
      args,
    ) {
      args
    })
    |> Parser::add_subcommand(
      subcommand("build", description="Compile the project"),
    )
    |> Parser::add_subcommand(subcommand("test", description="Run the tests"))
  let help = generate_help(p)
  // Usage shows <COMMAND>
  inspect(help.contains("Usage: cargo <COMMAND>"), content="true")
  // Commands section
  inspect(help.contains("Commands:"), content="true")
  inspect(help.contains("build"), content="true")
  inspect(help.contains("Compile the project"), content="true")
  inspect(help.contains("test"), content="true")
  inspect(help.contains("Run the tests"), content="true")
}

///|
test "help with metavar" {
  let p : Parser[ParsedArgs] = parser("serve", builder=fn(args) { args })
    |> Parser::add_option(
      int_option(
        "port",
        short='p',
        long="port",
        help="Port number",
        metavar="PORT",
      ),
    )
  let help = generate_help(p)
  inspect(help.contains("<PORT>"), content="true")
}

///|
test "help with long-only option" {
  let p : Parser[ParsedArgs] = parser("app", builder=fn(args) { args })
    |> Parser::add_option(
      str_option("config", long="config", help="Config file"),
    )
  let help = generate_help(p)
  inspect(help.contains("--config"), content="true")
  inspect(help.contains("Config file"), content="true")
}

///|
test "subcommand help generation" {
  let sub = subcommand(
    "build",
    description="Build the project",
    options=[
      flag("release", long="release", help="Build in release mode"),
      str_option("target", long="target", help="Target triple"),
    ],
    positionals=[positional("path", help="Path to project", required=false)],
  )
  let help = generate_subcommand_help(sub)
  inspect(help.contains("Build the project"), content="true")
  inspect(help.contains("Usage: build [OPTIONS] [path]"), content="true")
  inspect(help.contains("--release"), content="true")
  inspect(help.contains("--target"), content="true")
  inspect(help.contains("Build in release mode"), content="true")
}

///|
test "verbose_flag helper" {
  let opt = verbose_flag()
  inspect(option_key(opt), content="verbose")
  inspect(option_short(opt), content="Some('v')")
  inspect(option_long(opt), content="Some(\"verbose\")")
  inspect(option_help(opt), content="Enable verbose output")
}

///|
test "quiet_flag helper" {
  let opt = quiet_flag()
  inspect(option_key(opt), content="quiet")
  inspect(option_short(opt), content="Some('q')")
  inspect(option_long(opt), content="Some(\"quiet\")")
  inspect(option_help(opt), content="Suppress output")
}

///|
test "port_option rejects invalid port" {
  let p : Parser[ParsedArgs] = parser("test", builder=fn(args) { args })
    |> Parser::add_option(port_option())
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--port", "0"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "port_option accepts valid port" {
  let p : Parser[ParsedArgs] = parser("test", builder=fn(args) { args })
    |> Parser::add_option(port_option())
  let result = p.parse(["--port", "8080"])
  inspect(result.get_int("port"), content="Some(8080)")
}
