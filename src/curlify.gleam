import gleam/bit_array
import gleam/function
import gleam/http
import gleam/http/request
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

/// Escape a string for POSIX shell using single quotes.
/// Inside single quotes, everything is literal except ' itself.
/// To include a literal ': close quote, add \', open quote again.
@internal
pub fn shell_escape(input: String) -> String {
  "'" <> string.replace(input, "'", "'\\''") <> "'"
}

/// Request body variants. Text and Json both render as `--data`
/// in the curl command; Form renders as one or more `--data-urlencode`.
pub type Body {
  Empty
  Text(String)
  Json(String)
  Form(List(#(String, String)))
}

/// Errors that can occur when working with curl strings or requests.
pub type CurlParseError {
  /// The curl command had no URL positional argument.
  MissingUrl
  /// The URL parsed from the curl command could not be used to
  /// construct a valid Request (e.g. malformed scheme).
  RequestBuildError
  /// The curl command used an HTTP method that is not recognized
  /// by `gleam/http` (e.g. `-XWHATEVER`).
  UnknownHttpMethod(method: String)
}

/// Accumulated state for rendering a curl command.
/// HTTP-level fields plus common curl options.
pub type Curl {
  Curl(
    method: http.Method,
    url: String,
    headers: List(http.Header),
    body: Body,
    follow_redirects: Bool,
    verbose: Bool,
    insecure: Bool,
    compressed: Bool,
    timeout: Int,
    basic_auth: Option(#(String, String)),
  )
}

/// Build a Curl from a gleam_http Request.
/// If the request has an `Authorization: Basic` header, it is decoded
/// and stored in `basic_auth`, and the header is removed from the list
/// to avoid redundancy when rendering the curl command.
pub fn from_request(req: request.Request(String)) -> Curl {
  let body = case req.body {
    "" -> Empty
    body_content -> Text(body_content)
  }

  let #(basic_auth, headers) = extract_basic_auth(req.headers)

  Curl(
    method: req.method,
    url: build_request_url(req),
    headers: headers,
    body: body,
    follow_redirects: False,
    verbose: False,
    insecure: False,
    compressed: False,
    timeout: 0,
    basic_auth: basic_auth,
  )
}

/// Create a Curl from a URL string. The URL is stored as-is and
/// validated later if `to_request` is called.
pub fn from_url(url: String) -> Curl {
  Curl(
    method: http.Get,
    url: url,
    headers: [],
    body: Empty,
    follow_redirects: False,
    verbose: False,
    insecure: False,
    compressed: False,
    timeout: 0,
    basic_auth: None,
  )
}

/// Create a Curl from a `gleam/uri` Uri.
pub fn from_uri(u: uri.Uri) -> Curl {
  from_url(uri.to_string(u))
}

/// If the headers contain an `authorization: Basic <base64>` entry,
/// decode it into a `(user, password)` pair and remove the header.
fn extract_basic_auth(
  headers: List(http.Header),
) -> #(Option(#(String, String)), List(http.Header)) {
  case list.key_pop(headers, "authorization") {
    Ok(#(value, filtered)) -> {
      case string.starts_with(string.lowercase(value), "basic ") {
        True -> {
          let encoded = string.drop_start(value, 6)
          let auth = case bit_array.base64_decode(encoded) {
            Ok(bytes) ->
              case bit_array.to_string(bytes) {
                Ok(decoded) ->
                  case string.split_once(decoded, ":") {
                    Ok(#(u, p)) -> Some(#(u, p))
                    Error(Nil) -> Some(#(decoded, ""))
                  }
                Error(Nil) -> None
              }
            Error(Nil) -> None
          }
          #(auth, filtered)
        }
        False -> #(None, headers)
      }
    }
    Error(_) -> #(None, headers)
  }
}

fn build_request_url(req: request.Request(a)) -> String {
  req
  |> request.to_uri()
  |> uri.to_string
}

/// Set the body of a Curl.
pub fn set_body(curl: Curl, body: Body) -> Curl {
  Curl(..curl, body: body)
}

/// Follow HTTP redirects (`-L`).
pub fn set_follow_redirects(curl: Curl) -> Curl {
  Curl(..curl, follow_redirects: True)
}

/// Enable verbose output (`-v`).
pub fn set_verbose(curl: Curl) -> Curl {
  Curl(..curl, verbose: True)
}

/// Skip TLS certificate verification (`-k`).
pub fn set_insecure(curl: Curl) -> Curl {
  Curl(..curl, insecure: True)
}

/// Request a compressed response (`--compressed`).
pub fn set_compressed(curl: Curl) -> Curl {
  Curl(..curl, compressed: True)
}

/// Set a maximum transfer time in seconds (`--max-time`).
pub fn set_timeout(curl: Curl, seconds: Int) -> Curl {
  Curl(..curl, timeout: seconds)
}

/// Set HTTP basic authentication credentials (`-u username:password`).
pub fn set_basic_auth(curl: Curl, username: String, password: String) -> Curl {
  Curl(..curl, basic_auth: Some(#(username, password)))
}

/// Set a header on a Curl. Replaces any existing header with the same key.
pub fn set_header(curl: Curl, key: String, value: String) -> Curl {
  Curl(..curl, headers: list.key_set(curl.headers, key, value))
}

/// Set the HTTP method on a Curl.
pub fn set_method(curl: Curl, method: http.Method) -> Curl {
  Curl(..curl, method: method)
}

/// Render the complete curl command string from a Curl struct.
/// The output is safe for copy-paste into a POSIX shell.
///
/// Example output:
///
/// ```curl -X POST -H 'content-type: application/json' --data '{...}' 'https://example.com'```
pub fn to_string(curl: Curl) -> String {
  [
    "curl",
    ..to_arguments(curl, shell_escape)
    |> list.flatten
  ]
  |> string.join(" ")
}

/// Indentation string used by `to_pretty_string`. Change this to
/// adjust the indent level of continuation lines.
const pretty_indent: String = "  "

/// Render a multi-line curl command with backslash continuation.
/// Each flag goes on its own line for readability.
///
/// Example:
/// ```text
///   curl -X POST \
///     -H 'content-type: application/json' \
///     --data '{...}' \
///     'https://example.com'
/// ```
pub fn to_pretty_string(curl: Curl) -> String {
  let args =
    to_arguments(curl, shell_escape)
    |> list.map(string.join(_, " "))
    |> string.join(" \\\n" <> pretty_indent)

  "curl " <> args
}

fn bool_flag(name: String, value: Bool) -> List(String) {
  flag_if(value, [name])
}

fn string_flag(name: a, value: a) -> List(a) {
  [name, value]
}

fn int_flag(name: String, value: Int) -> List(String) {
  [name, int.to_string(value)]
}

fn positional_flag(value: a) -> List(a) {
  [value]
}

fn flag_if(predicate: Bool, flags: List(a)) -> List(a) {
  case predicate {
    True -> flags
    False -> []
  }
}

/// Build a list of argument groups that can be flattened into a
/// curl command. Shared by `to_string`, `to_args`, and `to_pretty_string`.
/// The `shell_escape` parameter controls whether values are escaped
/// (pass `shell_escape` for display output, `function.identity` for raw args).
fn to_arguments(
  curl: Curl,
  shell_escape: fn(String) -> String,
) -> List(List(String)) {
  [
    [
      flag_if(
        curl.method != http.Get,
        string_flag("-X", case curl.method {
          http.Other(m) -> shell_escape(m)
          _ -> http.method_to_string(curl.method)
        }),
      ),
    ],
    list.map(curl.headers, fn(header) {
      let #(key, value) = header
      string_flag("-H", shell_escape(key <> ": " <> value))
    }),

    case curl.body {
      Empty -> []
      Text(content) | Json(content) -> [
        string_flag("--data", shell_escape(content)),
      ]
      Form(fields) -> {
        list.map(fields, fn(field) {
          let #(key, value) = field
          string_flag("--data-urlencode", shell_escape(key <> "=" <> value))
        })
      }
    },
    [bool_flag("--verbose", curl.verbose)],
    case curl.basic_auth {
      None -> []
      Some(#(u, p)) -> [string_flag("--user", shell_escape(u <> ":" <> p))]
    },
    [bool_flag("--insecure", curl.insecure)],
    [bool_flag("--compressed", curl.compressed)],
    [flag_if(curl.timeout > 0, int_flag("--max-time", curl.timeout))],
    [bool_flag("--location", curl.follow_redirects)],
    [positional_flag(shell_escape(curl.url))],
  ]
  |> list.flatten
  |> list.filter(fn(x) { x != [] })
}

/// Return the curl arguments as a raw list of strings, without
/// shell escaping. Each element is a single argument suitable for
/// passing to exec or a subprocess.
///
/// Example:
///
/// ```
/// to_args(curlify)  →  ["-X", "POST", "-H", "content-type: application/json", ...]
/// to_string(curlify) → "curl -XPOST -H 'content-type: application/json' ..."
/// ```
pub fn to_args(curl: Curl) -> List(String) {
  to_arguments(curl, function.identity)
  |> list.flatten
}

/// Convert a gleam_http Request directly into a curl command string.
///
/// Equivalent to `from_request(req) |> to_string`.
pub fn request_to_curl(req: request.Request(String)) -> String {
  req |> from_request |> to_string
}

// ── Convert a Curl back to a gleam_http Request ──────────

/// Convert a Body value back into a raw request body string.
/// Form fields are URL-encoded and joined with `&`.
fn body_to_request_string(body: Body) -> String {
  case body {
    Empty -> ""
    Text(content) | Json(content) -> content
    Form(fields) -> uri.query_to_string(fields)
  }
}

/// The inverse of `from_request`. Reconstructs a `gleam/http/request.Request`
/// from the HTTP-relevant fields of a Curl. If the Curl has `basic_auth`
/// set, an `Authorization: Basic` header is added.
pub fn to_request(curl: Curl) -> Result(request.Request(String), Nil) {
  use req <- result.try(request.to(curl.url))

  let req = req |> request.set_method(curl.method)

  let req = case curl.basic_auth {
    None -> req
    Some(#(u, p)) -> {
      let credentials = u <> ":" <> p
      let encoded =
        bit_array.base64_encode(bit_array.from_string(credentials), True)
      request.set_header(req, "authorization", "Basic " <> encoded)
    }
  }

  let req =
    list.fold(curl.headers, req, fn(req, header) {
      let #(key, value) = header
      request.set_header(req, key, value)
    })

  Ok(request.set_body(req, body_to_request_string(curl.body)))
}

// ── Parse a curl command string into a Curl ──────────────

/// Tokenizer state: tracks whether we are inside shell quotes
/// so that whitespace and special characters are handled correctly.
type TokenizeState {
  Normal
  SingleQuote
  DoubleQuote
  Escape
}

/// Shell-style tokenizer: splits a command string into a list
/// of individual arguments, respecting POSIX quoting rules.
///
/// Handles:
///   - Single quotes:   'everything literal'
///   - Double quotes:   "escaped: \" \\ "
///   - Backslash:        \  next char treated literally
///   - Whitespace:       delimits tokens (outside quotes only)
fn tokenize(input: String) -> List(String) {
  tokenize_chars(string.to_graphemes(input), [], [], Normal)
}

/// Walk the grapheme list character by character, maintaining
/// the current token buffer and a state machine for quote handling.
/// Completed tokens are prepended to the output list (reversed at the end).
fn tokenize_chars(
  chars: List(String),
  tokens: List(String),
  current: List(String),
  state: TokenizeState,
) -> List(String) {
  case chars {
    [] -> {
      let tokens = case current {
        [] -> tokens
        _ -> [string.concat(list.reverse(current)), ..tokens]
      }
      list.reverse(tokens)
    }
    [char, ..rest] -> {
      case state, char {
        Normal, " " | Normal, "\t" -> {
          tokenize_chars(
            rest,
            case current {
              [] -> tokens
              _ -> [string.concat(list.reverse(current)), ..tokens]
            },
            [],
            Normal,
          )
        }
        Normal, "'" -> tokenize_chars(rest, tokens, current, SingleQuote)
        Normal, "\"" -> tokenize_chars(rest, tokens, current, DoubleQuote)
        Normal, "\\" -> tokenize_chars(rest, tokens, current, Escape)
        Normal, _ -> tokenize_chars(rest, tokens, [char, ..current], Normal)
        SingleQuote, "'" -> tokenize_chars(rest, tokens, current, Normal)
        SingleQuote, _ ->
          tokenize_chars(rest, tokens, [char, ..current], SingleQuote)
        DoubleQuote, "\"" -> tokenize_chars(rest, tokens, current, Normal)
        DoubleQuote, "\\" ->
          case rest {
            [] -> tokenize_chars(rest, tokens, current, Normal)
            [next, ..after] ->
              tokenize_chars(after, tokens, [next, ..current], DoubleQuote)
          }
        DoubleQuote, _ ->
          tokenize_chars(rest, tokens, [char, ..current], DoubleQuote)
        Escape, _ -> tokenize_chars(rest, tokens, [char, ..current], Normal)
      }
    }
  }
}

/// Split a `key=value` form pair on the first `=`.
/// If no `=` is present, the whole string is the key with an empty value.
fn parse_form_pair(input: String) -> #(String, String) {
  case string.split_once(input, "=") {
    Ok(#(key, value)) -> #(key, value)
    Error(_) -> #(input, "")
  }
}

/// Convert a list of shell-tokenized arguments into a Curl struct.
/// Starts with a default Curl, then walks tokens via `parse_tokens_loop`.
/// The URL comes from the first positional argument; headers are reversed
/// at the end (they were collected in reverse order by prepending).
fn parse_args(tokens: List(String)) -> Result(Curl, CurlParseError) {
  let initial =
    Curl(
      method: http.Get,
      url: "",
      headers: [],
      body: Empty,
      follow_redirects: False,
      verbose: False,
      insecure: False,
      compressed: False,
      timeout: 0,
      basic_auth: None,
    )

  use #(curl, positional) <- result.try(parse_args_loop(tokens, initial, []))

  let url = case positional {
    [u, ..] -> Ok(u)
    _ -> Error(MissingUrl)
  }
  use url <- result.try(url)

  Ok(Curl(..curl, url: url, headers: list.reverse(curl.headers)))
}

/// Recursive token walker. Each known flag pattern matches and updates the
/// Curl struct via record update. Combined short flags like `-XPOST` have
/// explicit patterns. Unknown tokens starting with `-` are silently dropped.
/// All other tokens are collected as positional (the first becomes the URL).
fn parse_args_loop(
  tokens: List(String),
  curl: Curl,
  positional: List(String),
) -> Result(#(Curl, List(String)), CurlParseError) {
  case tokens {
    [] -> Ok(#(curl, positional))
    ["-X", method, ..rest]
    | ["--request", method, ..rest]
    | ["-X" <> method, ..rest] ->
      case http.parse_method(method) {
        Ok(method) -> parse_args_loop(rest, Curl(..curl, method:), positional)
        Error(_) -> Error(UnknownHttpMethod(method))
      }

    ["-H", value, ..rest] | ["--header", value, ..rest] -> {
      let header = case string.split_once(value, ":") {
        Ok(#(k, v)) -> #(string.lowercase(string.trim(k)), string.trim(v))
        Error(_) -> #(value, "")
      }
      parse_args_loop(
        rest,
        Curl(..curl, headers: [header, ..curl.headers]),
        positional,
      )
    }

    ["-d", value, ..rest]
    | ["--data", value, ..rest]
    | ["--data-raw", value, ..rest]
    | ["--data-binary", value, ..rest] ->
      parse_args_loop(rest, Curl(..curl, body: Text(value)), positional)

    ["--json", value, ..rest] ->
      parse_args_loop(rest, Curl(..curl, body: Json(value)), positional)

    ["--data-urlencode", value, ..rest] -> {
      let pair = parse_form_pair(value)
      let body = case curl.body {
        Form(fields) -> Form(list.append(fields, [pair]))
        _ -> Form([pair])
      }
      parse_args_loop(rest, Curl(..curl, body: body), positional)
    }

    ["-L", ..rest] | ["--location", ..rest] ->
      parse_args_loop(rest, Curl(..curl, follow_redirects: True), positional)

    ["-v", ..rest] | ["--verbose", ..rest] ->
      parse_args_loop(rest, Curl(..curl, verbose: True), positional)

    ["-k", ..rest] | ["--insecure", ..rest] ->
      parse_args_loop(rest, Curl(..curl, insecure: True), positional)

    ["--compressed", ..rest] ->
      parse_args_loop(rest, Curl(..curl, compressed: True), positional)

    ["--max-time", value, ..rest] -> {
      let timeout = case int.parse(value) {
        Ok(n) -> n
        Error(_) -> curl.timeout
      }
      parse_args_loop(rest, Curl(..curl, timeout: timeout), positional)
    }

    ["-u", value, ..rest] | ["--user", value, ..rest] -> {
      let basic_auth = case string.split_once(value, ":") {
        Ok(#(u, p)) -> Some(#(u, p))
        Error(_) -> Some(#(value, ""))
      }
      parse_args_loop(rest, Curl(..curl, basic_auth: basic_auth), positional)
    }

    [token, ..rest] -> {
      case string.starts_with(token, "-") {
        True -> parse_args_loop(rest, curl, positional)
        False -> parse_args_loop(rest, curl, [token, ..positional])
      }
    }
  }
}

/// Parse a curl command string into a `Curl` struct.
///
/// Supported flags:
/// - -X/--request
/// - -H/--header
/// - -d/--data
/// - --data-raw
/// - --data-binary
/// - --json
/// - --data-urlencode,
/// - -L/--location
/// - -v/--verbose
/// - -k/--insecure
/// - --compressed,
/// - --max-time
/// - -u/--user.
///
/// Unsupported flags are silently dropped.
///
/// The input string is first tokenized using POSIX shell quoting
/// rules (single quotes, double quotes, backslash), then parsed
/// directly into a `Curl` struct. Returns an error if the URL
/// is missing.
pub fn parse(input: String) -> Result(Curl, CurlParseError) {
  parse_args(case tokenize(input) {
    ["curl", ..rest] -> rest
    tokens -> tokens
  })
}

/// Parse a curl command string and convert the result directly
/// into a gleam_http Request.
///
/// Equivalent to `parse(input) |> result.try(to_request(?))`.
/// Returns `Error(RequestBuildError)` if the parsed URL cannot be
/// used to construct a Request.
pub fn curl_to_request(
  input: String,
) -> Result(request.Request(String), CurlParseError) {
  use curlify <- result.try(parse(input))
  let result = to_request(curlify)
  result.map_error(result, fn(_) { RequestBuildError })
}
