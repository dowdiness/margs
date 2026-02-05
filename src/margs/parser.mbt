// Parsing engine for margs

///|
/// Initialize default values from option specs
fn init_defaults(options : Array[OptionSpec]) -> Map[String, ArgValue] {
  let values : Map[String, ArgValue] = {}
  for opt in options {
    match opt {
      StringOption(d) =>
        match d.default {
          Some(v) => values[d.key] = Str(v)
          None => ()
        }
      IntOption(d) =>
        match d.default {
          Some(v) => values[d.key] = Int(v)
          None => ()
        }
      BoolFlag(d) => values[d.key] = Bool(d.default)
      StringListOption(d) => values[d.key] = StrList([])
    }
  }
  values
}

///|
/// Find an option by its long name
fn find_option_by_long(
  options : Array[OptionSpec],
  name : String,
) -> OptionSpec? {
  for opt in options {
    match option_long(opt) {
      Some(long) => if long == name { return Some(opt) }
      None =>
        // Fall back to key as long name
        if option_key(opt) == name {
          return Some(opt)
        }
    }
  }
  None
}

///|
/// Find an option by its short character
fn find_option_by_short(options : Array[OptionSpec], ch : Char) -> OptionSpec? {
  for opt in options {
    match option_short(opt) {
      Some(s) => if s == ch { return Some(opt) }
      None => ()
    }
  }
  None
}

///|
/// Find a subcommand by name or alias
fn find_subcommand(
  subcommands : Array[SubcommandSpec],
  name : String,
) -> SubcommandSpec? {
  for sub in subcommands {
    if sub.name == name {
      return Some(sub)
    }
    for a in sub.aliases {
      if a == name {
        return Some(sub)
      }
    }
  }
  None
}

///|
/// Apply a value to an option, validating and storing it
fn apply_option_value(
  opt : OptionSpec,
  raw_value : String,
  values : Map[String, ArgValue],
) -> Unit raise ParseError {
  match opt {
    StringOption(d) => {
      match d.validator {
        Some(validate) =>
          if not(validate(raw_value)) {
            raise InvalidValue(
              "invalid value '\{raw_value}' for option '\{d.key}'",
            )
          }
        None => ()
      }
      values[d.key] = Str(raw_value)
    }
    IntOption(d) =>
      match parse_int(raw_value) {
        Some(n) => {
          match d.validator {
            Some(validate) =>
              if not(validate(n)) {
                raise InvalidValue(
                  "invalid value '\{raw_value}' for option '\{d.key}'",
                )
              }
            None => ()
          }
          values[d.key] = Int(n)
        }
        None =>
          raise InvalidValue(
            "expected integer for option '\{d.key}', got '\{raw_value}'",
          )
      }
    BoolFlag(d) => values[d.key] = Bool(true)
    StringListOption(d) =>
      match values.get(d.key) {
        Some(StrList(arr)) => {
          arr.push(raw_value)
          values[d.key] = StrList(arr)
        }
        _ => values[d.key] = StrList([raw_value])
      }
  }
}

///|
/// Check if an option is a flag (takes no value)
fn is_flag(opt : OptionSpec) -> Bool {
  match opt {
    BoolFlag(_) => true
    _ => false
  }
}

///|
/// Collect all long option names for suggestions
fn collect_long_names(options : Array[OptionSpec]) -> Array[String] {
  let names : Array[String] = []
  for opt in options {
    match option_long(opt) {
      Some(long) => names.push(long)
      None => names.push(option_key(opt))
    }
  }
  names
}

///|
/// Collect all short option characters for suggestions
fn collect_short_names(options : Array[OptionSpec]) -> Array[String] {
  let names : Array[String] = []
  for opt in options {
    match option_short(opt) {
      Some(ch) => names.push(ch.to_string())
      None => ()
    }
  }
  names
}

