import birdie
import curlify
import gleam/http
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import gleam/uri
import gleeunit

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn from_request_basic_test() {
  let assert Ok(req) = request.to("https://example.org/api/users")
  let req = req |> request.set_header("Accept", "application/json")

  let curlify = curlify.from_request(req)

  assert curlify.method == http.Get
  assert curlify.url == "https://example.org/api/users"
  assert curlify.body == curlify.Empty
  assert curlify.follow_redirects == False
  assert curlify.verbose == False
  assert curlify.insecure == False
  assert curlify.compressed == False
  assert curlify.timeout == 0
  assert curlify.basic_auth == None
}

pub fn from_request_with_body_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body("{\"name\": \"test\"}")

  let curlify = curlify.from_request(req)

  assert curlify.method == http.Post
  assert curlify.body == curlify.Text("{\"name\": \"test\"}")
}

pub fn from_request_with_basic_auth_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_header("authorization", "Basic YWRtaW46c2VjcmV0")

  let curlify = curlify.from_request(req)

  assert curlify.basic_auth == Some(#("admin", "secret"))
  // The Authorization header should be removed from headers
  assert curlify.headers == []
}

pub fn from_url_test() {
  let c = curlify.from_url("https://api.example.com/users")

  assert c.method == http.Get
  assert c.url == "https://api.example.com/users"
  assert c.body == curlify.Empty
  assert c.basic_auth == None
}

pub fn from_uri_test() {
  let assert Ok(parsed) = uri.parse("https://api.example.com/users")

  let c = curlify.from_uri(parsed)

  assert c.method == http.Get
  assert c.url == "https://api.example.com/users"
  assert c.body == curlify.Empty
  assert c.basic_auth == None
}

pub fn body_setter_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req)

  let with_json = curlify.set_body(c, curlify.Json("{\"id\": 123}"))
  assert with_json.body == curlify.Json("{\"id\": 123}")

  let with_form = curlify.set_body(c, curlify.Form([#("key", "value")]))
  assert with_form.body == curlify.Form([#("key", "value")])
}

pub fn follow_redirects_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req) |> curlify.set_follow_redirects()
  assert c.follow_redirects == True
}

pub fn with_verbose_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req) |> curlify.set_verbose()
  assert c.verbose == True
}

pub fn with_insecure_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req) |> curlify.set_insecure()
  assert c.insecure == True
}

pub fn with_compressed_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req) |> curlify.set_compressed()
  assert c.compressed == True
}

pub fn with_timeout_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req) |> curlify.set_timeout(30)
  assert c.timeout == 30
}

pub fn basic_auth_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let c = curlify.from_request(req) |> curlify.set_basic_auth("admin", "secret")
  assert c.basic_auth == Some(#("admin", "secret"))
}

pub fn body_to_string_empty_test() {
  let result = curlify.from_request(request.new())
  assert result.body == curlify.Empty
}

pub fn body_to_string_text_test() {
  let assert Ok(req) = request.to("https://example.org/api")
  let req = req |> request.set_body("Hello World")

  let result = curlify.from_request(req)
  assert result.body == curlify.Text("Hello World")
}

pub fn to_string_get_request_test() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  let result = curlify.from_request(req) |> curlify.to_string()

  assert result == "curl 'https://api.example.com/users'"
}

pub fn to_string_post_with_body_test() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body("{\"name\": \"test\"}")

  let result = curlify.from_request(req) |> curlify.to_string()

  assert result
    == "curl -X POST --data '{\"name\": \"test\"}' 'https://api.example.com/users'"
}

pub fn to_string_with_json_body_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req = req |> request.set_method(http.Post)

  let result =
    curlify.from_request(req)
    |> curlify.set_body(curlify.Json("{\"key\": \"value\"}"))
    |> curlify.to_string()

  assert result
    == "curl -X POST --data '{\"key\": \"value\"}' 'https://api.example.com/data'"
}

