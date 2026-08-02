import birdie
import curlify
import gleam/http

pub fn to_gleam_complex_test() {
  let curl =
    curlify.from_url("https://api.example.com/data")
    |> curlify.set_method(http.Post)
    |> curlify.set_body(curlify.Json("{\"name\": \"test\"}"))
    |> curlify.set_basic_auth("admin", "secret")

  let assert Ok(gleam_code) = curlify.to_gleam(curl)
  gleam_code
  |> birdie.snap(title: "gleam code post with auth")
}

pub fn to_gleam_form_test() {
  let curl =
    curlify.from_url("https://api.example.com/data")
    |> curlify.set_method(http.Post)
    |> curlify.set_body(curlify.Form([#("name", "John Doe"), #("age", "30")]))

  let assert Ok(gleam_code) = curlify.to_gleam(curl)
  gleam_code
  |> birdie.snap(title: "gleam code post with form")
}

pub fn to_gleam_with_custom_http_method_test() {
  let curl =
    curlify.from_url("https://api.example.com/data")
    |> curlify.set_method(http.Other("WIBBLE"))

  let assert Ok(gleam_code) = curlify.to_gleam(curl)
  gleam_code
  |> birdie.snap(title: "gleam code with custom http method")
}

pub fn to_gleam_with_url_params_test() {
  let curl = curlify.from_url("https://api.example.com/data?foo=bar")

  let assert Ok(gleam_code) = curlify.to_gleam(curl)
  gleam_code
  |> birdie.snap(title: "gleam code with url params")
}
