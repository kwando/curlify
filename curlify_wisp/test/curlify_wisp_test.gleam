import curlify
import curlify_wisp
import gleam/http
import gleeunit
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn from_request_get_test() {
  let req = simulate.request(http.Get, "/users")

  let assert Ok(result) = curlify_wisp.from_request(req, "")

  assert curlify.to_string(result) == "curl 'https://wisp.example.com/users'"
}

pub fn from_request_post_test() {
  let req =
    simulate.request(http.Post, "/data")
    |> simulate.string_body("{\"name\": \"test\"}")
    |> simulate.header("content-type", "application/json")

  let assert Ok(result) = curlify_wisp.from_request(req, "{\"name\": \"test\"}")

  assert curlify.to_string(result)
    == "curl -X POST -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://wisp.example.com/data'"
}

pub fn from_request_uses_forwarded_proto_test() {
  let req =
    simulate.request(http.Get, "/api")
    |> simulate.header("x-forwarded-proto", "http")

  let assert Ok(result) = curlify_wisp.from_request(req, "")

  assert curlify.to_string(result) == "curl 'http://wisp.example.com/api'"
}

pub fn from_request_uses_forwarded_host_test() {
  let req =
    simulate.request(http.Get, "/api")
    |> simulate.header("x-forwarded-host", "example.com")

  let assert Ok(result) = curlify_wisp.from_request(req, "")

  assert curlify.to_string(result) == "curl 'https://example.com/api'"
}

pub fn from_request_uses_forwarded_port_test() {
  let req =
    simulate.request(http.Get, "/api")
    |> simulate.header("x-forwarded-proto", "https")
    |> simulate.header("x-forwarded-host", "example.com")
    |> simulate.header("x-forwarded-port", "8443")

  let assert Ok(result) = curlify_wisp.from_request(req, "")

  assert curlify.to_string(result) == "curl 'https://example.com:8443/api'"
}
