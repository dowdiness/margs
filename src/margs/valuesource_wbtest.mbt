// Whitebox tests for resolve_raw_value and get_source

///|
test "resolve_raw_value returns env var with FromEnv" {
  @sys.set_env_var("TEST_RRV_KEY", "hello")
  let result = resolve_raw_value("key", Some("TEST_RRV_KEY"), None, None)
  @sys.unset_env_var("TEST_RRV_KEY")
  inspect(result, content="Some((\"hello\", FromEnv))")
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
  let result = resolve_raw_value(
    "key",
    Some("TEST_RRV_PREF"),
    Some(config),
    Some("default"),
  )
  @sys.unset_env_var("TEST_RRV_PREF")
  inspect(result, content="Some((\"from-env\", FromEnv))")
}

///|
test "resolve_raw_value prefers config over default when env not set" {
  let config : Map[String, String] = Map::new()
  config.set("key", "from-config")
  let result = resolve_raw_value("key", None, Some(config), Some("default"))
  inspect(result, content="Some((\"from-config\", FromConfig))")
}

// ===== get_source integration tests =====

///|
test "get_source returns FromCli for CLI-provided value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("host", str_option(long="host"))
  let result = p.parse(["--host", "example.com"])
  inspect(result.get_source("host"), content="Some(FromCli)")
}

///|
test "get_source returns FromDefault for default value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("host", str_option(long="host", default="localhost"))
  let result = p.parse([])
  inspect(result.get_source("host"), content="Some(FromDefault)")
}

///|
test "get_source returns FromEnv when env var is set" {
  @sys.set_env_var("TEST_VS_HOST", "env.example.com")
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("host", str_option(long="host", env="TEST_VS_HOST"))
  let result = p.parse([]) catch {
    e => {
      @sys.unset_env_var("TEST_VS_HOST")
      raise e
    }
  }
  @sys.unset_env_var("TEST_VS_HOST")
  inspect(result.get_source("host"), content="Some(FromEnv)")
}

///|
test "get_source returns None when value is absent" {
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("host", str_option(long="host"))
  let result = p.parse([])
  inspect(result.get_source("host"), content="None")
}

///|
test "CLI value overrides env — source is FromCli" {
  @sys.set_env_var("TEST_VS_PORT", "9000")
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("port", int_option(long="port", env="TEST_VS_PORT"))
  let result = p.parse(["--port", "8080"]) catch {
    e => {
      @sys.unset_env_var("TEST_VS_PORT")
      raise e
    }
  }
  @sys.unset_env_var("TEST_VS_PORT")
  inspect(result.get_source("port"), content="Some(FromCli)")
}

///|
test "get_source returns FromDefault for bool flag default" {
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("verbose", flag(long="verbose"))
  let result = p.parse([])
  inspect(result.get_source("verbose"), content="Some(FromDefault)")
}

///|
test "required double with invalid env raises InvalidValue not MissingRequired" {
  @sys.set_env_var("TEST_VS_DBL", "not-a-number")
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add(
    "rate",
    double_option(long="rate", env="TEST_VS_DBL", required=true),
  )
  let result = try {
    ignore(p.parse([]))
    "no-error"
  } catch {
    InvalidValue(_) => "InvalidValue"
    MissingRequired(_) => "MissingRequired"
    _ => "other"
  }
  @sys.unset_env_var("TEST_VS_DBL")
  inspect(result, content="InvalidValue")
}

///|
test "ParsedArgs equality is source-agnostic" {
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("host", str_option(long="host", default="localhost"))
  let result_default = p.parse([])
  let result_cli = p.parse(["--host", "localhost"])
  inspect(result_default.get_source("host"), content="Some(FromDefault)")
  inspect(result_cli.get_source("host"), content="Some(FromCli)")
  inspect(result_default == result_cli, content="true")
}

///|
test "get_source returns FromConfig for config-sourced value" {
  let config_content = "{\"host\": \"config.example.com\"}"
  let config_file = ".test_vs_config_get_src.json"
  @fs.write_string_to_file(config_file, config_content)
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("host", str_option(long="host"))
  let p = p.with_config_file(config_file)
  let result = p.parse([]) catch {
    e => {
      @fs.remove_file(config_file)
      raise e
    }
  }
  @fs.remove_file(config_file)
  inspect(result.get_source("host"), content="Some(FromConfig)")
  inspect(result.get_string("host"), content="Some(\"config.example.com\")")
}