///|
/// Parse a long option (--key=value or --key value)
fn parse_long_option(
  name : String,
  options : Array[OptionSpec],
  values : Map[String, ArgValue],
  args : Array[String],
  pos : Ref[Int],
) -> Unit raise ParseError {
  // Check for --key=value form
  match split_at(name, '=') {
    Some((key, value)) =>
      match find_option_by_long(options, key) {
        Some(opt) => apply_option_value(opt, value, values)
        None => {
          let candidates = collect_long_names(options)
          match find_similar(key, candidates) {
            Some(suggestion) =>
              raise UnknownOption(
                "unknown option '--\{key}'. Did you mean '--\{suggestion}'?",
              )
            None => raise UnknownOption("unknown option '--\{key}'")
          }
        }
      }
    None =>
      match find_option_by_long(options, name) {
        Some(opt) =>
          if is_flag(opt) {
            apply_option_value(opt, "", values)
          } else if pos.val + 1 < args.length() {
            pos.val = pos.val + 1
            apply_option_value(opt, args[pos.val], values)
          } else {
            raise MissingRequired("option '--\{name}' requires a value")
          }
        None => {
          let candidates = collect_long_names(options)
          match find_similar(name, candidates) {
            Some(suggestion) =>
              raise UnknownOption(
                "unknown option '--\{name}'. Did you mean '--\{suggestion}'?",
              )
            None => raise UnknownOption("unknown option '--\{name}'")
          }
        }
      }
  }
}

///|
/// Parse a short option (-f value or -fvalue)
fn parse_short_option(
  chars : StringView,
  options : Array[OptionSpec],
  values : Map[String, ArgValue],
  args : Array[String],
  pos : Ref[Int],
) -> Unit raise ParseError {
  match chars {
    [] => raise InvalidFormat("empty short option '-'")
    [ch, .. rest] =>
      match find_option_by_short(options, ch) {
        Some(opt) =>
          if is_flag(opt) {
            apply_option_value(opt, "", values)
            // Process remaining chars as additional flags
            if rest.length() > 0 {
              parse_short_option(rest, options, values, args, pos)
            }
          } else if rest.length() > 0 {
            // -fvalue form (value is the rest of the string)
            apply_option_value(opt, rest.to_string(), values)
          } else if pos.val + 1 < args.length() {
            // -f value form
            pos.val = pos.val + 1
            apply_option_value(opt, args[pos.val], values)
          } else {
            raise MissingRequired("option '-\{ch}' requires a value")
          }
        None => {
          let candidates = collect_short_names(options)
          match find_similar(ch.to_string(), candidates) {
            Some(suggestion) =>
              raise UnknownOption(
                "unknown option '-\{ch}'. Did you mean '-\{suggestion}'?",
              )
            None => raise UnknownOption("unknown option '-\{ch}'")
          }
        }
      }
  }
}

///|
/// Validate that all required options and positionals are present
fn validate_required(
  options : Array[OptionSpec],
  positionals : Array[PositionalSpec],
  parsed : ParsedArgs,
) -> Unit raise ParseError {
  for opt in options {
    if option_required(opt) {
      let key = option_key(opt)
      match parsed.values.get(key) {
        Some(_) => ()
        None => raise MissingRequired("required option '\{key}' is missing")
      }
    }
  }
  for i, spec in positionals {
    if spec.required && i >= parsed.positionals.length() {
      raise MissingRequired(
        "required positional argument '\{spec.name}' is missing",
      )
    }
  }
}

