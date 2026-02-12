# TODO

## Phase 1 - Core Wrapper API (P0)
- [x] Add high-level wrapper entry point (for example `create_cli(...)`).
- [x] Add command registration API with per-command handlers.
- [x] Support global options on wrapper-level CLI.
- [x] Implement wrapper dispatch on top of existing `Parser[T]` engine.
- [x] Add automatic help/version behavior at wrapper level.
- [x] Port `src/example/main.mbt` to wrapper API to validate ergonomics.

## Phase 2 - Reliability and Migration (P1)
- [ ] Define unified error boundary for parse errors and handler runtime errors.
- [ ] Use `GeneralError` for runtime handler failure path.
- [ ] Add migration guide from parser-first API to wrapper-first API (`docs/migration_guide.md`).
- [ ] Update README with wrapper-first examples and migration notes.

## Phase 3 - DX Features (P2)
- [ ] Add env-var backed defaults (opt-in per option).
- [ ] Add config-file backed defaults (start with one simple format).
- [ ] Define and implement middleware hooks (before/after handler).
- [ ] Add test helpers for in-process CLI invocation and assertions.
- [ ] Document precedence: CLI args > env > config > default.

## Phase 4 - Extended Usability (P3)
- [ ] Add shell completion generation (bash/zsh/fish).
- [ ] Add interactive prompts for missing required values.
- [ ] Add i18n support for help and error strings.
- [ ] Explore async-oriented handler support.

## Testing and Quality Gates
- [ ] Add wrapper-focused tests for dispatch, nested subcommands, and global options.
- [ ] Add tests for help/version rendering from wrapper API.
- [ ] Add tests for error-to-exit-code mapping (including `GeneralError`).
- [ ] Keep `moon check` and `moon test` green for each milestone.

## Release Readiness
- [ ] Ensure old parser API remains backward compatible.
- [ ] Regenerate and commit `pkg.generated.mbti` when public API changes.
- [ ] Add changelog/release notes for wrapper API introduction.
