import contour
import curlify
import curlify_app/gleam_code_gen
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/element
import lustre/element/html
import lustre/event

pub type Example {
  Example(title: String, curl: String)
}

const examples: List(Example) = [
  Example(title: "Simple GET", curl: "curl 'https://api.example.com/users'"),
  Example(
    title: "GET with query params",
    curl: "curl 'https://api.example.com/users?page=1&per_page=20'",
  ),
  Example(
    title: "POST with JSON body",
    curl: "curl -X POST --json '{\"name\": \"test\", \"email\": \"test@example.com\"}' \\\n  'https://api.example.com/users'",
  ),
  Example(
    title: "POST with form data",
    curl: "curl -X POST --data-urlencode 'name=John' --data-urlencode 'age=30' \\\n  'https://api.example.com/submit'",
  ),
  Example(
    title: "POST with raw text body",
    curl: "curl -X POST -H 'content-type: text/plain' --data 'Hello World' \\\n  'https://api.example.com/echo'",
  ),
  Example(
    title: "PUT with JSON and auth header",
    curl: "curl -X PUT -H 'authorization: Bearer tok_abc123' -H 'accept: application/json' \\\n  --json '{\"status\": \"active\"}' \\\n  'https://api.example.com/users/42'",
  ),
  Example(
    title: "DELETE with header",
    curl: "curl -X DELETE -H 'authorization: Bearer tok_abc123' \\\n  'https://api.example.com/users/42'",
  ),
  Example(
    title: "Basic auth",
    curl: "curl --user 'admin:secret' 'https://api.example.com/admin'",
  ),
  Example(
    title: "Boolean flags",
    curl: "curl -v -L -k --compressed 'https://example.com'",
  ),
  Example(
    title: "Full featured POST",
    curl: "curl -X POST \\\n  -H 'authorization: Bearer tok_abc123' \\\n  -H 'accept: application/json' \\\n  --json '{\"key\": \"value\"}' --verbose --user 'admin:secret' --insecure \\\n  --compressed --max-time 30 --location \\\n  'https://api.example.com/data'",
  ),
  Example(
    title: "Implicit POST from --data",
    curl: "curl -d 'hello' 'https://example.com'",
  ),
  Example(
    title: "Implicit POST from --json",
    curl: "curl --json '{\"key\": \"val\"}' 'https://example.com'",
  ),
  Example(
    title: "Shell escaping (embedded single quote)",
    curl: "curl -X POST -H 'content-type: application/json' \\\n  --data '{\"message\": \"it'\"'\"'s working\"}' \\\n  'https://example.com'",
  ),
  Example(
    title: "Unsupported flags dropped",
    curl: "curl --user-agent 'MyApp/1.0' --silent --show-error 'https://example.com'",
  ),
]

pub fn main() {
  let app = lustre.simple(init:, update:, view:)

  lustre.start(app, "#app", [])
}

pub opaque type Model {
  Model(
    input: String,
    curl: curlify.Curl,
    error: String,
    gleam_tokens: List(contour.Token),
    example: Option(Example),
    code_gen_options: gleam_code_gen.Options,
  )
}

pub opaque type Msg {
  InputUpdated(text: String)
  UserClickedClearInput
  UserClickerShowExampleButton
  UserToggledParseJson(Bool)
  UserToggledInlineBody(Bool)
}

fn update(model: Model, value: Msg) -> Model {
  case value {
    InputUpdated(text:) -> update_input(model, text)
    UserClickedClearInput -> update_input(model, "")
    UserClickerShowExampleButton -> {
      let example =
        list.sample(examples, 1)
        |> list.first
        |> option.from_result

      load_example(model, example)
    }
    UserToggledParseJson(parse_json) ->
      update_code_gen_options(model, fn(opts) {
        gleam_code_gen.Options(..opts, parse_json:)
      })
    UserToggledInlineBody(inline_body) ->
      update_code_gen_options(model, fn(opts) {
        gleam_code_gen.Options(..opts, inline_body:)
      })
  }
}

fn update_code_gen_options(
  model,
  update: fn(gleam_code_gen.Options) -> gleam_code_gen.Options,
) {
  Model(..model, code_gen_options: update(model.code_gen_options))
  |> update_curl_from_input
}

fn init(_flags: a) -> Model {
  let example =
    list.sample(examples, 1)
    |> list.first
    |> option.from_result

  Model(
    input: "",
    curl: curlify.from_url(""),
    error: "",
    gleam_tokens: [],
    example: None,
    code_gen_options: gleam_code_gen.Options(
      inline_body: False,
      parse_json: True,
      imports: True,
    ),
  )
  |> load_example(example)
}

fn load_example(model, example: Option(Example)) {
  case example {
    Some(e) -> Model(..model, example:, input: e.curl) |> update_curl_from_input
    None -> Model(..model, example:)
  }
}

fn update_curl_from_input(model: Model) -> Model {
  case model.input == "" {
    True ->
      Model(
        ..model,
        error: "",
        gleam_tokens: contour.to_tokens("todo \"write a curl command above\""),
      )
    False ->
      case curlify.parse(model.input) {
        Ok(curl) -> {
          Model(..model, curl:, error: "")
          |> update_gleam_code
        }
        Error(err) -> {
          Model(..model, error: string.inspect(err))
        }
      }
  }
}

fn update_input(model: Model, input: String) {
  Model(..model, input:, example: None)
  |> update_curl_from_input
}

fn update_gleam_code(model: Model) {
  let gleam_code =
    model.curl
    |> gleam_code_gen.to_gleam(model.code_gen_options)
    |> result.map(prepend_imports)
    |> result.unwrap("panic as \"could not parse curl command\"")

  let tokens = contour.to_tokens(gleam_code)

  Model(..model, gleam_tokens: tokens)
}

