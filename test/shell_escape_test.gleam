import curlify
import gleeunit/should

// Shell escaping tests
pub fn shell_escape_simple_strings_test() {
  // All strings are wrapped in single quotes for consistency and simplicity
  curlify.shell_escape("hello") |> should.equal("'hello'")
  curlify.shell_escape("Hello_World-123") |> should.equal("'Hello_World-123'")
  curlify.shell_escape("/api/v1/users") |> should.equal("'/api/v1/users'")
  curlify.shell_escape("key=value&foo=bar")
  |> should.equal("'key=value&foo=bar'")
  curlify.shell_escape("user@example.com") |> should.equal("'user@example.com'")
}

pub fn shell_escape_empty_string_test() {
  // Empty string needs explicit empty quotes
  curlify.shell_escape("") |> should.equal("''")
}

pub fn shell_escape_with_spaces_test() {
  // Strings with spaces need single quotes
  curlify.shell_escape("hello world") |> should.equal("'hello world'")
}

pub fn shell_escape_with_single_quotes_test() {
  // Single quotes need special escaping: close quote, add \\', open quote
  curlify.shell_escape("can't") |> should.equal("'can'\\''t'")
  curlify.shell_escape("it's a test") |> should.equal("'it'\\''s a test'")
}

pub fn shell_escape_with_special_chars_test() {
  // Various special characters need quoting
  curlify.shell_escape("hello$world") |> should.equal("'hello$world'")
  curlify.shell_escape("test|pipe") |> should.equal("'test|pipe'")
  curlify.shell_escape("foo;bar") |> should.equal("'foo;bar'")
  curlify.shell_escape("a&b") |> should.equal("'a&b'")
  curlify.shell_escape("x<y") |> should.equal("'x<y'")
  curlify.shell_escape("x>y") |> should.equal("'x>y'")
}

pub fn shell_escape_edge_cases_test() {
  // Single quote only
  curlify.shell_escape("'") |> should.equal("''\\'''")
  // Backslash is not safe, should be quoted but not escaped inside single quotes
  curlify.shell_escape("foo\\bar") |> should.equal("'foo\\bar'")
  // Control characters should be preserved inside quotes
  curlify.shell_escape("line1\nline2") |> should.equal("'line1\nline2'")
  curlify.shell_escape("col1\tcol2") |> should.equal("'col1\tcol2'")
}

pub fn shell_escape_multiple_single_quotes_test() {
  // Multiple single quotes in sequence: '' -> '\'''\''  wrapped -> ''\'''\'''
  curlify.shell_escape("''") |> should.equal("''\\'''\\'''")
  // Single quotes at start and end
  curlify.shell_escape("'hello'") |> should.equal("''\\''hello'\\'''")
  // Single quotes with spaces
  curlify.shell_escape("it's Bob's") |> should.equal("'it'\\''s Bob'\\''s'")
}

pub fn shell_escape_unicode_test() {
  // Basic unicode characters
  curlify.shell_escape("hello 世界") |> should.equal("'hello 世界'")
  // Emoji (single codepoint)
  curlify.shell_escape("test 🚀 rocket") |> should.equal("'test 🚀 rocket'")
  // Emoji with ZWJ (multi-codepoint grapheme cluster)
  curlify.shell_escape("family: 👨‍👩‍👧‍👦") |> should.equal("'family: 👨‍👩‍👧‍👦'")
  // Flag emoji (regional indicators)
  curlify.shell_escape("flag: 🇺🇸") |> should.equal("'flag: 🇺🇸'")
  // Emoji with skin tone modifier
  curlify.shell_escape("wave: 👋🏽") |> should.equal("'wave: 👋🏽'")
}

pub fn shell_escape_strings_starting_with_dash_test() {
  // All strings are quoted, including those starting with dashes
  curlify.shell_escape("-abc") |> should.equal("'-abc'")
  curlify.shell_escape("--flag") |> should.equal("'--flag'")
  curlify.shell_escape("-e 'malicious'")
  |> should.equal("'-e '\\''malicious'\\'''")
}

