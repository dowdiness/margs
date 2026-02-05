// Help text generation for margs

///|
/// Format the flags portion of an option (e.g., "-v, --verbose")
fn format_flags(opt : OptionSpec) -> String {
  let buf = StringBuilder::new()
  let short = option_short(opt)
  let long = option_long(opt)
  let key = option_key(opt)
  match (short, long) {
    (Some(s), Some(l)) => {
      buf.write_string("-\{s}, --\{l}")
      append_metavar(buf, opt)
    }
    (Some(s), None) => {
      buf.write_string("-\{s}")
      append_metavar(buf, opt)
    }
    (None, Some(l)) => {
      buf.write_string("    --\{l}")
      append_metavar(buf, opt)
    }
    (None, None) => {
      buf.write_string("    --\{key}")
      append_metavar(buf, opt)
    }
  }
  buf.to_string()
}

///|
/// Append the metavar to a flag description if needed
fn append_metavar(buf : StringBuilder, opt : OptionSpec) -> Unit {
  match opt {
    StringOption(d) => buf.write_string(" <\{d.metavar}>")
    IntOption(d) => buf.write_string(" <\{d.metavar}>")
    BoolFlag(_) => ()
    StringListOption(d) => buf.write_string(" <\{d.metavar}>")
  }
}

///|
/// Format a single option help line
fn format_option_help(opt : OptionSpec, col_width : Int) -> String {
  let flags = format_flags(opt)
  let help = option_help(opt)
  let padded = pad_right(flags, col_width)
  if help.length() > 0 {
    "  \{padded}  \{help}"
  } else {
    "  \{padded}"
  }
}

///|
/// Compute the maximum flag column width
fn max_flag_width(options : Array[OptionSpec]) -> Int {
  let mut max = 0
  for opt in options {
    let w = format_flags(opt).length()
    if w > max {
      max = w
    }
  }
  // Include -h, --help
  let help_width = "-h, --help".length()
  if help_width > max {
    max = help_width
  }
  max
}

///|
/// Format usage line
fn format_usage(
  name : String,
  options : Array[OptionSpec],
  positionals : Array[PositionalSpec],
  subcommands : Array[SubcommandSpec],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Usage: \{name}")
  if options.length() > 0 {
    buf.write_string(" [OPTIONS]")
  }
  if subcommands.length() > 0 {
    buf.write_string(" <COMMAND>")
  }
  for pos in positionals {
    if pos.required {
      buf.write_string(" <\{pos.name}>")
    } else {
      buf.write_string(" [\{pos.name}]")
    }
  }
  buf.to_string()
}

///|
/// Generate full help text for a parser
pub fn[T] generate_help(p : Parser[T]) -> String {
  let buf = StringBuilder::new()
  // Description
  if p.description.length() > 0 {
    buf.write_string(p.description)
    buf.write_string("\n\n")
  }
  // Version
  match p.version {
    Some(v) => {
      buf.write_string("Version: ")
      buf.write_string(v)
      buf.write_string("\n\n")
    }
    None => ()
  }
  // Usage
  buf.write_string(
    format_usage(p.name, p.options, p.positionals, p.subcommands),
  )
  buf.write_string("\n")
  // Examples
  if p.examples.length() > 0 {
    buf.write_string("\nExamples:\n")
    for example in p.examples {
      let (cmd, desc) = example
      buf.write_string("  $ ")
      buf.write_string(cmd)
      buf.write_string("\n      ")
      buf.write_string(desc)
      buf.write_string("\n\n")
    }
  }
  // Subcommands
  if p.subcommands.length() > 0 {
    buf.write_string("\nCommands:\n")
    let mut max_name = 0
    for sub in p.subcommands {
      if sub.name.length() > max_name {
        max_name = sub.name.length()
      }
    }
    for sub in p.subcommands {
      let padded = pad_right(sub.name, max_name)
      if sub.description.length() > 0 {
        buf.write_string("  \{padded}  \{sub.description}\n")
      } else {
        buf.write_string("  \{padded}\n")
      }
    }
  }
  // Positionals
  if p.positionals.length() > 0 {
    buf.write_string("\nArguments:\n")
    let mut max_name = 0
    for pos in p.positionals {
      if pos.name.length() > max_name {
        max_name = pos.name.length()
      }
    }
    for pos in p.positionals {
      let padded = pad_right(pos.name, max_name)
      if pos.help.length() > 0 {
        buf.write_string("  <\{padded}>  \{pos.help}\n")
      } else {
        buf.write_string("  <\{padded}>\n")
      }
    }
  }
  // Options
  buf.write_string("\nOptions:\n")
  let col_width = max_flag_width(p.options)
  for opt in p.options {
    buf.write_string(format_option_help(opt, col_width))
    buf.write_string("\n")
  }
  // Help option is always present
  let help_padded = pad_right("-h, --help", col_width)
  buf.write_string("  \{help_padded}  Print help\n")
  buf.to_string()
}

///|
/// Generate help text for a subcommand spec
pub fn generate_subcommand_help(sub : SubcommandSpec) -> String {
  let buf = StringBuilder::new()
  // Description
  if sub.description.length() > 0 {
    buf.write_string(sub.description)
    buf.write_string("\n\n")
  }
  // Usage
  buf.write_string(
    format_usage(sub.name, sub.options, sub.positionals, sub.subcommands),
  )
  buf.write_string("\n")
  // Nested subcommands
  if sub.subcommands.length() > 0 {
    buf.write_string("\nCommands:\n")
    let mut max_name = 0
    for s in sub.subcommands {
      if s.name.length() > max_name {
        max_name = s.name.length()
      }
    }
    for s in sub.subcommands {
      let padded = pad_right(s.name, max_name)
      if s.description.length() > 0 {
        buf.write_string("  \{padded}  \{s.description}\n")
      } else {
        buf.write_string("  \{padded}\n")
      }
    }
  }
  // Positionals
  if sub.positionals.length() > 0 {
    buf.write_string("\nArguments:\n")
    let mut max_name = 0
    for pos in sub.positionals {
      if pos.name.length() > max_name {
        max_name = pos.name.length()
      }
    }
    for pos in sub.positionals {
      let padded = pad_right(pos.name, max_name)
      if pos.help.length() > 0 {
        buf.write_string("  <\{padded}>  \{pos.help}\n")
      } else {
        buf.write_string("  <\{padded}>\n")
      }
    }
  }
  // Options
  buf.write_string("\nOptions:\n")
  let col_width = max_flag_width(sub.options)
  for opt in sub.options {
    buf.write_string(format_option_help(opt, col_width))
    buf.write_string("\n")
  }
  let help_padded = pad_right("-h, --help", col_width)
  buf.write_string("  \{help_padded}  Print help\n")
  buf.to_string()
}
