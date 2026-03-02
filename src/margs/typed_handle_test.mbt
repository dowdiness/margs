// Tests for TypedHandle::get, require, source, and custom_option

///|
test "TypedHandle::get returns Some for present value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(long="host", default="localhost"))
  let args = p.parse(["--host", "example.com"])
  inspect(host_h.get(args), content="Some(\"example.com\")")
}

///|
test "TypedHandle::get returns None for absent optional with no default" {
  let p = parser("test", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name"))
  let args = p.parse([])
  inspect(name_h.get(args), content="None")
}

///|
test "TypedHandle::get returns Some for int option default" {
  let p = parser("test", builder=fn(args) { args })
  let (p, port_h) = p.add("port", int_option(long="port", default=8080))
  let args = p.parse([])
  inspect(port_h.get(args), content="Some(8080)")
}

///|
test "TypedHandle::require returns value when present" {
  let p = parser("test", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name"))
  let args = p.parse(["--name", "alice"])
  let name = name_h.require(args)
  inspect(name, content="alice")
}

///|
test "TypedHandle::require raises MissingRequired for absent option" {
  let p = parser("test", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name"))
  let args = p.parse([])
  let r : Result[String, Error] = Ok(name_h.require(args)) catch { e => Err(e) }
  match r {
    Err(ParseError::MissingRequired(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}

///|
test "TypedHandle::require raises InvalidValue when stored default fails custom parse" {
  // custom_option default bypasses the validator; if the default string is
  // not parseable by `parse`, extract returns None but a value IS stored
  // (FromDefault), so require raises InvalidValue rather than MissingRequired.
  let p = parser("test", builder=fn(args) { args })
  let (p, url_h) = p.add(
    "url",
    custom_option(
      long="url",
      default="not-a-url",
      parse=fn(s) { if s.has_prefix("http") { Some(s) } else { None } },
    ),
  )
  let args = p.parse([])
  let r : Result[String, Error] = Ok(url_h.require(args)) catch { e => Err(e) }
  match r {
    Err(ParseError::InvalidValue(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}

///|
test "TypedHandle::source returns FromCli for CLI-provided value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(long="host"))
  let args = p.parse(["--host", "example.com"])
  inspect(host_h.source(args), content="Some(FromCli)")
}

///|
test "TypedHandle::source returns FromDefault for default value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(long="host", default="localhost"))
  let args = p.parse([])
  inspect(host_h.source(args), content="Some(FromDefault)")
}

///|
test "TypedHandle::source returns None when no value" {
  let p = parser("test", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name"))
  let args = p.parse([])
  inspect(name_h.source(args), content="None")
}

///|
test "TypedHandle::source returns FromEnv when env var is set" {
  @sys.set_env_var("TEST_TH_HOST", "env.example.com")
  let p = parser("test", builder=fn(args) { args })
  let (p, host_h) = p.add("host", str_option(long="host", env="TEST_TH_HOST"))
  let args = p.parse([]) catch {
    e => {
      @sys.unset_env_var("TEST_TH_HOST")
      raise e
    }
  }
  @sys.unset_env_var("TEST_TH_HOST")
  inspect(host_h.source(args), content="Some(FromEnv)")
}

///|
test "custom_option returns typed value for valid CLI input" {
  let p = parser("test", builder=fn(args) { args })
  let (p, port_h) = p.add(
    "port",
    custom_option(
      long="port",
      parse=fn(s) {
        match (try? @strconv.parse_int(s)) {
          Ok(n) => if n > 0 && n <= 65535 { Some(n) } else { None }
          Err(_) => None
        }
      },
    ),
  )
  let args = p.parse(["--port", "8080"])
  inspect(port_h.get(args), content="Some(8080)")
}

///|
test "custom_option validator rejects invalid CLI input at parse time" {
  let p = parser("test", builder=fn(args) { args })
  let (p, _) = p.add(
    "url",
    custom_option(
      long="url",
      parse=fn(s) { if s.has_prefix("http") { Some(s) } else { None } },
    ),
  )
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--url", "not-a-url"])) catch {
    e => Err(e)
  }
  match result {
    Err(ParseError::InvalidValue(_)) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}
