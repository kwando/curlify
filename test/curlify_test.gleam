import curlify
import gleam/http
import gleam/http/request
import gleam/io
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let assert Ok(req) = request.to("https://example.org/foo/bar?wibble=wobble")

  curlify.to_curl(req)
  |> should.equal("curl \"https://example.org/foo/bar?wibble=wobble\"")

  let assert Ok(req) = request.to("https://example.org/foo/bar?wibble=wobble")

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "text/plain")
    |> request.set_header("Accept", "application/json")
    |> request.set_body("{\"foo\": \"bar\"}")

  let str = curlify.to_curl(req)
  io.println_error(str)
  str
  |> should.equal(
    "curl -XPOST -H \"content-type: text/plain\" -H \"accept: application/json\" --data \"{\\\"foo\\\": \\\"bar\\\"}\" \"https://example.org/foo/bar?wibble=wobble\"",
  )
}

pub fn real_test() {
  let assert Ok(req) = request.to("https://home.merciless.me/links")

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "text/plain")
    |> request.set_body("name=Hello")

  curlify.to_curl(req)
  |> should.equal(
    "curl -XPOST -H \"content-type: text/plain\" --data \"name=Hello\" \"https://home.merciless.me/links\"",
  )
}
