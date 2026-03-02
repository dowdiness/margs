# Improvement 3: TypedHandle[T] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace string-key option access with type-safe `TypedHandle[T]` handles. Remove the old `add_option` + string-access API entirely.

**Architecture:** Add `TypedHandle[T]` and `OptionBuilder[T]` types; add `with[T]` methods to `Cli`, `CliCommand`, and `Parser`; change factory functions to return `OptionBuilder[T]` (removing the `key` first argument); change `CliCommand.handler` to `Option`; delete convenience helpers; demote old accessors and `subcommand` to pkg-private. Rewrite all test files and the example app.

**Tech Stack:** MoonBit, existing margs types. No new dependencies.

**Starting point:** This plan is executed after Improvements 1 and 2. Baseline test count is 181.

---

## Pre-flight: Enumerate all `pub fn` entries

Before writing any code, run:

```bash
moon info
```

Open `src/margs/pkg.generated.mbti` and classify every `pub fn` according to the disposition table in `docs/refactoring_design_en.md` (Improvement 3 section). Confirm the following against current file:

| Symbol | Expected disposition |
|---|---|
| `str_option`, `int_option`, `double_option`, `flag`, `str_list_option` | Remain `pub fn` (return type changes) |
| `custom_option` | New `pub fn` |
| `port_option`, `verbose_flag`, `quiet_flag`, `file_option`, `url_option` | **Deleted** |
| `subcommand` | Demoted to `fn` |
| `Cli::add_option`, `CliCommand::add_option` | Demoted to `fn add_option_internal` |
| `get_string`, `get_int`, `get_double`, `get_bool`, `get_string_list` | Demoted to `fn` |
| `get_source` | Already `fn` (added in Improvement 1) |
| `get_positional` | Remain `pub fn` (no `TypedHandle` for positionals) |
| `require_string`, `require_int`, `require_double` | Demoted to `fn` |
| `parse_int`, `parse_double`, `split_at`, `pad_right` | Demoted to `fn` |
| `find_similar`, `levenshtein_distance` | Demoted to `fn` |
| `option_key`, `option_short`, `option_long`, `option_required`, `option_help` | Demoted to `fn` |
| `generate_help`, `generate_subcommand_help`, `generate_metadata` | Remain `pub fn` |
| `load_config_file`, `discover_config_file`, `parse_json_config` | Remain `pub fn` |
| `log_debug`, `log_info`, `log_warn`, `log_error` | Remain `pub fn` |
| `failure`, `success`, `step`, `section`, `kv` | Remain `pub fn` |
| `exit_code_for_error` | Remain `pub fn` |
| `positional` | Remain `pub fn` |
| `parser` | Remain `pub fn` |
| `create_cli`, `command` | Remain `pub fn` (signatures change) |

Add any symbols present in `pkg.generated.mbti` but not listed above to the table before proceeding.

---

## Task 1: Add `TypedHandle[T]` and `OptionBuilder[T]` to `types.mbt`

**Files:**
- Modify: `src/margs/types.mbt` (append after `ParsedArgs` block)

**Step 1: Add the types**

Add after the `ParsedArgs` struct and its `derive` (before `ParseError`):

```moonbit
///|
/// Encapsulates option construction and value extraction as closures.
/// Returned by factory functions; consumed by `with[T]`.
pub struct OptionBuilder[T] {
  priv build_spec : (String) -> OptionSpec
  priv extract : (ParsedArgs, String) -> T?
}

///|
/// Type-safe option handle. Binds option definition to value access at compile time.
/// Fields are priv — handles can only be created via `with[T]`.
pub struct TypedHandle[T] {
  priv key : String
  priv extract : (ParsedArgs) -> T?
}

///|
pub fn TypedHandle::get(self : TypedHandle[T], args : ParsedArgs) -> T? {
  (self.extract)(args)
}

///|
/// Raises MissingRequired if no value was stored, or InvalidValue if a value
/// was stored but extraction returned None (e.g. type conversion failed).
pub fn TypedHandle::require(
  self : TypedHandle[T],
  args : ParsedArgs,
) -> T raise ParseError {
  match (self.extract)(args) {
    Some(v) => v
    None =>
      match args.get_source(self.key) {
        Some(source) =>
          raise InvalidValue(
            "option '\{self.key}' has an invalid value (source: \{source})",
          )
        None =>
          raise MissingRequired("required option '\{self.key}' is missing")
      }
  }
}

///|
pub fn TypedHandle::source(
  self : TypedHandle[T],
  args : ParsedArgs,
) -> ValueSource? {
  args.get_source(self.key)
}
```

