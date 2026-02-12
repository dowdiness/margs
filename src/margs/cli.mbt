// High-level CLI wrapper API built on top of Parser

///|
/// A command with its spec and handler.
pub struct CliCommand {
  spec : SubcommandSpec
  handler : (ParsedArgs) -> Unit raise Error
  commands : Array[CliCommand]
  before_hooks : Array[(ParsedArgs) -> Unit raise Error]
  after_hooks : Array[(ParsedArgs) -> Unit raise Error]
}

///|
/// High-level CLI configuration and command registry.
pub struct Cli {
  name : String
  description : String
  version : String?
  examples : Array[(String, String)]
  options : Array[OptionSpec]
  positionals : Array[PositionalSpec]
  commands : Array[CliCommand]
  handler : ((ParsedArgs) -> Unit raise Error)?
  before_hooks : Array[(ParsedArgs) -> Unit raise Error]
  after_hooks : Array[(ParsedArgs) -> Unit raise Error]
}

///|
/// Structured result for in-process CLI test execution.
pub struct CliTestResult {
  exit_code : ExitCode
  output : String?
  error : ParseError?
}

///|
/// Async-friendly command skeleton.
/// Currently delegates to sync parsing/dispatch until native async handlers are integrated.
pub struct AsyncCliCommand {
  spec : SubcommandSpec
  handler : (ParsedArgs) -> Unit raise Error
  commands : Array[AsyncCliCommand]
  before_hooks : Array[(ParsedArgs) -> Unit raise Error]
  after_hooks : Array[(ParsedArgs) -> Unit raise Error]
}

///|
/// Async-friendly CLI skeleton.
/// This provides API shape compatibility for future async handler integration.
pub struct AsyncCli {
  name : String
  description : String
  version : String?
  examples : Array[(String, String)]
  options : Array[OptionSpec]
  positionals : Array[PositionalSpec]
  commands : Array[AsyncCliCommand]
  handler : ((ParsedArgs) -> Unit raise Error)?
  before_hooks : Array[(ParsedArgs) -> Unit raise Error]
  after_hooks : Array[(ParsedArgs) -> Unit raise Error]
}

///|
/// Create a new high-level CLI wrapper.
pub fn create_cli(
  name : String,
  description? : String = "",
  version? : String,
) -> Cli {
  {
    name,
    description,
    version,
    examples: [],
    options: [],
    positionals: [],
    commands: [],
    handler: None,
    before_hooks: [],
    after_hooks: [],
  }
}

///|
/// Create a new async-friendly CLI skeleton.
pub fn create_async_cli(
  name : String,
  description? : String = "",
  version? : String,
) -> AsyncCli {
  {
    name,
    description,
    version,
    examples: [],
    options: [],
    positionals: [],
    commands: [],
    handler: None,
    before_hooks: [],
    after_hooks: [],
  }
}

///|
/// Create a command with a handler.
pub fn command(
  name : String,
  description? : String = "",
  aliases? : Array[String] = [],
  handler~ : (ParsedArgs) -> Unit raise Error,
) -> CliCommand {
  {
    spec: subcommand(name, description~, aliases~),
    handler,
    commands: [],
    before_hooks: [],
    after_hooks: [],
  }
}