fn prepend_imports(code: String) {
  "import gleam/http/request\nimport gleam/http\nimport gleam/json\n\n" <> code
}

fn view(model: Model) {
  html.div([class("p-4 flex flex-col gap-8")], [
    html.div([class("flex justify-between items-center")], [
      html.div([class("whitespace-nowrap")], [
        html.h1([class("font-mono text-xl text-center font-bold")], [
          prompt_element(),
          html.text("Curlify"),
        ]),
      ]),
      html.div([class("flex gap-4 justify-end")], [
        top_bar_link("https://hex.pm/packages/curlify", "hex.pm"),
        top_bar_link("https://curlify.hexdocs.pm/", "hexdocs"),
        top_bar_link("https://github.com/kwando/curlify", "github"),
      ]),
    ]),

    html.div([], [
      box_header("curl input"),

      html.div([class("relative")], [
        html.textarea(
          [
            event.on_input(InputUpdated),
            attribute.placeholder("curl https://gleam.run/"),
          ],
          model.input,
        ),
        case model.example {
          Some(example) ->
            html.div(
              [
                class(
                  "absolute top-3 right-3 rounded  py-2 px-4 bg-black/75 font-mono select-none",
                ),
              ],
              [
                html.text(example.title),
              ],
            )
          None -> element.none()
        },
      ]),

      html.div([class("flex gap-4")], [
        html.button(
          [
            class("btn"),
            attribute.classes([#("dimmed", model.input == "")]),
            event.on_click(UserClickedClearInput),
          ],
          [
            html.text("Clear"),
          ],
        ),
        show_example_button(model),
      ]),
    ]),

    box(
      "Gleam HTTP request",
      html.div([], [
        html.pre([class("p-4 mb-2")], [
          model.gleam_tokens
          |> contour_to_lustre
          |> element.fragment,
        ]),

        html.div([class("flex gap-4")], [
          checkbox_option(
            "Inline body",
            model.code_gen_options.inline_body,
            UserToggledInlineBody,
          ),
          checkbox_option(
            "Parse JSON",
            model.code_gen_options.parse_json,
            UserToggledParseJson,
          ),
        ]),
      ]),
    ),

    pre_box(
      "Multiline curl",
      model.curl
        |> curlify.to_pretty_string
        |> html.text,
    ),
    pre_box(
      "Single line curl",
      model.curl
        |> curlify.to_string
        |> html.text,
    ),
    pre_box(
      "Command flags",
      model.curl
        |> curlify.to_args
        |> string.inspect
        |> contour.to_tokens
        |> contour_to_lustre
        |> element.fragment,
    ),

    html.footer(
      [
        class(
          "text-center text-sm text-gray-500 mt-12 pt-4 border-t border-gray-700",
        ),
      ],
      [
        html.text("© 2026 kwando"),
        html.br([]),
        html.text(
          "Visitor stats collected via Umami — no cookies, no personal data.",
        ),
      ],
    ),
  ])
}

fn checkbox_option(label: String, value: Bool, msg) -> element.Element(Msg) {
  html.label(
    [class("flex gap-2 items-center font-bold font-mono cursor-pointer")],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(value),
        event.on_check(msg),
      ]),
      html.text(label),
    ],
  )
}

fn top_bar_link(url, text) -> element.Element(Msg) {
  html.a(
    [
      class("btn outline"),
      attribute.href(url),
    ],
    [
      html.text(text),
    ],
  )
}

fn show_example_button(model: Model) -> element.Element(Msg) {
  html.button(
    [
      class("btn"),
      attribute.classes([
        #("dimmed", model.input != "" && model.example == None),
      ]),
      attribute.data("umami-event", "example-buttom-pressed"),
      event.on_click(UserClickerShowExampleButton),
    ],
    [
      html.text(case model.example {
        Some(_) -> "Show another example"
        None -> "Show an example"
      }),
    ],
  )
}

fn box(title: String, content) -> element.Element(Msg) {
  html.div([class("overflow-none")], [
    box_header(title),
    content,
  ])
}

fn pre_box(title: String, content) -> element.Element(Msg) {
  box(
    title,
    html.pre([class("p-4")], [
      content,
    ]),
  )
}

fn box_header(title: String) -> element.Element(Msg) {
  html.h1([class("font-bold font-mono mb-3")], [
    prompt_element(),
    html.text(title),
  ])
}

fn prompt_element() -> element.Element(Msg) {
  html.span([class("text-amber-500 prompt")], [html.text(">_ ")])
}

fn contour_to_lustre(tokens: List(contour.Token)) {
  list.map(tokens, fn(token) {
    case token {
      contour.Whitespace(txt) -> html.text(txt)
      contour.Keyword(txt) -> html.span([class("gl-keyword")], [html.text(txt)])
      contour.String(txt) -> html.span([class("gl-string")], [html.text(txt)])
      contour.Number(txt) -> html.span([class("gl-number")], [html.text(txt)])
      contour.Variant(txt) -> html.span([class("gl-variant")], [html.text(txt)])
      contour.Function(txt) ->
        html.span([class("gl-function")], [html.text(txt)])
      contour.Module(txt) -> html.span([class("gl-module")], [html.text(txt)])
      contour.Operator(txt) ->
        html.span([class("gl-operator")], [html.text(txt)])
      contour.Comment(txt) -> html.span([class("gl-comment")], [html.text(txt)])
      contour.Other(txt) -> html.span([class("gl-other")], [html.text(txt)])
    }
  })
}
