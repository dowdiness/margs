# margs CLI Library: Analysis and Improvement Plan

## 1. Overview

The **margs** project is a type‑safe command‑line argument parsing library written in MoonBit.  It aims to provide a robust alternative to hand‑rolled parsers by supporting a wide range of features, including:

- **Type‑safe options and flags** – String, integer, boolean and string‑list options are supported and parsed into strongly typed values, reducing runtime errors【668764125869422†L4-L17】.  Developers can define defaults and mark options as required.
- **Positional arguments** and **subcommands** – The parser supports positional arguments with automatic help messages and can nest subcommands for complex CLIs【668764125869422†L4-L17】.
- **Smart defaults and validators** – Built‑in validators for files, ports, URLs, verbosity flags, etc., enable common patterns like range checks and existence checks【668764125869422†L4-L17】.
- **Automatic help and error messages** – The library generates usage information, flag/option descriptions, examples, and version output, and suggests corrections for typos using Levenshtein distance【668764125869422†L4-L17】.  It defines structured exit codes for different error classes.
- **Extensible API** – A builder pattern lets developers create parsers, add options, add subcommands, and customise help text and version output.  Parsed results are accessed via typed getters (`get_string`, `get_int`, etc.)【496166231662369†L26-L80】.

Despite these capabilities, **margs** is still primarily an argument parser.  The user’s goal is to evolve it into a more **user‑friendly CLI construction library** (similar to Python’s `click` or `commander` in Node.js) so that developers can “spin up” CLIs quickly without worrying about underlying parsing details.

## 2. Codebase Structure

The project is organised under `src/margs` with supportive modules and an `example` directory demonstrating usage.  The main files and their responsibilities are summarised below:

| File | Description |
| --- | --- |
| `src/margs/types.mbt` | Defines core types: `ArgValue` (str/int/bool/strlist), option and positional definitions, subcommand spec, parsed result (`ParsedArgs`), and `ParseError` union describing error variants【496166231662369†L26-L80】. |
| `src/margs/builder.mbt` | Provides the builder API.  Functions such as `str_option`, `int_option`, `flag`, `str_list_option`, `positional`, `parser`, and `subcommand` create option specs and parsers.  Methods on the `Parser` allow adding options, positionals, subcommands, version and example text【427817050538342†L4-L47】. |
| `src/margs/parser.mbt` | Implements the parsing engine.  It initialises defaults, matches options by long/short names, validates types, parses long and short options, handles `--` termination, deals with subcommands recursively, and performs required‑value validation.  It also defines typed accessors on `ParsedArgs` (e.g. `get_string`, `require_int`)【477455542317388†L170-L207】. |
| `src/margs/help.mbt` | Generates help and usage messages.  It computes flag widths, formats usage lines, lists commands/arguments/options, and includes description, version and examples.  It also produces subcommand‑specific help【427817050538342†L4-L47】. |
| `src/margs/validators.mbt` | Supplies convenience constructors for common patterns such as `file_option` (checks file existence), `port_option` (range 1–65535), `url_option`, and verbosity flags (`verbose_flag`, `quiet_flag`). |
| `src/margs/utils.mbt` | Contains utility functions: string splitting, integer parsing, padding text, retrieving option keys/short names/help, and Levenshtein distance with suggestion search【477455542317388†L170-L207】. |
| `src/margs/exit_codes.mbt` | Defines `ExitCode` (Success, GeneralError, MisusedCommand, InvalidInput) and maps parsing errors to exit codes. |
| `src/example/main.mbt` | Demonstrates usage: defines a parser with `serve`, `build` and `init` subcommands; adds options like `--host`, `--port`, `--output`, `--target`; parses arguments and handles `HelpRequested` or other errors appropriately.  This file illustrates typical usage patterns for developers. |

## 3. Public API and Design Goals

### Current API

The existing API emphasises low‑level control over argument parsing.  Developers must:

