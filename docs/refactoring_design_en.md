# margs Internal Refactoring and Type-Safe API Design

## Overview

This document defines three interrelated improvements to margs.
Changes are applied from the inside out, in the following order.

1. **`resolve_raw_value` + `ValueSource`** — Separate value resolution into a two-stage pipeline
2. **Config test hardening** — Verify and complete test coverage for the existing `@json.parse` implementation
3. **`TypedHandle[T]`** — Eliminate string keys and guarantee option access at compile time

Each improvement builds on the output of the previous step.
Improvement 1 is an internal refactor plus making `ParsedArgs` fields `priv` (with accessors added). Improvement 2 is a test hardening pass (no code changes to `config.mbt`). Improvement 3 is a breaking change that removes the old API entirely.

### Versioning

Improvement 3 redesigns the majority of the public API and is a breaking change. The project is currently pre-1.0 (`0.1.x`), so this is shipped as a patch version bump (`0.1.2` → `0.1.3`). No compatibility layer or migration shim is provided. Users must rewrite to the new API entirely. Improvements 1 and 2 do not remove public APIs on their own, but they include field `priv` changes that anticipate Improvement 3, so all three are shipped in a single release.

---

## Improvement 1: `resolve_raw_value` + `ValueSource`

### Motivation

The current `init_defaults` (parser.mbt) hand-writes a three-stage env → config → default fallback for each of the five option types. This results in approximately 150 lines of identically-structured nesting repeated five times, with the following problems.

- Every new option type requires copying the same fallback structure
- Information about where a value came from (CLI, env, config, default) is lost
- Consistent fallback behavior is difficult to guarantee

### Design

#### `ValueSource` Type

```moonbit
pub enum ValueSource {
  FromCli
  FromEnv
  FromConfig
  FromDefault
} derive(Show, Eq)
```

#### Type Change for `ParsedArgs.values`

```moonbit
// Before
pub struct ParsedArgs {
  values : Map[String, ArgValue]
  ...
}

// After
pub struct ParsedArgs {
  priv command_path : Array[String]
  priv values : Map[String, (ArgValue, ValueSource)]
  priv positionals : Array[String]
}
```

All fields are made `priv`, and access is unified through accessors.
This prevents the type change in `values` from propagating to external code, and ensures from the start that `TypedHandle` cannot be bypassed in Improvement 3.

Note that `ParsedArgs` has `derive(Eq)`, so adding `ValueSource` to the tuple in `values` changes the semantics of `==` comparison. Before starting the refactor, grep for whole-`ParsedArgs` `==` comparisons across all test files (`grep -r "ParsedArgs" src/ --include="*.mbt" | grep "=="`) and rewrite any found to use accessors. Tests that compare individual values through accessors are unaffected.

#### `resolve_raw_value` Function

Unifies value resolution at the string level and attaches source information.

```moonbit
fn resolve_raw_value(
  key : String,
  env : String?,
  config : Map[String, String]?,
  default : String?,
) -> (String, ValueSource)? {
  // 1. env var
  match env {
    Some(env_name) =>
      match @sys.get_env_var(env_name) {
        Some(val) => return Some((val, FromEnv))
        None => ()
      }
    None => ()
  }
  // 2. config file
  match config {
    Some(cfg) =>
      match cfg.get(key) {
        Some(val) => return Some((val, FromConfig))
        None => ()
      }
    None => ()
  }
  // 3. default
  match default {
    Some(val) => Some((val, FromDefault))
    None => None
  }
}
```

#### Refactoring `init_defaults` (IntOption Example)

```moonbit
// Before: ~40 lines of nesting
IntOption(d) => {
  let value = match d.env {
    Some(env_name) =>
      match @sys.get_env_var(env_name) {
        Some(env_val) =>
          match parse_int_safe(env_val) {
            Some(n) => Some(n)
            None => d.default
          }
        None =>
          match config {
            Some(cfg) =>
              match cfg.get(d.key) {
                Some(cfg_val) =>
                  match parse_int_safe(cfg_val) { ... }
                None => d.default
              }
            None => d.default
          }
      }
    None => // ... same structure repeated ...
  }
  ...
}

// After: ~10 lines
IntOption(d) => {
  let default_str = d.default.map(fn(n) { n.to_string() })
  match resolve_raw_value(d.key, d.env, config, default_str) {
    Some((v, source)) =>
      match parse_int_safe(v) {
        Some(n) => values[d.key] = (Int(n), source)
        None =>
          match d.default {
            Some(n) => values[d.key] = (Int(n), FromDefault)
            None => ()
          }
      }
    None => ()
  }
}
```

