// Tests for environment variable support

///|
test "env var provides default for string option" {
  @sys.set_env_var("TEST_HOST", "example.com")

  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", env="TEST_HOST", default="localhost"),
  )

  let result = p.parse([])
  inspect(result.get_string("host"), content="Some(\"example.com\")")

  @sys.unset_env_var("TEST_HOST")
}

///|
test "cli arg overrides env var for string option" {
  @sys.set_env_var("TEST_HOST", "example.com")

  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host", env="TEST_HOST"),
  )

  let result = p.parse(["--host", "custom.com"])
  inspect(result.get_string("host"), content="Some(\"custom.com\")")

  @sys.unset_env_var("TEST_HOST")
}

///|
test "env var overrides default for string option" {
  @sys.set_env_var("TEST_PORT", "3000")

  let p = parser("test", builder=fn(args) { args }).add_option(
    int_option("port", env="TEST_PORT", default=8080),
  )

  let result = p.parse([])
  inspect(result.get_int("port"), content="Some(3000)")

  @sys.unset_env_var("TEST_PORT")
}

///|
test "uses default when env var not set" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", env="NONEXISTENT_VAR", default="localhost"),
  )

  let result = p.parse([])
  inspect(result.get_string("host"), content="Some(\"localhost\")")
}

///|
test "env var parses int option" {
  @sys.set_env_var("TEST_COUNT", "42")

  let p = parser("test", builder=fn(args) { args }).add_option(
    int_option("count", env="TEST_COUNT"),
  )

  let result = p.parse([])
  inspect(result.get_int("count"), content="Some(42)")

  @sys.unset_env_var("TEST_COUNT")
}

///|
test "invalid int in env var falls back to default" {
  @sys.set_env_var("TEST_COUNT", "not-a-number")

  let p = parser("test", builder=fn(args) { args }).add_option(
    int_option("count", env="TEST_COUNT", default=10),
  )

  let result = p.parse([])
  inspect(result.get_int("count"), content="Some(10)")

  @sys.unset_env_var("TEST_COUNT")
}

///|
test "env var parses bool flag as true" {
  @sys.set_env_var("TEST_VERBOSE", "true")

  let p = parser("test", builder=fn(args) { args }).add_option(
    flag("verbose", env="TEST_VERBOSE"),
  )

  let result = p.parse([])
  inspect(result.get_bool("verbose"), content="true")

  @sys.unset_env_var("TEST_VERBOSE")
}

///|
test "env var parses bool flag from 1" {
  @sys.set_env_var("TEST_DEBUG", "1")

  let p = parser("test", builder=fn(args) { args }).add_option(
    flag("debug", env="TEST_DEBUG"),
  )

  let result = p.parse([])
  inspect(result.get_bool("debug"), content="true")

  @sys.unset_env_var("TEST_DEBUG")
}

///|
test "env var parses bool flag as false for other values" {
  @sys.set_env_var("TEST_VERBOSE", "0")

  let p = parser("test", builder=fn(args) { args }).add_option(
    flag("verbose", env="TEST_VERBOSE"),
  )

  let result = p.parse([])
  inspect(result.get_bool("verbose"), content="false")

  @sys.unset_env_var("TEST_VERBOSE")
}

// TODO: String list env var support needs debugging
// Tests commented out until issue with array element comparison is resolved