Note: `args.get_source` is pkg-private and added in Improvement 1. This code is in the same package, so it compiles.

**Step 2: Run tests**

Run: `moon test`
Expected: all 181 tests pass (purely additive change).

**Step 3: Commit**

```bash
git add src/margs/types.mbt
git commit -m "Add TypedHandle[T] and OptionBuilder[T] types"
```

---

## Task 2: Add `with[T]` methods and `add_option_internal`

**Files:**
- Modify: `src/margs/cli.mbt`
- Modify: `src/margs/builder.mbt` (add `Parser::with`)

**Step 1: Add `add_option_internal` in `cli.mbt`**

Add immediately before the existing `Cli::add_option` definition:

```moonbit
///|
fn Cli::add_option_internal(self : Cli, opt : OptionSpec) -> Cli {
  { ..self, options: self.options + [opt] }
}

///|
fn CliCommand::add_option_internal(
  self : CliCommand,
  opt : OptionSpec,
) -> CliCommand {
  { ..self, spec: { ..self.spec, options: self.spec.options + [opt] } }
}
```

**Step 2: Add `Cli::with[T]` and `CliCommand::with[T]` in `cli.mbt`**

Add after `add_option_internal`:

```moonbit
///|
pub fn Cli::with[T](
  self : Cli,
  key : String,
  builder : OptionBuilder[T],
) -> (Cli, TypedHandle[T]) {
  let spec = (builder.build_spec)(key)
  let handle : TypedHandle[T] = {
    key,
    extract: fn(args) { (builder.extract)(args, key) },
  }
  (self.add_option_internal(spec), handle)
}

///|
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

**Step 3: Add `Parser::with[U]` in `builder.mbt`**

Lower-level tests use `Parser::add_option`. Since factory functions will no longer return `OptionSpec`, add `Parser::with[U]` so lower-level tests can use the same pattern:

Add after `Parser::add_option`:

```moonbit
///|
pub fn[T, U] Parser::with(
  self : Parser[T],
  key : String,
  builder : OptionBuilder[U],
) -> (Parser[T], TypedHandle[U]) {
  let spec = (builder.build_spec)(key)
  let handle : TypedHandle[U] = {
    key,
    extract: fn(args) { (builder.extract)(args, key) },
  }
  (self.add_option(spec), handle)
}
```

**Step 4: Run tests**

Run: `moon test`
Expected: all 181 tests pass (still additive — factory functions not yet changed).

**Step 5: Commit**

```bash
git add src/margs/cli.mbt src/margs/builder.mbt
git commit -m "Add with[T] methods and add_option_internal"
```

---

## Task 3: Change factory function signatures, add `custom_option`, rewrite all call sites

This is the largest task. Factory functions lose the `key` first argument and change return type from `OptionSpec` to `OptionBuilder[T]`. This immediately breaks every `.add_option(str_option(...))` call site. All affected files must be fixed in this same commit.

**Files:**
- Modify: `src/margs/builder.mbt`
- Modify: `src/margs/cli_test.mbt`
- Modify: `src/margs/help_test.mbt`
- Modify: `src/margs/metadata_test.mbt`
- Modify: `src/margs/env_test.mbt`
- Modify: `src/margs/parser_test.mbt`
- Modify: `src/margs/cli_wbtest.mbt`
- Modify: `src/margs/config_integration_test.mbt`
- Modify: `src/example/main.mbt`

### Step 1: Change factory functions in `builder.mbt`

Replace all five factory functions. The `key` parameter is removed — it is now passed via `with[T]`.

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

pub fn double_option(
  short? : Char, long? : String, help : String = "",
  metavar : String = "NUM", required : Bool = false,
  default? : Double, env? : String, validator? : (Double) -> Bool,
) -> OptionBuilder[Double] {
  {
    build_spec: fn(key) {
      DoubleOption({ key, short, long, help, metavar, required, default, env, validator })
    },
    extract: fn(args, key) { args.get_double(key) },
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

Also delete `subcommand` from `builder.mbt` (move to `cli.mbt` as `fn subcommand`), and delete `port_option`, `verbose_flag`, `quiet_flag`, `file_option`, `url_option`, `positional` convenience wrappers... wait, `positional` is still needed by external users (listed in "Remain `pub fn`"). Keep `positional`. Delete the convenience option helpers only.

### Step 2: Verify compilation fails

Run: `moon check`
Expected: errors at every `.add_option(str_option(...))` / `.add_option(int_option(...))` etc. call site. Errors confirm scope.

### Step 3: Rewrite test files

**Mechanical transformation rules:**

| Before | After |
|---|---|
| `.add_option(str_option("key", ...))` | `let (x, key_h) = x.with("key", str_option(...))` |
| `parser(...).add_option(str_option("key", env=...))` | `let (p, key_h) = p.with("key", str_option(env=...))` |
| `make_test_parser(options=[str_option("key", ...)])` | Delete helper; inline as `let p = parser("test", builder=fn(args) { args })` then `let (p, key_h) = p.with("key", str_option(...))` |
| `Parser::with_options([str_option("k1", ...), flag("k2", ...)])` | `let (p, k1_h) = p.with("k1", str_option(...))` then `let (p, k2_h) = p.with("k2", flag(...))` |
| `args.get_string("key")` | `key_h.get(args)` |
| `args.get_int("key")` | `key_h.get(args)` |
| `args.get_bool("key")` | `key_h.get(args).unwrap_or(false)` (flag always has value) |
| `result.get_string("key")` | `key_h.get(result)` (where `result : ParsedArgs` from `Parser[ParsedArgs]::parse`) |
| `result.get_int("key")` | `key_h.get(result)` |
| `result.get_bool("key")` | `key_h.get(result).unwrap_or(false)` |
| `result.get_positional(n)` | `result.get_positional(n)` (unchanged; `get_positional` remains `pub`) |
| `port_option(...)` | `int_option(long="port", ...)` |
| `verbose_flag()` | `flag(short='v', long="verbose", ...)` |

Apply these transformations to every affected test file.

For tests that do not use the new `TypedHandle` pattern (e.g. tests that verify error behavior without inspecting values), simply replace:
```moonbit
// Before
command("name", handler=fn(args) { ... }).add_option(str_option("key", ...))

