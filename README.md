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

- Wrapper API: `@margs.create_cli`, `@margs.command`, `Cli::add_command`, `Cli::add_before_hook`, `Cli::add_after_hook`, `Cli::run`
- Parser/builders: `@margs.parser`, `@margs.subcommand`
- Option constructors: `@margs.str_option`, `@margs.int_option`, `@margs.flag`, `@margs.str_list_option`, `@margs.positional`
- Validator helpers: `@margs.port_option`, `@margs.file_option`, `@margs.url_option`, `@margs.verbose_flag`, `@margs.quiet_flag`
- Help output: `@margs.generate_help`, `@margs.generate_subcommand_help`
- Parsed accessors: `get_string`, `get_int`, `get_bool`, `get_string_list`, `get_positional`, `require_string`, `require_int`

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
