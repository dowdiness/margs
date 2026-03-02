// Whitebox tests for low-level parser: subcommand option access and require accessors.
// These tests use pkg-private get_bool/get_string/require_* methods and must stay
// in a whitebox file after those methods were demoted in Improvement 3.

// ===== Subcommand option access via raw ParsedArgs =====

///|
test "subcommand dispatches correctly" {
  let sub = subcommand("build", description="Build the project", options=[
    build_spec("release", flag(long="release")),
  ])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_subcommand(sub)
  let result = p.parse(["build", "--release"])
  inspect(result.get_command_path().length(), content="2")
  inspect(result.get_bool("release"), content="true")
}

///|
test "subcommand preserves parent options" {
  let sub = subcommand("build", options=[
    build_spec("release", flag(long="release")),
  ])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, config_h) = p.add(
    "config",
    str_option(long="config", default="default.toml"),
  )
  let p = p.add_subcommand(sub)
  let result = p.parse(["--config", "my.toml", "build", "--release"])
  inspect(config_h.get(result), content="Some(\"my.toml\")")
  inspect(result.get_bool("release"), content="true")
  inspect(result.get_command_path().length(), content="2")
}

///|
test "subcommand with parent required positional does not fail" {
  let sub = subcommand("build", options=[
    build_spec("release", flag(long="release")),
  ])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("file", required=true))
  let p = p.add_subcommand(sub)
  // Subcommand dispatch should NOT check parent positionals
  let result = p.parse(["build", "--release"])
  inspect(result.get_command_path().length(), content="2")
  inspect(result.get_bool("release"), content="true")
}

///|
test "subcommand option takes precedence over parent with same key" {
  let sub = subcommand("build", options=[
    build_spec("output", str_option(long="output", default="build/out")),
  ])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("output", str_option(long="output", default="default/out"))
  let p = p.add_subcommand(sub)
  // Child default should win, not parent default
  let result = p.parse(["build"])
  inspect(result.get_string("output"), content="Some(\"build/out\")")
}

///|
test "subcommand explicit value not overwritten by parent default" {
  let sub = subcommand("build", options=[
    build_spec("output", str_option(long="output")),
  ])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("output", str_option(long="output", default="default/out"))
  let p = p.add_subcommand(sub)
  let result = p.parse(["build", "--output", "my/path"])
  inspect(result.get_string("output"), content="Some(\"my/path\")")
}

///|
test "subcommand still works when positionals also defined" {
  let sub = subcommand("build", options=[
    build_spec("release", flag(long="release")),
  ])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("file"))
  let p = p.add_subcommand(sub)
  let result = p.parse(["build", "--release"])
  inspect(result.get_command_path().length(), content="2")
  inspect(result.get_bool("release"), content="true")
}

// ===== Require accessors =====

///|
test "require_string succeeds when present" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("name", str_option(long="name"))
  let result = p.parse(["--name", "test"])
  let name = result.require_string("name")
  inspect(name, content="test")
}

///|
test "require_string fails when missing" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let result = p.parse([])
  let r : Result[String, Error] = Ok(result.require_string("name")) catch {
    e => Err(e)
  }
  inspect(r is Err(_), content="true")
}

///|
test "require_int succeeds when present" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("port", int_option(long="port"))
  let result = p.parse(["--port", "8080"])
  let port = result.require_int("port")
  inspect(port, content="8080")
}