1. **Define a `Parser`** via builder functions (e.g. `parser("myapp")`), then call `.add_option`, `.add_positional`, `.add_subcommand`, `.set_version`, etc.
2. **Define subcommands** using `subcommand(name, description, builder_function)`; nested subcommands require manually creating new parsers.
3. **Parse arguments** with `parser.run(argv)`.  The result is a `ParsedArgs` structure, from which values are retrieved using typed getters (`get_string`, `get_int`)【477455542317388†L170-L207】.
4. **Handle errors** by catching variants of `ParseError` and converting them to exit codes with helper functions.

While powerful, this design can feel verbose for simple CLIs, and it still exposes the underlying parse engine.  To reposition **margs** as a **CLI‑builder library** rather than just an argument parser, the API should offer higher‑level abstractions.

### Proposed High‑Level API

A wrapper should allow developers to declaratively define a CLI with minimal boilerplate.  The following functions illustrate a possible API in pseudocode (MoonBit syntax simplified for clarity):

```moonbit
// top‑level entry point returning a CLI program
let app = create_cli(name: string, description: string, version: string?)

// define a top‑level option
app.add_global_option(name: string, short: char?, type: Type, default: ArgValue, description: string)

// define a command or subcommand (returns Command object)
let cmd = app.command(name: string, description: string)

// add options / positional arguments to a command
cmd.option(name: string, short: char?, type: Type, default: ArgValue, description: string, required: bool)
cmd.positional(name: string, type: Type, description: string, required: bool)

// define the handler executed when the command is invoked
cmd.handle(async fn(args: ParsedArgs) {
    // business logic using typed getters
})

// start processing (parses arguments, dispatches to appropriate handler)
app.run()
```

This API hides low‑level parser mechanics.  Developers focus on describing commands and options and providing handlers.  Internally, the library builds `Parser` and `SubcommandSpec` structures, applies validators, generates help/usage text, and dispatches to the correct handler.  Additional features (hooks, middleware, interactive prompts) can be integrated via optional APIs.

## 4. Internal Architecture (How It Works)

`parser.mbt` is the heart of the library.  Key functions include:

- **`init_defaults`** – populates the parsed result with default values for each option before parsing begins.
- **`find_option_by_long` / `find_option_by_short`** – search registered options by name or short flag, enabling suggestions when unknown flags are encountered.
- **`parse_long_option` / `parse_short_option`** – parse `--key=value` or `-abc` forms, splitting combined short flags into multiple options and handling flags with values (e.g. `-o output`).  Unknown options trigger `UnknownOption` errors with suggestion hints using Levenshtein distance【477455542317388†L170-L207】.
- **`parse_args`** – loops through command‑line arguments, routes to subcommands when matching a name, stops option parsing at `--`, collects positional arguments, and validates that all required options and positionals are provided.
- **`apply_option_value`** – applies type conversions and validators, storing results in the `ParsedArgs` map or raising `InvalidValue` errors when conversion fails.
- **Typed accessors** – methods on `ParsedArgs` (e.g. `get_string`, `get_int`, `get_bool`, `get_string_list`) safely retrieve values with optional `require_*` variants that throw if the value is missing【477455542317388†L170-L207】.

Error handling is robust: parsing functions return `ParseError` variants (e.g. `UnknownOption`, `MissingRequired`, `InvalidValue`, `InvalidFormat`) which map to exit codes via `exit_codes.mbt`.  Help and version requests are handled by exceptions (`HelpRequested`, `VersionRequested`) that short‑circuit normal execution.

## 5. Proposed Enhancements and Design Ideas

To reposition **margs** as a convenient **CLI construction framework**, the following improvements are recommended:

