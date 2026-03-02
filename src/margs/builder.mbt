// Builder API for constructing parsers and option specs

///|
/// Create a string option builder
pub fn str_option(
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "VALUE",
  required? : Bool = false,
  default? : String,
  env? : String,
  validator? : (String) -> Bool,
) -> OptionBuilder[String] {
  {
    build_spec: fn(key) {
      StringOption({
        key,
        short,
        long,
        help,
        metavar,
        required,
        default,
        env,
        validator,
      })
    },
    extract: fn(args, key) { args.get_string(key) },
  }
}

///|
/// Create an integer option builder
pub fn int_option(
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "NUM",
  required? : Bool = false,
  default? : Int,
  env? : String,
  validator? : (Int) -> Bool,
) -> OptionBuilder[Int] {
  {
    build_spec: fn(key) {
      IntOption({
        key,
        short,
        long,
        help,
        metavar,
        required,
        default,
        env,
        validator,
      })
    },
    extract: fn(args, key) { args.get_int(key) },
  }
}

///|
/// Create a double option builder
pub fn double_option(
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "NUM",
  required? : Bool = false,
  default? : Double,
  env? : String,
  validator? : (Double) -> Bool,
) -> OptionBuilder[Double] {
  {
    build_spec: fn(key) {
      DoubleOption({
        key,
        short,
        long,
        help,
        metavar,
        required,
        default,
        env,
        validator,
      })
    },
    extract: fn(args, key) { args.get_double(key) },
  }
}

///|
/// Create a boolean flag builder
pub fn flag(
  short? : Char,
  long? : String,
  help? : String = "",
  default? : Bool = false,
  env? : String,
) -> OptionBuilder[Bool] {
  {
    build_spec: fn(key) { BoolFlag({ key, short, long, help, default, env }) },
    extract: fn(args, key) { Some(args.get_bool(key)) },
  }
}

///|
/// Create a string list option builder (can be specified multiple times)
pub fn str_list_option(
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "VALUE",
  env? : String,
) -> OptionBuilder[Array[String]] {
  {
    build_spec: fn(key) {
      StringListOption({ key, short, long, help, metavar, env })
    },
    extract: fn(args, key) { Some(args.get_string_list(key)) },
  }
}

///|
/// Create a custom-typed option builder backed by a string option.
/// `parse~` converts the raw string value to `T?`; returning `None` rejects the value.
pub fn[T] custom_option(
  short? : Char,
  long? : String,
  help? : String = "",
  metavar? : String = "VALUE",
  required? : Bool = false,
  default? : String,
  env? : String,
  parse~ : (String) -> T?,
) -> OptionBuilder[T] {
  {
    build_spec: fn(key) {
      StringOption({
        key,
        short,
        long,
        help,
        metavar,
        required,
        default,
        env,
        validator: Some(fn(s) { parse(s) is Some(_) }),
      })
    },
    extract: fn(args, key) {
      match args.get_string(key) {
        Some(s) => parse(s)
        None => None
      }
    },
  }
}

///|
/// Pkg-private helper: materialise an OptionBuilder into an OptionSpec for a given key.
/// Used internally by subcommand option arrays in tests.
pub fn[T] build_spec(key : String, builder : OptionBuilder[T]) -> OptionSpec {
  (builder.build_spec)(key)
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
    config_file: None,
    builder,
  }
}

///|
/// Add an option to the parser
pub fn[T] Parser::add_option(self : Parser[T], opt : OptionSpec) -> Parser[T] {
  { ..self, options: self.options + [opt] }
}

///|
pub fn[T, U] Parser::add(
  self : Parser[T],
  key : String,
  builder : OptionBuilder[U],
) -> (Parser[T], TypedHandle[U]) {
  let spec = (builder.build_spec)(key)
  let handle : TypedHandle[U] = {
    key,
    extract: fn(args) { (builder.extract)(args, key) },
  }
  (self.add_option(spec), handle)
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
/// Set config file path for loading defaults
pub fn[T] Parser::with_config_file(
  self : Parser[T],
  path : String,
) -> Parser[T] {
  { ..self, config_file: Some(path) }
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