// After
let cmd = command("name")
let (cmd, key_h) = cmd.with("key", str_option(...))
let cmd = cmd.set_handler(fn(args) { ... use key_h.get(args) ... })
```

### Step 4: Rewrite `src/example/main.mbt`

Rewrite using the new API. The `serve` command example:

```moonbit
let cli = create_cli("demo", description="A demo project tool built with margs", version="1.0.0")
  .add_example("demo serve --port 8080", "Start server on port 8080")
  ...

let (cli, verbose) = cli.with("verbose", flag(short='v', long="verbose", help="Enable verbose output"))

let serve = command("serve", description="Start development server", aliases=["s"])
let (serve, host) = serve.with("host", str_option(short='H', long="host", help="Host to bind to", default="localhost"))
let (serve, port) = serve.with("port", int_option(short='p', long="port", help="Port to listen on", default=3000))
let serve = serve.set_handler(fn(args) {
  let v = verbose.get(args).unwrap_or(false)
  let h = host.get(args).unwrap_or("localhost")
  let p = port.get(args).unwrap_or(3000)
  if v { println("[verbose] Configuring server...") }
  println("Server listening on http://\{h}:\{p}")
})
```

### Step 5: Run tests

Run: `moon test`
Expected: all tests pass. Count will differ from 181 due to test rewrites — note the actual count.

### Step 6: Commit

```bash
git add src/margs/builder.mbt src/margs/cli_test.mbt src/margs/help_test.mbt \
  src/margs/metadata_test.mbt src/margs/env_test.mbt src/margs/parser_test.mbt \
  src/margs/cli_wbtest.mbt src/margs/config_integration_test.mbt src/example/main.mbt
