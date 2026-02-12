# margs Improvement Plan

## Objective
Evolve `margs` from a low-level parser into a higher-level CLI construction library while preserving the current parser API and behavior.

## Current Baseline
- Stable parser core with typed options, subcommands, help generation, typo suggestions, validators, and exit code mapping.
- Test suite is already strong (`moon test` currently passes with 90+ tests).
- Public API is centered on `Parser[T]` + `SubcommandSpec` + `ParsedArgs` (`src/margs/*.mbt`).
- Existing roadmap ideas are documented in `docs/margs_cli_library_report.md`.

## Success Criteria
- New high-level API can define commands and handlers without manual command-path matching.
- Backward compatibility: existing `@margs.parser(...).add_*` code continues to work.
- Documentation includes migration examples from current API to the new wrapper.
- Test coverage expands for new API, command dispatch, and failure/exit-code behavior.

## Phase 1: Core Wrapper API (Priority: P0)
### Deliverables
1. Add a new high-level CLI wrapper layer (suggested new file: `src/margs/cli.mbt`).
2. Support command registration with handler functions.
3. Keep `Parser[T]` as the engine under the hood.
4. Add automatic `--help` and `--version` handling at wrapper level.

### Proposed API shape
- `create_cli(name, description?, version?)`
- `Cli::option(...)` for global options
- `Cli::command(name, description?)`
- `Command::option(...)`, `Command::positional(...)`, `Command::handle(...)`
- `Cli::run()`

### File-level work
- `src/margs/types.mbt`: add wrapper structs/types for CLI and command handler registration.
- `src/margs/builder.mbt`: helper constructors for wrapper composition.
- `src/margs/parser.mbt`: minimal changes only if required for wrapper integration.
- `src/margs/help_test.mbt` and new wrapper tests: validate help/version/dispatch.

### Exit gate
- Wrapper can reimplement current `src/example/main.mbt` behavior with less boilerplate.

## Phase 2: Reliability + Migration (Priority: P1)
### Deliverables
1. Unified error boundary for handler failures and parser failures.
2. Clear exit behavior for parse errors vs runtime handler errors.
3. Migration documentation and before/after examples.

### File-level work
- `src/margs/exit_codes.mbt`: map wrapper runtime failures to `GeneralError` (currently unused).
- `README.md`: add migration section and wrapper-first examples.
- `docs/`: add `migration_guide.md`.

### Exit gate
- Existing parser API unchanged; wrapper recommended as default for new users.

## Phase 3: Developer Experience Features (Priority: P2)
### Deliverables
1. Environment variable defaults (opt-in per option).
2. Config file defaults (start with one simple format).
3. Middleware/hooks (before/after command execution).
4. Test helpers for invoking CLI commands in-process.

### Exit gate
- Documented precedence order: CLI args > env > config > default.

## Phase 4: Extended Usability (Priority: P3)
### Candidate features
- Shell completion generation (`bash`/`zsh`/`fish`).
- Interactive prompts for missing required values.
- i18n for help and error messages.
- Async-oriented handler patterns (if MoonBit ecosystem tooling supports this cleanly).

## Testing Plan
- Keep black-box tests in `*_test.mbt` next to implementation.
- Add dedicated wrapper tests:
  - command dispatch correctness
  - nested subcommand dispatch
  - global options inheritance
  - help/version rendering
  - unknown option/command suggestion quality
  - exit code assertions
- Maintain a runnable integration sample in `src/example/main.mbt` using the new wrapper.

## Risks and Mitigations
- **Risk: API churn**. Mitigation: wrapper additive only; do not break parser API.
- **Risk: complexity growth**. Mitigation: keep parser core unchanged; isolate wrapper logic.
- **Risk: unclear precedence with config/env**. Mitigation: codify precedence in docs + tests before implementation.

## Immediate Next Steps (Execution Order)
1. Create wrapper type definitions and method skeletons.
2. Implement command registration and dispatch.
3. Port `src/example/main.mbt` to wrapper API.
4. Add tests for wrapper help/version/dispatch.
5. Use `GeneralError` for handler failures and test exit-code mapping.
6. Publish migration guide and update README examples.
