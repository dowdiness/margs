# Repository Guidelines

## Project Structure & Module Organization
This is a MoonBit module (`moon.mod.json`) with source rooted at `src/`.
- `src/margs/`: core library package (parser, builder, validators, help text, exit codes, tests).
- `src/example/`: runnable demo CLI (`is-main: true`) for integration-style validation.
- `docs/`: project docs and reports.
- `_build/` and `target/`: generated build artifacts (do not edit manually).

Keep new code in the package that owns the behavior; prefer small, feature-focused `.mbt` files over large catch-all files.

## Build, Test, and Development Commands
Use MoonBit tooling from the repository root:
- `moon check`: fast type-check during development.
- `moon build`: compile all packages.
- `moon test`: run all tests (`*_test.mbt`).
- `moon test src/margs/parser_test.mbt`: run a specific test file.
- `moon run src/example -- --help`: run the demo CLI with arguments.
- `moon info`: refresh interface files such as `pkg.generated.mbti` after public API changes.

## Coding Style & Naming Conventions
- Run `moon fmt` before committing.
- Follow existing MoonBit naming: lowercase `snake_case` for functions/values; descriptive type/variant names.
- Keep parser errors explicit and typed (use `Result`/`catch` + pattern matching).
- Match existing style for fluent builder pipelines (`|>`), test naming, and option key naming (`"verbose"`, `"port"`, etc.).

## Testing Guidelines
- Place tests in `*_test.mbt` beside the code they validate.
- Use clear test names like `test "parse long option with = separator"`.
- Prefer `inspect(...)` assertions (often with `content=` snapshots) for stable outputs.
- For failure paths, capture errors via `Result[...] = Ok(...) catch { ... }` and assert `Err` cases.
- Run `moon test` for every change; update assertions intentionally when behavior changes.

## Commit & Pull Request Guidelines
- Follow the repository’s commit style: concise, imperative, capitalized subjects (for example, `Add CLI improvements...`, `Update .gitignore...`).
- Keep commits scoped to one logical change.
- PRs should include: what changed, why, how it was tested (`moon test`, targeted runs), and relevant CLI output for UX/help changes.
- If public APIs change, include updated `pkg.generated.mbti` in the PR.
