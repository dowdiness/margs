// Core types for the margs argparser

///|
/// Concrete argument value types
pub enum ArgValue {
  Str(String)
  Int(Int)
  Double(Double)
  Bool(Bool)
  StrList(Array[String])
} derive(Eq)

///|
pub impl Show for ArgValue with output(self, logger) {
  match self {
    Str(s) => logger.write_string("Str(\{s})")
    Int(n) => logger.write_string("Int(\{n})")
    Double(n) => logger.write_string("Double(\{n})")
    Bool(b) => logger.write_string("Bool(\{b})")
    StrList(arr) => {
      logger.write_string("StrList(")
      logger.write_object(arr)
      logger.write_string(")")
    }
  }
}

///|
pub enum ValueSource {
  FromCli
  FromEnv
  FromConfig
  FromDefault
} derive(Show, Eq)

///|
/// Definition for a string-valued option
pub struct StringOptionDef {
  key : String
  short : Char?
  long : String?
  help : String
  metavar : String
  required : Bool
  default : String?
  env : String?
  validator : ((String) -> Bool)?
}

///|
/// Definition for an integer-valued option
pub struct IntOptionDef {
  key : String
  short : Char?
  long : String?
  help : String
  metavar : String
  required : Bool
  default : Int?
  env : String?
  validator : ((Int) -> Bool)?
}

///|
/// Definition for a double-valued option
pub struct DoubleOptionDef {
  key : String
  short : Char?
  long : String?
  help : String
  metavar : String
  required : Bool
  default : Double?
  env : String?
  validator : ((Double) -> Bool)?
}

///|
/// Definition for a boolean flag
pub struct BoolFlagDef {
  key : String
  short : Char?
  long : String?
  help : String
  default : Bool
  env : String?
}

///|
/// Definition for a string list option (can be specified multiple times)
pub struct StringListOptionDef {
  key : String
  short : Char?
  long : String?
  help : String
  metavar : String
  env : String?
}

///|
/// Union of all option spec types
pub enum OptionSpec {
  StringOption(StringOptionDef)
  IntOption(IntOptionDef)
  DoubleOption(DoubleOptionDef)
  BoolFlag(BoolFlagDef)
  StringListOption(StringListOptionDef)
}

// Manual Show impls since structs contain function fields

///|
pub impl Show for StringOptionDef with output(self, logger) {
  logger.write_string("StringOptionDef(key=\{self.key})")
}

///|
pub impl Show for IntOptionDef with output(self, logger) {
  logger.write_string("IntOptionDef(key=\{self.key})")
}

///|
pub impl Show for DoubleOptionDef with output(self, logger) {
  logger.write_string("DoubleOptionDef(key=\{self.key})")
}

///|
pub impl Show for BoolFlagDef with output(self, logger) {
  logger.write_string("BoolFlagDef(key=\{self.key})")
}

///|
pub impl Show for StringListOptionDef with output(self, logger) {
  logger.write_string("StringListOptionDef(key=\{self.key})")
}

///|
pub impl Show for OptionSpec with output(self, logger) {
  match self {
    StringOption(d) => logger.write_object(d)
    IntOption(d) => logger.write_object(d)
    DoubleOption(d) => logger.write_object(d)
    BoolFlag(d) => logger.write_object(d)
    StringListOption(d) => logger.write_object(d)
  }
}

///|
/// Positional argument specification
pub struct PositionalSpec {
  name : String
  help : String
  required : Bool
} derive(Show, Eq)

///|
/// Subcommand specification (recursive, no Parser[T] reference)
pub struct SubcommandSpec {
  name : String
  description : String
  aliases : Array[String]
  options : Array[OptionSpec]
  positionals : Array[PositionalSpec]
  subcommands : Array[SubcommandSpec]
} derive(Show)

///|
/// Result of parsing arguments
pub struct ParsedArgs {
  priv command_path : Array[String]
  priv values : Map[String, (ArgValue, ValueSource)]
  priv positionals : Array[String]
} derive(Show)

///|
/// Equality compares command path, positionals, and option values only.
/// ValueSource provenance is intentionally excluded so that two parses
/// producing the same logical values compare equal regardless of source.
pub impl Eq for ParsedArgs with equal(self, other : ParsedArgs) -> Bool {
  if self.command_path != other.command_path {
    return false
  }
  if self.positionals != other.positionals {
    return false
  }
  for entry in self.values {
    let (k, v) = entry
    let (argval, _) = v
    match other.values.get(k) {
      Some((ov, _)) => if argval != ov { return false }
      None => return false
    }
  }
  for entry in other.values {
    let (k, _) = entry
    match self.values.get(k) {
      None => return false
      Some(_) => ()
    }
  }
  true
}

///|
/// Encapsulates option construction and value extraction as closures.
/// Returned by factory functions; consumed by `.add()`.
pub struct OptionBuilder[T] {
  priv build_spec : (String) -> OptionSpec
  priv extract : (ParsedArgs, String) -> T?
}

///|
/// Type-safe option handle. Binds option definition to value access at compile time.
/// Fields are priv — handles can only be created via `.add()`.
pub struct TypedHandle[T] {
  priv key : String
  priv extract : (ParsedArgs) -> T?
}

///|
pub fn[T] TypedHandle::get(self : TypedHandle[T], args : ParsedArgs) -> T? {
  (self.extract)(args)
}

///|
/// Raises MissingRequired if no value was stored, or InvalidValue if a value
/// was stored but extraction returned None (e.g. type conversion failed).
pub fn[T] TypedHandle::require(
  self : TypedHandle[T],
  args : ParsedArgs,
) -> T raise ParseError {
  match (self.extract)(args) {
    Some(v) => v
    None =>
      match args.get_source(self.key) {
        Some(source) =>
          raise InvalidValue(
            "option '\{self.key}' has an invalid value (source: \{source})",
          )
        None =>
          raise MissingRequired("required option '\{self.key}' is missing")
      }
  }
}

///|
pub fn[T] TypedHandle::source(
  self : TypedHandle[T],
  args : ParsedArgs,
) -> ValueSource? {
  args.get_source(self.key)
}

///|
/// Parse error type
pub suberror ParseError {
  MissingRequired(String)
  InvalidValue(String)
  UnknownOption(String)
  UnknownCommand(String)
  InvalidFormat(String)
  HelpRequested(String)
  VersionRequested(String)
  HandlerError(String)
}

///|
/// The main parser type, parameterized by the result type T
pub struct Parser[T] {
  name : String
  description : String
  version : String?
  examples : Array[(String, String)]
  options : Array[OptionSpec]
  positionals : Array[PositionalSpec]
  subcommands : Array[SubcommandSpec]
  config_file : String?
  builder : (ParsedArgs) -> T raise ParseError
}
