# Add Built-In Double Option

## Architecture

Add a new built-in `DoubleOption` alongside `IntOption`, with a `double_option` builder that mirrors `int_option` (short/long/help/metavar/required/default/env/validator). Parsing uses `parse_double` to reject `NaN`/`Infinity`, and `ParsedArgs::get_double` accessors are added in parallel to existing int/string/bool access. JSON/env/config parsing will treat numeric values as strings: integers remain formatted as plain integer strings, while doubles preserve decimal representation; invalid numeric formats cause a parse error at option extraction (or validator for CLI input).

## Components

1. Parser core: add `parse_double` with explicit checks for `NaN`/`Infinity`; add `DoubleOption` variant and parsing/validation in the same places as `IntOption`.
2. Builders: add `double_option(...) -> OptionSpec` in the same module as `int_option`.
3. Args access: add `ParsedArgs::get_double(key)` alongside existing accessors.
4. Config/env: update JSON parsing to safely format numbers into strings for subsequent parsing; ensure env/config values for `DoubleOption` are parsed using `parse_double`.
5. Docs/tests: update docs for new option type; add tests for CLI/env/config parsing of doubles and for rejection of `NaN`/`Infinity`.

## Data Flow

Raw CLI args, env var values, and config file values arrive as strings. After parsing, a `DoubleOption` is stored as `Double(n)` in the `ArgValue` map — not kept as a string. Both `apply_option_value` (CLI path) and `init_defaults` (env/config path) call `parse_double` and write `ArgValue::Double(n)` into `ParsedArgs.values`. JSON parsing emits plain numeric strings for numbers (integer-only strings are still valid as doubles). When a source (env var or config) provides an invalid numeric string and no valid fallback exists (no default), a NaN sentinel (`Double(not_a_number)`) is stored so `require_double` can surface the failure as `InvalidValue` at access time rather than silently omitting the key.

## Error Handling

CLI invalid doubles (passed via `--flag value`) fail immediately in `apply_option_value` and raise `InvalidValue`. Env/config invalid doubles do **not** fail during load: `init_defaults` falls back to `d.default` when `parse_double` returns `None`. When the fallback itself is `None` (no default configured), a NaN sentinel (`Double(not_a_number)`) is stored to mark the failure. `require_double` detects this sentinel and raises `InvalidValue` — not `MissingRequired` — so callers get an accurate error. `get_double` returns `None` for the sentinel, treating it as absent. `NaN`/`Infinity` are rejected by `parse_double` in all sources and are what the sentinel is tested for via `is_nan()`.

## Testing

Add tests for `double_option` covering:

1. CLI parsing for `--threshold=1.25`
2. Env/config parsing for `1.25`
3. Integer strings accepted for doubles
4. Rejection of `NaN`, `Infinity`, and invalid formats