#### Fallback Behavior on Type Conversion Failure

`resolve_raw_value` operates at the string level, so type conversion (`parse_int_safe`, etc.) is performed by the caller. The behavior when type conversion fails is defined explicitly.

**Design decision: silent fallback (preserves current behavior)**

When a string obtained from env or config fails type conversion (e.g. `MYAPP_PORT=abc`), no error is reported and the value falls back to `default`. If no `default` exists either, the value remains unset (`None`).

This behavior is chosen for the following reasons.

- It matches the current codebase's behavior. Improvement 1 is an internal refactor and should not change external behavior.
- Env variables depend on the user's environment. A hard error at startup could cause an app that worked in development to fail in production.
- When strict validation is needed, the user can check `TypedHandle::source` in the handler and reject values from unexpected sources.

**Tradeoff: silent fallback can produce surprising behavior**

When `MYAPP_PORT=abc` is set, the user's intent is "set port to abc", but the default value is used instead. This is arguably a surprising outcome. A future version should consider adding an option for strict env validation (`strict_env~ : Bool`).

#### Changes to `apply_option_value`

Values coming from the CLI are tagged with `FromCli`.

```moonbit
// Before
values[d.key] = Str(raw_value)

// After
values[d.key] = (Str(raw_value), FromCli)
```

#### Accessor Changes

Only tuple destructuring in pattern matches. The return type visible to external code remains unchanged.

```moonbit
// Before
pub fn ParsedArgs::get_string(self, key) -> String? {
  match self.values.get(key) {
    Some(Str(s)) => Some(s)
    _ => None
  }
}

// After
pub fn ParsedArgs::get_string(self, key) -> String? {
  match self.values.get(key) {
    Some((Str(s), _)) => Some(s)
    _ => None
  }
}
```

#### New Accessors

```moonbit
fn ParsedArgs::get_source(self, key) -> ValueSource? {
  match self.values.get(key) {
    Some((_, source)) => Some(source)
    None => None
  }
}

pub fn ParsedArgs::get_command_path(self) -> Array[String] {
  self.command_path
}
```

`get_source` is not made `pub` because it will only be exposed through `TypedHandle::source` in Improvement 3.

Note: MoonBit function visibility has only two levels: `pub fn` (exported outside the package) and `fn` (pkg-private, visible from all files within the package). There is no `priv` modifier for functions (`priv` is only used for struct fields and type declarations). Wherever this document says "remove `pub`" or "demote to pkg-private", it means `fn` (without `pub`). Since `fn` is accessible from any file within the package, there are no file placement constraints.

`get_command_path` and the existing `get_positional` remain `pub fn`. Command path and positional arguments are outside the scope of `TypedHandle`, and users need direct access to them.

### Impact

| File | Changes |
|---|---|
| `types.mbt` | Add `ValueSource`, make all `ParsedArgs` fields `priv`, change `values` type |
| `parser.mbt` | Add `resolve_raw_value`, refactor `init_defaults`, update accessors, update `apply_option_value`, add `get_source`, add `get_command_path` |
| `cli.mbt` | Replace direct field access on `ParsedArgs` with accessor calls (`args.command_path` → `args.get_command_path()`, etc.) |
| All existing test files | Verify no whole-`ParsedArgs` `==` comparisons or direct field access exist. Tests using accessors require no changes |
| New tests | `valuesource_wbtest.mbt` (whitebox tests for `resolve_raw_value` and `get_source`) |

New tests are written as whitebox tests (`_wbtest.mbt`). At the Improvement 1 stage, only `get_source` is pkg-private and thus the only target that strictly requires whitebox tests. However, since `get_string` and other accessors will also be demoted to `fn` (pkg-private) in Improvement 3, writing whitebox tests from the start avoids having to rewrite tests when Improvement 3 is applied.

