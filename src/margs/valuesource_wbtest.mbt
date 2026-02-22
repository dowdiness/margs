// Whitebox tests for resolve_raw_value and get_source

///|
test "resolve_raw_value returns env var with FromEnv" {
  @sys.set_env_var("TEST_RRV_KEY", "hello")
  let result = resolve_raw_value("key", Some("TEST_RRV_KEY"), None, None)
  inspect(result, content="Some((\"hello\", FromEnv))")
  @sys.unset_env_var("TEST_RRV_KEY")
}

///|
test "resolve_raw_value skips env and returns config with FromConfig" {
  let config : Map[String, String] = Map::new()
  config.set("key", "world")
  let result = resolve_raw_value("key", None, Some(config), None)
  inspect(result, content="Some((\"world\", FromConfig))")
}

///|
test "resolve_raw_value falls through to default with FromDefault" {
  let result = resolve_raw_value("key", None, None, Some("fallback"))
  inspect(result, content="Some((\"fallback\", FromDefault))")
}

///|
test "resolve_raw_value returns None when no source" {
  let result = resolve_raw_value("key", None, None, None)
  inspect(result, content="None")
}

///|
test "resolve_raw_value prefers env over config" {
  @sys.set_env_var("TEST_RRV_PREF", "from-env")
  let config : Map[String, String] = Map::new()
  config.set("key", "from-config")
  let result = resolve_raw_value("key", Some("TEST_RRV_PREF"), Some(config), Some("default"))
  inspect(result, content="Some((\"from-env\", FromEnv))")
  @sys.unset_env_var("TEST_RRV_PREF")
}

///|
test "resolve_raw_value prefers config over default when env not set" {
  let config : Map[String, String] = Map::new()
  config.set("key", "from-config")
  let result = resolve_raw_value("key", None, Some(config), Some("default"))
  inspect(result, content="Some((\"from-config\", FromConfig))")
}

///|
test "resolve_raw_value env name set but var not present falls through to config" {
  // Ensure the env var is not set
  @sys.unset_env_var("TEST_RRV_ABSENT")
  let config : Map[String, String] = Map::new()
  config.set("key", "from-config")
  let result = resolve_raw_value("key", Some("TEST_RRV_ABSENT"), Some(config), Some("default"))
  inspect(result, content="Some((\"from-config\", FromConfig))")
}

// ===== get_source integration tests =====

///|
test "get_source returns FromCli for CLI-provided value" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host"),
  )
  let result = p.parse(["--host", "example.com"])
  inspect(result.get_source("host"), content="Some(FromCli)")
}

///|
test "get_source returns FromDefault for default value" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host", default="localhost"),
  )
  let result = p.parse([])
  inspect(result.get_source("host"), content="Some(FromDefault)")
}

///|
test "get_source returns FromEnv when env var is set" {
  @sys.set_env_var("TEST_VS_HOST", "env.example.com")
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host", env="TEST_VS_HOST"),
  )
  let result = p.parse([])
  inspect(result.get_source("host"), content="Some(FromEnv)")
  @sys.unset_env_var("TEST_VS_HOST")
}

///|
test "get_source returns None when value is absent" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("host", long="host"),
  )
  let result = p.parse([])
  inspect(result.get_source("host"), content="None")
}

///|
test "CLI value overrides env — source is FromCli" {
  @sys.set_env_var("TEST_VS_PORT", "9000")
  let p = parser("test", builder=fn(args) { args }).add_option(
    int_option("port", long="port", env="TEST_VS_PORT"),
  )
  let result = p.parse(["--port", "8080"])
  inspect(result.get_source("port"), content="Some(FromCli)")
  @sys.unset_env_var("TEST_VS_PORT")
}

///|
test "get_source returns FromDefault for bool flag default" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    flag("verbose", long="verbose"),
  )
  let result = p.parse([])
  inspect(result.get_source("verbose"), content="Some(FromDefault)")
}
