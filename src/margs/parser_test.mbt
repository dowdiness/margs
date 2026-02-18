// Parser tests for margs

// ===== Helper: simple parser that returns ParsedArgs =====

///|
fn make_test_parser(
  options? : Array[OptionSpec] = [],
  positionals? : Array[PositionalSpec] = [],
  subcommands? : Array[SubcommandSpec] = [],
) -> Parser[ParsedArgs] {
  parser("test", description="test parser", builder=fn(args) { args })
  |> Parser::with_options(options)
  |> p => {
    let mut p = p
    for pos in positionals {
      p = p.add_positional(pos)
    }
    for sub in subcommands {
      p = p.add_subcommand(sub)
    }
    p
  }
}

// ===== Long option parsing =====

///|
test "parse long option with space separator" {
  let p = make_test_parser(options=[str_option("name", long="name")])
  let result = p.parse(["--name", "hello"])
  inspect(result.get_string("name"), content="Some(\"hello\")")
}

///|
test "parse long option with = separator" {
  let p = make_test_parser(options=[str_option("name", long="name")])
  let result = p.parse(["--name=hello"])
  inspect(result.get_string("name"), content="Some(\"hello\")")
}

///|
test "parse long option falls back to key as long name" {
  let p = make_test_parser(options=[str_option("output")])
  let result = p.parse(["--output", "/tmp/out"])
  inspect(result.get_string("output"), content="Some(\"/tmp/out\")")
}

// ===== Short option parsing =====

///|
test "parse short option with space separator" {
  let p = make_test_parser(options=[str_option("name", short='n')])
  let result = p.parse(["-n", "hello"])
  inspect(result.get_string("name"), content="Some(\"hello\")")
}

///|
test "parse short option with attached value" {
  let p = make_test_parser(options=[str_option("name", short='n')])
  let result = p.parse(["-nhello"])
  inspect(result.get_string("name"), content="Some(\"hello\")")
}

// ===== Flag parsing =====

///|
test "parse boolean flag long" {
  let p = make_test_parser(options=[flag("verbose", long="verbose")])
  let result = p.parse(["--verbose"])
  inspect(result.get_bool("verbose"), content="true")
}

///|
test "parse boolean flag short" {
  let p = make_test_parser(options=[flag("verbose", short='v')])
  let result = p.parse(["-v"])
  inspect(result.get_bool("verbose"), content="true")
}

///|
test "flag defaults to false" {
  let p = make_test_parser(options=[flag("verbose", short='v')])
  let result = p.parse([])
  inspect(result.get_bool("verbose"), content="false")
}

///|
test "combined short flags" {
  let p = make_test_parser(options=[
    flag("verbose", short='v'),
    flag("force", short='f'),
    flag("quiet", short='q'),
  ])
  let result = p.parse(["-vfq"])
  inspect(result.get_bool("verbose"), content="true")
  inspect(result.get_bool("force"), content="true")
  inspect(result.get_bool("quiet"), content="true")
}

// ===== Integer option parsing =====

///|
test "parse integer option" {
  let p = make_test_parser(options=[int_option("port", long="port")])
  let result = p.parse(["--port", "8080"])
  inspect(result.get_int("port"), content="Some(8080)")
}

///|
test "parse integer option with = form" {
  let p = make_test_parser(options=[int_option("port", long="port")])
  let result = p.parse(["--port=3000"])
  inspect(result.get_int("port"), content="Some(3000)")
}

///|
test "parse negative integer" {
  let p = make_test_parser(options=[int_option("offset", long="offset")])
  let result = p.parse(["--offset", "-5"])
  inspect(result.get_int("offset"), content="Some(-5)")
}

