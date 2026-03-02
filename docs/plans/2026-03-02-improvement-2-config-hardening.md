# Improvement 2: Config Test Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Verify and complete test coverage for the existing `@json.parse` implementation in `config.mbt`. No code changes to `config.mbt` are required — only tests.

**Architecture:** Three test changes across two files: uncomment the stale escaped-quote test (should pass as-is with `@json.parse`), add a JSON-native boolean unit test to `config_test.mbt`, and update `config_integration_test.mbt` fixtures to use JSON-native number and boolean types where appropriate.

**Tech Stack:** MoonBit, `@json` (already in use), `@fs` (temp files in integration tests).

**Starting point:** This plan is executed after Improvement 1. Baseline test count is 179.

---

## Task 1: Uncomment escaped-quote test in `config_test.mbt`

**Files:**
- Modify: `src/margs/config_test.mbt` (lines 57–67)

**Step 1: Uncomment the test**

Remove the comment markers and the TODO comment. Replace lines 57–67 with:

```moonbit
///|
test "parse JSON with escaped quotes" {
  let json = "{\"message\": \"Hello \\\"World\\\"\"}"
  match parse_json_config(json) {
    Some(config) => {
      inspect(config.get("message"), content="Some(\"Hello \\\"World\\\"\")")
    }
    None => inspect(false, content="true")
  }
}
```

**Step 2: Run tests**

Run: `moon test`
Expected: `Total tests: 180, passed: 180, failed: 0.`

If the test fails with `None`, `@json.parse` is not handling escaped quotes — investigate before proceeding.

**Step 3: Commit**

```bash
git add src/margs/config_test.mbt
git commit -m "Uncomment escaped-quote config test (passes with @json.parse)"
```

---

## Task 2: Add JSON-native boolean test to `config_test.mbt`

**Files:**
- Modify: `src/margs/config_test.mbt` (append after the escaped-quote test)

**Step 1: Add the test**

Append after the escaped-quote test:

```moonbit
///|
test "parse JSON config with native boolean values" {
  let json = "{\"verbose\": true, \"debug\": false}"
  match parse_json_config(json) {
    Some(config) => {
      inspect(config.get("verbose"), content="Some(\"true\")")
      inspect(config.get("debug"), content="Some(\"false\")")
    }
    None => inspect(false, content="true")
  }
}
```

**Step 2: Run tests**

Run: `moon test`
Expected: `Total tests: 181, passed: 181, failed: 0.`

**Step 3: Commit**

```bash
git add src/margs/config_test.mbt
git commit -m "Add JSON-native boolean test for parse_json_config"
```

---

## Task 3: Update `config_integration_test.mbt` fixtures to JSON-native types

**Files:**
- Modify: `src/margs/config_integration_test.mbt`

Three fixture strings use JSON string encoding where JSON-native types are more appropriate.

**Step 1: Update "parser loads string option from config file"**

The `port` field is currently a JSON string `"9000"`. Change to a JSON number:

```moonbit
// Before
let config_content = "{\"host\": \"config.example.com\", \"port\": \"9000\", \"ratio\": 1.25}"

// After
let config_content = "{\"host\": \"config.example.com\", \"port\": 9000, \"ratio\": 1.25}"
```

**Step 2: Update "env vars override config file values"**

The `port` field is currently a JSON string `"3000"`. Change to a JSON number:

```moonbit
// Before
let config_content = "{\"port\": \"3000\"}"

// After
let config_content = "{\"port\": 3000}"
```

**Step 3: Update "bool flag loads from config file"**

The `verbose` and `debug` fields are currently JSON strings `"true"` and `"1"`. Change to JSON-native booleans:

```moonbit
// Before
let config_content = "{\"verbose\": \"true\", \"debug\": \"1\"}"

// After
let config_content = "{\"verbose\": true, \"debug\": true}"
```

**Step 4: Run tests**

Run: `moon test`
Expected: `Total tests: 181, passed: 181, failed: 0.`

No new tests are added; test count is unchanged. Existing assertions remain valid since the parsed values (`9000`, `true`, etc.) are identical — only the JSON encoding in the fixture changes.

**Step 5: Commit**

```bash
git add src/margs/config_integration_test.mbt
git commit -m "Update config integration test fixtures to use JSON-native types"
```

---

## Task 4: Final verification

**Step 1: Run full test suite**

Run: `moon test`
Expected: all tests pass, 0 failures.

**Step 2: Confirm no changes to `config.mbt`**

Run: `git log -- src/margs/config.mbt`
Expected: no commits from this improvement touch `config.mbt`.
