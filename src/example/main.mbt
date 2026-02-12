// Demo CLI application built with margs wrapper API
// Try running:
//   moon run src/example -- --help
//   moon run src/example -- --version
//   moon run src/example -- serve --help
//   moon run src/example -- -v serve --port 8080
//   moon run src/example -- build -o out -t wasm -t js
//   moon run src/example -- init my-app
//   moon run src/example -- project deploy --env staging

///|
fn build_app() -> @margs.Cli {
  @margs.create_cli(
    "demo",
    description="A demo project tool built with margs",
    version="1.0.0",
  )
  .add_example("demo serve --port 8080", "Start server on port 8080")
  .add_example("demo build -o dist -t wasm", "Build for wasm target")
  .add_example("demo init my-app", "Create a new project")
  .add_example("demo project deploy --env staging", "Deploy a project")
  .add_option(@margs.verbose_flag())
  .add_command(
    @margs.command(
      "serve",
      description="Start development server",
      aliases=["s"],
      handler=fn(args) {
        let verbose = args.get_bool("verbose")
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
      },
    )
    .add_option(
      @margs.str_option(
        "host",
        short='H',
        long="host",
        help="Host to bind to",
        default="localhost",
      ),
    )
    .add_option(@margs.port_option(default=3000)),
  )
  .add_command(
    @margs.command("build", description="Build the project", aliases=["b"], handler=fn(
      args,
    ) {
      let verbose = args.get_bool("verbose")
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
    })
    .add_option(
      @margs.str_option(
        "output",
        short='o',
        long="output",
        help="Output directory",
        default="dist",
        metavar="DIR",
      ),
    )
    .add_option(
      @margs.str_list_option(
        "target",
        short='t',
        long="target",
        help="Build target",
        metavar="TARGET",
      ),
    ),
  )
  .add_command(
    @margs.command(
      "init",
      description="Initialize a new project",
      aliases=["i"],
      handler=fn(args) {
        let verbose = args.get_bool("verbose")
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
      },
    ).add_positional(@margs.positional("name", help="Project name")),
  )
  .add_command(
    @margs.command("project", description="Manage the current project", handler=fn(
      _,
    ) {
      ()
    }).add_command(
      @margs.command(
        "deploy",
        description="Deploy the project",
        aliases=["d"],
        handler=fn(args) {
          let env = match args.get_string("env") {
            Some(value) => value
            None => "prod"
          }
          println("Deploying to \{env}...")
          println("Deployment complete!")
        },
      ).add_option(
        @margs.str_option(
          "env",
          short='e',
          long="env",
          help="Deployment environment",
          default="prod",
        ),
      ),
    ),
  )
}

///|
fn main {
  build_app().run()
}
