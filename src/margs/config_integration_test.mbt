// Integration tests for config file support with CLI

///|
test "parser loads string option from config file" {
  // Create a temp config file
  let config_content = "{\"host\": \"config.example.com\", \"port\": \"9000\", \"ratio\": 1.25}"
  @fs.write_string_to_file(".test_config.json", config_content)

  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("host", default="localhost"))
    .add_option(int_option("port", default=8080))
    .add_option(double_option("ratio", default=0.5))
    .with_config_file(".test_config.json")

  let result = p.parse([])

  inspect(result.get_string("host"), content="Some(\"config.example.com\")")
  inspect(result.get_int("port"), content="Some(9000)")
  inspect(result.get_double("ratio"), content="Some(1.25)")

  // Cleanup
  @fs.remove_file(".test_config.json")
}

///|
test "cli args override config file values" {
  let config_content = "{\"host\": \"config.example.com\"}"
  @fs.write_string_to_file(".test_config2.json", config_content)

  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("host", long="host"))
    .with_config_file(".test_config2.json")

  let result = p.parse(["--host", "cli.example.com"])

  inspect(result.get_string("host"), content="Some(\"cli.example.com\")")

  @fs.remove_file(".test_config2.json")
}

///|
test "env vars override config file values" {
  let config_content = "{\"port\": \"3000\"}"
  @fs.write_string_to_file(".test_config3.json", config_content)

  @sys.set_env_var("TEST_PORT", "5000")

  let p = parser("test", builder=fn(args) { args })
    .add_option(int_option("port", env="TEST_PORT"))
    .with_config_file(".test_config3.json")

  let result = p.parse([])

  inspect(result.get_int("port"), content="Some(5000)")

  @sys.unset_env_var("TEST_PORT")
  @fs.remove_file(".test_config3.json")
}

///|
test "config file falls back to default if file missing" {
  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("host", default="localhost"))
    .with_config_file(".nonexistent_config.json")

  let result = p.parse([])

  inspect(result.get_string("host"), content="Some(\"localhost\")")
}

///|
test "bool flag loads from config file" {
  let config_content = "{\"verbose\": \"true\", \"debug\": \"1\"}"
  @fs.write_string_to_file(".test_config4.json", config_content)

  let p = parser("test", builder=fn(args) { args })
    .add_option(flag("verbose"))
    .add_option(flag("debug"))
    .with_config_file(".test_config4.json")

  let result = p.parse([])

  inspect(result.get_bool("verbose"), content="true")
  inspect(result.get_bool("debug"), content="true")

  @fs.remove_file(".test_config4.json")
}

///|
test "full precedence chain: cli > env > config > default" {
  let config_content = "{\"alpha\": \"from_config\", \"beta\": \"from_config\", \"gamma\": \"from_config\", \"delta\": \"from_config\", \"epsilon\": 1.25}"
  @fs.write_string_to_file(".test_config5.json", config_content)

  @sys.set_env_var("TEST_BETA", "from_env")
  @sys.set_env_var("TEST_GAMMA", "from_env")
  @sys.set_env_var("TEST_EPSILON", "2.5")

  let p = parser("test", builder=fn(args) { args })
    .add_option(
      str_option("alpha", long="alpha", env="TEST_ALPHA", default="default"),
    )
    .add_option(
      str_option("beta", long="beta", env="TEST_BETA", default="default"),
    )
    .add_option(
      str_option("gamma", long="gamma", env="TEST_GAMMA", default="default"),
    )
    .add_option(
      str_option("delta", long="delta", env="TEST_DELTA", default="default"),
    )
    .add_option(
      double_option("epsilon", long="epsilon", env="TEST_EPSILON", default=0.5),
    )
    .with_config_file(".test_config5.json")

  let result = p.parse(["--gamma", "from_cli", "--epsilon", "3.5"])

  // alpha: no cli, no env → config
  inspect(result.get_string("alpha"), content="Some(\"from_config\")")
  // beta: no cli, has env → env
  inspect(result.get_string("beta"), content="Some(\"from_env\")")
  // gamma: has cli, has env → cli wins
  inspect(result.get_string("gamma"), content="Some(\"from_cli\")")
  // delta: no cli, no env → uses config value
  inspect(result.get_string("delta"), content="Some(\"from_config\")")
  // epsilon: has cli, has env, has config → cli wins
  inspect(result.get_double("epsilon"), content="Some(3.5)")

  @sys.unset_env_var("TEST_BETA")
  @sys.unset_env_var("TEST_GAMMA")
  @sys.unset_env_var("TEST_EPSILON")
  @fs.remove_file(".test_config5.json")
}
