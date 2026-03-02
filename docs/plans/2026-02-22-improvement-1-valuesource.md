# Improvement 1: resolve_raw_value + ValueSource Implementation Plan

> **REQUIRED SUB-SKILL:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor `init_defaults` into a unified `resolve_raw_value` pipeline and attach `ValueSource` provenance to every stored value, making all `ParsedArgs` fields `priv` to shield external users from the internal type change.

**Architecture:** Add `ValueSource` enum to `types.mbt`; add `resolve_raw_value` (env → config → default, returns raw string + source) to `parser.mbt`; change `ParsedArgs.values` from `Map[String, ArgValue]` to `Map[String, (ArgValue, ValueSource)]`; update every consumer of that map; make all three `ParsedArgs` fields `priv`; add `get_source` (pkg-private) and `get_command_path` (pub) accessors; update `cli.mbt` to use `get_command_path()`. Improvements 1 and 2 are shipped together as a breaking release so `ParsedArgs` field visibility is finalized here.

**Tech Stack:** MoonBit, `@sys` (env vars), `@json` (config), existing margs types.

---

## Task 1: Add `ValueSource` enum to `types.mbt`

**Files:**
- Modify: `src/margs/types.mbt` (after `ArgValue` block, ~line 12)

**Step 1: Add the enum**

```moonbit
///|
pub enum ValueSource {
  FromCli
  FromEnv
  FromConfig
  FromDefault
} derive(Show, Eq)
```

Insert after the `ArgValue` Show impl block (around line 26), before the option def structs.

**Step 2: Run tests**

Run: `moon test`
Expected: `Total tests: 165, passed: 165, failed: 0.`

**Step 3: Commit**

```bash
git add src/margs/types.mbt
git commit -m "Add ValueSource enum for value provenance tracking"
```

---

## Task 2: Add `resolve_raw_value` with whitebox tests (TDD)

**Files:**
- Create: `src/margs/valuesource_wbtest.mbt`
- Modify: `src/margs/parser.mbt` (add function before `init_defaults`)

**Step 1: Create the whitebox test file with failing tests**

```moonbit
// Whitebox tests for resolve_raw_value and get_source

///|
test "resolve_raw_value returns env var with FromEnv" {
  @sys.set_env_var("TEST_RRV_KEY", "hello")
  let result = resolve_raw_value("key", Some("TEST_RRV_KEY"), None, None)
  inspect(result, content="Some((\"hello\", FromEnv))")
  @sys.unset_env_var("TEST_RRV_KEY")
}

///|
test "resolve_raw_value skips env and returns config with FromConfig" {
  let config : Map[String, String] = Map::new()
  config.set("key", "world")
  let result = resolve_raw_value("key", None, Some(config), None)
  inspect(result, content="Some((\"world\", FromConfig))")
}

///|
test "resolve_raw_value falls through to default with FromDefault" {
  let result = resolve_raw_value("key", None, None, Some("fallback"))
  inspect(result, content="Some((\"fallback\", FromDefault))")
}

///|
test "resolve_raw_value returns None when no source" {
  let result = resolve_raw_value("key", None, None, None)
  inspect(result, content="None")
}

///|
test "resolve_raw_value prefers env over config" {
  @sys.set_env_var("TEST_RRV_PREF", "from-env")
  let config : Map[String, String] = Map::new()
  config.set("key", "from-config")
  let result = resolve_raw_value("key", Some("TEST_RRV_PREF"), Some(config), Some("default"))
  inspect(result, content="Some((\"from-env\", FromEnv))")
  @sys.unset_env_var("TEST_RRV_PREF")
}

///|
test "resolve_raw_value prefers config over default when env not set" {
  let config : Map[String, String] = Map::new()
  config.set("key", "from-config")
  let result = resolve_raw_value("key", None, Some(config), Some("default"))
  inspect(result, content="Some((\"from-config\", FromConfig))")
}
```

**Step 2: Verify tests fail**

Run: `moon test src/margs`
Expected: FAIL — `resolve_raw_value` not found.