///|
/// Create an async-friendly command skeleton.
pub fn async_command(
  name : String,
  description? : String = "",
  aliases? : Array[String] = [],
  handler~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCliCommand {
  {
    spec: subcommand(name, description~, aliases~),
    handler,
    commands: [],
    before_hooks: [],
    after_hooks: [],
  }
}

///|
/// Set or replace the root handler.
pub fn Cli::set_handler(
  self : Cli,
  handler~ : (ParsedArgs) -> Unit raise Error,
) -> Cli {
  { ..self, handler: Some(handler) }
}

///|
/// Add a hook that runs before dispatching a handler.
pub fn Cli::add_before_hook(
  self : Cli,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> Cli {
  { ..self, before_hooks: self.before_hooks + [hook] }
}

///|
/// Add a hook that runs after a handler succeeds.
pub fn Cli::add_after_hook(
  self : Cli,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> Cli {
  { ..self, after_hooks: self.after_hooks + [hook] }
}

///|
/// Add a global option to the CLI.
pub fn Cli::add_option(self : Cli, opt : OptionSpec) -> Cli {
  { ..self, options: self.options + [opt] }
}

///|
/// Add a root positional argument to the CLI.
pub fn Cli::add_positional(self : Cli, pos : PositionalSpec) -> Cli {
  { ..self, positionals: self.positionals + [pos] }
}

///|
/// Add a usage example to the CLI help output.
pub fn Cli::add_example(self : Cli, cmd : String, desc : String) -> Cli {
  { ..self, examples: self.examples + [(cmd, desc)] }
}

///|
/// Set CLI version information.
pub fn Cli::with_version(self : Cli, version : String) -> Cli {
  { ..self, version: Some(version) }
}

///|
/// Add a command to the CLI.
pub fn Cli::add_command(self : Cli, cmd : CliCommand) -> Cli {
  { ..self, commands: self.commands + [cmd] }
}

///|
/// Set or replace the root async skeleton handler.
pub fn AsyncCli::set_handler(
  self : AsyncCli,
  handler~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCli {
  { ..self, handler: Some(handler) }
}

///|
/// Add a hook that runs before async skeleton dispatch.
pub fn AsyncCli::add_before_hook(
  self : AsyncCli,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCli {
  { ..self, before_hooks: self.before_hooks + [hook] }
}

///|
/// Add a hook that runs after async skeleton handler success.
pub fn AsyncCli::add_after_hook(
  self : AsyncCli,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCli {
  { ..self, after_hooks: self.after_hooks + [hook] }
}

///|
/// Add a global option to the async skeleton.
pub fn AsyncCli::add_option(self : AsyncCli, opt : OptionSpec) -> AsyncCli {
  { ..self, options: self.options + [opt] }
}

///|
/// Add a root positional argument to the async skeleton.
pub fn AsyncCli::add_positional(
  self : AsyncCli,
  pos : PositionalSpec,
) -> AsyncCli {
  { ..self, positionals: self.positionals + [pos] }
}

///|
/// Add a usage example to async skeleton help output.
pub fn AsyncCli::add_example(
  self : AsyncCli,
  cmd : String,
  desc : String,
) -> AsyncCli {
  { ..self, examples: self.examples + [(cmd, desc)] }
}

///|
/// Set async skeleton version information.
pub fn AsyncCli::with_version(self : AsyncCli, version : String) -> AsyncCli {
  { ..self, version: Some(version) }
}

///|
/// Add a command to the async skeleton.
pub fn AsyncCli::add_command(
  self : AsyncCli,
  cmd : AsyncCliCommand,
) -> AsyncCli {
  { ..self, commands: self.commands + [cmd] }
}

///|
/// Add an option to a command.
pub fn CliCommand::add_option(
  self : CliCommand,
  opt : OptionSpec,
) -> CliCommand {
  { ..self, spec: { ..self.spec, options: self.spec.options + [opt] } }
}

///|
/// Add a positional argument to a command.
pub fn CliCommand::add_positional(
  self : CliCommand,
  pos : PositionalSpec,
) -> CliCommand {
  { ..self, spec: { ..self.spec, positionals: self.spec.positionals + [pos] } }
}

///|
/// Add a nested subcommand spec to a command.
pub fn CliCommand::add_subcommand(
  self : CliCommand,
  sub : SubcommandSpec,
) -> CliCommand {
  { ..self, spec: { ..self.spec, subcommands: self.spec.subcommands + [sub] } }
}

///|
/// Add a nested command to a command.
pub fn CliCommand::add_command(
  self : CliCommand,
  cmd : CliCommand,
) -> CliCommand {
  {
    ..self,
    spec: { ..self.spec, subcommands: self.spec.subcommands + [cmd.spec] },
    commands: self.commands + [cmd],
  }
}

///|
/// Add a hook that runs before this command's handler.
pub fn CliCommand::add_before_hook(
  self : CliCommand,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> CliCommand {
  { ..self, before_hooks: self.before_hooks + [hook] }
}

///|
/// Add a hook that runs after this command's handler succeeds.
pub fn CliCommand::add_after_hook(
  self : CliCommand,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> CliCommand {
  { ..self, after_hooks: self.after_hooks + [hook] }
}

///|
/// Set or replace a command handler.
pub fn CliCommand::set_handler(
  self : CliCommand,
  handler~ : (ParsedArgs) -> Unit raise Error,
) -> CliCommand {
  { ..self, handler, }
}

///|
/// Add an option to an async skeleton command.
pub fn AsyncCliCommand::add_option(
  self : AsyncCliCommand,
  opt : OptionSpec,
) -> AsyncCliCommand {
  { ..self, spec: { ..self.spec, options: self.spec.options + [opt] } }
}

///|
/// Add a positional argument to an async skeleton command.
pub fn AsyncCliCommand::add_positional(
  self : AsyncCliCommand,
  pos : PositionalSpec,
) -> AsyncCliCommand {
  { ..self, spec: { ..self.spec, positionals: self.spec.positionals + [pos] } }
}

///|
/// Add a nested subcommand spec to an async skeleton command.
pub fn AsyncCliCommand::add_subcommand(
  self : AsyncCliCommand,
  sub : SubcommandSpec,
) -> AsyncCliCommand {
  { ..self, spec: { ..self.spec, subcommands: self.spec.subcommands + [sub] } }
}

///|
/// Add a nested command to an async skeleton command.
pub fn AsyncCliCommand::add_command(
  self : AsyncCliCommand,
  cmd : AsyncCliCommand,
) -> AsyncCliCommand {
  {
    ..self,
    spec: { ..self.spec, subcommands: self.spec.subcommands + [cmd.spec] },
    commands: self.commands + [cmd],
  }
}

///|
/// Add a hook that runs before this async skeleton command handler.
pub fn AsyncCliCommand::add_before_hook(
  self : AsyncCliCommand,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCliCommand {
  { ..self, before_hooks: self.before_hooks + [hook] }
}

///|
/// Add a hook that runs after this async skeleton command handler succeeds.
pub fn AsyncCliCommand::add_after_hook(
  self : AsyncCliCommand,
  hook~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCliCommand {
  { ..self, after_hooks: self.after_hooks + [hook] }
}

///|
/// Set or replace an async skeleton command handler.
pub fn AsyncCliCommand::set_handler(
  self : AsyncCliCommand,
  handler~ : (ParsedArgs) -> Unit raise Error,
) -> AsyncCliCommand {
  { ..self, handler, }
}

///|
/// Convert the high-level CLI wrapper into a low-level parser.
pub fn Cli::to_parser(self : Cli) -> Parser[Unit] {
  fn run_effect(
    effect : (ParsedArgs) -> Unit raise Error,
    args : ParsedArgs,
  ) -> Unit raise ParseError {
    // Keep this list in sync with ParseError variants.
    effect(args) catch {
      MissingRequired(_) as err => raise err
      InvalidValue(_) as err => raise err
      UnknownOption(_) as err => raise err
      UnknownCommand(_) as err => raise err
      InvalidFormat(_) as err => raise err
      HelpRequested(_) as err => raise err
      HandlerError(_) as err => raise err
      runtime => raise HandlerError(runtime.to_string())
    }
  }

  fn run_hooks(
    hooks : Array[(ParsedArgs) -> Unit raise Error],
    args : ParsedArgs,
  ) -> Unit raise ParseError {
    for hook in hooks {
      run_effect(hook, args)
    }
  }

  fn run_with_hooks(
    before_hooks : Array[(ParsedArgs) -> Unit raise Error],
    handler : (ParsedArgs) -> Unit raise Error,
    after_hooks : Array[(ParsedArgs) -> Unit raise Error],
    args : ParsedArgs,
  ) -> Unit raise ParseError {
    run_hooks(before_hooks, args)
    run_effect(handler, args)
    run_hooks(after_hooks, args)
  }

  fn contains_alias(aliases : Array[String], name : String) -> Bool {
    for al in aliases {
      if al == name {
        return true
      }
    }
    false
  }

  fn dispatch(
    args : ParsedArgs,
    commands : Array[CliCommand],
    index : Int,
    before_hooks : Array[(ParsedArgs) -> Unit raise Error],
    after_hooks : Array[(ParsedArgs) -> Unit raise Error],
  ) -> Bool raise ParseError {
    if index >= args.command_path.length() {
      return false
    }
    let cmd_name = args.command_path[index]
    for cmd in commands {
      if cmd.spec.name == cmd_name || contains_alias(cmd.spec.aliases, cmd_name) {
        let combined_before = before_hooks + cmd.before_hooks
        let combined_after = cmd.after_hooks + after_hooks
        if index == args.command_path.length() - 1 {
          run_with_hooks(combined_before, cmd.handler, combined_after, args)
          return true
        }
        let child = dispatch(
          args,
          cmd.commands,
          index + 1,
          combined_before,
          combined_after,
        )
        if child {
          return true
        }
        run_with_hooks(combined_before, cmd.handler, combined_after, args)
        return true
      }
    }
    false
  }

  let mut p : Parser[Unit] = parser(self.name, description=self.description, builder=args => {
    if args.command_path.length() > 1 {
      let handled = dispatch(
        args,
        self.commands,
        1,
        self.before_hooks,
        self.after_hooks,
      )
      if not(handled) {
        let cmd_name = args.command_path[1]
        raise UnknownCommand("unknown command '\{cmd_name}'")
      }
      return ()
    }
    match self.handler {
      Some(run) =>
        run_with_hooks(self.before_hooks, run, self.after_hooks, args)
      None =>
        if self.commands.length() > 0 {
          raise HelpRequested("")
        } else {
          ()
        }
    }
  })

  p = p.with_options(self.options)
  for pos in self.positionals {
    p = p.add_positional(pos)
  }
  for cmd in self.commands {
    p = p.add_subcommand(cmd.spec)
  }
  match self.version {
    Some(v) => p = p.with_version(v)
    None => ()
  }
  for example in self.examples {
    let (cmd, desc) = example
    p = p.add_example(cmd, desc)
  }
  p
}

///|
/// Parse explicit args and dispatch to the matching handler.
pub fn Cli::parse(self : Cli, args : Array[String]) -> Unit raise ParseError {
  self.to_parser().parse(args)
}

///|
/// Run the CLI in-process for tests without printing or exiting the process.
/// Returns structured output, exit code, and optional parse error.
pub fn Cli::run_for_test(self : Cli, args : Array[String]) -> CliTestResult {
  // Match run(): with no args and command-only CLI, show help without exit.
  if args.length() == 0 && self.commands.length() > 0 {
    match self.handler {
      Some(_) => ()
      None =>
        return {
          exit_code: Success,
          output: Some(generate_help(self.to_parser())),
          error: None,
        }
    }
  }

  // Match run(): wrapper-level version handling.
  if args.length() > 0 && is_version_arg(args[0]) {
    match self.version {
      Some(v) => return { exit_code: Success, output: Some(v), error: None }
      None => ()
    }
  }

  let parsed : Result[Unit, ParseError] = Ok(self.parse(args)) catch {
    err => Err(err)
  }

  match parsed {
    Ok(_) => { exit_code: Success, output: None, error: None }
    Err(err) =>
      match err {
        HelpRequested(_) => {
          let text = match
            resolve_help_subcommand(
              args,
              self.options,
              root_subcommand_specs(self.commands),
            ) {
            Some(spec) => generate_subcommand_help(spec)
            None => generate_help(self.to_parser())
          }
          {
            exit_code: exit_code_for_error(err),
            output: Some(text),
            error: Some(err),
          }
        }
        MissingRequired(msg)
        | InvalidValue(msg)
        | UnknownOption(msg)
        | UnknownCommand(msg)
        | InvalidFormat(msg)
        | HandlerError(msg) =>
          {
            exit_code: exit_code_for_error(err),
            output: Some("Error: \{msg}"),
            error: Some(err),
          }
      }
  }
}

///|
/// Convert an async skeleton command into a concrete sync wrapper command.
pub fn AsyncCliCommand::to_cli_command(self : AsyncCliCommand) -> CliCommand {
  let children : Array[CliCommand] = []
  for cmd in self.commands {
    let child = cmd.to_cli_command()
    children.push(child)
  }
  {
    spec: self.spec,
    handler: self.handler,
    commands: children,
    before_hooks: self.before_hooks,
    after_hooks: self.after_hooks,
  }
}

///|
/// Convert async skeleton CLI into the concrete sync wrapper.
pub fn AsyncCli::to_cli(self : AsyncCli) -> Cli {
  let commands : Array[CliCommand] = []
  for cmd in self.commands {
    commands.push(cmd.to_cli_command())
  }
  {
    name: self.name,
    description: self.description,
    version: self.version,
    examples: self.examples,
    options: self.options,
    positionals: self.positionals,
    commands,
    handler: self.handler,
    before_hooks: self.before_hooks,
    after_hooks: self.after_hooks,
  }
}

///|
/// Parse explicit args through the async skeleton wrapper.
pub fn AsyncCli::parse(
  self : AsyncCli,
  args : Array[String],
) -> Unit raise ParseError {
  self.to_cli().parse(args)
}

///|
/// Run async skeleton in-process for tests.
pub fn AsyncCli::run_for_test(
  self : AsyncCli,
  args : Array[String],
) -> CliTestResult {
  self.to_cli().run_for_test(args)
}

///|
/// Run async skeleton using process args.
pub fn AsyncCli::run(self : AsyncCli) -> Unit {
  self.to_cli().run()
}

///|
/// Placeholder async-oriented entry that currently delegates to sync parsing.
pub fn AsyncCli::run_async_args(
  self : AsyncCli,
  args : Array[String],
) -> Unit raise ParseError {
  self.parse(args)
}

///|
/// Placeholder async-oriented run entry that currently delegates to sync run.
pub fn AsyncCli::run_async(self : AsyncCli) -> Unit {
  self.run()
}

///|
/// Return true if argument requests version output.
fn is_version_arg(arg : String) -> Bool {
  arg == "--version" || arg == "-V"
}

///|
/// Check if option is a flag (does not consume a value).
fn option_is_flag(opt : OptionSpec) -> Bool {
  match opt {
    BoolFlag(_) => true
    _ => false
  }
}

///|
/// Find an option by long name (or key fallback).
fn find_option_by_long_name(
  options : Array[OptionSpec],
  name : String,
) -> OptionSpec? {
  for opt in options {
    match option_long(opt) {
      Some(l) => if l == name { return Some(opt) }
      None => if option_key(opt) == name { return Some(opt) }
    }
  }
  None
}

///|
/// Find an option by short name.
fn find_option_by_short_name(
  options : Array[OptionSpec],
  name : Char,
) -> OptionSpec? {
  for opt in options {
    match option_short(opt) {
      Some(s) => if s == name { return Some(opt) }
      None => ()
    }
  }
  None
}

///|
/// Return true if short option cluster consumes the next arg as a value.
fn short_cluster_consumes_next_arg(
  chars : StringView,
  options : Array[OptionSpec],
) -> Bool {
  match chars {
    [] => false
    [ch, .. rest] =>
      match find_option_by_short_name(options, ch) {
        Some(opt) =>
          if option_is_flag(opt) {
            short_cluster_consumes_next_arg(rest, options)
          } else {
            rest.length() == 0
          }
        None => false
      }
  }
}

///|
/// Find a subcommand spec by name or alias.
fn find_subcommand_spec(
  subcommands : Array[SubcommandSpec],
  name : String,
) -> SubcommandSpec? {
  for sub in subcommands {
    if sub.name == name {
      return Some(sub)
    }
    for a in sub.aliases {
      if a == name {
        return Some(sub)
      }
    }
  }
  None
}

///|
/// Build root subcommand specs from CLI command registrations.
fn root_subcommand_specs(commands : Array[CliCommand]) -> Array[SubcommandSpec] {
  let specs : Array[SubcommandSpec] = []
  for cmd in commands {
    specs.push(cmd.spec)
  }
  specs
}

///|
/// Resolve the deepest subcommand targeted by `--help`/`-h`.
/// This parser-aware scanner skips known option values and handles nested commands.
fn resolve_help_subcommand(
  args : Array[String],
  root_options : Array[OptionSpec],
  root_subcommands : Array[SubcommandSpec],
) -> SubcommandSpec? {
  let mut options = root_options
  let mut subcommands = root_subcommands
  let mut target : SubcommandSpec? = None
  let pos = Ref::new(0)

  while pos.val < args.length() {
    let arg = args[pos.val]
    if arg == "--help" || arg == "-h" || arg == "--" {
      break
    }
    match arg.view() {
      ['-', '-', .. rest] => {
        let long_name = rest.to_string()
        match split_at(long_name, '=') {
          Some(_) => ()
          None =>
            match find_option_by_long_name(options, long_name) {
              Some(opt) =>
                if not(option_is_flag(opt)) && pos.val + 1 < args.length() {
                  pos.val = pos.val + 1
                }
              None => ()
            }
        }
      }
      ['-', .. rest] =>
        if short_cluster_consumes_next_arg(rest, options) &&
          pos.val + 1 < args.length() {
          pos.val = pos.val + 1
        }
      _ =>
        match find_subcommand_spec(subcommands, arg) {
          Some(sub) => {
            target = Some(sub)
            options = sub.options
            subcommands = sub.subcommands
          }
          None => ()
        }
    }
    pos.val = pos.val + 1
  }
  target
}

///|
/// Run using process CLI args with automatic help/version/error handling.
pub fn Cli::run(self : Cli) -> Unit {
  let all_args = @sys.get_cli_args()
  let args : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    args.push(all_args[i])
  }

  let result = self.run_for_test(args)
  match result.output {
    Some(text) => println(text)
    None => ()
  }
  match result.error {
    Some(_) => @sys.exit(result.exit_code.code())
    None => ()
  }
}