### Verification

```bash
moon test                    # Verify existing tests pass
moon info                    # Regenerate pkg.generated.mbti
```

Any tests that use direct field access on `ParsedArgs` or whole-struct `==` comparisons must be rewritten to use accessors. Tests that already use only accessors require no changes. In the latter case, tests passing after Improvement 1 serves as evidence that the internal refactor has not altered external behavior.

---

## Improvement 2: Config Test Hardening for Existing `@json.parse`

### Motivation

`config.mbt` already uses `@json.parse` with typed extraction for strings, numbers (via `format_json_number` with `repr` preservation), and booleans. The hand-rolled `extract_strings` function has been removed. Improvement 2 is therefore not a parser replacement but a hardening pass to verify and complete the existing implementation.

Remaining gaps:

- A test for escaped-quote values is commented out (`config_test.mbt:59`) with a TODO. With `@json.parse` in place this should already pass; the test needs to be uncommented and verified.
- Dedicated `parse_json_config` coverage for JSON-native boolean values (`"verbose": true`) is absent.
- Number parsing and empty-object behavior are already covered in `config_test.mbt`; keep those tests as regression guards.

### Design

#### Current Implementation

`config.mbt` already uses `@json.parse` and handles all three primitive JSON types:

```moonbit
Number(n, repr~) => format_json_number(n, repr)  // preserves original repr for large ints
True  => config.set(key, "true")
False => config.set(key, "false")
```

`format_json_number` returns `None` for NaN/Infinity and uses `repr` when available to avoid 32-bit overflow on large integer literals. No code replacement is required.

#### Work Required

1. **Uncomment the escaped-quotes test** in `config_test.mbt:58-61`. The test is a leftover TODO from before `@json.parse` was introduced; it should pass as-is.

2. **Add an explicit test** for JSON-native boolean values in `parse_json_config`:

```moonbit
test "parse_json_config handles JSON boolean type" {
  let result = parse_json_config("{\"verbose\": true}")
  inspect(result, content="Some({\"verbose\": \"true\"})")
}
```

3. **Update `config_integration_test.mbt`** to use JSON-native types where appropriate (e.g. `"port": 3000` instead of `"port": "3000"`).

### Impact

| File | Changes |
|---|---|
| `config.mbt` | No changes required |
| `config_test.mbt` | Uncomment escaped-quote test; add explicit boolean test (number and empty-object tests already exist) |
| `config_integration_test.mbt` | Update fixtures to use JSON-native types where appropriate |

### Verification

```bash
moon test                    # All config tests pass, including the uncommented escaped-quote test
```

---

## Improvement 3: `TypedHandle[T]` — Type-Safe Option Access

### Motivation

The current API accesses option values by string key.

```moonbit
command("serve", handler=fn(args) {
  let port = args.get_int("port")     // typo "prot" just returns None
  let host = args.get_string("host")
})
.add_option(port_option())
.add_option(str_option("host", default="localhost"))
```

This design lacks the following type safety guarantees.

- Option name typos → not detectable at compile time
- Type mismatch (accessing an Int option with `get_string`) → silently returns `None`
- Correspondence between defined options and access points → must be matched manually

### Design Approach

Accept breaking changes and delete the old API entirely.

| Old API | Replacement |
|---|---|
| `command(name, handler~)` | `command(name)` + `set_handler` |
| `CliCommand::add_option(opt)` | `CliCommand::with[T](key, builder)` |
| `Cli::add_option(opt)` | `Cli::with[T](key, builder)` |
| `port_option(...)`, `verbose_flag()` and similar helpers | Deleted (factory functions are sufficient) |

#### `TypedHandle[T]` Type

A handle for extracting values from parse results in a type-safe manner. Generated at option definition time and used within the handler.

