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

CLI/env/config/default values are stored as strings (unchanged). When an option is `DoubleOption`, CLI values are validated via `parse_double` in the validator, and extraction uses the same parser for env/config/default values. JSON parsing emits plain numeric strings for numbers; integer-only strings are still valid for doubles. If a numeric string parses to `NaN`/`Infinity`, extraction fails with `InvalidValue`.

## Error Handling

CLI invalid doubles (passed via `--flag value`) fail immediately during `apply_option_value` and raise `InvalidValue`. Env/config/default invalid doubles do **not** fail during load — `init_defaults` silently falls back to the option's `default` value (or omits the key entirely if `default` is `None`). `InvalidValue` is only returned later when `ParsedArgs::require_double` (or `get_double` with no default) is called and no valid value was stored. `NaN`/`Infinity` are treated as invalid input in all sources. This applies to `DoubleOption`, `parse_double`, and the `ParsedArgs::require_double` accessor.

## Testing

Add tests for `double_option` covering:

1. CLI parsing for `--threshold=1.25`
2. Env/config parsing for `1.25`
3. Integer strings accepted for doubles
4. Rejection of `NaN`, `Infinity`, and invalid formats
