# margs

A simple command-line argument parser for MoonBit.

## Features

- **Type-safe parsing** - Define your CLI structure once, get strongly-typed results
- **Rich option types** - String, Int, Bool flags, and String lists
- **Subcommands** - Nested subcommands with their own options and positionals
- **Flexible syntax** - Supports both short (`-p`) and long (`--port`) options
- **Validators** - Built-in and custom validation for option values
- **Help generation** - Automatic help text generation from your specification
- **Positional arguments** - Required and optional positional arguments
- **Smart defaults** - Common CLI patterns like `--verbose`, `--port`, `--file`

## Installation

Add margs to your `moon.mod.json`:

```json
{
  "deps": {
    "dowdiness/margs": "*"
  }
}
```

Or install via moon:

```bash
moon install dowdiness/margs
```

## Quick Start

```moonbit
fn main {
  let app = @margs.parser(
    "myapp",
    description="A simple CLI tool",
    builder=fn(args) {
      let name = args.get_string("name").unwrap_or("World")
      let count = args.get_int("count").unwrap_or(1)
      for i = 0; i < count; i = i + 1 {
        println("Hello, \{name}!")
      }
    },
  )
  .add_option(@margs.str_option(
    "name",
    short='n',
    long="name",
    help="Name to greet",
    default="World",
  ))
  .add_option(@margs.int_option(
    "count",
    short='c',
    long="count",
    help="Number of greetings",
    default=1,
  ))

  let _ : Result[Unit, Unit] = Ok(app.run()) catch {
    @margs.HelpRequested(_) => {
      println(@margs.generate_help(app))
      Ok(())
    }
    @margs.ParseError(msg) => {
      println("Error: \{msg}")
      Ok(())
    }
  }
}
```

Usage:
```bash
$ myapp --name Alice --count 3
Hello, Alice!
Hello, Alice!
Hello, Alice!

$ myapp --help
A simple CLI tool

Usage: myapp [OPTIONS]

Options:
  -n, --name <VALUE>   Name to greet
  -c, --count <NUM>    Number of greetings
  -h, --help           Print help
```

## Option Types

### String Options

```moonbit
@margs.str_option(
  "output",
  short='o',
  long="output",
  help="Output file path",
  metavar="FILE",
  required=true,
  default="out.txt",
  validator=fn(s) { s.length() > 0 },
)
```

### Integer Options

```moonbit
@margs.int_option(
  "port",
  short='p',
  long="port",
  help="Port number",
  metavar="PORT",
  default=8080,
  validator=fn(n) { n > 0 && n <= 65535 },
)
```

### Boolean Flags

```moonbit
@margs.flag(
  "verbose",
  short='v',
  long="verbose",
  help="Enable verbose output",
  default=false,
)
```

### String List Options

Can be specified multiple times to collect multiple values:

```moonbit
@margs.str_list_option(
  "target",
  short='t',
  long="target",
  help="Build target",
  metavar="TARGET",
)
```

Usage: `myapp -t wasm -t js -t native`

## Positional Arguments

```moonbit
@margs.positional(
  "input",
  help="Input file path",
  required=true,
)
```

## Subcommands

Create complex CLI tools with nested subcommands:

```moonbit
let serve_cmd = @margs.subcommand(
  "serve",
  description="Start development server",
  aliases=["s"],
  options=[
    @margs.str_option("host", short='H', long="host", default="localhost"),
    @margs.port_option(default=3000),
  ],
)

let app = @margs.parser(
  "mytool",
  description="A CLI with subcommands",
  builder=fn(args) {
    let cmd = if args.command_path.length() > 1 {
      args.command_path[1]
    } else {
      ""
    }
    match cmd {
      "serve" => {
        let host = args.get_string("host").unwrap_or("localhost")
        let port = args.get_int("port").unwrap_or(3000)
        println("Server running on http://\{host}:\{port}")
      }
      _ => println("No command specified")
    }
  },
)
.add_subcommand(serve_cmd)
```

## Accessing Parsed Values

The `ParsedArgs` type provides type-safe accessors:

```moonbit
// Optional values (return Option[T])
args.get_string("key")      // -> String?
args.get_int("key")         // -> Int?
args.get_bool("key")        // -> Bool (defaults to false)
args.get_string_list("key") // -> Array[String]

// Required values (raise ParseError if missing)
args.require_string("key")  // -> String raise ParseError
args.require_int("key")     // -> Int raise ParseError

// Positional arguments
args.get_positional(0)      // -> String?

// Command path (e.g., ["app", "subcommand"])
args.command_path           // -> Array[String]
```

## Common Validators

Pre-built validators for common patterns:

```moonbit
// Port number (1-65535)
@margs.port_option(key="port", short='p', default=8080)

// File path
@margs.file_option(key="config", short='c', required=true)

// URL
@margs.url_option(key="endpoint", short='u')

// Verbose flag
@margs.verbose_flag()

// Quiet flag
@margs.quiet_flag()
```

## Error Handling

All parsing errors are represented by the `ParseError` suberror type:

```moonbit
@margs.MissingRequired(String)  // Required option/positional missing
@margs.InvalidValue(String)     // Validation failed
@margs.UnknownOption(String)    // Unrecognized option
@margs.UnknownCommand(String)   // Unrecognized subcommand
@margs.InvalidFormat(String)    // Malformed argument
@margs.HelpRequested(String)    // User requested help
```

Handle errors with pattern matching:

```moonbit
let _ = Ok(app.run()) catch {
  @margs.HelpRequested(_) => {
    println(@margs.generate_help(app))
    Ok(())
  }
  @margs.MissingRequired(msg) => {
    println("Error: \{msg}")
    Ok(())
  }
  @margs.InvalidValue(msg) => {
    println("Error: \{msg}")
    Ok(())
  }
}
```

## Help Generation

Help text is automatically generated from your parser specification:

```moonbit
// For main parser
@margs.generate_help(app)

// For subcommands
@margs.generate_subcommand_help(subcommand_spec)
```

## Argument Syntax

margs supports standard CLI conventions:

```bash
# Long options
--name value
--name=value

# Short options
-n value
-nvalue

# Flags (boolean)
-v
--verbose

# Combining short flags
-vvv  # Multiple verbose flags
-abc  # Equivalent to -a -b -c

# End of options marker
-- --not-an-option  # Everything after -- is positional

# Help
--help
-h
```

## Advanced Example

See the complete example in `src/example/main.mbt`:

```bash
# Run the example
moon run src/example -- --help
moon run src/example -- serve --port 8080
moon run src/example -- build -o dist -t wasm -t js
moon run src/example -- init my-project
```

## Testing

Run tests with:

```bash
moon test
```

## Project Structure

```
margs/
├── src/
│   ├── margs/
│   │   ├── types.mbt        # Core types and data structures
│   │   ├── builder.mbt      # Builder API for parser construction
│   │   ├── parser.mbt       # Parsing engine
│   │   ├── help.mbt         # Help text generation
│   │   ├── validators.mbt   # Common validators
│   │   ├── utils.mbt        # Utility functions
│   │   └── *_test.mbt       # Unit tests
│   └── example/
│       └── main.mbt         # Demo CLI application
├── moon.mod.json
└── README.md
```

## Design Philosophy

- **Type safety first** - Leverage MoonBit's type system to catch errors at compile time
- **Ergonomic API** - Fluent builder pattern for intuitive parser construction
- **No magic** - Explicit, predictable behavior without hidden surprises
- **Standard conventions** - Follow established CLI patterns (POSIX-style options)
