///|
/// Split a string into two elements tuple at the first occurrence of a delimiter.
pub fn split_at(s : String, delimiter : Char) -> (String, String)? {
  match s.find(delimiter.to_string()) {
    Some(i) => {
      let before = try? s[:i]
      let after = try? s[i + 1:]
      match (before, after) {
        (Ok(b), Ok(a)) => return Some((b.to_string(), a.to_string()))
        _ => return None
      }
    }
    None => return None
  }
}

// ===== split_at Helper Tests =====

///|
test "split_at with valid delimiter" {
  let result = split_at("key=value", '=')
  inspect(result, content="Some((\"key\", \"value\"))")
}

///|
test "split_at with multiple delimiters - splits at first" {
  let result = split_at("key=value=extra", '=')
  inspect(result, content="Some((\"key\", \"value=extra\"))")
}

///|
test "split_at with no delimiter" {
  let result = split_at("nodelimiter", '=')
  inspect(result, content="None")
}

///|
test "split_at with empty string" {
  let result = split_at("", '=')
  inspect(result, content="None")
}

///|
test "split_at with delimiter at start" {
  let result = split_at("=value", '=')
  inspect(result, content="Some((\"\", \"value\"))")
}

///|
test "split_at with delimiter at end" {
  let result = split_at("key=", '=')
  inspect(result, content="Some((\"key\", \"\"))")
}

///|
test "split_at with space delimiter" {
  let result = split_at("hello world", ' ')
  inspect(result, content="Some((\"hello\", \"world\"))")
}

///|
/// Parse an integer from a string. Returns None if the string is not a valid integer.
pub fn parse_int(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut result = 0
  let mut i = 0
  let negative = s[0] == '-'
  if negative {
    if s.length() == 1 {
      return None
    }
    i = 1
  }
  while i < s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
      i = i + 1
    } else {
      return None
    }
  }
  if negative {
    Some(-result)
  } else {
    Some(result)
  }
}

///|
/// Pad a string to the right with spaces to reach the desired width.
pub fn pad_right(s : String, width : Int) -> String {
  let len = s.length()
  if len >= width {
    s
  } else {
    let buf = StringBuilder::new()
    buf.write_string(s)
    for _i = 0; _i < width - len; _i = _i + 1 {
      buf.write_char(' ')
    }
    buf.to_string()
  }
}

///|
/// Extract the key from any OptionSpec variant.
pub fn option_key(opt : OptionSpec) -> String {
  match opt {
    StringOption(d) => d.key
    IntOption(d) => d.key
    BoolFlag(d) => d.key
    StringListOption(d) => d.key
  }
}

///|
/// Extract the short flag from any OptionSpec variant.
pub fn option_short(opt : OptionSpec) -> Char? {
  match opt {
    StringOption(d) => d.short
    IntOption(d) => d.short
    BoolFlag(d) => d.short
    StringListOption(d) => d.short
  }
}

///|
/// Extract the long flag from any OptionSpec variant.
pub fn option_long(opt : OptionSpec) -> String? {
  match opt {
    StringOption(d) => d.long
    IntOption(d) => d.long
    BoolFlag(d) => d.long
    StringListOption(d) => d.long
  }
}

///|
/// Extract the help text from any OptionSpec variant.
pub fn option_help(opt : OptionSpec) -> String {
  match opt {
    StringOption(d) => d.help
    IntOption(d) => d.help
    BoolFlag(d) => d.help
    StringListOption(d) => d.help
  }
}

///|
/// Check if an option is required.
pub fn option_required(opt : OptionSpec) -> Bool {
  match opt {
    StringOption(d) => d.required
    IntOption(d) => d.required
    BoolFlag(_) => false
    StringListOption(_) => false
  }
}

// ===== parse_int Helper Tests =====

///|
test "parse_int with valid positive integer" {
  inspect(parse_int("123"), content="Some(123)")
}

///|
test "parse_int with valid negative integer" {
  inspect(parse_int("-42"), content="Some(-42)")
}

///|
test "parse_int with zero" {
  inspect(parse_int("0"), content="Some(0)")
}

///|
test "parse_int with invalid string" {
  inspect(parse_int("abc"), content="None")
}

///|
test "parse_int with empty string" {
  inspect(parse_int(""), content="None")
}

///|
test "parse_int with mixed content" {
  inspect(parse_int("12abc"), content="None")
}

///|
test "parse_int with lone minus" {
  inspect(parse_int("-"), content="None")
}

// ===== pad_right Helper Tests =====

///|
test "pad_right pads short string" {
  inspect(pad_right("hi", 5), content="hi   ")
}

///|
test "pad_right does not truncate long string" {
  inspect(pad_right("hello", 3), content="hello")
}

///|
test "pad_right exact width" {
  inspect(pad_right("abc", 3), content="abc")
}

// ===== option_key Helper Tests =====

///|
test "option_key extracts key from StringOption" {
  let opt = str_option("name", long="name")
  inspect(option_key(opt), content="name")
}

///|
test "option_key extracts key from BoolFlag" {
  let opt = flag("verbose", short='v')
  inspect(option_key(opt), content="verbose")
}