pub fn to_string_with_form_body_test() {
  let assert Ok(req) = request.to("https://api.example.com/submit")
  let req = req |> request.set_method(http.Post)

  let result =
    curlify.from_request(req)
    |> curlify.set_body(curlify.Form([#("name", "John"), #("age", "30")]))
    |> curlify.to_string()

  assert result
    == "curl -X POST --data-urlencode 'name=John' --data-urlencode 'age=30' 'https://api.example.com/submit'"
}

pub fn to_string_complex_request_test() {
  let assert Ok(req) = request.to("https://api.example.com/users?page=1")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer token123")
    |> request.set_header("content-type", "application/json")

  let result =
    curlify.from_request(req)
    |> curlify.set_body(curlify.Json("{\"name\": \"test\"}"))
    |> curlify.to_string()

  assert result
    == "curl -X POST -H 'authorization: Bearer token123' -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://api.example.com/users?page=1'"
}

pub fn to_string_with_options_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")

  let result =
    curlify.from_request(req)
    |> curlify.set_verbose()
    |> curlify.set_basic_auth("admin", "secret")
    |> curlify.set_insecure()
    |> curlify.set_compressed()
    |> curlify.set_timeout(30)
    |> curlify.set_follow_redirects()
    |> curlify.to_string()

  assert result
    == "curl --verbose --user 'admin:secret' --insecure --compressed --max-time 30 --location 'https://api.example.com/data'"
}

pub fn to_pretty_string_get_test() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  let result = curlify.from_request(req) |> curlify.to_pretty_string()
  // No flags → single line, same as to_string
  assert result == "curl 'https://api.example.com/users'"
}

pub fn to_pretty_string_post_with_headers_snapshot_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body("{\"name\": \"test\"}")

  curlify.from_request(req)
  |> curlify.to_pretty_string()
  |> birdie.snap(title: "pretty string post with headers")
}

pub fn to_pretty_string_with_options_snapshot_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")

  curlify.from_request(req)
  |> curlify.set_verbose()
  |> curlify.set_basic_auth("admin", "secret")
  |> curlify.set_insecure()
  |> curlify.set_compressed()
  |> curlify.set_timeout(30)
  |> curlify.set_follow_redirects()
  |> curlify.to_pretty_string()
  |> birdie.snap(title: "pretty string with all options")
}

pub fn hello_world_test() {
  let assert Ok(req) = request.to("https://example.org/foo/bar?wibble=wobble")

  assert curlify.from_request(req)
    |> curlify.to_string()
    == "curl 'https://example.org/foo/bar?wibble=wobble'"

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "text/plain")
    |> request.set_header("accept", "application/json")
    |> request.set_body("{\"foo\": \"bar\"}")
    |> request.set_query([#("mish", "mash")])

  let str = curlify.from_request(req) |> curlify.to_string()
  assert str
    == "curl -X POST -H 'content-type: text/plain' -H 'accept: application/json' --data '{\"foo\": \"bar\"}' 'https://example.org/foo/bar?mish=mash'"

  let assert Ok(req) = curlify.curl_to_request(str)
  assert req.query == Some("mish=mash")
}

pub fn to_request_basic_auth_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")

  let assert Ok(result) =
    curlify.from_request(req)
    |> curlify.set_basic_auth("admin", "secret")
    |> curlify.to_request()

  let found =
    list.find(result.headers, fn(header) {
      let #(key, _) = header
      key == "authorization"
    })
  let assert Ok(#(_, value)) = found
  assert value == "Basic YWRtaW46c2VjcmV0"
}

pub fn to_request_round_trip_get_test() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  let req = req |> request.set_header("accept", "application/json")

  let assert Ok(result) = curlify.from_request(req) |> curlify.to_request()

  assert result.method == http.Get
  assert result.body == ""
}

pub fn to_request_with_post_body_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_body("{\"name\": \"test\"}")

  let assert Ok(result) = curlify.from_request(req) |> curlify.to_request()

  assert result.method == http.Post
  assert result.body == "{\"name\": \"test\"}"
}

