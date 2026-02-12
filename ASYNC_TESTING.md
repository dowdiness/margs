# Async Testing Strategies for MoonBit

## Problem

`moon test` hits a compiler ICE when using `%async.run` intrinsic in test contexts:
```
Invalid_argument("Moonc.Basic_lst.fold_right2")
```

This affects async CLI tests that use `run_async_block()` wrapper (Moon v0.8.1+bd827dc85).

---

## Solution 1: Structure Tests (Immediate) ✅

**Test the API without executing async code.**

```moonbit
test "async cli accepts commands" {
  let cli = create_async_cli("demo")
    .add_command(async_command("run", handler=async fn(_) { () }))

  // Validate structure only - no execution
  inspect(cli.commands.length(), content="1")
  inspect(cli.commands[0].spec.name, content="run")
}
```

**Pros:**
- ✅ Works today with no compiler issues
- ✅ Tests builder API, command registration, hook composition
- ✅ Fast and lightweight

**Cons:**
- ❌ Doesn't test actual async execution
- ❌ Can't verify runtime behavior

**Status:** Implemented in `src/margs/async_cli_structure_test.mbt`

---

## Solution 2: Integration Tests (Recommended) ⭐

**Test the compiled CLI binary as a subprocess.**

```moonbit
// Build test CLI binary
fn build_test_cli() -> String {
  // Compile test/async_cli_demo.mbt to binary
  "@sys.exec("moon build test/async_cli_demo")"
  "target/async_cli_demo"
}

test "async cli via subprocess" {
  let binary = build_test_cli()
  let result = @sys.exec("\{binary} run --verbose")

  inspect(result.exit_code, content="0")
  inspect(result.stdout.contains("Running..."), content="true")
}
```

**Pros:**
- ✅ Tests real execution behavior
- ✅ No compiler ICE (runs compiled code, not in test context)
- ✅ Tests the actual user experience
- ✅ Can validate exit codes, stdout, stderr

**Cons:**
- ❌ Slower than unit tests
- ❌ Requires building separate test binaries
- ❌ More complex test harness

**Implementation Steps:**
1. Create `test/fixtures/async_cli_demo.mbt` with sample CLI
2. Add build script to compile test binaries
3. Write subprocess-based tests
4. Add to CI pipeline

---

## Solution 3: Sync Wrapper Testing (Workaround)

**Test via `AsyncCli::run()` which bridges to async internally.**

```moonbit
test "async cli via sync wrapper" {
  // This still uses %async.run internally but may work
  // if called from different compilation context

  let cli = create_async_cli("demo")
    .add_command(async_command("check", handler=async fn(_) { () }))

  // AsyncCli::run() internally calls run_async_compat()
  // which uses %async.run intrinsic

  // May still trigger ICE, but worth trying
  cli.run()
}
```

**Status:** Not reliable - likely still triggers ICE.

---

## Solution 4: Wait for Compiler Fix (Long-term)

**Track the Moon compiler issue and update when fixed.**

**Status:**
- Issue tracked in `TODO.md`
- Moon version: v0.8.1+bd827dc85
- Expected fix: Future Moon release

**Action items:**
1. File issue with Moon team if not already reported
2. Test with each new Moon version
3. Update `README.md` when resolved

---

## Recommended Approach

### Immediate (Today):
1. ✅ Use **structure tests** for API validation (Solution 1)
2. ✅ Keep existing `run_async_block` tests but mark as skipped:
   ```moonbit
   ///| @skip("Moon v0.8.1 ICE - awaiting compiler fix")
   test "async cli dispatches command handler" { ... }
   ```

### Short-term (This week):
3. ⭐ Implement **integration tests** via subprocess (Solution 2)
4. Document testing strategy in `CONTRIBUTING.md`

### Long-term (When available):
5. Monitor Moon releases for ICE fix
6. Re-enable in-process async tests when compiler is updated

---

## Current Test Coverage

| Test Type | Coverage | Works? |
|-----------|----------|--------|
| Sync CLI | Full | ✅ Yes |
| Async CLI structure | Full | ✅ Yes |
| Async CLI execution | Limited | ❌ Compiler ICE |
| Integration tests | None yet | N/A (to implement) |

---

## Examples

### Structure Test (Works Now)
```moonbit
test "async hooks compose correctly" {
  let cli = create_async_cli("demo")
    .add_before_hook(hook=async fn(_) { () })
    .add_command(
      async_command("deploy", handler=async fn(_) { () })
        .add_after_hook(hook=async fn(_) { () })
    )

  // Validate structure
  inspect(cli.before_hooks.length(), content="1")
  inspect(cli.commands[0].after_hooks.length(), content="1")
}
```

### Integration Test (To Implement)
```moonbit
test "async cli handles errors in subprocess" {
  let output = run_subprocess_cli(["deploy", "--invalid-flag"])

  inspect(output.exit_code, content="2") // UnknownOption
  inspect(output.stderr.contains("unknown option"), content="true")
}
```

---

## Conclusion

The **structure tests** (Solution 1) provide immediate value and work around the compiler ICE. The **integration tests** (Solution 2) should be implemented for comprehensive async execution testing. Once the Moon compiler is fixed, in-process async tests can be re-enabled.
