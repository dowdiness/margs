# Async CLI Implementation (Archived)

## Status: On Hold

Async CLI support has been implemented but is **archived in the `feature/async-cli` branch** due to a Moon compiler bug.

## Why Archived?

Moon compiler `v0.8.1+bd827dc85` has an Internal Compiler Error (ICE) when compiling async function types in test mode:

```
Error: Invalid_argument("Moonc.Basic_lst.fold_right2")
```

This prevents `moon test` from running, even though:
- ✅ `moon check` passes
- ✅ `moon build` works
- ✅ Runtime execution works correctly

## What Was Implemented

The `feature/async-cli` branch contains:

1. **AsyncCli and AsyncCliCommand** - Full async API mirroring sync CLI
2. **Async dispatch** - Proper async/await execution with error handling
3. **Async hooks** - Before/after hooks with async support
4. **Bridge to sync** - `AsyncCli::run()` for sync context execution
5. **Tests** - Converted to `async test` syntax (blocked by compiler)

## How to Revive

When Moon compiler support improves:

```bash
# Switch to async branch
git checkout feature/async-cli

# Test if compiler is fixed
moon test

# If tests pass, merge to main
git checkout main
git merge feature/async-cli
```

## API Preview

```moonbit
let cli = create_async_cli("mytool")
  .add_before_hook(hook=async fn(args) {
    await validate_credentials(args)
  })
  .add_command(
    async_command("deploy", handler=async fn(args) {
      let servers = get_string_list(args, "servers")
      await deploy_all(servers)  // Concurrent deployment
    })
  )

// Run from async context
cli.run_async()

// Or bridge from sync main
cli.run()
```

## Timeline

- **Implemented**: 2026-02-13
- **Archived**: 2026-02-13
- **Next check**: When Moon releases a new version

## References

- Branch: `feature/async-cli`
- Commit: `4f737d1 WIP: Async CLI implementation`
- Issue: Moon compiler ICE with async types in test mode
