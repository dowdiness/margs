# Add Built-In Double Option

## Architecture

Add a new built-in `DoubleOption` alongside `IntOption`, with a `double_option` builder that mirrors `int_option` (short/long/help/metavar/required/default/env/validator). Parsing uses a new `parse_double_safe` helper that rejects `NaN`/`Infinity`, and `Args.get_double`/`TypedHandle[Double]` accessors are added in parallel to existing int/string/bool access. JSON/env/config parsing will treat numeric values as strings: integers remain formatted as plain integer strings, while doubles preserve decimal representation; invalid numeric formats cause a parse error at option extraction (or validator for CLI input).

## Components

1. Parser core: add `parse_double_safe` with explicit checks for `NaN`/`Infinity`; add `DoubleOption` variant and parsing/validation in the same places as `IntOption`.
2. Builders: add `double_option(...) -> OptionBuilder[Double]` in the same module as `int_option`.
3. Args access: add `Args.get_double(key)` and typed-handle support for `Double`.
4. Config/env: update JSON parsing to safely format numbers into strings for subsequent parsing; ensure env/config values for `DoubleOption` are parsed using `parse_double_safe`.
5. Docs/tests: update docs for new option type; add tests for CLI/env/config parsing of doubles and for rejection of `NaN`/`Infinity`.

## Data Flow

CLI/env/config/default values are stored as strings (unchanged). When an option is `DoubleOption`, CLI values are validated via `parse_double_safe` in the validator, and extraction uses the same parser for env/config/default values. JSON parsing emits plain numeric strings for numbers; integer-only strings are still valid for doubles. If a numeric string parses to `NaN`/`Infinity`, extraction fails with `InvalidValue`.

## Error Handling

CLI invalid doubles fail during validation and surface as option validation errors. Env/config/default invalid doubles surface at `TypedHandle::require` as `InvalidValue`, mirroring existing custom option behavior. `NaN`/`Infinity` are treated as invalid input in all sources.

## Testing

Add tests for `double_option` covering:

1. CLI parsing for `--threshold=1.25`
2. Env/config parsing for `1.25`
3. Integer strings accepted for doubles
4. Rejection of `NaN`, `Infinity`, and invalid formats
