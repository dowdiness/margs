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
  let cli = @margs.create_cli(
    "demo",
    description="A demo project tool built with margs",
    version="1.0.0",
  )
  .add_example("demo serve --port 8080", "Start server on port 8080")
  .add_example("demo build -o dist -t wasm", "Build for wasm target")
  .add_example("demo init my-app", "Create a new project")
  .add_example("demo project deploy --env staging", "Deploy a project")

  let (cli, verbose) = cli.add(
    "verbose",
    @margs.flag(short='v', long="verbose", help="Enable verbose output"),
  )

  let serve = @margs.command("serve", description="Start development server", aliases=["s"])
  let (serve, host) = serve.add(
    "host",
    @margs.str_option(short='H', long="host", help="Host to bind to", default="localhost"),
  )
  let (serve, port) = serve.add(
    "port",
    @margs.int_option(
      short='p',
      long="port",
      help="Port number",
      default=3000,
      validator=fn(n) { n > 0 && n <= 65535 },
    ),
  )
  let serve = serve.set_handler(handler=fn(args) {
    let v = verbose.get(args).unwrap_or(false)
    let h = host.get(args).unwrap_or("localhost")
    let p = port.get(args).unwrap_or(3000)
    if v {
      println("[verbose] Configuring server...")
    }
    println("Server listening on http://\{h}:\{p}")
  })

  let build = @margs.command("build", description="Build the project", aliases=["b"])
  let (build, output) = build.add(
    "output",
    @margs.str_option(short='o', long="output", help="Output directory", default="dist", metavar="DIR"),
  )
  let (build, targets) = build.add(
    "target",
    @margs.str_list_option(short='t', long="target", help="Build target", metavar="TARGET"),
  )
  let build = build.set_handler(handler=fn(args) {
    let v = verbose.get(args).unwrap_or(false)
    let o = output.get(args).unwrap_or("dist")
    let ts = targets.get(args).unwrap_or([])
    if v {
      println("[verbose] Starting build...")
    }
    println("Building project -> \{o}/")
    for target in ts {
      println("  target: \{target}")
    }
    println("Build complete!")
  })

  let init_cmd = @margs.command("init", description="Initialize a new project", aliases=["i"])
  let init_cmd = init_cmd.add_positional(@margs.positional("name", help="Project name"))
  let init_cmd = init_cmd.set_handler(handler=fn(args) {
    let v = verbose.get(args).unwrap_or(false)
    let name = match args.get_positional(0) {
      Some(n) => n
      None => "my-project"
    }
    if v {
      println("[verbose] Scaffolding project...")
    }
    println("Initializing project '\{name}'")
    println("  Created \{name}/moon.mod.json")
    println("  Created \{name}/src/main/main.mbt")
    println("Done!")
  })

  let deploy = @margs.command("deploy", description="Deploy the project", aliases=["d"])
  let (deploy, env_opt) = deploy.add(
    "env",
    @margs.str_option(short='e', long="env", help="Deployment environment", default="prod"),
  )
  let deploy = deploy.set_handler(handler=fn(args) {
    let env = env_opt.get(args).unwrap_or("prod")
    println("Deploying to \{env}...")
    println("Deployment complete!")
  })

  let project = @margs.command("project", description="Manage the current project")
  let project = project.set_handler(handler=fn(_) { () })
  let project = project.add_command(deploy)

  cli
  .add_command(serve)
  .add_command(build)
  .add_command(init_cmd)
  .add_command(project)
}

///|
fn main {
  build_app().run()
}