pub fn shell_escape_long_strings_test() {
  // Long string (all strings are quoted)
  let long_str =
    "abcdefghijklmnopqrstuvwxyz0123456789_-./abcdefghijklmnopqrstuvwxyz0123456789_-./"
  curlify.shell_escape(long_str) |> should.equal("'" <> long_str <> "'")
  // Long string with many quotes
  let long_with_quotes =
    "it's a long string with 'many' quotes and 'more' quotes"
  curlify.shell_escape(long_with_quotes)
  |> should.equal(
    "'it'\\''s a long string with '\\''many'\\'' quotes and '\\''more'\\'' quotes'",
  )
}

pub fn shell_escape_json_payloads_test() {
  // Typical JSON payload
  curlify.shell_escape("{\"name\": \"test\", \"value\": 123}")
  |> should.equal("'{\"name\": \"test\", \"value\": 123}'")
  // JSON with nested quotes
  curlify.shell_escape("{\"message\": \"it's working\"}")
  |> should.equal("'{\"message\": \"it'\\''s working\"}'")
  // JSON array
  curlify.shell_escape("[1, 2, 3]") |> should.equal("'[1, 2, 3]'")
}

pub fn shell_escape_url_components_test() {
  // URL with query params
  curlify.shell_escape("https://example.com/path?foo=bar&baz=qux")
  |> should.equal("'https://example.com/path?foo=bar&baz=qux'")
  // URL with fragment
  curlify.shell_escape("https://example.com/page#section")
  |> should.equal("'https://example.com/page#section'")
  // URL with auth (contains @)
  curlify.shell_escape("https://user:pass@example.com")
  |> should.equal("'https://user:pass@example.com'")
  // URL with percent encoding
  curlify.shell_escape("https://example.com/path%20with%20spaces")
  |> should.equal("'https://example.com/path%20with%20spaces'")
}

pub fn shell_escape_shell_injection_attempts_test() {
  // Command substitution attempts
  curlify.shell_escape("$(whoami)") |> should.equal("'$(whoami)'")
  curlify.shell_escape("`whoami`") |> should.equal("'`whoami`'")
  // Variable expansion attempts
  curlify.shell_escape("$HOME") |> should.equal("'$HOME'")
  curlify.shell_escape("${HOME}") |> should.equal("'${HOME}'")
  // Subshell attempts
  curlify.shell_escape("$(cat /etc/passwd)")
  |> should.equal("'$(cat /etc/passwd)'")
  // Pipe and redirect attempts
  curlify.shell_escape("test | cat /etc/passwd")
  |> should.equal("'test | cat /etc/passwd'")
  curlify.shell_escape("test > /tmp/evil") |> should.equal("'test > /tmp/evil'")
  curlify.shell_escape("test < /etc/passwd")
  |> should.equal("'test < /etc/passwd'")
  // Semicolon command chaining
  curlify.shell_escape("test; rm -rf /") |> should.equal("'test; rm -rf /'")
  // Background execution
  curlify.shell_escape("test & evil") |> should.equal("'test & evil'")
}

pub fn shell_escape_whitespace_variants_test() {
  // Various whitespace characters
  curlify.shell_escape("a\tb") |> should.equal("'a\tb'")
  curlify.shell_escape("a\nb") |> should.equal("'a\nb'")
  curlify.shell_escape("a\rb") |> should.equal("'a\rb'")
  // Multiple spaces
  curlify.shell_escape("a   b") |> should.equal("'a   b'")
  // Leading/trailing whitespace
  curlify.shell_escape(" leading") |> should.equal("' leading'")
  curlify.shell_escape("trailing ") |> should.equal("'trailing '")
  curlify.shell_escape(" both ") |> should.equal("' both '")
}
