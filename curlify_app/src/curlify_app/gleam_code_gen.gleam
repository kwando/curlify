import curlify
import gleam/bool
import gleam/dict
import gleam/float
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import json_value

pub type Options {
  Options(inline_body: Bool, parse_json: Bool, imports: Bool)
}

/// Generate Gleam source code that reconstructs this Curl as a
/// `gleam_http` request. The output can be pasted into the body of a
/// Gleam function.
///
/// No import are generated.
///
/// The usefulness of this function is debatable.. but here it is anyways.
pub fn to_gleam(curl: curlify.Curl, options: Options) -> Result(String, Nil) {
  use req <- result.try(curlify.to_request(curl))
  let url = gleam_escape(curl.url)

  "let assert Ok(req) = request.to($url)
$let_body
req$set_method$set_headers$set_body"
  |> string.replace("$url", url)
  |> string.replace("$set_method", case req.method {
    http.Get -> ""
    http.Post -> "\n|> request.set_method(http.Post)"
    http.Head -> "\n|> request.set_method(http.Head)"
    http.Put -> "\n|> request.set_method(http.Put)"
    http.Delete -> "\n|> request.set_method(http.Delete)"
    http.Trace -> "\n|> request.set_method(http.Trace)"
    http.Connect -> "\n|> request.set_method(http.Connect)"
    http.Options -> "\n|> request.set_method(http.Options)"
    http.Patch -> "\n|> request.set_method(http.Patch)"
    http.Other(other) ->
      "\n|> request.set_method(http.Other(" <> gleam_escape(other) <> "))"
  })
  |> string.replace("$headers", case req.headers {
    [] -> "[]"
    _ -> string.inspect(req.headers)
  })
  |> string.replace("$set_body", case curl.body {
    curlify.Empty -> ""
    _ ->
      "\n|> request.set_body("
      <> case options.inline_body {
        True -> "$body"
        False -> "body"
      }
      <> ")"
  })
  |> string.replace(
    "$set_headers",
    req.headers
      |> list.map(fn(header) {
        "\n|> request.set_header("
        <> gleam_escape(header.0)
        <> ", "
        <> gleam_escape(header.1)
        <> ")"
      })
      |> string.concat,
  )
  |> string.replace("$let_body", case curl.body, options.inline_body {
    curlify.Empty, _ | _, True -> ""
    _, False -> "let body = $body\n"
  })
  |> string.replace("$body", body_to_gleam_literal(curl.body, options))
  |> string.remove_suffix("\nreq")
  |> Ok
}

fn gleam_escape(input: String) -> String {
  "\""
  <> input
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
  <> "\""
}

fn body_to_gleam_literal(body: curlify.Body, options: Options) {
  case body {
    curlify.Empty -> ""
    curlify.Json(json_str) -> {
      case options.parse_json {
        True ->
          case json.parse(json_str, json_value.decoder()) {
            Ok(value) ->
              json_value_to_json_string(value) <> " |> json.to_string"
            Error(_) -> gleam_escape(json_str)
          }
        False -> gleam_escape(json_str)
      }
    }
    curlify.Text(text) -> gleam_escape(text)
    curlify.Form(form) -> gleam_escape(uri.query_to_string(form))
  }
}

type ArrayClass {
  Empty
  PreprocessedArray
  Array(literals: List(String), kind: String)
}

fn classify_array(values: List(json_value.JsonValue)) {
  case values {
    [] -> Empty
    [value, ..values] ->
      case gleam_literal(value) {
        Error(_) -> PreprocessedArray
        Ok(#(literal, kind)) -> classify_array_loop(values, kind, [literal])
      }
  }
}

fn gleam_literal(value: json_value.JsonValue) {
  case value {
    json_value.Null -> Error(Nil)
    json_value.String(value) -> Ok(#(gleam_escape(value), "json.string"))
    json_value.Int(value) -> Ok(#(int.to_string(value), "json.int"))
    json_value.Bool(value) -> Ok(#(bool.to_string(value), "json.bool"))
    json_value.Float(value) -> Ok(#(float.to_string(value), "json.float"))
    json_value.Array(_) -> Error(Nil)
    json_value.Object(_) -> Error(Nil)
  }
}

fn classify_array_loop(values, expected, literals) {
  case values {
    [] -> Array(list.reverse(literals), expected)
    [value, ..values] -> {
      case gleam_literal(value) {
        Ok(#(literal, kind)) if kind == expected ->
          classify_array_loop(values, kind, [literal, ..literals])
        Error(_) | Ok(_) -> PreprocessedArray
      }
    }
  }
}

pub fn json_value_to_json_string(value: json_value.JsonValue) -> String {
  case value {
    json_value.Null -> "json.null()"
    json_value.String(value) -> "json.string(" <> gleam_escape(value) <> ")"
    json_value.Int(value) -> "json.int(" <> int.to_string(value) <> ")"
    json_value.Bool(value) -> "json.bool(" <> bool.to_string(value) <> ")"
    json_value.Float(value) -> "json.float(" <> float.to_string(value) <> ")"
    json_value.Array(values) ->
      case classify_array(values) {
        Empty -> "json.preprocessed_array([])"
        PreprocessedArray ->
          "json.preprocessed_array(["
          <> values |> list.map(json_value_to_json_string) |> string.join(", ")
          <> "])"
        Array(literals, kind) ->
          "json.array([" <> string.join(literals, ", ") <> "], " <> kind <> ")"
      }
    json_value.Object(object) -> {
      case dict.is_empty(object) {
        True -> "json.object([])"
        False ->
          dict.fold(object, "json.object([", fn(acc, key, value) {
            acc
            <> "#("
            <> gleam_escape(key)
            <> ", "
            <> json_value_to_json_string(value)
            <> "), "
          })
          |> string.remove_suffix(", ")
          <> "])"
      }
    }
  }
}