1. **High‑level declaration API** – Provide functions such as `create_cli`, `command`, `option`, `positional`, and `run` (as shown above).  This hides internal parser details and emphasises declarative command specification.  Subcommands should be created via method calls rather than manual parser instantiation.  A default help and version flag should be automatically added.
2. **Command handlers with dependency injection** – Allow each command to define an async handler that receives parsed arguments and returns a result or error.  This pattern encourages a single entry point and avoids manual `match` statements.
3. **Global options and context** – Support global flags (e.g. `--verbose`, `--quiet`, `--config`) that apply to all commands.  The CLI runner should propagate these values to handlers.
4. **Middleware / hooks** – Add a mechanism to register middleware functions executed before/after command handlers.  This enables cross‑cutting concerns like logging, timing, telemetry, or pre‑validation.
5. **Environment variables and config files** – Provide a way to bind options to environment variables (e.g. `MYAPP_HOST`) and to load default values from configuration files (TOML/YAML).  This reduces the need for repetitive options in scripts.
6. **Interactive prompts** – Integrate interactive prompts (yes/no, select list, input) to collect values when options are missing.  This makes CLI tools more user friendly.
7. **Auto‑completion scripts** – Generate shell completion scripts (bash, zsh, fish) automatically from the command specification, improving discoverability.
8. **Internationalisation (i18n)** – Externalise help messages and error text to allow translation.  Provide locale selection via environment variable.
9. **Asynchronous command support** – Support async handlers (similar to `async fn` in other languages) to simplify integration with asynchronous I/O (network, file operations).
10. **Testing helpers** – Provide utilities to test CLI applications easily (simulate command invocations and capture output), encouraging robust test coverage.

These enhancements will elevate **margs** from a parser to a full‑fledged CLI framework with a friendly developer experience.

## 6. Roadmap

A phased roadmap helps prioritise features and manage scope:

### Phase 1 – Core Wrapper (Must‑Have)

- **Implement the high‑level API** (`create_cli`, `command`, `option`, `positional`, `run`); unify subcommand handling and hide parser internals.
- **Automatic help and version** – Always include `--help` and `--version` flags with generated usage text and version output.
- **Global error handling** – Centralise catch of `ParseError` and map to exit codes; unify error messages.
- **Documentation and examples** – Add comprehensive examples demonstrating simple and complex CLI apps using the new API.

### Phase 2 – Advanced Features (Should‑Have)

- **Middleware / hooks** – Provide registration of pre‑ and post‑handlers for commands.
- **Config and environment** – Allow options to be read from env variables or a config file; support default paths.
- **Auto‑completion** – Generate shell completion scripts from the command specification.
- **Testing utilities** – Offer functions to invoke the CLI programmatically and assert on results, exit codes, and output.

### Phase 3 – Extended Usability (Nice‑to‑Have)

- **Interactive prompts** – Integrate a prompt system to ask for missing values or confirmations.
- **Internationalisation** – Add i18n support for help and error messages.
- **Async handlers** – Provide built‑in scheduling of async tasks and concurrency support.

### Long‑Term Vision

- Support remote command execution and plugin systems.
- Provide a GUI wrapper to auto‑generate cross‑platform desktop apps from CLI definitions.
- Explore code generation to produce skeleton CLI projects from definitions (for languages beyond MoonBit).

## 7. Example TODO File

A `TODO.md` file can capture concrete tasks for contributors:

```
# TODO for margs CLI framework

## Phase 1

- [ ] Introduce `create_cli` and `command` functions with handler registration.
- [ ] Refactor existing parser to support declarative command definitions.
- [ ] Add global `--help`/`--version` support automatically.
- [ ] Write a migration guide from current API to new high‑level API.

## Phase 2

- [ ] Implement middleware hooks (before/after command).
- [ ] Add environment variable and config file parsing.
- [ ] Generate shell completion scripts.
- [ ] Provide test helpers for CLI invocation.

## Phase 3

- [ ] Integrate interactive prompts for missing values.
- [ ] Add localisation support (language files).
- [ ] Enable async command handlers.

```

## 8. Conclusion

The **margs** project is already a robust type‑safe argument parser.  However, by introducing a high‑level declarative API, global options, middleware, configuration and testing support, it can evolve into a modern CLI framework.  These improvements will reduce boilerplate, improve usability, and encourage adoption within the MoonBit ecosystem.  A phased roadmap and clear TODO items provide a path forward for contributors.
