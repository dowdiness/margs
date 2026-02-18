# Double Option Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a built-in `double_option` with safe parsing, env/config support, and tests that reject `NaN`/`Infinity`.

**Architecture:** Introduce a `DoubleOption`/`DoubleOptionDef` path parallel to `IntOption`, backed by `parse_double_safe` and `ArgValue::Double`. Extend help, metadata, and accessors to include the new type, and update JSON config parsing to produce safe number strings.

**Tech Stack:** MoonBit, margs core modules, MoonBit JSON core package.

---

### Task 1: Add failing parser tests for doubles

**Files:**
- Modify: `src/margs/parser_test.mbt`

**Step 1: Write the failing tests**

```moonbit
///|
test "parse double option" {
  let p = make_test_parser(options=[double_option("threshold", long="threshold")])
  let result = p.parse(["--threshold", "1.25"])
  inspect(result.get_double("threshold"), content="Some(1.25)")
}

///|
test "parse double option from integer string" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result = p.parse(["--ratio", "2"])
  inspect(result.get_double("ratio"), content="Some(2)")
}

///|
test "invalid double raises error" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "NaN"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}
```

**Step 2: Run test to verify it fails**

Run: `moon test src/margs/parser_test.mbt`
Expected: FAIL with missing `double_option`/`get_double` symbols.

**Step 3: Commit**

```bash
git add src/margs/parser_test.mbt
git commit -m "Add failing double option parser tests"
```

### Task 2: Add core types and accessors for doubles

**Files:**
- Modify: `src/margs/types.mbt`
- Modify: `src/margs/utils.mbt`
- Modify: `src/margs/parser.mbt`

**Step 1: Write failing tests for accessors**

```moonbit
///|
test "parsed args exposes double accessor" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result = p.parse(["--ratio", "3.5"])
  inspect(result.get_double("ratio"), content="Some(3.5)")
}
```

**Step 2: Run test to verify it fails**

Run: `moon test src/margs/parser_test.mbt`
Expected: FAIL with missing `get_double` implementation.

**Step 3: Implement minimal types and accessors**

```moonbit
// src/margs/types.mbt
pub enum ArgValue {
  Str(String)
  Int(Int)
  Double(Double)
  Bool(Bool)
  StrList(Array[String])
}

pub struct DoubleOptionDef {
  key : String
  short : Char?
  long : String?
  help : String
  metavar : String
  required : Bool
  default : Double?
  env : String?
  validator : ((Double) -> Bool)?
}

pub enum OptionSpec {
  StringOption(StringOptionDef)
  IntOption(IntOptionDef)
  DoubleOption(DoubleOptionDef)
  BoolFlag(BoolFlagDef)
  StringListOption(StringListOptionDef)
}
```

```moonbit
// src/margs/utils.mbt
pub fn option_key(opt : OptionSpec) -> String {
  match opt {
    StringOption(d) => d.key
    IntOption(d) => d.key
    DoubleOption(d) => d.key
    BoolFlag(d) => d.key
    StringListOption(d) => d.key
  }
}
```

```moonbit
// src/margs/parser.mbt
pub fn ParsedArgs::get_double(self : ParsedArgs, key : String) -> Double? {
  match self.values.get(key) {
    Some(Double(n)) => Some(n)
    _ => None
  }
}
```

**Step 4: Run test to verify it passes**

Run: `moon test src/margs/parser_test.mbt`
Expected: PASS for the new accessor test.

**Step 5: Commit**

```bash
git add src/margs/types.mbt src/margs/utils.mbt src/margs/parser.mbt src/margs/parser_test.mbt
git commit -m "Add double value types and accessors"
```

### Task 3: Add double option builder and parsing

**Files:**
- Modify: `src/margs/builder.mbt`
- Modify: `src/margs/parser.mbt`
- Modify: `src/margs/help.mbt`
- Modify: `src/margs/metadata.mbt`
- Modify: `src/margs/utils.mbt`

**Step 1: Write failing tests for builder behavior**

```moonbit
///|
test "double option uses metavar" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let help = generate_help(p)
  inspect(help.contains("--ratio <NUM>"), content="true")
}
```

**Step 2: Run test to verify it fails**

Run: `moon test src/margs/parser_test.mbt`
Expected: FAIL due to missing `double_option` and help formatting.

**Step 3: Implement minimal parsing and builder**

```moonbit
// src/margs/utils.mbt
pub fn parse_double_safe(s : String) -> Double? {
  let trimmed = s.trim().to_string()
  if trimmed.length() == 0 {
    return None
  }
  let value = Double::from_string(trimmed) catch { _ => return None }
  if value.is_nan() || value.is_infinite() {
    None
  } else {
    Some(value)
  }
}
```

```moonbit
// src/margs/builder.mbt
pub fn double_option(
  key : String,
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "NUM",
  required? : Bool = false,
  default? : Double,
  env? : String,
  validator? : (Double) -> Bool,
) -> OptionSpec {
  DoubleOption({
    key,
    short,
    long,
    help,
    metavar,
    required,
    default,
    env,
    validator,
  })
}
```

```moonbit
// src/margs/parser.mbt
fn apply_option_value(opt : OptionSpec, raw_value : String, values : Map[String, ArgValue]) -> Unit raise ParseError {
  match opt {
    DoubleOption(d) =>
      match parse_double_safe(raw_value) {
        Some(n) => {
          match d.validator {
            Some(validate) => if not(validate(n)) {
              raise InvalidValue("invalid value '\{raw_value}' for option '\{d.key}'")
            }
            None => ()
          }
          values[d.key] = Double(n)
        }
        None => raise InvalidValue("expected number for option '\{d.key}', got '\{raw_value}'")
      }
    // existing branches...
  }
}
```

