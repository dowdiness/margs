// Demo CLI application built with margs
// Showcases: subcommands, options, flags, positionals, validators, and help generation
//
// Try running:
//   moon run src/example -- --help
//   moon run src/example -- serve --help
//   moon run src/example -- -v serve --port 8080
//   moon run src/example -- build -o out -t wasm -t js
//   moon run src/example -- init my-app

///|
/// Find the subcommand name from CLI args for help routing.
/// Returns the first non-option argument, or empty string if none found.
fn find_subcmd_name() -> String {
  let args = @sys.get_cli_args()
  for i = 1; i < args.length(); i = i + 1 {
    let arg = args[i]
    // Stop if help is requested before any subcommand
    if arg == "--help" || arg == "-h" {
      return ""
    }
    // First non-option argument is the subcommand
    if arg.length() > 0 && arg[0] != '-' {
      return arg
    }
  }
  ""
}

///|
fn build_app(
  serve_cmd : @margs.SubcommandSpec,
  build_cmd : @margs.SubcommandSpec,
  init_cmd : @margs.SubcommandSpec,
) -> @margs.Parser[Unit] {
  @margs.parser(
    "demo",
    description="A demo project tool built with margs",
    builder=fn(args) {
      let verbose = args.get_bool("verbose")
      let cmd = if args.command_path.length() > 1 {
        args.command_path[1]
      } else {
        ""
      }
      match cmd {
        "serve" => {
          let host = match args.get_string("host") {
            Some(h) => h
            None => "localhost"
          }
          let port = match args.get_int("port") {
            Some(p) => p
            None => 3000
          }
          if verbose {
            println("[verbose] Configuring server...")
          }
          println("Server listening on http://\{host}:\{port}")
        }
        "build" => {
          let output = match args.get_string("output") {
            Some(o) => o
            None => "dist"
          }
          let targets = args.get_string_list("target")
          if verbose {
            println("[verbose] Starting build...")
          }
          println("Building project -> \{output}/")
          for target in targets {
            println("  target: \{target}")
          }
          println("Build complete!")
        }
        "init" => {
          let name = match args.get_positional(0) {
            Some(n) => n
            None => "my-project"
          }
          if verbose {
            println("[verbose] Scaffolding project...")
          }
          println("Initializing project '\{name}'")
          println("  Created \{name}/moon.mod.json")
          println("  Created \{name}/src/main/main.mbt")
          println("Done!")
        }
        _ => println("No command specified. Run with --help for usage information.")
      }
    },
  )
  .with_version("1.0.0")
  .add_example("demo serve --port 8080", "Start server on port 8080")
  .add_example("demo build -o dist -t wasm", "Build for wasm target")
  .add_example("demo init my-app", "Create a new project")
  .add_option(@margs.verbose_flag())
  .add_subcommand(serve_cmd)
  .add_subcommand(build_cmd)
  .add_subcommand(init_cmd)
}

fn main {
  let serve_cmd = @margs.subcommand(
    "serve",
    description="Start development server",
    aliases=["s"],
    options=[
      @margs.str_option(
        "host",
        short='H',
        long="host",
        help="Host to bind to",
        default="localhost",
      ),
      @margs.port_option(default=3000),
    ],
  )
  let build_cmd = @margs.subcommand(
    "build",
    description="Build the project",
    aliases=["b"],
    options=[
      @margs.str_option(
        "output",
        short='o',
        long="output",
        help="Output directory",
        default="dist",
        metavar="DIR",
      ),
      @margs.str_list_option(
        "target",
        short='t',
        long="target",
        help="Build target",
        metavar="TARGET",
      ),
    ],
  )
  let init_cmd = @margs.subcommand(
    "init",
    description="Initialize a new project",
    aliases=["i"],
    positionals=[@margs.positional("name", help="Project name")],
  )
  let app = build_app(serve_cmd, build_cmd, init_cmd)

  // Show help if no command specified
  let all_args = @sys.get_cli_args()
  if all_args.length() <= 1 {
    println(@margs.generate_help(app))
    return
  }

  let sub_name = find_subcmd_name()
  let _ : Result[Unit, Unit] = Ok(app.run()) catch {
    err => {
      match err {
        @margs.HelpRequested(_) =>
          match sub_name {
            "serve" => println(@margs.generate_subcommand_help(serve_cmd))
            "s" => println(@margs.generate_subcommand_help(serve_cmd))
            "build" => println(@margs.generate_subcommand_help(build_cmd))
            "b" => println(@margs.generate_subcommand_help(build_cmd))
            "init" => println(@margs.generate_subcommand_help(init_cmd))
            "i" => println(@margs.generate_subcommand_help(init_cmd))
            _ => println(@margs.generate_help(app))
          }
        @margs.MissingRequired(msg)
        | @margs.InvalidValue(msg)
        | @margs.UnknownOption(msg)
        | @margs.UnknownCommand(msg)
        | @margs.InvalidFormat(msg) => println("Error: \{msg}")
      }
      let exit_code = @margs.exit_code_for_error(err)
      @sys.exit(exit_code.code())
      Ok(())
    }
  }
}