```moonbit
/// Type-safe option handle.
/// Binds option definition to value access at compile time.
/// Fields are priv so handles can only be created via `with`.
pub struct TypedHandle[T] {
  priv key : String
  priv extract : (ParsedArgs) -> T?
}

/// Get the value from the handle.
pub fn TypedHandle::get(self : TypedHandle[T], args : ParsedArgs) -> T? {
  (self.extract)(args)
}

/// Get the value from the handle.
/// Raises MissingRequired if the value was never set,
/// or InvalidValue if a value exists but type conversion failed.
/// The distinction is determined by checking get_source:
///   - get_source returns None → parser did not store a value → MissingRequired
///   - get_source returns Some(_) → parser stored a value but extract could not convert → InvalidValue
pub fn TypedHandle::require(
  self : TypedHandle[T],
  args : ParsedArgs,
) -> T raise ParseError {
  match (self.extract)(args) {
    Some(v) => v
    None =>
      match args.get_source(self.key) {
        Some(source) => raise InvalidValue(
          "option '\{self.key}' has an invalid value (source: \{source})",
        )
        None => raise MissingRequired(
          "required option '\{self.key}' is missing",
        )
      }
  }
}

/// Get the ValueSource from the handle.
pub fn TypedHandle::source(
  self : TypedHandle[T],
  args : ParsedArgs,
) -> ValueSource? {
  args.get_source(self.key)
}
```

`ParseError` already has an `InvalidValue` variant (`types.mbt`); no change needed. `TypedHandle::require` reuses it for the case where a value exists but extraction returns `None`.

#### `OptionBuilder[T]` Type

A type that absorbs differences in parameter signatures (e.g. flags have no `metavar`). Factory functions accept type-specific parameters and encapsulate both the `OptionSpec` construction method and the value extraction method as closures.

The `extract` field references `T`, so there is no phantom type parameter issue. Since no traits are used, there is no need to consider trait visibility, coherence rules, or local methods.

```moonbit
pub struct OptionBuilder[T] {
  priv build_spec : (String) -> OptionSpec
  priv extract : (ParsedArgs, String) -> T?
}
```

#### `CliCommand::with[T]` Method

Consolidates four `with_*` methods into a single generic method. `T` is inferred from `OptionBuilder[T]`, so the caller never needs to specify it explicitly. Works with plain generics, no trait constraints.

```moonbit
pub fn CliCommand::with[T](
  self : CliCommand,
  key : String,
  builder : OptionBuilder[T],
) -> (CliCommand, TypedHandle[T]) {
  let spec = (builder.build_spec)(key)
  let handle : TypedHandle[T] = {
    key,
    extract: fn(args) { (builder.extract)(args, key) },
  }
  (self.add_option_internal(spec), handle)
}
```

Note: `add_option_internal` is a rename of `add_option`. It disappears from the public API and is used only as an internal implementation detail of `with` (`fn`, pkg-private).

#### Factory Functions

Type-specific parameter differences are absorbed by factory functions. They share the same names as the old `str_option` etc., but the return type changes from `OptionSpec` to `OptionBuilder[T]`. Each factory encapsulates both `build_spec` (OptionSpec construction) and `extract` (value retrieval from ParsedArgs) as closures.

```moonbit
pub fn str_option(
  short? : Char, long? : String, help : String = "",
  metavar : String = "VALUE", required : Bool = false,
  default? : String, env? : String, validator? : (String) -> Bool,
) -> OptionBuilder[String] {
  {
    build_spec: fn(key) {
      StringOption({ key, short, long, help, metavar, required, default, env, validator })
    },
    extract: fn(args, key) { args.get_string(key) },
  }
}

pub fn int_option(
  short? : Char, long? : String, help : String = "",
  metavar : String = "NUM", required : Bool = false,
  default? : Int, env? : String, validator? : (Int) -> Bool,
) -> OptionBuilder[Int] {
  {
    build_spec: fn(key) {
      IntOption({ key, short, long, help, metavar, required, default, env, validator })
    },
    extract: fn(args, key) { args.get_int(key) },
  }
}

pub fn flag(
  short? : Char, long? : String, help : String = "",
  default : Bool = false, env? : String,
) -> OptionBuilder[Bool] {
  {
    build_spec: fn(key) {
      BoolFlag({ key, short, long, help, default, env })
    },
    extract: fn(args, key) { Some(args.get_bool(key)) },
  }
}

pub fn str_list_option(
  short? : Char, long? : String, help : String = "",
  metavar : String = "VALUE", env? : String,
) -> OptionBuilder[Array[String]] {
  {
    build_spec: fn(key) {
      StringListOption({ key, short, long, help, metavar, env })
    },
    extract: fn(args, key) { Some(args.get_string_list(key)) },
  }
}
```

