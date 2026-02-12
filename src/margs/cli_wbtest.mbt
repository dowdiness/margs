// White-box tests for internal CLI wrapper helpers

///|
test "help routing resolves deepest nested subcommand" {
  let cli = create_cli("project").add_command(
    command("deploy", handler=fn(_) { () }).add_subcommand(
      subcommand("prod", description="Deploy to production"),
    ),
  )

  let target = resolve_help_subcommand(
    ["deploy", "prod", "--help"],
    cli.options,
    root_subcommand_specs(cli.commands),
  )
  let name = match target {
    Some(spec) => spec.name
    None => ""
  }
  inspect(name, content="prod")
}

///|
test "help routing skips global option values before subcommand" {
  let cli = create_cli("project")
    .add_option(str_option("config", short='c', long="config"))
    .add_command(command("deploy", handler=fn(_) { () }))

  let target = resolve_help_subcommand(
    ["--config", "app.toml", "deploy", "--help"],
    cli.options,
    root_subcommand_specs(cli.commands),
  )
  let name = match target {
    Some(spec) => spec.name
    None => ""
  }
  inspect(name, content="deploy")
}