///|
/// Main argument parsing loop
fn parse_args(
  options : Array[OptionSpec],
  positionals : Array[PositionalSpec],
  subcommands : Array[SubcommandSpec],
  args : Array[String],
  command_path : Array[String],
) -> ParsedArgs raise ParseError {
  let values = init_defaults(options)
  let pos_values : Array[String] = []
  let pos = Ref::new(0)
  let double_dash = Ref::new(false)
  while pos.val < args.length() {
    let arg = args[pos.val]
    if double_dash.val {
      // After --, everything is a positional
      pos_values.push(arg)
    } else if arg == "--" {
      double_dash.val = true
    } else if arg == "--help" || arg == "-h" {
      raise HelpRequested("")
    } else {
      match arg.view() {
        ['-', '-', .. rest] => {
          let name = rest.to_string()
          parse_long_option(name, options, values, args, pos)
        }
        ['-', .. rest] => parse_short_option(rest, options, values, args, pos)
        _ =>
          // Check if this is a subcommand
          if pos_values.length() == 0 && subcommands.length() > 0 {
            match find_subcommand(subcommands, arg) {
              Some(sub) => {
                // Validate parent required options (not positionals) before entering subcommand
                let parent_parsed : ParsedArgs = {
                  command_path,
                  values,
                  positionals: pos_values,
                }
                validate_required(options, [], parent_parsed)
                // Parse remaining args with subcommand's options
                let sub_args : Array[String] = []
                for i = pos.val + 1; i < args.length(); i = i + 1 {
                  sub_args.push(args[i])
                }
                let sub_path = command_path + [sub.name]
                let sub_parsed = parse_args(
                  sub.options,
                  sub.positionals,
                  sub.subcommands,
                  sub_args,
                  sub_path,
                )
                // Merge parent option values into subcommand result (preserve child precedence)
                for entry in values {
                  let (k, v) = entry
                  match sub_parsed.values.get(k) {
                    Some(_) => () // Child value takes precedence
                    None => sub_parsed.values[k] = v
                  }
                }
                return sub_parsed
              }
              None =>
                // Fall through to positional if positional specs exist
                if positionals.length() > 0 {
                  pos_values.push(arg)
                } else {
                  // Suggest similar subcommand names
                  let candidates : Array[String] = []
                  for sub in subcommands {
                    candidates.push(sub.name)
                  }
                  match find_similar(arg, candidates) {
                    Some(suggestion) =>
                      raise UnknownCommand(
                        "unknown command '\{arg}'. Did you mean '\{suggestion}'?",
                      )
                    None => raise UnknownCommand("unknown command '\{arg}'")
                  }
                }
            }
          } else {
            pos_values.push(arg)
          }
      }
    }
    pos.val = pos.val + 1
  }
  let parsed : ParsedArgs = { command_path, values, positionals: pos_values }
  validate_required(options, positionals, parsed)
  parsed
}

///|
/// Parse from an explicit argument array (for testing)
pub fn[T] Parser::parse(
  self : Parser[T],
  args : Array[String],
) -> T raise ParseError {
  let parsed = parse_args(
    self.options,
    self.positionals,
    self.subcommands,
    args,
    [self.name],
  )
  (self.builder)(parsed)
}

///|
/// Parse from CLI arguments (sys.get_cli_args())
pub fn[T] Parser::run(self : Parser[T]) -> T raise ParseError {
  let all_args = @sys.get_cli_args()
  let args : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    args.push(all_args[i])
  }
  self.parse(args)
}

// ===== Type-safe accessors on ParsedArgs =====

///|
/// Get a string value by key
pub fn ParsedArgs::get_string(self : ParsedArgs, key : String) -> String? {
  match self.values.get(key) {
    Some(Str(s)) => Some(s)
    _ => None
  }
}

///|
/// Get an integer value by key
pub fn ParsedArgs::get_int(self : ParsedArgs, key : String) -> Int? {
  match self.values.get(key) {
    Some(Int(n)) => Some(n)
    _ => None
  }
}

///|
/// Get a boolean value by key (defaults to false if not present)
pub fn ParsedArgs::get_bool(self : ParsedArgs, key : String) -> Bool {
  match self.values.get(key) {
    Some(Bool(b)) => b
    _ => false
  }
}

///|
/// Get a string list value by key
pub fn ParsedArgs::get_string_list(
  self : ParsedArgs,
  key : String,
) -> Array[String] {
  match self.values.get(key) {
    Some(StrList(arr)) => arr
    _ => []
  }
}

///|
/// Require a string value by key (raises if missing)
pub fn ParsedArgs::require_string(
  self : ParsedArgs,
  key : String,
) -> String raise ParseError {
  match self.values.get(key) {
    Some(Str(s)) => s
    _ => raise MissingRequired("required string option '\{key}' is missing")
  }
}

///|
/// Require an integer value by key (raises if missing)
pub fn ParsedArgs::require_int(
  self : ParsedArgs,
  key : String,
) -> Int raise ParseError {
  match self.values.get(key) {
    Some(Int(n)) => n
    _ => raise MissingRequired("required integer option '\{key}' is missing")
  }
}

///|
/// Get a positional argument by index
pub fn ParsedArgs::get_positional(self : ParsedArgs, index : Int) -> String? {
  if index >= 0 && index < self.positionals.length() {
    Some(self.positionals[index])
  } else {
    None
  }
}