#### `custom_option` — User-Defined Type Support

Used when a user wants to use a custom type such as `Duration` as an option. Parses as a string option, then converts via a user-provided `parse` function.

**Parse failure detection — two paths:**

When `parse` returns `None`, error reporting depends on the value's source.

**Path 1: Values from CLI (caught by validator)**

`parse` is integrated into the `validator` inside `build_spec`, so CLI-provided values are caught at parser level (reported as a validation error before handler execution). Invalid values like `--timeout=abc` are rejected by the validator in `apply_option_value`.

**Path 2: Values from env/config/default (caught by `require`)**

`init_defaults` does not run validators (constraint of the current codebase). As a result, values like `MYAPP_TIMEOUT=abc` are not caught at parser level and are stored as strings. At `extract` time, `parse("abc")` returns `None`, but `TypedHandle::require` checks `get_source`: when a source exists but extract returns `None`, it reports `InvalidValue` (not `MissingRequired`).

When using `TypedHandle::get`, `None` is returned and parse failure is indistinguishable from absence. If the distinction is needed, use the `get` + `source` combination, or use `require`.

**Behavior difference:** built-in options like `int_option` ignore invalid environment variables and fall back to defaults, while `custom_option` reports `InvalidValue` when an env/config/default value fails to parse. Call this out in docs and consider whether this stricter behavior is acceptable for your custom types.

```moonbit
pub fn custom_option[T](
  short? : Char, long? : String, help : String = "",
  metavar : String = "VALUE", required : Bool = false,
  default? : String, env? : String,
  parse~ : (String) -> T?,
) -> OptionBuilder[T] {
  {
    build_spec: fn(key) {
      StringOption({
        key, short, long, help, metavar, required, default, env,
        // validator only applies to CLI-provided values.
        // env/config/default are processed by init_defaults, which skips validators.
        validator: Some(fn(s) { parse(s).is_some() }),
      })
    },
    extract: fn(args, key) {
      match args.get_string(key) {
        Some(s) => parse(s)
        None => None
      }
    },
  }
}
```

Usage example:

```moonbit
let (cmd, timeout) = cmd.with("timeout", custom_option(
  long="timeout", metavar="SECONDS",
  parse=fn(s) { @duration.from_seconds_string(s) },
))
```

Error reporting summary:

| Source | Example invalid value | Detection timing | Error |
|---|---|---|---|
| CLI | `--timeout=abc` | Parse time (validator) | Validation error (before handler) |
| env | `MYAPP_TIMEOUT=abc` | In handler (`require` call) | `InvalidValue` |
| config | `{"timeout": "abc"}` | In handler (`require` call) | `InvalidValue` |
| None | Not specified | In handler (`require` call) | `MissingRequired` |

#### Changes to `command`

The `handler~` parameter is removed. Handlers are always set via `set_handler`.

**Handler type: preserving `raise Error`**

The current codebase's handler type is `(ParsedArgs) -> Unit raise Error`, where errors raised by handlers are caught and reported by the execution engine. The new API preserves this type. Dropping `raise Error` would cause the following regressions.

Calling `TypedHandle::require` directly inside a handler would become impossible (since `require` is `raise ParseError` and `ParseError` is a subtype of `Error`). Existing tests (`cli_test.mbt` etc.) that raise errors from handlers would break. The idiom of propagating I/O errors from handlers would be lost.

**Behavior when no handler is set:**
When `set_handler` is not called, the default handler displays the command's help text. This covers two cases.

Parent commands that only have subcommands (e.g. `git remote`) display help when invoked without a subcommand — this is intentional design. Forgetting to call `set_handler` results in help being displayed instead of a silent no-op, making the problem easy to notice.

```moonbit
/// Create a command.
/// Set the handler with set_handler after defining options.
/// If set_handler is not called, the command's help text is displayed.
pub fn command(
  name : String,
  description~ : String = "",
  aliases~ : Array[String] = [],
) -> CliCommand {
  {
    spec: subcommand(name, description~, aliases~),
    handler: None,  // None = display help
    commands: [],
    before_hooks: [],
    after_hooks: [],
  }
}
```

