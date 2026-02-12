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
- Parsed accessors: `get_string`, `get_int`, `get_bool`, `get_string_list`, `get_positional`, `require_string`, `require_int`

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

**Current status:** Only CLI arguments and defaults are implemented. Environment variable and config file support are planned for Phase 2.

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