**Step 3: Implement `resolve_raw_value` in `parser.mbt`**

Add immediately before `fn init_defaults` (around line 104):

```moonbit
///|
/// Resolve a raw string value from env → config → default, in that order.
/// Returns the value and its source, or None if nothing is configured.
fn resolve_raw_value(
  key : String,
  env : String?,
  config : Map[String, String]?,
  default : String?,
) -> (String, ValueSource)? {
  // 1. Environment variable
  match env {
    Some(env_name) =>
      match @sys.get_env_var(env_name) {
        Some(val) => return Some((val, FromEnv))
        None => ()
      }
    None => ()
  }
  // 2. Config file
  match config {
    Some(cfg) =>
      match cfg.get(key) {
        Some(val) => return Some((val, FromConfig))
        None => ()
      }
    None => ()
  }
  // 3. Default
  match default {
    Some(val) => Some((val, FromDefault))
    None => None
  }
}
```

**Step 4: Run tests**

Run: `moon test`
Expected: `Total tests: 171, passed: 171, failed: 0.`

**Step 5: Commit**

```bash
git add src/margs/valuesource_wbtest.mbt src/margs/parser.mbt
git commit -m "Add resolve_raw_value with whitebox tests"
```

---

## Task 3: Change `ParsedArgs.values` type, make fields `priv`, fix all usages

This is the core refactor. All changes within `parser.mbt` are within the same package so `priv` fields remain accessible — only the VALUE TYPE changes require pattern-match updates.

**Pre-check: grep for whole-struct `ParsedArgs` equality comparisons**

Adding `ValueSource` to the `values` tuple changes the semantics of `==` (because `ParsedArgs` has `derive(Eq)`). Before making any changes, verify no tests compare whole `ParsedArgs` structs:

```bash
grep -r "ParsedArgs" src/ --include="*.mbt" | grep "=="
```

Expected: no matches. If any are found, rewrite those assertions to use accessors before proceeding.

**Files:**
- Modify: `src/margs/types.mbt`
- Modify: `src/margs/parser.mbt`
- Modify: `src/margs/cli.mbt`

### Step 1: Update `ParsedArgs` in `types.mbt`

Change the struct definition (~line 161):

```moonbit
///|
/// Result of parsing arguments
pub struct ParsedArgs {
  priv command_path : Array[String]
  priv values : Map[String, (ArgValue, ValueSource)]
  priv positionals : Array[String]
} derive(Show, Eq)
```

### Step 2: Refactor `init_defaults` in `parser.mbt` using `resolve_raw_value`

Replace the entire `init_defaults` body with:

```moonbit
fn init_defaults(
  options : Array[OptionSpec],
  config : Map[String, String]?,
) -> Map[String, (ArgValue, ValueSource)] {
  let values : Map[String, (ArgValue, ValueSource)] = {}
  for opt in options {
    match opt {
      StringOption(d) => {
        match resolve_raw_value(d.key, d.env, config, d.default) {
          Some((v, source)) => values[d.key] = (Str(v), source)
          None => ()
        }
      }
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
      DoubleOption(d) => {
        let default_str = d.default.map(fn(n) { n.to_string() })
        match resolve_raw_value(d.key, d.env, config, default_str) {
          Some((v, source)) =>
            match parse_double(v) {
              Some(n) => values[d.key] = (Double(n), source)
              None =>
                // Parse failed — fall back to typed default, or store NaN sentinel
                // so require_double can raise InvalidValue instead of MissingRequired
                match d.default {
                  Some(n) => values[d.key] = (Double(n), FromDefault)
                  None => values[d.key] = (Double(@double.not_a_number), source)
                }
            }
          None => ()
        }
      }
      BoolFlag(d) => {
        let default_str = Some(if d.default { "true" } else { "false" })
        match resolve_raw_value(d.key, d.env, config, default_str) {
          Some((v, source)) => values[d.key] = (Bool(parse_bool_env(v)), source)
          None => ()
        }
      }
      StringListOption(d) => {
        match resolve_raw_value(d.key, d.env, config, None) {
          Some((v, source)) => values[d.key] = (StrList(split_env_list(v)), source)
          None => values[d.key] = (StrList([]), FromDefault)
        }
      }
    }
  }
  values
}
```

