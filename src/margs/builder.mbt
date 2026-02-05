// Builder API for constructing parsers and option specs

///|
/// Create a string option spec
pub fn str_option(
  key : String,
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "VALUE",
  required? : Bool = false,
  default? : String,
  validator? : (String) -> Bool,
) -> OptionSpec {
  StringOption({ key, short, long, help, metavar, required, default, validator })
}

///|
/// Create an integer option spec
pub fn int_option(
  key : String,
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "NUM",
  required? : Bool = false,
  default? : Int,
  validator? : (Int) -> Bool,
) -> OptionSpec {
  IntOption({ key, short, long, help, metavar, required, default, validator })
}

///|
/// Create a boolean flag spec
pub fn flag(
  key : String,
  short? : Char,
  long? : String,
  help? : String = "",
  default? : Bool = false,
) -> OptionSpec {
  BoolFlag({ key, short, long, help, default })
}

///|
/// Create a string list option spec (can be specified multiple times)
pub fn str_list_option(
  key : String,
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "VALUE",
) -> OptionSpec {
  StringListOption({ key, short, long, help, metavar })
}

///|
/// Create a positional argument spec
pub fn positional(
  name : String,
  help? : String = "",
  required? : Bool = true,
) -> PositionalSpec {
  { name, help, required }
}

///|
/// Create a new parser
pub fn[T] parser(
  name : String,
  description? : String = "",
  builder~ : (ParsedArgs) -> T raise ParseError,
) -> Parser[T] {
  {
    name,
    description,
    version: None,
    examples: [],
    options: [],
    positionals: [],
    subcommands: [],
    builder,
  }
}

///|
/// Add an option to the parser
pub fn[T] Parser::add_option(self : Parser[T], opt : OptionSpec) -> Parser[T] {
  { ..self, options: self.options + [opt] }
}

///|
/// Add a positional argument to the parser
pub fn[T] Parser::add_positional(
  self : Parser[T],
  pos : PositionalSpec,
) -> Parser[T] {
  { ..self, positionals: self.positionals + [pos] }
}

///|
/// Add a subcommand to the parser
pub fn[T] Parser::add_subcommand(
  self : Parser[T],
  sub : SubcommandSpec,
) -> Parser[T] {
  { ..self, subcommands: self.subcommands + [sub] }
}

///|
/// Add multiple options at once
pub fn[T] Parser::with_options(
  self : Parser[T],
  opts : Array[OptionSpec],
) -> Parser[T] {
  { ..self, options: self.options + opts }
}

///|
/// Add version information to the parser
pub fn[T] Parser::with_version(self : Parser[T], v : String) -> Parser[T] {
  { ..self, version: Some(v) }
}

///|
/// Add a usage example to the parser
pub fn[T] Parser::add_example(
  self : Parser[T],
  cmd : String,
  desc : String,
) -> Parser[T] {
  { ..self, examples: self.examples + [(cmd, desc)] }
}

///|
/// Create a subcommand spec
pub fn subcommand(
  name : String,
  description? : String = "",
  aliases? : Array[String] = [],
  options? : Array[OptionSpec] = [],
  positionals? : Array[PositionalSpec] = [],
  subcommands? : Array[SubcommandSpec] = [],
) -> SubcommandSpec {
  { name, description, aliases, options, positionals, subcommands }
}
