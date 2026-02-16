// Exit code helpers for CLI programs

///|
/// Standard exit codes for CLI programs
pub enum ExitCode {
  Success // 0 - Successful execution
  GeneralError // 1 - General error
  MisusedCommand // 2 - Misused shell command (invalid options/arguments)
  InvalidInput // 3 - Invalid user input
} derive(Eq)

///|
pub impl Show for ExitCode with output(self, logger) {
  match self {
    Success => logger.write_string("Success")
    GeneralError => logger.write_string("GeneralError")
    MisusedCommand => logger.write_string("MisusedCommand")
    InvalidInput => logger.write_string("InvalidInput")
  }
}

///|
/// Convert ExitCode to integer
pub fn ExitCode::code(self : ExitCode) -> Int {
  match self {
    Success => 0
    GeneralError => 1
    MisusedCommand => 2
    InvalidInput => 3
  }
}

///|
/// Convert a raised error to an appropriate exit code.
pub fn exit_code_for_error(err : ParseError) -> ExitCode {
  match err {
    HelpRequested(_) => Success
    VersionRequested(_) => Success
    UnknownOption(_) | UnknownCommand(_) | MissingRequired(_) => MisusedCommand
    InvalidValue(_) | InvalidFormat(_) => InvalidInput
    HandlerError(_) => GeneralError
  }
}
