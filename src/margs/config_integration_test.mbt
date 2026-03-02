// Integration tests for config file support with CLI

///|
test "parser loads string option from config file" {
  // Create a temp config file
  let config_content = "{\"host\": \"config.example.com\", \"port\": 9000, \"ratio\": 1.25}"
  @fs.write_string_to_file(".test_config.json", config_content)

  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(default="localhost"))
  let (p, port_h) = p.add("port", int_option(default=8080))
  let (p, ratio_h) = p.add("ratio", double_option(default=0.5))
  let p = p.with_config_file(".test_config.json")

  let result = p.parse([])

  inspect(host_h.get(result), content="Some(\"config.example.com\")")
  inspect(port_h.get(result), content="Some(9000)")
  inspect(ratio_h.get(result), content="Some(1.25)")

  // Cleanup
  @fs.remove_file(".test_config.json")
}

///|
test "cli args override config file values" {
  let config_content = "{\"host\": \"config.example.com\"}"
  @fs.write_string_to_file(".test_config2.json", config_content)

  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(long="host"))
  let p = p.with_config_file(".test_config2.json")

  let result = p.parse(["--host", "cli.example.com"])

  inspect(host_h.get(result), content="Some(\"cli.example.com\")")

  @fs.remove_file(".test_config2.json")
}

///|
test "env vars override config file values" {
  let config_content = "{\"port\": 3000}"
  @fs.write_string_to_file(".test_config3.json", config_content)

  @sys.set_env_var("TEST_PORT", "5000")

  let p = parser("test", builder=fn(args) { args })
  let (p, port_h) = p.add("port", int_option(env="TEST_PORT"))
  let p = p.with_config_file(".test_config3.json")

  let result = p.parse([])

  inspect(port_h.get(result), content="Some(5000)")

  @sys.unset_env_var("TEST_PORT")
  @fs.remove_file(".test_config3.json")
}

///|
test "config file falls back to default if file missing" {
  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(default="localhost"))
  let p = p.with_config_file(".nonexistent_config.json")

  let result = p.parse([])

  inspect(host_h.get(result), content="Some(\"localhost\")")
}

///|
test "invalid required double in config fails parse-time validation" {
  let config_content = "{\"ratio\": \"not-a-number\"}"
  @fs.write_string_to_file(
    ".test_config_invalid_required_double.json", config_content,
  )

  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add("ratio", double_option(required=true))
  let p = p.with_config_file(".test_config_invalid_required_double.json")

  let caught = Ref::new(false)
  let _ : Result[ParsedArgs, Unit] = Ok(p.parse([])) catch {
    @margs.InvalidValue(_) => {
      caught.val = true
      Err(())
    }
    _ => Err(())
  }
  inspect(caught.val, content="true")

  @fs.remove_file(".test_config_invalid_required_double.json")
}

///|
test "bool flag loads from config file" {
  let config_content = "{\"verbose\": true, \"debug\": true}"
  @fs.write_string_to_file(".test_config4.json", config_content)

  let p = parser("test", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag())
  let (p, debug_h) = p.add("debug", flag())
  let p = p.with_config_file(".test_config4.json")

  let result = p.parse([])

  inspect(verbose_h.get(result).unwrap_or(false), content="true")
  inspect(debug_h.get(result).unwrap_or(false), content="true")

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
  let (p, alpha_h) = p.add(
    "alpha",
    str_option(long="alpha", env="TEST_ALPHA", default="default"),
  )
  let (p, beta_h) = p.add(
    "beta",
    str_option(long="beta", env="TEST_BETA", default="default"),
  )
  let (p, gamma_h) = p.add(
    "gamma",
    str_option(long="gamma", env="TEST_GAMMA", default="default"),
  )
  let (p, delta_h) = p.add(
    "delta",
    str_option(long="delta", env="TEST_DELTA", default="default"),
  )
  let (p, epsilon_h) = p.add(
    "epsilon",
    double_option(long="epsilon", env="TEST_EPSILON", default=0.5),
  )
  let p = p.with_config_file(".test_config5.json")

  let result = p.parse(["--gamma", "from_cli", "--epsilon", "3.5"])

  // alpha: no cli, no env → config
  inspect(alpha_h.get(result), content="Some(\"from_config\")")
  // beta: no cli, has env → env
  inspect(beta_h.get(result), content="Some(\"from_env\")")
  // gamma: has cli, has env → cli wins
  inspect(gamma_h.get(result), content="Some(\"from_cli\")")
  // delta: no cli, no env → uses config value
  inspect(delta_h.get(result), content="Some(\"from_config\")")
  // epsilon: has cli, has env, has config → cli wins
  inspect(epsilon_h.get(result), content="Some(3.5)")

  @sys.unset_env_var("TEST_BETA")
  @sys.unset_env_var("TEST_GAMMA")
  @sys.unset_env_var("TEST_EPSILON")
  @fs.remove_file(".test_config5.json")
}