The `handler` field type is changed to `((ParsedArgs) -> Unit raise Error)?`. `None` indicates no handler is set, and the execution engine displays help text. `Some(fn)` is a user-defined handler, and errors are caught and reported by the execution engine. This eliminates the need for sentinel function identity checks, and guarantees handler-not-set detection at the type level.

#### Adding `set_handler`

Does not exist in the current codebase; must be newly added.

```moonbit
/// Set the handler on a command.
/// Call after defining options with `with`.
/// Handlers are allowed to raise Error, enabling direct TypedHandle::require calls
/// and I/O error propagation.
pub fn CliCommand::set_handler(
  self : CliCommand,
  handler : (ParsedArgs) -> Unit raise Error,
) -> CliCommand {
  { ..self, handler: Some(handler) }
}
```

#### Adding `with[T]` to `Cli` as Well

For global options. Signature is identical to `CliCommand::with`.

```moonbit
pub fn Cli::with[T](
  self : Cli,
  key : String,
  builder : OptionBuilder[T],
) -> (Cli, TypedHandle[T]) { ... }
```

#### Usage Example

```moonbit
fn main {
  let (cli, verbose) = create_cli("demo", version="1.0.0")
    .with("verbose", flag(short='v', help="Enable verbose output"))

  let cmd = command("serve")
  let (cmd, host) = cmd.with("host", str_option(short='H', default="localhost"))
  let (cmd, port) = cmd.with("port", int_option(short='p', default=3000))
  // Handlers are allowed to raise Error.
  // require can be called directly (no try/catch needed).
  let cmd = cmd.set_handler(fn(args) {
    let v = verbose.get(args).unwrap_or(false)
    let h = host.require!(args)   // Raises MissingRequired if no value
    let p = port.require!(args)   // Raises InvalidValue if value is unconvertible
    if v {
      println("[verbose] Configuring server...")
    }
    println("Server listening on http://\{h}:\{p}")
  })

  cli.add_command(cmd).run()
}
```

Note: `host` and `port` have default values, so `require` will not actually fail. `require` is used here to demonstrate that it can be called directly inside a `raise Error` handler. When defaults are present, `get(args).unwrap_or(default)` is also sufficient.

#### Accessing ValueSource via TypedHandle

Can be combined with the output of Improvement 1 for debug output.

```moonbit
let (cmd, port) = cmd.with("port", int_option(default=8080, env="MYAPP_PORT"))
let cmd = cmd.set_handler(fn(args) {
  let p = port.get(args).unwrap_or(8080)
  let source = port.source(args)
  match source {
    Some(FromEnv) => println("[info] port=\{p} (from environment variable)")
    Some(FromConfig) => println("[info] port=\{p} (from config file)")
    _ => ()
  }
})
```

### API Change Summary

| Old API | Change |
|---|---|
| `command(name, handler~)` | **Removed** → `command(name)` + `set_handler` |
| `CliCommand::add_option(opt)` | **Removed** → `CliCommand::with[T]` |
| `Cli::add_option(opt)` | **Removed** → `Cli::with[T]` |
| `str_option(...)`, `int_option(...)`, `flag(...)`, `str_list_option(...)` | Return type changed from `OptionSpec` to `OptionBuilder[T]` (remain `pub fn`) |
| `port_option(...)`, `verbose_flag()` and similar helpers | **Removed** (factory functions are sufficient) |
| `get_string(key)`, `get_int(key)` and similar accessors | **Demoted to `fn` (pkg-private)** (`OptionBuilder.extract` closures use them internally. Tests use whitebox tests) |

| New API | Description |
|---|---|
| `OptionBuilder[T]` | Encapsulates parameter differences and value extraction in closures. Returned by factory functions |
| `CliCommand::with[T](key, builder)` | Returns option definition and `TypedHandle[T]` as a tuple. Single generic method |
| `Cli::with[T](key, builder)` | For global options. Same as above |
| `custom_option[T](parse~)` | User-defined type support. Accepts a string parsing function |
| `CliCommand::set_handler(handler)` | Set the handler after option definitions. `(ParsedArgs) -> Unit raise Error` type |
| `TypedHandle::get`, `require`, `source` | Type-safe value access from handles |