```moonbit
// src/margs/help.mbt
fn append_metavar(buf : StringBuilder, opt : OptionSpec) -> Unit {
  match opt {
    DoubleOption(d) => buf.write_string(" <\{d.metavar}>")
    // existing branches...
  }
}
```

```moonbit
// src/margs/metadata.mbt
DoubleOption(d) => {
  buf.write_string("\{spaces}  \"key\": \"\{escape_json(d.key)}\",\n")
  buf.write_string("\{spaces}  \"type\": \"double\",\n")
  write_option_common_fields(buf, spaces, d.short, d.long, d.help)
  buf.write_string("\{spaces}  \"metavar\": \"\{escape_json(d.metavar)}\",\n")
  buf.write_string("\{spaces}  \"required\": \{d.required}\n")
}
```

**Step 4: Run test to verify it passes**

Run: `moon test src/margs/parser_test.mbt`
Expected: PASS for double parsing and help tests.

**Step 5: Commit**

```bash
git add src/margs/builder.mbt src/margs/parser.mbt src/margs/help.mbt src/margs/metadata.mbt src/margs/utils.mbt
git commit -m "Add double option builder and parsing"
```

### Task 4: Add env/config support for doubles

**Files:**
- Modify: `src/margs/parser.mbt`
- Modify: `src/margs/env_test.mbt`
- Modify: `src/margs/config.mbt`
- Modify: `src/margs/config_test.mbt`

**Step 1: Write failing tests for env/config doubles**

```moonbit
///|
test "env var parses double option" {
  @sys.set_env_var("TEST_RATIO", "1.75")
  let p = parser("test", builder=fn(args) { args }).add_option(
    double_option("ratio", env="TEST_RATIO"),
  )
  let result = p.parse([])
  inspect(result.get_double("ratio"), content="Some(1.75)")
  @sys.unset_env_var("TEST_RATIO")
}
```

```moonbit
///|
test "parse JSON config with numeric values" {
  let json = "{\"rate\": 1.25, \"count\": 3}"
  match parse_json_config(json) {
    Some(config) => {
      inspect(config.get("rate"), content="Some(\"1.25\")")
      inspect(config.get("count"), content="Some(\"3\")")
    }
    None => inspect(false, content="true")
  }
}
```

**Step 2: Run test to verify it fails**

Run: `moon test src/margs/env_test.mbt src/margs/config_test.mbt`
Expected: FAIL for missing double env/config support.

**Step 3: Implement minimal env/config handling**

```moonbit
// src/margs/parser.mbt (init_defaults)
DoubleOption(d) => {
  let value = match d.env {
    Some(env_name) =>
      match @sys.get_env_var(env_name) {
        Some(env_val) =>
          match parse_double_safe(env_val) {
            Some(n) => Some(n)
            None => d.default
          }
        None =>
          match config {
            Some(cfg) =>
              match cfg.get(d.key) {
                Some(cfg_val) =>
                  match parse_double_safe(cfg_val) {
                    Some(n) => Some(n)
                    None => d.default
                  }
                None => d.default
              }
            None => d.default
          }
      }
    None =>
      match config {
        Some(cfg) =>
          match cfg.get(d.key) {
            Some(cfg_val) =>
              match parse_double_safe(cfg_val) {
                Some(n) => Some(n)
                None => d.default
              }
            None => d.default
          }
        None => d.default
      }
  }
  match value {
    Some(v) => values[d.key] = Double(v)
    None => ()
  }
}
```

```moonbit
// src/margs/config.mbt
match value {
  String(s) => config.set(key, s)
  Number(n) => config.set(key, format_json_number(n))
  True => config.set(key, "true")
  False => config.set(key, "false")
  _ => ()
}
```

```moonbit
// src/margs/config.mbt
fn format_json_number(n : Double) -> String {
  if n.is_nan() || n.is_infinite() {
    ""
  } else if n == n.round() {
    n.round().to_int().to_string()
  } else {
    n.to_string()
  }
}
```

**Step 4: Run test to verify it passes**

Run: `moon test src/margs/env_test.mbt src/margs/config_test.mbt`
Expected: PASS for env/config double tests.

**Step 5: Commit**

```bash
git add src/margs/parser.mbt src/margs/env_test.mbt src/margs/config.mbt src/margs/config_test.mbt
git commit -m "Add double support for env and config"
```

### Task 5: Update docs and generated interface

**Files:**
- Modify: `docs/refactoring_design_en.md`
- Modify: `src/margs/pkg.generated.mbti`

**Step 1: Update docs**

Add `double_option` to any option listings and note JSON numeric formatting behavior.

**Step 2: Refresh mbti**

Run: `moon info`
Expected: `src/margs/pkg.generated.mbti` updated to include `DoubleOption` and `double_option`.

**Step 3: Commit**

```bash
git add docs/refactoring_design_en.md src/margs/pkg.generated.mbti
git commit -m "Document double option and refresh mbti"
```

### Task 6: Full test run

**Step 1: Run all tests**

Run: `moon test`
Expected: `Total tests: ..., failed: 0`

**Step 2: Commit (if needed)**

```bash
git status --short
```

If any formatting or metadata changes occurred (e.g., from `moon fmt`), commit them with a concise message.