### Step 3: Update `apply_option_value` — tag all CLI values with `FromCli`

Change every `values[d.key] = X` to `values[d.key] = (X, FromCli)` in `apply_option_value`:

```moonbit
fn apply_option_value(
  opt : OptionSpec,
  raw_value : String,
  values : Map[String, (ArgValue, ValueSource)],
) -> Unit raise ParseError {
  match opt {
    StringOption(d) => {
      match d.validator {
        Some(validate) =>
          if not(validate(raw_value)) {
            raise InvalidValue(
              "invalid value '\{raw_value}' for option '\{d.key}'",
            )
          }
        None => ()
      }
      values[d.key] = (Str(raw_value), FromCli)
    }
    IntOption(d) =>
      match parse_int(raw_value) {
        Some(n) => {
          match d.validator {
            Some(validate) =>
              if not(validate(n)) {
                raise InvalidValue(
                  "invalid value '\{raw_value}' for option '\{d.key}'",
                )
              }
            None => ()
          }
          values[d.key] = (Int(n), FromCli)
        }
        None =>
          raise InvalidValue(
            "expected integer for option '\{d.key}', got '\{raw_value}'",
          )
      }
    DoubleOption(d) =>
      match parse_double(raw_value) {
        Some(n) => {
          match d.validator {
            Some(validate) =>
              if not(validate(n)) {
                raise InvalidValue(
                  "invalid value '\{raw_value}' for option '\{d.key}'",
                )
              }
            None => ()
          }
          values[d.key] = (Double(n), FromCli)
        }
        None =>
          raise InvalidValue(
            "expected number for option '\{d.key}', got '\{raw_value}'",
          )
      }
    BoolFlag(d) => values[d.key] = (Bool(true), FromCli)
    StringListOption(d) =>
      match values.get(d.key) {
        Some((StrList(arr), _)) => {
          arr.push(raw_value)
          values[d.key] = (StrList(arr), FromCli)
        }
        _ => values[d.key] = (StrList([raw_value]), FromCli)
      }
  }
}
```

### Step 4: Update all `get_*` and `require_*` accessors

Each accessor needs tuple destructuring `(val, _)`:

```moonbit
pub fn ParsedArgs::get_string(self : ParsedArgs, key : String) -> String? {
  match self.values.get(key) {
    Some((Str(s), _)) => Some(s)
    _ => None
  }
}

pub fn ParsedArgs::get_int(self : ParsedArgs, key : String) -> Int? {
  match self.values.get(key) {
    Some((Int(n), _)) => Some(n)
    _ => None
  }
}

pub fn ParsedArgs::get_double(self : ParsedArgs, key : String) -> Double? {
  match self.values.get(key) {
    Some((Double(n), _)) => if n.is_nan() { None } else { Some(n) }
    _ => None
  }
}

pub fn ParsedArgs::get_bool(self : ParsedArgs, key : String) -> Bool {
  match self.values.get(key) {
    Some((Bool(b), _)) => b
    _ => false
  }
}

pub fn ParsedArgs::get_string_list(
  self : ParsedArgs,
  key : String,
) -> Array[String] {
  match self.values.get(key) {
    Some((StrList(arr), _)) => arr
    _ => []
  }
}

pub fn ParsedArgs::require_string(
  self : ParsedArgs,
  key : String,
) -> String raise ParseError {
  match self.values.get(key) {
    Some((Str(s), _)) => s
    _ => raise MissingRequired("required string option '\{key}' is missing")
  }
}

pub fn ParsedArgs::require_int(
  self : ParsedArgs,
  key : String,
) -> Int raise ParseError {
  match self.values.get(key) {
    Some((Int(n), _)) => n
    _ => raise MissingRequired("required integer option '\{key}' is missing")
  }
}

pub fn ParsedArgs::require_double(
  self : ParsedArgs,
  key : String,
) -> Double raise ParseError {
  match self.values.get(key) {
    Some((Double(n), _)) =>
      if n.is_nan() {
        raise InvalidValue("invalid value for double option '\{key}'")
      } else {
        n
      }
    _ => raise MissingRequired("required double option '\{key}' is missing")
  }
}
```

