// Metadata generation for shell completion support

///|
/// Generate JSON metadata for a parser
/// This output can be consumed by shell completion generators
pub fn[T] generate_metadata(parser : Parser[T]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\n")
  buf.write_string("  \"name\": \"\{escape_json(parser.name)}\",\n")

  match parser.version {
    Some(v) => buf.write_string("  \"version\": \"\{escape_json(v)}\",\n")
    None => ()
  }

  if parser.description != "" {
    buf.write_string(
      "  \"description\": \"\{escape_json(parser.description)}\",\n",
    )
  }

  // Global options
  buf.write_string("  \"options\": ")
  buf.write_string(options_to_json(parser.options))
  buf.write_string(",\n")

  // Positional arguments
  buf.write_string("  \"positionals\": ")
  buf.write_string(positionals_to_json(parser.positionals))
  buf.write_string(",\n")

  // Subcommands
  buf.write_string("  \"commands\": ")
  buf.write_string(subcommands_to_json(parser.subcommands))
  buf.write_string("\n")

  buf.write_string("}")
  buf.to_string()
}

///|
/// Convert options array to JSON
fn options_to_json(options : Array[OptionSpec]) -> String {
  if options.length() == 0 {
    return "[]"
  }

  let buf = StringBuilder::new()
  buf.write_string("[\n")
  for i = 0; i < options.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("    ")
    buf.write_string(option_to_json(options[i], indent=2))
  }
  buf.write_string("\n  ]")
  buf.to_string()
}

///|
/// Convert a single option to JSON with specified indentation level
fn option_to_json(opt : OptionSpec, indent~ : Int) -> String {
  let spaces = indent_string(indent)
  let buf = StringBuilder::new()

  buf.write_string("{\n")

  match opt {
    StringOption(d) => {
      buf.write_string("\{spaces}  \"key\": \"\{escape_json(d.key)}\",\n")
      buf.write_string("\{spaces}  \"type\": \"string\",\n")
      write_option_common_fields(buf, spaces, d.short, d.long, d.help)
      buf.write_string(
        "\{spaces}  \"metavar\": \"\{escape_json(d.metavar)}\",\n",
      )
      buf.write_string("\{spaces}  \"required\": \{d.required}\n")
    }
    IntOption(d) => {
      buf.write_string("\{spaces}  \"key\": \"\{escape_json(d.key)}\",\n")
      buf.write_string("\{spaces}  \"type\": \"int\",\n")
      write_option_common_fields(buf, spaces, d.short, d.long, d.help)
      buf.write_string(
        "\{spaces}  \"metavar\": \"\{escape_json(d.metavar)}\",\n",
      )
      buf.write_string("\{spaces}  \"required\": \{d.required}\n")
    }
    DoubleOption(d) => {
      buf.write_string("\{spaces}  \"key\": \"\{escape_json(d.key)}\",\n")
      buf.write_string("\{spaces}  \"type\": \"double\",\n")
      write_option_common_fields(buf, spaces, d.short, d.long, d.help)
      buf.write_string(
        "\{spaces}  \"metavar\": \"\{escape_json(d.metavar)}\",\n",
      )
      buf.write_string("\{spaces}  \"required\": \{d.required}\n")
    }
    BoolFlag(d) => {
      buf.write_string("\{spaces}  \"key\": \"\{escape_json(d.key)}\",\n")
      buf.write_string("\{spaces}  \"type\": \"bool\",\n")
      write_option_common_fields(buf, spaces, d.short, d.long, d.help)
      buf.write_string("\{spaces}  \"required\": false\n")
    }
    StringListOption(d) => {
      buf.write_string("\{spaces}  \"key\": \"\{escape_json(d.key)}\",\n")
      buf.write_string("\{spaces}  \"type\": \"string_list\",\n")
      write_option_common_fields(buf, spaces, d.short, d.long, d.help)
      buf.write_string(
        "\{spaces}  \"metavar\": \"\{escape_json(d.metavar)}\",\n",
      )
      buf.write_string("\{spaces}  \"required\": false\n")
    }
  }

  buf.write_string("\{spaces}}")
  buf.to_string()
}

///|
/// Write common option fields (short, long, help) to buffer
fn write_option_common_fields(
  buf : StringBuilder,
  spaces : String,
  short : Char?,
  long : String?,
  help : String,
) -> Unit {
  match short {
    Some(c) => buf.write_string("\{spaces}  \"short\": \"\{c}\",\n")
    None => ()
  }

  match long {
    Some(l) => buf.write_string("\{spaces}  \"long\": \"\{escape_json(l)}\",\n")
    None => ()
  }

  if help != "" {
    buf.write_string("\{spaces}  \"help\": \"\{escape_json(help)}\",\n")
  }
}

