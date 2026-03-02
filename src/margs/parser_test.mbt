// Parser tests for margs

// ===== Long option parsing =====

///|
test "parse long option with space separator" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name"))
  let result = p.parse(["--name", "hello"])
  inspect(name_h.get(result), content="Some(\"hello\")")
}

///|
test "parse long option with = separator" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name"))
  let result = p.parse(["--name=hello"])
  inspect(name_h.get(result), content="Some(\"hello\")")
}

///|
test "parse long option falls back to key as long name" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, output_h) = p.add("output", str_option())
  let result = p.parse(["--output", "/tmp/out"])
  inspect(output_h.get(result), content="Some(\"/tmp/out\")")
}

// ===== Short option parsing =====

///|
test "parse short option with space separator" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(short='n'))
  let result = p.parse(["-n", "hello"])
  inspect(name_h.get(result), content="Some(\"hello\")")
}

///|
test "parse short option with attached value" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(short='n'))
  let result = p.parse(["-nhello"])
  inspect(name_h.get(result), content="Some(\"hello\")")
}

// ===== Flag parsing =====

///|
test "parse boolean flag long" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(long="verbose"))
  let result = p.parse(["--verbose"])
  inspect(verbose_h.get(result).unwrap_or(false), content="true")
}

///|
test "parse boolean flag short" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(short='v'))
  let result = p.parse(["-v"])
  inspect(verbose_h.get(result).unwrap_or(false), content="true")
}

///|
test "flag defaults to false" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(short='v'))
  let result = p.parse([])
  inspect(verbose_h.get(result).unwrap_or(false), content="false")
}

///|
test "combined short flags" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(short='v'))
  let (p, force_h) = p.add("force", flag(short='f'))
  let (p, quiet_h) = p.add("quiet", flag(short='q'))
  let result = p.parse(["-vfq"])
  inspect(verbose_h.get(result).unwrap_or(false), content="true")
  inspect(force_h.get(result).unwrap_or(false), content="true")
  inspect(quiet_h.get(result).unwrap_or(false), content="true")
}

// ===== Integer option parsing =====

///|
test "parse integer option" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, port_h) = p.add("port", int_option(long="port"))
  let result = p.parse(["--port", "8080"])
  inspect(port_h.get(result), content="Some(8080)")
}

///|
test "parse integer option with = form" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, port_h) = p.add("port", int_option(long="port"))
  let result = p.parse(["--port=3000"])
  inspect(port_h.get(result), content="Some(3000)")
}

///|
test "parse negative integer" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, offset_h) = p.add("offset", int_option(long="offset"))
  let result = p.parse(["--offset", "-5"])
  inspect(offset_h.get(result), content="Some(-5)")
}

///|
test "invalid integer raises error" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("port", int_option(long="port"))
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--port", "abc"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Double option parsing =====

///|
test "parse double option" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, threshold_h) = p.add("threshold", double_option(long="threshold"))
  let result = p.parse(["--threshold", "1.25"])
  inspect(threshold_h.get(result), content="Some(1.25)")
}

///|
test "parse double option with = separator" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, threshold_h) = p.add("threshold", double_option(long="threshold"))
  let result = p.parse(["--threshold=1.25"])
  inspect(threshold_h.get(result), content="Some(1.25)")
}

///|
test "parse double option from integer string" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, ratio_h) = p.add("ratio", double_option(long="ratio"))
  let result = p.parse(["--ratio", "2"])
  inspect(ratio_h.get(result), content="Some(2)")
}

///|
test "invalid double raises error" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("ratio", double_option(long="ratio"))
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "NaN"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "invalid double rejects infinity" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("ratio", double_option(long="ratio"))
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "Infinity"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "invalid double rejects non-numeric" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("ratio", double_option(long="ratio"))
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--ratio", "abc"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Default values =====

///|
test "string option default value" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, format_h) = p.add("format", str_option(long="format", default="json"))
  let result = p.parse([])
  inspect(format_h.get(result), content="Some(\"json\")")
}

///|
test "integer option default value" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, port_h) = p.add("port", int_option(long="port", default=3000))
  let result = p.parse([])
  inspect(port_h.get(result), content="Some(3000)")
}

///|
test "default value overridden by explicit" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, format_h) = p.add("format", str_option(long="format", default="json"))
  let result = p.parse(["--format", "yaml"])
  inspect(format_h.get(result), content="Some(\"yaml\")")
}

// ===== Required options =====

///|
test "missing required option raises error" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("name", str_option(long="name", required=true))
  let result : Result[ParsedArgs, Error] = Ok(p.parse([])) catch { e => Err(e) }
  inspect(result is Err(_), content="true")
}

///|
test "required option provided succeeds" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, name_h) = p.add("name", str_option(long="name", required=true))
  let result = p.parse(["--name", "test"])
  inspect(name_h.get(result), content="Some(\"test\")")
}

// ===== String list options =====

