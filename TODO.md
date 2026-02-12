# TODO

## Done
- [x] Add high-level wrapper entry point (for example `create_cli(...)`).
- [x] Add command registration API with per-command handlers.
- [x] Support global options on wrapper-level CLI.
- [x] Implement wrapper dispatch on top of existing `Parser[T]` engine.
- [x] Add alias dispatch for wrapper commands.
- [x] Add nested command dispatch support.
- [x] Add automatic help/version behavior at wrapper level.
- [x] Port `src/example/main.mbt` to wrapper API to validate ergonomics.
- [x] Add wrapper-focused tests for dispatch, nested subcommands, and global options.
- [x] Define unified error boundary for parse errors and handler runtime errors.
- [x] Use `GeneralError` for runtime handler failure path.

## Phase 1 - Wrapper MVP + Extensibility
- [ ] Define and implement middleware hooks (before/after handler).
- [ ] Add test helpers for in-process CLI invocation and assertions.
- [ ] Explore async-friendly handler support (even experimental).
- [ ] Add tests for help/version rendering from wrapper API.
- [ ] Add tests for error-to-exit-code mapping (including `GeneralError`).

## Phase 2 - Real-world Usability
- [ ] Add env-var backed defaults (opt-in per option).
- [ ] Add config-file backed defaults (start with one simple format).
- [ ] Document precedence: CLI args > env > config > default.
- [ ] Add structured output helpers (JSON/logging).
- [ ] Version command metadata for stable completion output.

## Phase 3 - Developer Experience
- [ ] Add shell completion generation (bash/zsh/fish).
- [ ] Add interactive prompts for missing required values.
- [ ] Add i18n support for help and error strings.

## Phase 4 - Advanced
- [ ] Add plugin system.
- [ ] Add code generation/scaffolding tools.

## Release Readiness
- [ ] Regenerate and commit `pkg.generated.mbti` when public API changes.
- [ ] Add changelog/release notes for wrapper API updates.