`get_positional` is unchanged (accesses `self.positionals`, same package).

### Step 5: Update `validate_required` in `parser.mbt`

The pattern match on `parsed.values.get(key)` must destructure the tuple:

```moonbit
fn validate_required(
  options : Array[OptionSpec],
  positionals : Array[PositionalSpec],
  parsed : ParsedArgs,
) -> Unit raise ParseError {
  for opt in options {
    if option_required(opt) {
      let key = option_key(opt)
      match parsed.values.get(key) {
        Some((Double(n), _)) =>
          match opt {
            // Internal NaN sentinel represents a failed env/config parse
            // with no valid fallback. Raise InvalidValue (not MissingRequired)
            // to preserve current parser.mbt semantics.
            DoubleOption(_) =>
              if n.is_nan() {
                raise InvalidValue("invalid value for double option '\{key}'")
              }
            _ => ()
          }
        Some(_) => ()
        None => raise MissingRequired("required option '\{key}' is missing")
      }
    }
  }
  for i, spec in positionals {
    if spec.required && i >= parsed.positionals.length() {
      raise MissingRequired(
        "required positional argument '\{spec.name}' is missing",
      )
    }
  }
}
```

### Step 6: Update subcommand value-merge loop in `parse_args`

The merge loop around line 683 destructures `entry` — no change needed since `v` is taken as the full tuple and assigned directly. But the local `values` variable type changes:

```moonbit
// Change the type annotation on the values map in parse_args
let values = init_defaults(options, config)
// (type is now inferred as Map[String, (ArgValue, ValueSource)] from init_defaults return type)
```

The merge loop:
```moonbit
for entry in values {
  let (k, v) = entry
  match sub_parsed.values.get(k) {
    Some(_) => () // Child value takes precedence
    None => sub_parsed.values[k] = v
  }
}
```
`v` is now `(ArgValue, ValueSource)` — the assignment `sub_parsed.values[k] = v` is still valid since both sides are the same tuple type. No change needed here.

### Step 7: Add `get_source` and `get_command_path` to `parser.mbt`

Add after `get_positional`:

```moonbit
///|
/// Get the source (CLI, env, config, default) of a value by key.
/// Not pub — exposed through TypedHandle::source in Improvement 3.
fn ParsedArgs::get_source(self : ParsedArgs, key : String) -> ValueSource? {
  match self.values.get(key) {
    Some((_, source)) => Some(source)
    None => None
  }
}

///|
/// Get the command path (e.g. ["myapp", "serve"]).
pub fn ParsedArgs::get_command_path(self : ParsedArgs) -> Array[String] {
  self.command_path
}
```

### Step 8: Update `cli.mbt` to use `get_command_path()`

Find every `args.command_path` access in `cli.mbt` and replace with `args.get_command_path()`.

There are 5 sites (around lines 255, 258, 263, 285, 294):

```moonbit
// Before
if index >= args.command_path.length() {
let cmd_name = args.command_path[index]
if index == args.command_path.length() - 1 {
if args.command_path.length() > 1 {
let cmd_name = args.command_path[1]

// After
if index >= args.get_command_path().length() {
let cmd_name = args.get_command_path()[index]
if index == args.get_command_path().length() - 1 {
if args.get_command_path().length() > 1 {
let cmd_name = args.get_command_path()[1]
```

### Step 9: Run all tests

Run: `moon test`
Expected: `Total tests: 171, passed: 171, failed: 0.`

If compilation fails, the error messages will point to specific pattern matches needing the `(val, source)` destructuring — fix them one by one.

