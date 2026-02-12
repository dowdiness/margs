// Tests for metadata generation

///|
test "generate metadata for simple parser with version" {
  let p = parser("myapp", description="My application", builder=fn(args) {
      args
    })
    .with_version("1.0.0")
    .add_option(str_option("host", long="host", help="Server hostname"))
    .add_option(flag("verbose", short='v', help="Enable verbose output"))

  let meta = generate_metadata(p)

  inspect(meta.contains("\"name\": \"myapp\""), content="true")
  inspect(meta.contains("\"version\": \"1.0.0\""), content="true")
  inspect(meta.contains("\"description\": \"My application\""), content="true")
  inspect(meta.contains("\"key\": \"host\""), content="true")
  inspect(meta.contains("\"type\": \"string\""), content="true")
  inspect(meta.contains("\"key\": \"verbose\""), content="true")
  inspect(meta.contains("\"type\": \"bool\""), content="true")
}

///|
test "generate metadata includes all option types" {
  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("name", short='n', help="Name value"))
    .add_option(int_option("port", short='p', help="Port number"))
    .add_option(flag("debug", short='d', help="Debug mode"))
    .add_option(str_list_option("tags", short='t', help="Tag list"))

  let meta = generate_metadata(p)

  inspect(meta.contains("\"type\": \"string\""), content="true")
  inspect(meta.contains("\"type\": \"int\""), content="true")
  inspect(meta.contains("\"type\": \"bool\""), content="true")
  inspect(meta.contains("\"type\": \"string_list\""), content="true")
}

///|
test "generate metadata includes short and long flags" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("output", short='o', long="output", help="Output file"),
  )

  let meta = generate_metadata(p)

  inspect(meta.contains("\"short\": \"o\""), content="true")
  inspect(meta.contains("\"long\": \"output\""), content="true")
}

///|
test "generate metadata includes required flags" {
  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("required-field", long="required", required=true))
    .add_option(str_option("optional-field", long="optional", required=false))

  let meta = generate_metadata(p)

  // Check that required appears correctly (at least once for each option)
  let required_count = count_occurrences(meta, "\"required\": true")
  let optional_count = count_occurrences(meta, "\"required\": false")

  inspect(required_count >= 1, content="true")
  inspect(optional_count >= 1, content="true")
}

///|
test "generate metadata with positional arguments" {
  let p = parser("test", builder=fn(args) { args })
    .add_positional(positional("input", help="Input file", required=true))
    .add_positional(positional("output", help="Output file", required=false))

  let meta = generate_metadata(p)

  inspect(meta.contains("\"name\": \"input\""), content="true")
  inspect(meta.contains("\"help\": \"Input file\""), content="true")
  inspect(meta.contains("\"name\": \"output\""), content="true")
  inspect(meta.contains("\"help\": \"Output file\""), content="true")
}

///|
test "generate metadata with subcommands" {
  let p = parser("cli", builder=fn(args) { args })
    .add_subcommand(
      subcommand("serve", description="Start server", aliases=["s", "start"], options=[
        int_option("port", short='p', help="Server port"),
      ]),
    )
    .add_subcommand(subcommand("build", description="Build project"))

  let meta = generate_metadata(p)

  inspect(meta.contains("\"name\": \"serve\""), content="true")
  inspect(meta.contains("\"description\": \"Start server\""), content="true")
  inspect(meta.contains("\"aliases\": [\"s\", \"start\"]"), content="true")
  inspect(meta.contains("\"name\": \"build\""), content="true")
  inspect(meta.contains("\"description\": \"Build project\""), content="true")
}

///|
test "generate metadata with nested subcommands" {
  let p = parser("cli", builder=fn(args) { args }).add_subcommand(
    subcommand("db", description="Database commands", subcommands=[
      subcommand("migrate", description="Run migrations"),
      subcommand("seed", description="Seed database"),
    ]),
  )

  let meta = generate_metadata(p)

  inspect(meta.contains("\"name\": \"db\""), content="true")
  inspect(meta.contains("\"name\": \"migrate\""), content="true")
  inspect(meta.contains("\"name\": \"seed\""), content="true")
}

///|
test "generate metadata escapes JSON special characters" {
  let p = parser("test", builder=fn(args) { args }).add_option(
    str_option("field", help="A \"quoted\" description with\nnewlines"),
  )

  let meta = generate_metadata(p)

  inspect(meta.contains("\\\"quoted\\\""), content="true")
  inspect(meta.contains("\\n"), content="true")
}

///|
test "generate metadata with empty parser" {
  let p = parser("empty", builder=fn(args) { args })

  let meta = generate_metadata(p)

  inspect(meta.contains("\"name\": \"empty\""), content="true")
  inspect(meta.contains("\"options\": []"), content="true")
  inspect(meta.contains("\"positionals\": []"), content="true")
  inspect(meta.contains("\"commands\": []"), content="true")
}

///|
test "generate metadata includes metavar for value options" {
  let p = parser("test", builder=fn(args) { args })
    .add_option(str_option("file", metavar="PATH"))
    .add_option(int_option("count", metavar="NUM"))

  let meta = generate_metadata(p)

  inspect(meta.contains("\"metavar\": \"PATH\""), content="true")
  inspect(meta.contains("\"metavar\": \"NUM\""), content="true")
}

// Helper function to count occurrences of a substring

///|
fn count_occurrences(haystack : String, needle : String) -> Int {
  let mut count = 0
  let mut pos = 0
  let needle_len = needle.length()

  while pos <= haystack.length() - needle_len {
    let mut matches = true
    for i = 0; i < needle_len; i = i + 1 {
      if haystack[pos + i] != needle[i] {
        matches = false
        break
      }
    }
    if matches {
      count = count + 1
      pos = pos + needle_len
    } else {
      pos = pos + 1
    }
  }

  count
}
