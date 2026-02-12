# margs

`margs` is a type-safe CLI toolkit for MoonBit.

It includes:
- A low-level parser/builder API (`parser`, `subcommand`, option constructors)
- A high-level wrapper API (`create_cli`, `command`) with handler-based dispatch

## Current Status

Implemented today:
- Typed options: `String`, `Int`, `Bool` flags, and repeated `String` lists
- Positional arguments and nested subcommands
- Auto-generated help text (main parser + subcommands)
- Built-in validators (`port_option`, `file_option`, `url_option`, `verbose_flag`, `quiet_flag`)
- Typo suggestions for unknown options/commands
- Structured parse errors and exit-code mapping
- High-level command wrapper API with global options and per-command handlers
- Middleware hooks (`add_before_hook` / `add_after_hook`) on CLI and commands
- In-process test helper (`run_for_test`) for CLI assertions

Not implemented yet:
- Env/config binding, shell completion, prompts, i18n, async handlers

## Installation

Add to `moon.mod.json`:

```json
{
  "deps": {
    "dowdiness/margs": "*"
  }
}
```

Or install via MoonBit tooling:

```bash
moon install dowdiness/margs
```

## Quick Start

```moonbit
fn main {
  @margs.create_cli("hello", description="Greeting CLI", version="0.1.0")
    .add_command(
      @margs.command("greet", handler=fn(args) {
        let name = match args.get_string("name") {
          Some(v) => v
          None => "World"
        }
        println("Hello, \{name}!")
      })
      .add_option(@margs.str_option("name", short='n', long="name", default="World")),
    )
    .run()
}
```

## Core API

- Wrapper API: `@margs.create_cli`, `@margs.command`, `Cli::add_command`, `Cli::add_before_hook`, `Cli::add_after_hook`, `Cli::run`, `Cli::run_for_test`
- Parser/builders: `@margs.parser`, `@margs.subcommand`
- Option constructors: `@margs.str_option`, `@margs.int_option`, `@margs.flag`, `@margs.str_list_option`, `@margs.positional`
- Validator helpers: `@margs.port_option`, `@margs.file_option`, `@margs.url_option`, `@margs.verbose_flag`, `@margs.quiet_flag`
- Help output: `@margs.generate_help`, `@margs.generate_subcommand_help`
- Metadata generation: `@margs.generate_metadata`
- Parsed accessors: `get_string`, `get_int`, `get_bool`, `get_string_list`, `get_positional`, `require_string`, `require_int`
- Output helpers: `@margs.log_info`, `@margs.log_warn`, `@margs.log_error`, `@margs.log_debug`, `@margs.success`, `@margs.failure`, `@margs.step`, `@margs.section`, `@margs.kv`

## Hook Semantics

- `before_hooks` run before handler dispatch.
- `after_hooks` are success-only: they run only if all `before_hooks` and the handler complete without raising.
- `after_hooks` are not `finally` hooks; do cleanup in the handler (or a dedicated wrapper) if cleanup must always run.

## Test Helper Semantics

- `run_for_test` is for asserting parse/help/error behavior and exit-code mapping.
- `CliTestResult.output` includes only framework-managed output (help/version/error text).
- `run_for_test` does not capture handler `println`/stdout on successful execution.

## Value Precedence

When an option value is specified in multiple places, `margs` resolves it using this precedence order (highest to lowest):

1. **Command-line arguments** (highest priority)
   ```bash
   mytool --port 3000
   ```

2. **Environment variables** (planned for Phase 2)
   ```bash
   MY_APP_PORT=3000 mytool
   ```

3. **Configuration file** (planned for Phase 2)
   ```json
   # ~/.mytoolrc.json
   { "port": 3000 }
   ```

4. **Option default value** (lowest priority)
   ```moonbit
   int_option("port", default=8080)
   ```

**Current status:**
- ✅ CLI arguments and defaults
- ✅ Environment variables (strings, ints, bools)
- ✅ Config file support (JSON)

## Environment Variable Support

Options can fall back to environment variables before using defaults:

```moonbit
let cli = create_cli("myapp")
  .add_option(str_option(
    "host",
    long="host",
    env="MYAPP_HOST",           // Falls back to $MYAPP_HOST
    default="localhost",
    help="Server hostname"
  ))
  .add_option(int_option(
    "port",
    long="port",
    env="MYAPP_PORT",           // Falls back to $MYAPP_PORT
    default=8080,
    help="Server port"
  ))
  .add_option(flag(
    "verbose",
    short='v',
    env="MYAPP_VERBOSE",        // Accepts: 1, true, yes, on
    help="Enable verbose logging"
  ))
```

