import gleam/http
import gleam/http/request
import gleam/list
import gleam/string
import gleam/uri

pub type Options(a) {
  Options(body: fn(a) -> String)
}

pub fn default_options() {
  Options(fn(a) { a })
}

// Generates a curl command for the given request
pub fn to_curl(req: request.Request(String)) -> String {
  to_curl_with_options(req, default_options())
}

pub fn to_curl_with_options(
  req: request.Request(a),
  options: Options(a),
) -> String {
  "curl"
  <> method_to_string(req.method)
  <> build_headers(req)
  <> build_body(req, options.body)
  <> " "
  <> build_url(req)
}

fn build_body(req: request.Request(a), body_fun: fn(a) -> String) {
  case body_fun(req.body) {
    "" -> ""
    body -> " --data " <> string.inspect(body)
  }
}

fn build_url(req) {
  req
  |> request.to_uri()
  |> uri.to_string
  |> string.inspect
}

fn build_headers(req: request.Request(a)) {
  list.fold(req.headers, "", fn(acc, header) {
    let #(key, value) = header

    acc <> " -H " <> string.inspect(key <> ": " <> value)
  })
}

fn method_to_string(method: http.Method) {
  case method {
    http.Get -> ""
    _ -> " -X" <> http.method_to_string(method) |> string.uppercase()
  }
}