pub fn to_request_form_body_test() {
  let assert Ok(req) = request.to("https://api.example.com/submit")

  let assert Ok(result) =
    curlify.from_request(req)
    |> curlify.set_body(curlify.Form([#("name", "John Doe"), #("age", "30")]))
    |> curlify.to_request()

  assert result.body == "name=John%20Doe&age=30"
}

pub fn header_order_preserved_in_to_string_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_header("Accept", "application/json")
    |> request.set_header("X-Custom", "first")
    |> request.set_header("Authorization", "Bearer token")

  let result = curlify.from_request(req) |> curlify.to_string()

  assert result
    == "curl -H 'accept: application/json' -H 'x-custom: first' -H 'authorization: Bearer token' 'https://api.example.com/data'"
}

pub fn header_order_preserved_in_parse_curl_test() {
  let assert Ok(result) =
    curlify.parse(
      "curl -H 'Accept: application/json' -H 'X-Custom: first' -H 'Authorization: Bearer token' 'https://api.example.com'",
    )

  assert result.headers
    == [
      #("accept", "application/json"),
      #("x-custom", "first"),
      #("authorization", "Bearer token"),
    ]
}

pub fn header_order_preserved_in_round_trip_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_header("Accept", "application/json")
    |> request.set_header("X-Custom", "first")
    |> request.set_header("Authorization", "Bearer token")

  let assert Ok(result) = curlify.from_request(req) |> curlify.to_request()

  assert result.headers
    == [
      #("accept", "application/json"),
      #("x-custom", "first"),
      #("authorization", "Bearer token"),
    ]
}

pub fn to_request_invalid_url_test() {
  let bad =
    curlify.Curl(
      method: http.Get,
      url: "://invalid",
      headers: [],
      body: curlify.Empty,
      follow_redirects: False,
      verbose: False,
      insecure: False,
      compressed: False,
      timeout: 0,
      basic_auth: None,
    )

  let assert Error(_) = curlify.to_request(bad)
}

pub fn parse_curl_simple_get_test() {
  let assert Ok(result) = curlify.parse("curl 'https://example.org'")

  assert result.method == http.Get
  assert result.url == "https://example.org"
  assert result.body == curlify.Empty
}

pub fn parse_curl_without_leading_curl_test() {
  let assert Ok(result) =
    curlify.parse("-XPOST -d 'hello' 'http://example.com'")

  assert result.method == http.Post
  assert result.url == "http://example.com"
  assert result.body == curlify.Text("hello")
}

pub fn parse_curl_post_with_data_test() {
  let assert Ok(result) =
    curlify.parse(
      "curl -XPOST -d '{\"name\": \"test\"}' 'https://api.example.com/data'",
    )

  assert result.method == http.Post
  assert result.body == curlify.Text("{\"name\": \"test\"}")
}

pub fn parse_curl_with_headers_test() {
  let assert Ok(result) =
    curlify.parse(
      "curl -H 'Accept: application/json' -H 'Authorization: Bearer tok' 'https://api.example.com'",
    )

  assert result.headers
    == [
      #("accept", "application/json"),
      #("authorization", "Bearer tok"),
    ]
}

pub fn parse_curl_json_body_test() {
  let assert Ok(result) =
    curlify.parse("curl --json '{\"a\": 1}' 'https://api.example.com'")

  assert result.body == curlify.Json("{\"a\": 1}")
}

pub fn parse_curl_form_body_test() {
  let assert Ok(result) =
    curlify.parse(
      "curl --data-urlencode 'name=John' --data-urlencode 'age=30' 'https://api.example.com/submit'",
    )

  assert result.body == curlify.Form([#("name", "John"), #("age", "30")])
}

pub fn parse_curl_multiple_data_one_body_test() {
  let assert Ok(result) =
    curlify.parse("curl -d 'first' -d 'second' 'https://api.example.com'")

  assert result.body == curlify.Text("second")
}

pub fn parse_curl_missing_url_test() {
  let result = curlify.parse("curl -XGET")

  assert result == Error(curlify.MissingUrl)
}

pub fn parse_curl_ignores_unknown_flag_test() {
  let assert Ok(result) =
    curlify.parse("curl --nonexistent 'https://example.com'")

  assert result.url == "https://example.com"
  assert result.method == http.Get
  assert result.body == curlify.Empty
}

pub fn parse_curl_follow_redirects_test() {
  let assert Ok(result) = curlify.parse("curl -L 'https://api.example.com'")
  assert result.follow_redirects == True
}

pub fn parse_curl_verbose_test() {
  let assert Ok(result) = curlify.parse("curl -v 'https://api.example.com'")
  assert result.verbose == True
}

pub fn parse_curl_insecure_test() {
  let assert Ok(result) = curlify.parse("curl -k 'https://api.example.com'")
  assert result.insecure == True
}

pub fn parse_curl_compressed_test() {
  let assert Ok(result) =
    curlify.parse("curl --compressed 'https://api.example.com'")
  assert result.compressed == True
}

pub fn parse_curl_timeout_test() {
  let assert Ok(result) =
    curlify.parse("curl --max-time 30 'https://api.example.com'")
  assert result.timeout == 30
}

pub fn parse_curl_basic_auth_test() {
  let assert Ok(result) =
    curlify.parse("curl -u 'admin:secret' 'https://api.example.com'")
  assert result.basic_auth == Some(#("admin", "secret"))
}

pub fn parse_curl_tokenizer_embedded_quote_test() {
  let assert Ok(result) =
    curlify.parse("curl -d 'it'\"'\"'s' 'https://api.example.com'")

  assert result.body == curlify.Text("it's")
}

pub fn request_to_curl_get_test() {
  let assert Ok(req) = request.to("https://api.example.com/users")

  let result = curlify.request_to_curl(req)

  assert result == "curl 'https://api.example.com/users'"
}

pub fn request_to_curl_post_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body("{\"name\": \"test\"}")

  let result = curlify.request_to_curl(req)

  assert result
    == "curl -X POST -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://api.example.com/data'"
}

pub fn curl_to_request_get_test() {
  let assert Ok(result) =
    curlify.curl_to_request("curl 'https://api.example.com/users'")

  assert result.method == http.Get
  assert result.body == ""
}

pub fn curl_to_request_post_test() {
  let assert Ok(result) =
    curlify.curl_to_request(
      "curl -XPOST -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://api.example.com/data'",
    )

  assert result.method == http.Post
  assert result.body == "{\"name\": \"test\"}"
}

pub fn curl_to_request_bad_url_test() {
  let result = curlify.curl_to_request("curl '://invalid'")

  assert result == Error(curlify.RequestBuildError)
}

pub fn curl_to_request_missing_url_test() {
  let result = curlify.curl_to_request("curl -XGET")

  assert result == Error(curlify.MissingUrl)
}

pub fn to_args_get_test() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  let result = curlify.from_request(req) |> curlify.to_args()
  assert result == ["https://api.example.com/users"]
}

pub fn to_args_post_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body("{\"name\": \"test\"}")

  let result = curlify.from_request(req) |> curlify.to_args()
  assert result
    == [
      "-X", "POST", "--data", "{\"name\": \"test\"}",
      "https://api.example.com/data",
    ]
}

pub fn to_args_with_headers_test() {
  let assert Ok(req) = request.to("https://api.example.com/data")
  let req = req |> request.set_header("Accept", "application/json")

  let result = curlify.from_request(req) |> curlify.to_args()
  assert result
    == ["-H", "accept: application/json", "https://api.example.com/data"]
}

pub fn to_args_form_test() {
  let assert Ok(req) = request.to("https://api.example.com/submit")
  let c =
    curlify.from_request(req)
    |> curlify.set_body(curlify.Form([#("name", "John"), #("age", "30")]))

  let result = curlify.to_args(c)
  assert result
    == [
      "--data-urlencode",
      "name=John",
      "--data-urlencode",
      "age=30",
      "https://api.example.com/submit",
    ]
}

pub fn http_method_is_escaped_test() {
  let assert Ok(curl) = curlify.parse("curl -X** https://example.com")
  assert curl.method == http.Other("**")

  assert curlify.to_string(curl) == "curl -X '**' 'https://example.com'"
  assert curlify.to_pretty_string(curl)
    == "curl -X '**' \\\n  'https://example.com'"
}
