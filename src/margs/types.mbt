// Core types for the margs argparser

///|
/// Concrete argument value types
pub enum ArgValue {
  Str(String)
  Int(Int)
  Bool(Bool)
  StrList(Array[String])
} derive(Eq)

///|
pub impl Show for ArgValue with output(self, logger) {
  match self {
    Str(s) => logger.write_string("Str(\{s})")
    Int(n) => logger.write_string("Int(\{n})")
    Bool(b) => logger.write_string("Bool(\{b})")
    StrList(arr) => {
      logger.write_string("StrList(")
      logger.write_object(arr)
      logger.write_string(")")
    }
  }
}

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
  command_path : Array[String]
  values : Map[String, ArgValue]
  positionals : Array[String]
} derive(Show, Eq)

///|
/// Parse error type
pub suberror ParseError {
  MissingRequired(String)
  InvalidValue(String)
  UnknownOption(String)
  UnknownCommand(String)
  InvalidFormat(String)
  HelpRequested(String)
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
  builder : (ParsedArgs) -> T raise ParseError
}