`TypedHandle` calls existing accessors through the `OptionBuilder`'s `extract` closure. No changes to the parsing engine (`parser.mbt`) are required.

All `ParsedArgs` fields are made `priv` in Improvement 1, so bypassing `TypedHandle` for direct access is not possible.

#### Public API Surface After Improvement 3

The complete set of APIs available outside the package after all improvements is listed below.

**Types:**
`Cli`, `CliCommand`, `ParsedArgs` (fields `priv`), `TypedHandle[T]`, `OptionBuilder[T]`, `ValueSource`, `ParseError`

**Command construction:**
`create_cli`, `command`, `CliCommand::set_handler`, `CliCommand::with[T]`, `Cli::with[T]`, `Cli::add_command`, `Cli::run`

**Factory functions:**
`str_option`, `int_option`, `flag`, `str_list_option`, `custom_option[T]`

**Value access (via TypedHandle):**
`TypedHandle::get`, `TypedHandle::require`, `TypedHandle::source`

**Value access (direct):**
`ParsedArgs::get_command_path`, `ParsedArgs::get_positional`

**Intentionally non-public APIs:**
`get_string`, `get_int`, `get_bool`, `get_string_list`, `get_source` → `fn` (pkg-private).
`add_option_internal` → `fn` (pkg-private).

**Disposition of currently-public builder.mbt APIs:**

Improvement 3 defines an explicit disposition for every public function in `builder.mbt`. At implementation time, enumerate all current `pub fn` entries in `builder.mbt` and classify according to the following rules.

| Function | Disposition | Reason |
|---|---|---|
| `str_option`, `int_option`, `flag`, `str_list_option` | **Remain `pub fn`** (return type changes to `OptionBuilder[T]`) | Survive as factory functions in the new API |
| `port_option`, `verbose_flag` and similar convenience helpers | **Deleted** | Replaceable by factory function default arguments |
| `subcommand` | **Demoted to `fn` (pkg-private)** | Used internally by `command`. No need for external calls |
| Other `pub fn` (verify at implementation time) | **Case-by-case** | Demote or delete if unnecessary in new API. Keep if needed |

At implementation start, check `pkg.generated.mbti` generated by `moon info` and amend this table with dispositions for any public symbols not listed above before proceeding with implementation.

**Type dispositions:**

| Type | Disposition | Reason |
|---|---|---|
| `OptionSpec` (enum) | **Remain `pub`** (no change in Improvement 3) | Only constructed inside `build_spec` closures so external use is unnecessary, but making enum variants non-public requires verifying MoonBit type system constraints. Consider non-public status in a future release |
| `ArgValue` (enum) | **Remain `pub`** (no change in Improvement 3) | Same reasoning. Used only inside the `values` Map, which is already isolated via `priv` fields |
| `SubcommandSpec` | **Remain `pub`** | May be exposed as a field of `CliCommand`. Verify at implementation time |

### Impact

| File | Changes |
|---|---|
| `types.mbt` | Add `TypedHandle[T]` struct (fields `priv`), add `OptionBuilder[T]` struct, change `CliCommand.handler` type to `((ParsedArgs) -> Unit raise Error)?` (`InvalidValue` already present, no change needed) |
| `cli.mbt` | Remove `handler~` from `command`, add `set_handler` (`raise Error` type), demote `add_option` to `fn` (pkg-private), add `with[T]` method, add `handler: None` handling in execution engine |
| `builder.mbt` | Change return type of `str_option`, `int_option`, `flag`, `str_list_option` to `OptionBuilder[T]`, add `custom_option`, demote `subcommand` to `fn`, delete convenience helpers |
| `src/example/main.mbt` | Rewrite with new API |
| All existing test files | Rewrite with new API |
| New tests | `typed_handle_test.mbt` (including `InvalidValue` tests) |

### Verification

```bash
moon check                   # Type check
moon test                    # All tests (existing + new)
moon run src/example -- --help       # Verify sample app behavior
moon run src/example -- serve --port 8080
```