**Step 10: Commit**

```bash
git add src/margs/types.mbt src/margs/parser.mbt src/margs/cli.mbt
git commit -m "Change ParsedArgs.values to (ArgValue, ValueSource) tuple, make fields priv"
```

---

## Task 4: Whitebox tests for `get_source` and end-to-end ValueSource tracking

**Files:**
- Modify: `src/margs/valuesource_wbtest.mbt` (append)

**Step 1: Append get_source tests**

```moonbit
// ===== get_source integration tests =====

///|
test "get_source returns FromCli for CLI-provided value" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host"),
  )
  let result = p.parse(["--host", "example.com"])
  inspect(result.get_source("host"), content="Some(FromCli)")
}

///|
test "get_source returns FromDefault for default value" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host", default="localhost"),
  )
  let result = p.parse([])
  inspect(result.get_source("host"), content="Some(FromDefault)")
}

///|
test "get_source returns FromEnv when env var is set" {
  @sys.set_env_var("TEST_VS_HOST", "env.example.com")
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host", env="TEST_VS_HOST"),
  )
  let result = p.parse([])
  inspect(result.get_source("host"), content="Some(FromEnv)")
  @sys.unset_env_var("TEST_VS_HOST")
}

///|
test "get_source returns None when value is absent" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host"),
  )
  let result = p.parse([])
  inspect(result.get_source("host"), content="None")
}

///|
test "CLI value overrides env — source is FromCli" {
  @sys.set_env_var("TEST_VS_PORT", "9000")
  let p = parser("test", builder=fn(args) { args }).add_option(
    int_option("port", long="port", env="TEST_VS_PORT"),
  )
  let result = p.parse(["--port", "8080"])
  inspect(result.get_source("port"), content="Some(FromCli)")
  @sys.unset_env_var("TEST_VS_PORT")
}

///|
test "get_source returns FromDefault for bool flag default" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    flag("verbose", long="verbose"),
  )
  let result = p.parse([])
  inspect(result.get_source("verbose"), content="Some(FromDefault)")
}

///|
test "required double with invalid env raises InvalidValue not MissingRequired" {
  @sys.set_env_var("TEST_VS_DBL", "not-a-number")
  let p = parser("test", builder=fn(args) { args }).add_option(
    double_option("rate", long="rate", env="TEST_VS_DBL", required=true),
  )
  let result = try {
    p.parse([])
    "no-error"
  } catch {
    InvalidValue(_) => "InvalidValue"
    MissingRequired(_) => "MissingRequired"
    _ => "other"
  }
  inspect(result, content="\"InvalidValue\"")
  @sys.unset_env_var("TEST_VS_DBL")
}

///|
test "get_source returns FromConfig for config-sourced value" {
  let config_content = "{\"host\": \"config.example.com\"}"
  @fs.write_string_to_file(".test_vs_config.json", config_content)
  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("host", long="host"))
    .with_config_file(".test_vs_config.json")
  let result = p.parse([])
  inspect(result.get_source("host"), content="Some(FromConfig)")
  inspect(result.get_string("host"), content="Some(\"config.example.com\")")
  @fs.remove_file(".test_vs_config.json")
}
```

**Step 2: Run tests**

Run: `moon test`
Expected: `Total tests: 179, passed: 179, failed: 0.`

**Step 3: Commit**

```bash
git add src/margs/valuesource_wbtest.mbt
git commit -m "Add get_source whitebox tests for ValueSource tracking"
```

---

## Task 5: Regenerate interface and final verification

**Step 1: Regenerate `pkg.generated.mbti`**

Run: `moon info`
Expected: `src/margs/pkg.generated.mbti` updated with `ValueSource` type and `get_command_path` function.

**Step 2: Run full test suite**

Run: `moon test`
Expected: all tests pass, 0 failures.

**Step 3: Commit**

```bash
git add src/margs/pkg.generated.mbti
git commit -m "Refresh generated interface after Improvement 1"
```