///|
test "string list option collects multiple values" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, include_h) = p.add("include", str_list_option(short='I'))
  let result = p.parse(["-I", "src", "-I", "lib", "-I", "vendor"])
  inspect(include_h.get(result).map(fn(a) { a.length() }), content="Some(3)")
}

///|
test "string list option empty by default" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, include_h) = p.add("include", str_list_option(short='I'))
  let result = p.parse([])
  inspect(include_h.get(result).map(fn(a) { a.length() }), content="Some(0)")
}

// ===== Positional arguments =====

///|
test "positional arguments collected" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("file"))
  let result = p.parse(["hello.txt"])
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
}

///|
test "multiple positional arguments" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("src"))
  let p = p.add_positional(positional("dest"))
  let result = p.parse(["a.txt", "b.txt"])
  inspect(result.get_positional(0), content="Some(\"a.txt\")")
  inspect(result.get_positional(1), content="Some(\"b.txt\")")
}

///|
test "missing required positional raises error" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("file", required=true))
  let result : Result[ParsedArgs, Error] = Ok(p.parse([])) catch { e => Err(e) }
  inspect(result is Err(_), content="true")
}

///|
test "optional positional not required" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("file", required=false))
  let result = p.parse([])
  inspect(result.get_positional(0), content="None")
}

// ===== Mixed options and positionals =====

///|
test "options before positionals" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(short='v'))
  let p = p.add_positional(positional("file"))
  let result = p.parse(["-v", "hello.txt"])
  inspect(verbose_h.get(result).unwrap_or(false), content="true")
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
}

///|
test "options after positionals" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(short='v'))
  let p = p.add_positional(positional("file"))
  let result = p.parse(["hello.txt", "-v"])
  inspect(verbose_h.get(result).unwrap_or(false), content="true")
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
}

// ===== Double dash =====

///|
test "double dash stops option parsing" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, verbose_h) = p.add("verbose", flag(short='v'))
  let result = p.parse(["--", "-v"])
  inspect(verbose_h.get(result).unwrap_or(false), content="false")
  inspect(result.get_positional(0), content="Some(\"-v\")")
}

// ===== Validator =====

///|
test "validator rejects invalid value" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add(
    "port",
    int_option(long="port", validator=fn(n) { n > 0 && n < 65536 }),
  )
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--port", "99999"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "validator accepts valid value" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, port_h) = p.add(
    "port",
    int_option(long="port", validator=fn(n) { n > 0 && n < 65536 }),
  )
  let result = p.parse(["--port", "8080"])
  inspect(port_h.get(result), content="Some(8080)")
}

// ===== Unknown option =====

///|
test "unknown long option raises error" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--unknown"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "unknown short option raises error" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["-x"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Help request =====

///|
test "help flag raises HelpRequested" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["--help"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "short help flag raises HelpRequested" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["-h"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Subcommand parsing =====

///|
test "subcommand with alias" {
  let sub = subcommand("build", aliases=["b"])
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_subcommand(sub)
  let result = p.parse(["b"])
  inspect(result.get_command_path().length(), content="2")
}

///|
test "subcommand validates parent required options" {
  let sub = subcommand("build")
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("config", str_option(long="config", required=true))
  let p = p.add_subcommand(sub)
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["build"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "unknown subcommand raises error" {
  let sub = subcommand("build")
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_subcommand(sub)
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["buid"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "positional parsed when subcommands defined but not matched" {
  let sub = subcommand("build")
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_positional(positional("file"))
  let p = p.add_subcommand(sub)
  let result = p.parse(["hello.txt"])
  inspect(result.get_positional(0), content="Some(\"hello.txt\")")
  inspect(result.get_command_path().length(), content="1")
}

///|
test "unknown token raises error when only subcommands and no positionals" {
  let sub = subcommand("build")
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_subcommand(sub)
  let result : Result[ParsedArgs, Error] = Ok(p.parse(["buid"])) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// ===== Complex scenario =====

///|
test "full parser scenario" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, output_h) = p.add(
    "output",
    str_option(short='o', long="output", default="a.out"),
  )
  let (p, jobs_h) = p.add("jobs", int_option(short='j', long="jobs", default=1))
  let (p, verbose_h) = p.add("verbose", flag(short='v', long="verbose"))
  let p = p.add_positional(positional("file"))
  let result = p.parse(["-v", "--output=build/main", "-j", "4", "main.c"])
  inspect(verbose_h.get(result).unwrap_or(false), content="true")
  inspect(output_h.get(result), content="Some(\"build/main\")")
  inspect(jobs_h.get(result), content="Some(4)")
  inspect(result.get_positional(0), content="Some(\"main.c\")")
}

// ===== Did you mean? suggestions =====

///|
test "unknown long option suggests similar option" {
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("port", str_option(long="port"))
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
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("port", flag(short='p'))
  let (p, _) = p.add("help", flag(short='h'))
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
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let p = p.add_subcommand(sub)
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
  let p = parser("test", description="test parser", builder=fn(args) { args })
  let (p, _) = p.add("port", str_option(long="port"))
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