///|
test "invalid integer raises error" {
  let p = make_test_parser(options=[int_option("port", long="port")])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--port", "abc"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Double option parsing =====

///|
test "parse double option" {
  let p = make_test_parser(options=[
    double_option("threshold", long="threshold"),
  ])
  let result = p.parse(["--threshold", "1.25"])
  inspect(result.get_double("threshold"), content="Some(1.25)")
}

///|
test "parse double option with = separator" {
  let p = make_test_parser(options=[
    double_option("threshold", long="threshold"),
  ])
  let result = p.parse(["--threshold=1.25"])
  inspect(result.get_double("threshold"), content="Some(1.25)")
}

///|
test "parse double option from integer string" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result = p.parse(["--ratio", "2"])
  inspect(result.get_double("ratio"), content="Some(2)")
}

///|
test "invalid double raises error" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "NaN"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "invalid double rejects infinity" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "Infinity"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "invalid double rejects non-numeric" {
  let p = make_test_parser(options=[double_option("ratio", long="ratio")])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "abc"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Default values =====

///|
test "string option default value" {
  let p = make_test_parser(options=[
    str_option("format", long="format", default="json"),
  ])
  let result = p.parse([])
  inspect(result.get_string("format"), content="Some(\"json\")")
}

///|
test "integer option default value" {
  let p = make_test_parser(options=[
    int_option("port", long="port", default=3000),
  ])
  let result = p.parse([])
  inspect(result.get_int("port"), content="Some(3000)")
}

///|
test "default value overridden by explicit" {
  let p = make_test_parser(options=[
    str_option("format", long="format", default="json"),
  ])
  let result = p.parse(["--format", "yaml"])
  inspect(result.get_string("format"), content="Some(\"yaml\")")
}

// ===== Required options =====

///|
test "missing required option raises error" {
  let p = make_test_parser(options=[
    str_option("name", long="name", required=true),
  ])
  let result : Result[ParsedArgs, Error] = Ok(p.parse([])) catch { e => Err(e) }
  inspect(result is Err(_), content="true")
}

///|
test "required option provided succeeds" {
  let p = make_test_parser(options=[
    str_option("name", long="name", required=true),
  ])
  let result = p.parse(["--name", "test"])
  inspect(result.get_string("name"), content="Some(\"test\")")
}

// ===== String list options =====

///|
test "string list option collects multiple values" {
  let p = make_test_parser(options=[str_list_option("include", short='I')])
  let result = p.parse(["-I", "src", "-I", "lib", "-I", "vendor"])
  inspect(result.get_string_list("include").length(), content="3")
}

///|
test "string list option empty by default" {
  let p = make_test_parser(options=[str_list_option("include", short='I')])
  let result = p.parse([])
  inspect(result.get_string_list("include").length(), content="0")
}

// ===== Positional arguments =====

///|
test "positional arguments collected" {
  let p = make_test_parser(positionals=[positional("file")])
  let result = p.parse(["hello.txt"])
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
}

///|
test "multiple positional arguments" {
  let p = make_test_parser(positionals=[positional("src"), positional("dest")])
  let result = p.parse(["a.txt", "b.txt"])
  inspect(result.get_positional(0), content="Some(\"a.txt\")")
  inspect(result.get_positional(1), content="Some(\"b.txt\")")
}

///|
test "missing required positional raises error" {
  let p = make_test_parser(positionals=[positional("file", required=true)])
  let result : Result[ParsedArgs, Error] = Ok(p.parse([])) catch { e => Err(e) }
  inspect(result is Err(_), content="true")
}

///|
test "optional positional not required" {
  let p = make_test_parser(positionals=[positional("file", required=false)])
  let result = p.parse([])
  inspect(result.get_positional(0), content="None")
}

// ===== Mixed options and positionals =====

///|
test "options before positionals" {
  let p = make_test_parser(options=[flag("verbose", short='v')], positionals=[
    positional("file"),
  ])
  let result = p.parse(["-v", "hello.txt"])
  inspect(result.get_bool("verbose"), content="true")
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
}

///|
test "options after positionals" {
  let p = make_test_parser(options=[flag("verbose", short='v')], positionals=[
    positional("file"),
  ])
  let result = p.parse(["hello.txt", "-v"])
  inspect(result.get_bool("verbose"), content="true")
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
}

// ===== Double dash =====

///|
test "double dash stops option parsing" {
  let p = make_test_parser(options=[flag("verbose", short='v')])
  let result = p.parse(["--", "-v"])
  inspect(result.get_bool("verbose"), content="false")
  inspect(result.get_positional(0), content="Some(\"-v\")")
}

// ===== Validator =====

///|
test "validator rejects invalid value" {
  let p = make_test_parser(options=[
    int_option("port", long="port", validator=fn(n) { n > 0 && n < 65536 }),
  ])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--port", "99999"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "validator accepts valid value" {
  let p = make_test_parser(options=[
    int_option("port", long="port", validator=fn(n) { n > 0 && n < 65536 }),
  ])
  let result = p.parse(["--port", "8080"])
  inspect(result.get_int("port"), content="Some(8080)")
}

// ===== Unknown option =====

///|
test "unknown long option raises error" {
  let p = make_test_parser()
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--unknown"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "unknown short option raises error" {
  let p = make_test_parser()
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["-x"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Help request =====

///|
test "help flag raises HelpRequested" {
  let p = make_test_parser()
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--help"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "short help flag raises HelpRequested" {
  let p = make_test_parser()
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["-h"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Subcommand parsing =====

///|
test "subcommand dispatches correctly" {
  let sub = subcommand("build", description="Build the project", options=[
    flag("release", long="release"),
  ])
  let p = make_test_parser(subcommands=[sub])
  let result = p.parse(["build", "--release"])
  inspect(result.command_path.length(), content="2")
  inspect(result.get_bool("release"), content="true")
}

///|
test "subcommand with alias" {
  let sub = subcommand("build", aliases=["b"])
  let p = make_test_parser(subcommands=[sub])
  let result = p.parse(["b"])
  inspect(result.command_path.length(), content="2")
}

///|
test "subcommand preserves parent options" {
  let sub = subcommand("build", options=[flag("release", long="release")])
  let p = make_test_parser(
    options=[str_option("config", long="config", default="default.toml")],
    subcommands=[sub],
  )
  let result = p.parse(["--config", "my.toml", "build", "--release"])
  inspect(result.get_string("config"), content="Some(\"my.toml\")")
  inspect(result.get_bool("release"), content="true")
  inspect(result.command_path.length(), content="2")
}

///|
test "subcommand validates parent required options" {
  let sub = subcommand("build")
  let p = make_test_parser(
    options=[str_option("config", long="config", required=true)],
    subcommands=[sub],
  )
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["build"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "unknown subcommand raises error" {
  let sub = subcommand("build")
  let p = make_test_parser(subcommands=[sub])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["buid"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "subcommand with parent required positional does not fail" {
  let sub = subcommand("build", options=[flag("release", long="release")])
  let p = make_test_parser(positionals=[positional("file", required=true)], subcommands=[
    sub,
  ])
  // Subcommand dispatch should NOT check parent positionals
  let result = p.parse(["build", "--release"])
  inspect(result.command_path.length(), content="2")
  inspect(result.get_bool("release"), content="true")
}

///|
test "subcommand option takes precedence over parent with same key" {
  let sub = subcommand("build", options=[
    str_option("output", long="output", default="build/out"),
  ])
  let p = make_test_parser(
    options=[str_option("output", long="output", default="default/out")],
    subcommands=[sub],
  )
  // Child default should win, not parent default
  let result = p.parse(["build"])
  inspect(result.get_string("output"), content="Some(\"build/out\")")
}

///|
test "subcommand explicit value not overwritten by parent default" {
  let sub = subcommand("build", options=[str_option("output", long="output")])
  let p = make_test_parser(
    options=[str_option("output", long="output", default="default/out")],
    subcommands=[sub],
  )
  let result = p.parse(["build", "--output", "my/path"])
  inspect(result.get_string("output"), content="Some(\"my/path\")")
}

///|
test "positional parsed when subcommands defined but not matched" {
  let sub = subcommand("build")
  let p = make_test_parser(positionals=[positional("file")], subcommands=[sub])
  let result = p.parse(["hello.txt"])
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
  inspect(result.command_path.length(), content="1")
}

///|
test "subcommand still works when positionals also defined" {
  let sub = subcommand("build", options=[flag("release", long="release")])
  let p = make_test_parser(positionals=[positional("file")], subcommands=[sub])
  let result = p.parse(["build", "--release"])
  inspect(result.command_path.length(), content="2")
  inspect(result.get_bool("release"), content="true")
}

///|
test "unknown token raises error when only subcommands and no positionals" {
  let sub = subcommand("build")
  let p = make_test_parser(subcommands=[sub])
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["buid"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Complex scenario =====

///|
test "full parser scenario" {
  let p = make_test_parser(
    options=[
      str_option("output", short='o', long="output", default="a.out"),
      int_option("jobs", short='j', long="jobs", default=1),
      flag("verbose", short='v', long="verbose"),
    ],
    positionals=[positional("file")],
  )
  let result = p.parse(["-v", "--output=build/main", "-j", "4", "main.c"])
  inspect(result.get_bool("verbose"), content="true")
  inspect(result.get_string("output"), content="Some(\"build/main\")")
  inspect(result.get_int("jobs"), content="Some(4)")
  inspect(result.get_positional(0), content="Some(\"main.c\")")
}

// ===== Require accessors =====

///|
test "require_string succeeds when present" {
  let p = make_test_parser(options=[str_option("name", long="name")])
  let result = p.parse(["--name", "test"])
  let name = result.require_string("name")
  inspect(name, content="test")
}

///|
test "require_string fails when missing" {
  let p = make_test_parser()
  let result = p.parse([])
  let r : Result[String, Error] = Ok(result.require_string("name")) catch {
    e => Err(e)
  }
  inspect(r is Err(_), content="true")
}

///|
test "require_int succeeds when present" {
  let p = make_test_parser(options=[int_option("port", long="port")])
  let result = p.parse(["--port", "8080"])
  let port = result.require_int("port")
  inspect(port, content="8080")
}

// ===== Did you mean? suggestions =====

///|
test "unknown long option suggests similar option" {
  let p = make_test_parser(options=[str_option("port", long="port")])
  let caught = Ref::new(false)
  let _ : Result[ParsedArgs, Unit] = Ok(p.parse(["--prot", "8080"])) catch {
    @margs.UnknownOption(msg) => {
      caught.val = true
      inspect(msg.contains("Did you mean"), content="true")
      inspect(msg.contains("--port"), content="true")
      Err(())
    }
    _ => Err(())
  }
  inspect(caught.val, content="true")
}

///|
test "unknown short option suggests similar option" {
  let p = make_test_parser(options=[
    flag("port", short='p'),
    flag("help", short='h'),
  ])
  let caught = Ref::new(false)
  let _ : Result[ParsedArgs, Unit] = Ok(p.parse(["-o"])) catch {
    @margs.UnknownOption(msg) => {
      caught.val = true
      inspect(msg.contains("Did you mean"), content="true")
      Err(())
    }
    _ => Err(())
  }
  inspect(caught.val, content="true")
}

///|
test "unknown command suggests similar command" {
  let sub = subcommand("serve", options=[])
  let p = make_test_parser(subcommands=[sub])
  let caught = Ref::new(false)
  let _ : Result[ParsedArgs, Unit] = Ok(p.parse(["serv"])) catch {
    @margs.UnknownCommand(msg) => {
      caught.val = true
      inspect(msg.contains("Did you mean"), content="true")
      inspect(msg.contains("serve"), content="true")
      Err(())
    }
    _ => Err(())
  }
  inspect(caught.val, content="true")
}

///|
test "very different option does not suggest" {
  let p = make_test_parser(options=[str_option("port", long="port")])
  let caught = Ref::new(false)
  let _ : Result[ParsedArgs, Unit] = Ok(p.parse(["--xyz"])) catch {
    @margs.UnknownOption(msg) => {
      caught.val = true
      inspect(msg.contains("Did you mean"), content="false")
      Err(())
    }
    _ => Err(())
  }
  inspect(caught.val, content="true")
}
