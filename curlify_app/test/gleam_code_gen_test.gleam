import birdie
import curlify
import curlify_app/gleam_code_gen
import gleam/json
import gleam/list
import json_value

pub fn json_value_string_test() {
  json_value.string("hello world")
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - string literal")
}

pub fn json_value_int_test() {
  json_value.int(42)
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - int literal")
}

pub fn json_value_float_test() {
  json_value.float(6.7)
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - float literal")
}

pub fn json_value_bool_test() {
  json_value.bool(True)
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - bool literal")
}

pub fn json_value_null_test() {
  json_value.null
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - null literal")
}

pub fn json_value_array_with_different_kinds_test() {
  json_value.Array([json_value.int(23), json_value.bool(True)])
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - array with different kinds")
}

pub fn json_value_array_with_strings_test() {
  json_value.Array(["wibble", "wobble"] |> list.map(json_value.string))
  |> gleam_code_gen.json_value_to_json_string
  |> birdie.snap("codegen - array with only strings")
}

pub fn to_gleam_with_json_body_test() {
  let assert Ok(gleam_code) =
    curlify.from_url("https://gleam.run/")
    |> curlify.set_body(
      curlify.Json(
        json.to_string(json.object([#("lucy", json.string("lucy"))])),
      ),
    )
    |> gleam_code_gen.to_gleam(gleam_code_gen.Options(
      inline_body: False,
      parse_json: True,
      imports: True,
    ))

  gleam_code
  |> birdie.snap("codegen - to_gleam - curl with json body")
}
