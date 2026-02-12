# margs

`margs` is a type-safe command-line argument parser for MoonBit.

It provides a small builder API for defining options, flags, positionals, and subcommands, then parsing CLI input into typed values.

## Current Status

Implemented today:
- Typed options: `String`, `Int`, `Bool` flags, and repeated `String` lists
- Positional arguments and nested subcommands
- Auto-generated help text (main parser + subcommands)
- Built-in validators (`port_option`, `file_option`, `url_option`, `verbose_flag`, `quiet_flag`)
- Typo suggestions for unknown options/commands
- Structured parse errors and exit-code mapping

Not implemented yet:
- High-level command handler wrapper API (`create_cli`-style)
- Env/config binding, middleware hooks, shell completion, prompts, i18n, async handlers

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
  let app = @margs.parser(
    "hello",
    description="Greeting CLI",
    builder=fn(args) {
      let name = match args.get_string("name") {
        Some(v) => v
        None => "World"
      }
      let count = match args.get_int("count") {
        Some(v) => v
        None => 1
      }
      for i = 0; i < count; i = i + 1 {
        println("Hello, \{name}!")
      }
    },
  )
  .with_version("0.1.0")
  .add_option(@margs.str_option("name", short='n', long="name", default="World"))
  .add_option(@margs.int_option("count", short='c', long="count", default=1))

  let _ : Result[Unit, Unit] = Ok(app.run()) catch {
    err => {
      match err {
        @margs.HelpRequested(_) => println(@margs.generate_help(app))
        @margs.MissingRequired(msg)
        | @margs.InvalidValue(msg)
        | @margs.UnknownOption(msg)
        | @margs.UnknownCommand(msg)
        | @margs.InvalidFormat(msg) => println("Error: \{msg}")
      }
      @sys.exit(@margs.exit_code_for_error(err).code())
      Ok(())
    }
  }
}
```

## Core API

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

Planned direction from `docs/margs_cli_library_report.md`:

1. Phase 1: high-level wrapper API for command handlers, automatic help/version flow, and migration docs.
2. Phase 2: middleware/hooks, environment/config integration, shell completion, and CLI test helpers.
3. Phase 3: interactive prompts, i18n support, and async-oriented command workflows.

These roadmap items are proposals and are not fully implemented in the current codebase.