///|
/// Convert positionals array to JSON
fn positionals_to_json(positionals : Array[PositionalSpec]) -> String {
  if positionals.length() == 0 {
    return "[]"
  }

  let buf = StringBuilder::new()
  buf.write_string("[\n")
  for i = 0; i < positionals.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",\n")
    }

    buf.write_string("    {\n")
    buf.write_string(
      "      \"name\": \"\{escape_json(positionals[i].name)}\",\n",
    )

    if positionals[i].help != "" {
      buf.write_string(
        "      \"help\": \"\{escape_json(positionals[i].help)}\",\n",
      )
    }

    buf.write_string("      \"required\": \{positionals[i].required}\n")
    buf.write_string("    }")
  }
  buf.write_string("\n  ]")
  buf.to_string()
}

///|
/// Convert subcommands array to JSON
fn subcommands_to_json(subcommands : Array[SubcommandSpec]) -> String {
  if subcommands.length() == 0 {
    return "[]"
  }

  let buf = StringBuilder::new()
  buf.write_string("[\n")
  for i = 0; i < subcommands.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("    ")
    buf.write_string(subcommand_to_json(subcommands[i], indent=2))
  }
  buf.write_string("\n  ]")
  buf.to_string()
}

///|
/// Convert a single subcommand to JSON with specified indentation level
fn subcommand_to_json(sub : SubcommandSpec, indent~ : Int) -> String {
  let spaces = indent_string(indent)
  let buf = StringBuilder::new()

  buf.write_string("{\n")
  buf.write_string("\{spaces}  \"name\": \"\{escape_json(sub.name)}\",\n")

  if sub.description != "" {
    buf.write_string(
      "\{spaces}  \"description\": \"\{escape_json(sub.description)}\",\n",
    )
  }

  // Aliases
  if sub.aliases.length() > 0 {
    buf.write_string("\{spaces}  \"aliases\": [")
    for i = 0; i < sub.aliases.length(); i = i + 1 {
      if i > 0 {
        buf.write_string(", ")
      }
      buf.write_string("\"\{escape_json(sub.aliases[i])}\"")
    }
    buf.write_string("],\n")
  }

  // Options (nested)
  if sub.options.length() > 0 {
    buf.write_string("\{spaces}  \"options\": [\n")
    for i = 0; i < sub.options.length(); i = i + 1 {
      if i > 0 {
        buf.write_string(",\n")
      }
      buf.write_string("\{spaces}    ")
      buf.write_string(option_to_json(sub.options[i], indent=indent + 2))
    }
    buf.write_string("\n\{spaces}  ],\n")
  }

  // Positionals (nested)
  if sub.positionals.length() > 0 {
    buf.write_string("\{spaces}  \"positionals\": [\n")
    for i = 0; i < sub.positionals.length(); i = i + 1 {
      if i > 0 {
        buf.write_string(",\n")
      }
      buf.write_string("\{spaces}    {\n")
      buf.write_string(
        "\{spaces}      \"name\": \"\{escape_json(sub.positionals[i].name)}\",\n",
      )
      if sub.positionals[i].help != "" {
        buf.write_string(
          "\{spaces}      \"help\": \"\{escape_json(sub.positionals[i].help)}\",\n",
        )
      }
      buf.write_string(
        "\{spaces}      \"required\": \{sub.positionals[i].required}\n",
      )
      buf.write_string("\{spaces}    }")
    }
    buf.write_string("\n\{spaces}  ],\n")
  }

  // Nested subcommands
  if sub.subcommands.length() > 0 {
    buf.write_string("\{spaces}  \"subcommands\": [\n")
    for i = 0; i < sub.subcommands.length(); i = i + 1 {
      if i > 0 {
        buf.write_string(",\n")
      }
      buf.write_string("\{spaces}    ")
      buf.write_string(
        subcommand_to_json(sub.subcommands[i], indent=indent + 2),
      )
    }
    buf.write_string("\n\{spaces}  ]\n")
  } else {
    buf.write_string("\{spaces}  \"subcommands\": []\n")
  }

  buf.write_string("\{spaces}}")
  buf.to_string()
}

///|
/// Generate indentation string (2 spaces per level)
fn indent_string(level : Int) -> String {
  let buf = StringBuilder::new()
  for _i = 0; _i < level * 2; _i = _i + 1 {
    buf.write_string(" ")
  }
  buf.to_string()
}

///|
/// Escape special characters for JSON strings
fn escape_json(s : String) -> String {
  let buf = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c == '"' {
      buf.write_string("\\\"")
    } else if c == '\\' {
      buf.write_string("\\\\")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if c == '\t' {
      buf.write_string("\\t")
    } else {
      // Convert UInt16 to Char, then to String
      match c.to_int().to_char() {
        Some(ch) => buf.write_string(ch.to_string())
        None => () // Skip invalid characters
      }
    }
  }
  buf.to_string()
}