**Precedence**: CLI arguments > environment variables > config file > default values

```bash
# Uses default
myapp
# → host=localhost, port=8080

# Uses env var
MYAPP_PORT=3000 myapp
# → host=localhost, port=3000

# CLI overrides env var
MYAPP_PORT=3000 myapp --port 9000
# → host=localhost, port=9000
```

## Config File Support

Load default values from a JSON configuration file:

```moonbit
let cli = create_cli("myapp")
  .with_config_file(".myapprc.json")
  .add_option(str_option("host", env="MYAPP_HOST", default="localhost"))
  .add_option(int_option("port", env="MYAPP_PORT", default=8080))
```

**Config file format** (`.myapprc.json`):
```json
{
  "host": "prod.example.com",
  "port": "3000",
  "verbose": "true"
}
```

**Precedence chain in action:**
```bash
# Config: host=prod.example.com, port=3000
# Env: MYAPP_PORT=5000
# CLI: --host custom.com

myapp
# → host=custom.com (CLI), port=5000 (env)
```

**Features:**
- Gracefully handles missing config files
- Simple flat JSON structure
- Works with all option types (string, int, bool, list)
- Auto-discovery with `discover_config_file("myapp")` (checks `.myapprc`, `.myapprc.json`)

## Metadata Generation

Generate JSON metadata from your CLI structure for shell completion scripts:

```moonbit
let cli = create_cli("myapp", version="1.0.0")
  .add_option(str_option("host", long="host", help="Server hostname"))
  .add_option(int_option("port", short='p', help="Server port"))
  .add_command(
    command("serve", handler=fn(_) { () })
      .add_option(flag("daemon", short='d', help="Run as daemon"))
  )

let metadata = generate_metadata(cli.parser)
println(metadata)
```

**Output** (formatted JSON):
```json
{
  "name": "myapp",
  "version": "1.0.0",
  "options": [
    {
      "key": "host",
      "type": "string",
      "long": "host",
      "help": "Server hostname",
      "metavar": "VALUE",
      "required": false
    },
    {
      "key": "port",
      "type": "int",
      "short": "p",
      "help": "Server port",
      "metavar": "NUM",
      "required": false
    }
  ],
  "commands": [
    {
      "name": "serve",
      "options": [
        {
          "key": "daemon",
          "type": "bool",
          "short": "d",
          "help": "Run as daemon",
          "required": false
        }
      ],
      "subcommands": []
    }
  ]
}
```

**Use cases:**
- Generate shell completion scripts (bash, zsh, fish)
- Create documentation automatically
- Build IDE/editor integrations
- Generate man pages

## Structured Output

Use the output helpers for consistent CLI formatting:

```moonbit
command("deploy", handler=fn(args) {
  section("Deployment")

  step("Building application...")
  // build logic here

  step("Uploading to server...")
  // upload logic here

  success("Deployment completed")

  kv("Status", "deployed")
  kv("Version", "1.2.3")
  kv("URL", "https://app.example.com")
})
```

Output:
```
=== Deployment ===
• Building application...
• Uploading to server...
✓ Deployment completed
  Status: deployed
  Version: 1.2.3
  URL: https://app.example.com
```

## Example App

A complete demo CLI is in `src/example/main.mbt`.

Run it:

```bash
moon run src/example -- --help
moon run src/example -- serve --help
moon run src/example -- build -o out -t wasm -t js
moon run src/example -- init my-app
```

## Development

```bash
moon check        # fast type-check
moon build        # build module
moon test         # run test suite
moon test -v      # verbose tests
moon run src/example -- --help
```

Project layout:
- `src/margs/`: library implementation (`types.mbt`, `builder.mbt`, `parser.mbt`, `help.mbt`, `validators.mbt`, `exit_codes.mbt`)
- `src/example/`: demo CLI using the library
- `docs/`: reports and planning docs

## Documents

- `docs/margs_cli_library_report.md`: architecture review, API analysis, and improvement proposals.

## Future Plans (Roadmap)

Planned direction (merged with what's already implemented):

1. Done: wrapper API, alias/nested command dispatch, and example CLI.
2. Phase 1: CLI test helpers and async-friendly handlers.
3. Phase 2: env/config integration, structured output helpers, metadata versioning.
4. Phase 3: shell completion, interactive prompts, i18n support.
5. Phase 4: plugin system and code generation/scaffolding.

These roadmap items are proposals and are not fully implemented in the current codebase.
