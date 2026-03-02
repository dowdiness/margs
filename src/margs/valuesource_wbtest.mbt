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
