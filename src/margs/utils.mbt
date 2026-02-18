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
/// Parse a double from a string. Returns None if the string is not a valid number.
pub fn parse_double(s : String) -> Double? {
  let trimmed = s.trim().to_string()
  if trimmed.length() == 0 {
    return None
  }
  let value = @strconv.parse_double(trimmed) catch { _ => return None }
  if value.is_nan() ||
    value == @double.infinity ||
    value == @double.neg_infinity {
    None
  } else {
    Some(value)
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
    DoubleOption(d) => d.key
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
    DoubleOption(d) => d.short
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
    DoubleOption(d) => d.long
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
    DoubleOption(d) => d.help
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
    DoubleOption(d) => d.required
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

// ===== parse_double Helper Tests =====

///|
test "parse_double with valid value" {
  inspect(parse_double("3.5"), content="Some(3.5)")
}

///|
test "parse_double rejects NaN" {
  inspect(parse_double("NaN"), content="None")
}

///|
test "parse_double rejects infinity" {
  inspect(parse_double("Infinity"), content="None")
}

///|
test "parse_double with invalid string" {
  inspect(parse_double("abc"), content="None")
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

///|
/// Calculate Levenshtein distance between two strings (for typo suggestions)
pub fn levenshtein_distance(a : String, b : String) -> Int {
  let len_a = a.length()
  let len_b = b.length()
  if len_a == 0 {
    return len_b
  }
  if len_b == 0 {
    return len_a
  }
  // Create a 2D matrix to store distances
  let mut prev_row : Array[Int] = []
  let mut curr_row : Array[Int] = []
  // Initialize first row (distance from empty string to b[0..j])
  for j = 0; j <= len_b; j = j + 1 {
    prev_row.push(j)
  }
  for i = 0; i < len_a; i = i + 1 {
    curr_row = []
    curr_row.push(i + 1) // Distance from a[0..i] to empty string
    for j = 0; j < len_b; j = j + 1 {
      let cost = if a[i] == b[j] { 0 } else { 1 }
      let delete = prev_row[j + 1] + 1
      let insert = curr_row[j] + 1
      let substitute = prev_row[j] + cost
      let min_val = if delete < insert {
        if delete < substitute {
          delete
        } else {
          substitute
        }
      } else if insert < substitute {
        insert
      } else {
        substitute
      }
      curr_row.push(min_val)
    }
    prev_row = curr_row
  }
  curr_row[len_b]
}

///|
/// Find the most similar string from candidates (returns None if no good match)
pub fn find_similar(input : String, candidates : Array[String]) -> String? {
  let mut best_match : String? = None
  let mut best_distance = 3 // Only suggest if distance <= 2
  for candidate in candidates {
    let distance = levenshtein_distance(input, candidate)
    if distance < best_distance {
      best_distance = distance
      best_match = Some(candidate)
    }
  }
  best_match
}

// ===== Levenshtein Distance Tests =====

///|
test "levenshtein_distance with identical strings" {
  inspect(levenshtein_distance("hello", "hello"), content="0")
}

///|
test "levenshtein_distance with one character difference" {
  inspect(levenshtein_distance("hello", "hallo"), content="1")
}

///|
test "levenshtein_distance with two character differences" {
  inspect(levenshtein_distance("serve", "serv"), content="1")
}

///|
test "levenshtein_distance with completely different strings" {
  inspect(levenshtein_distance("abc", "xyz"), content="3")
}

///|
test "levenshtein_distance with empty string" {
  inspect(levenshtein_distance("", "hello"), content="5")
  inspect(levenshtein_distance("hello", ""), content="5")
}

///|
test "find_similar returns closest match" {
  let candidates = ["serve", "start", "stop", "status"]
  inspect(find_similar("serv", candidates), content="Some(\"serve\")")
}

///|
test "find_similar returns None for distant matches" {
  let candidates = ["serve", "start", "stop"]
  inspect(find_similar("xyz", candidates), content="None")
}

///|
test "find_similar with typo in port" {
  let candidates = ["port", "path", "help"]
  inspect(find_similar("prot", candidates), content="Some(\"port\")")
}
