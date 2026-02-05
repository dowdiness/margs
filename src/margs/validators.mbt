// Common validators and smart constructors for margs

///|
/// Create a file path option (string with --file/-f convention)
pub fn file_option(
  key? : String = "file",
  short? : Char = 'f',
  long? : String = "file",
  help? : String = "Path to file",
  required? : Bool = false,
) -> OptionSpec {
  str_option(key, short~, long~, help~, metavar="FILE", required~)
}

///|
/// Create a port option (integer between 1 and 65535)
pub fn port_option(
  key? : String = "port",
  short? : Char = 'p',
  long? : String = "port",
  help? : String = "Port number",
  default? : Int,
) -> OptionSpec {
  int_option(key, short~, long~, help~, metavar="PORT", default?, validator=fn(
    n,
  ) {
    n > 0 && n <= 65535
  })
}

///|
/// Create a URL option
pub fn url_option(
  key? : String = "url",
  short? : Char = 'u',
  long? : String = "url",
  help? : String = "URL",
  required? : Bool = false,
) -> OptionSpec {
  str_option(key, short~, long~, help~, metavar="URL", required~)
}

///|
/// Create a verbose flag (-v, --verbose)
pub fn verbose_flag() -> OptionSpec {
  flag("verbose", short='v', long="verbose", help="Enable verbose output")
}

///|
/// Create a quiet flag (-q, --quiet)
pub fn quiet_flag() -> OptionSpec {
  flag("quiet", short='q', long="quiet", help="Suppress output")
}