---

## Implementation Order and Dependencies

```
Improvement 1: resolve_raw_value + ValueSource
  │
  │  ParsedArgs.values type changes
  │  get_source becomes available
  │
  ├──→ Improvement 2: config test hardening
  │      │
  │      │  escaped-quote handling verified
  │      │  JSON native type coverage confirmed
  │      │
  │      └──→ Improvement 3: TypedHandle[T]
  │             │
  │             │  get_source exposed via TypedHandle::source
  │             │  JSON parsing enables typed defaults from config
  │             │
  │             └──→ Rewrite example + update documentation
```

Improvements 1 and 2 can be implemented independently, but 1 → 2 order is recommended. Introducing the `resolve_raw_value` pipeline in Improvement 1 first, then hardening config tests in Improvement 2, allows config-based fallback to be validated consistently on the new pipeline.

Improvement 3 depends on 1 (`TypedHandle::source` uses `get_source`).

---

## Risks and Notes

### MoonBit Json API Stability

The interfaces for `@json.parse` and the `Json` enum may change across MoonBit versions. Verify against the `moonbitlang/core` documentation for the relevant version at implementation time.

References:
- https://mooncakes.io/docs/moonbitlang/core/json#FromJson
- https://mooncakes.io/docs/moonbitlang/core/builtin#ToJson

### Closure Captures in `TypedHandle` and `OptionBuilder`

Three closures are involved in this design. Their capture targets are summarized below.

**1. `OptionBuilder.build_spec`** (defined inside factory functions)

Has the form `fn(key) { StringOption({ key, short, long, ... }) }`. `key` is received as an argument. Captures the factory function's parameter group (`short`, `long`, `help`, `default`, `env`, `validator`, etc.).

**2. `OptionBuilder.extract`** (defined inside factory functions)

Has the form `fn(args, key) { args.get_string(key) }`. `key` is received as an argument. For built-in factories (`str_option`, etc.), no external variables are captured. For `custom_option`, the user-provided `parse` function is captured.

**3. `TypedHandle.extract`** (defined inside `with[T]`)

Has the form `fn(args) { (builder.extract)(args, key) }`. Captures `builder.extract` (closure #2 above) and `key` (the `String` parameter of `with[T]`). `key` is immutable, so mutation issues do not arise.

During the `with` method chain, `cmd` is shadowed, but none of the three closures depend on `cmd`, so there is no impact.

### Scope of Breaking Changes

Improvement 3 is a breaking change that modifies the following public APIs.

- `command(name, handler~)` → changed to `command(name)` (`handler~` parameter removed)
- `CliCommand`'s `handler` field type changed to `((ParsedArgs) -> Unit raise Error)?` (`None` = display help)
- `CliCommand::add_option(opt)` and `Cli::add_option(opt)` → demoted to `fn` (pkg-private) (`with[T]` uses them internally)
- `str_option(...)`, `int_option(...)`, `flag(...)`, `str_list_option(...)` → return type changed from `OptionSpec` to `OptionBuilder[T]`
- `port_option(...)`, `verbose_flag()` and similar helpers → deleted
- `subcommand(...)` → demoted to `fn` (pkg-private)
- `InvalidValue` variant in `ParseError` — already present; reused by `TypedHandle::require` (no change needed)
- `get_string(key)`, `get_int(key)`, `get_double(key)`, `get_bool(key)`, `get_string_list(key)` → demoted to `fn` (pkg-private); external callers must switch to `TypedHandle::get` / `TypedHandle::require`

The `raise Error` handler type matches the current codebase and is not itself a breaking change.

All existing test files must be rewritten with the new API. `src/example/main.mbt` and the README quickstart must also be updated to the new API.

### Testing Strategy

Each improvement gates on `moon test` passing all tests.

For Improvement 1, tests that use direct field access must be rewritten to use accessors before verifying all tests pass. Accessor-based tests passing without modification provides evidence that the internal refactor preserves external behavior — though this is regression detection within the scope of test coverage, not a proof of correctness.

For Improvement 3, all existing tests are rewritten with the new API, so tests passing confirms the new API's behavior, not equivalence with the old API.