git commit -m "Change factory functions to OptionBuilder[T], rewrite all call sites"
```

---

## Task 4: Change `command()` handler to `Option`, update `dispatch`

**Files:**
- Modify: `src/margs/cli.mbt`

### Step 1: Change `CliCommand.handler` type in `types.mbt`

Wait — `CliCommand` is defined in `cli.mbt`, not `types.mbt`. Change the struct definition at the top of `cli.mbt`:

```moonbit
// Before
pub struct CliCommand {
  spec : SubcommandSpec
  handler : (ParsedArgs) -> Unit raise Error
  ...
}

// After
pub struct CliCommand {
  spec : SubcommandSpec
  handler : ((ParsedArgs) -> Unit raise Error)?
  ...
}
```

### Step 2: Change `command()` to remove `handler~`

```moonbit
pub fn command(
  name : String,
  description? : String = "",
  aliases? : Array[String] = [],
) -> CliCommand {
  {
    spec: subcommand(name, description~, aliases~),
    handler: None,
    commands: [],
    before_hooks: [],
    after_hooks: [],
  }
}
```

### Step 3: Update `CliCommand::set_handler` to wrap in `Some`

```moonbit
pub fn CliCommand::set_handler(
  self : CliCommand,
  handler : (ParsedArgs) -> Unit raise Error,
) -> CliCommand {
  { ..self, handler: Some(handler) }
}
```

Note: `handler~` labeled parameter becomes positional `handler`. Update all `set_handler(handler=fn...)` call sites to `set_handler(fn...)`.

### Step 4: Update `dispatch` in `Cli::to_parser`

The `dispatch` function calls `cmd.handler` directly. When `handler` is `None`, display the command's help text instead:

```moonbit
if index == args.command_path.length() - 1 {
  match cmd.handler {
    Some(h) => run_with_hooks(combined_before, h, combined_after, args)
    None => raise HelpRequested("")
  }
  return true
}
```

Apply the same `None` check to the fallback call at line 277:

```moonbit
match cmd.handler {
  Some(h) => run_with_hooks(combined_before, h, combined_after, args)
  None => raise HelpRequested("")
}
return true
```

### Step 5: Update `subcommand` visibility

Demote `subcommand` from `pub fn` to `fn` (remove `pub` keyword). It is only called from `command()` internally.

### Step 6: Run tests

Run: `moon test`
Expected: all tests pass.

### Step 7: Commit

```bash
git add src/margs/cli.mbt src/margs/builder.mbt
git commit -m "Change command() handler to Option, update dispatch for None case"
```

---

## Task 5: Demote and delete old APIs

**Files:**
- Modify: `src/margs/cli.mbt`
- Modify: `src/margs/parser.mbt`

### Step 1: Demote `Cli::add_option` and `CliCommand::add_option` in `cli.mbt`

These are now replaced by `add_option_internal`. Remove the `pub` keyword from both. Verify no external references remain (tests were rewritten in Task 3).

### Step 2: Demote accessor and require methods in `parser.mbt`

Remove `pub` from:
- `ParsedArgs::get_string`
- `ParsedArgs::get_int`
- `ParsedArgs::get_double`
- `ParsedArgs::get_bool`
- `ParsedArgs::get_string_list`
- `ParsedArgs::require_string`
- `ParsedArgs::require_int`
- `ParsedArgs::require_double`

These are called internally by `OptionBuilder.extract` closures and `TypedHandle::require`. After Task 3 rewrites all test files to use `TypedHandle`, no external test calls these directly.

### Step 3: Demote utility functions in `parser.mbt` and `cli.mbt`

Remove `pub` from: `parse_int`, `parse_double`, `split_at`, `pad_right`, `find_similar`, `levenshtein_distance`, `option_key`, `option_short`, `option_long`, `option_required`, `option_help`.

Verify each: search for references outside the package before demoting. If any external test uses them directly, rewrite that test first.

### Step 4: Run tests

Run: `moon test`
Expected: all tests pass.

### Step 5: Commit

```bash
git add src/margs/cli.mbt src/margs/parser.mbt
git commit -m "Demote old accessors, add_option, and utility functions to pkg-private"
```

---

## Task 6: Add `typed_handle_test.mbt`

**Files:**
- Create: `src/margs/typed_handle_test.mbt`

Write tests that exercise `TypedHandle::get`, `TypedHandle::require`, `TypedHandle::source`, and `custom_option`. Focus on cases not already covered by rewritten tests:

```moonbit
///|
test "TypedHandle::get returns Some for present value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.with("host", str_option(long="host", default="localhost"))
  let args = p.parse(["--host", "example.com"])
  inspect(host_h.get(args), content="Some(\"example.com\")")
}
```

Note: Use `parser("test", builder=fn(args) { args })` + `Parser::with` for `TypedHandle` unit tests — this gives back `ParsedArgs` directly from `parse`. The `Cli`/`CliCommand` API returns `Unit` from `parse`, so handle values must be tested via `Parser[ParsedArgs]` at the lower level.

Write at minimum:
1. `TypedHandle::get` returns `None` for absent optional
2. `TypedHandle::require` raises `MissingRequired` for absent required option
3. `TypedHandle::require` raises `InvalidValue` for invalid env value (use `custom_option`)
4. `TypedHandle::source` returns correct `ValueSource` variant
5. `custom_option` validator rejects invalid CLI input
6. `custom_option` parse failure from env raises `InvalidValue` via `require`

**Step 2: Run tests**

Run: `moon test`
Expected: all tests pass.

**Step 3: Commit**

```bash
git add src/margs/typed_handle_test.mbt
git commit -m "Add TypedHandle and custom_option tests"
```

---

## Task 7: Regenerate interface and final verification

**Step 1: Regenerate `pkg.generated.mbti`**

Run: `moon info`

Verify the generated file reflects the new public API:
- `TypedHandle[T]`, `OptionBuilder[T]` appear as types
- `TypedHandle::get`, `TypedHandle::require`, `TypedHandle::source` appear
- `CliCommand::with[T]`, `Cli::with[T]`, `Parser::with[U]` appear
- `custom_option[T]` appears
- `command` signature has no `handler~` parameter
- `str_option`, `int_option`, etc. have no `key` first argument
- `port_option`, `verbose_flag`, `quiet_flag`, `file_option`, `url_option` are absent
- `subcommand`, `get_string`, `get_int`, `add_option` (on Cli/CliCommand) are absent

**Step 2: Run full test suite**

Run: `moon test`
Expected: all tests pass, 0 failures.

**Step 3: Run example app**

```bash
moon run src/example -- --help
moon run src/example -- serve --port 8080
moon run src/example -- serve -v --port 9000
moon run src/example -- project deploy --env staging
```

Verify output matches expected behavior from the old API.

**Step 4: Commit**

```bash
git add src/margs/pkg.generated.mbti
git commit -m "Refresh generated interface after Improvement 3"
```
