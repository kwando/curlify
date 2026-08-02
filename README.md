# curlify

[![Package Version](https://img.shields.io/hexpm/v/curlify)](https://hex.pm/packages/curlify)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/curlify`/)`

Utilitys for generating `curl` commands. Use the builder api, convert a `gleam_http` request or
parse a curl command line string.

Checkout the companion lib called `curlify_wisp` if you are a wisp user.

```sh
gleam add curlify@1
```

## Usage

### URL → curl string

```gleam
import curlify
import gleam/http

pub fn main() {
  curlify.from_url("https://api.example.com/users")
  |> curlify.set_method(http.Post)
  |> curlify.set_body(curlify.Json("{\"name\": \"test\"}"))
  |> curlify.to_string()

  // → curl -X POST --json '{"name": "test"}' 'https://api.example.com/users'
}
```

### Request → curl string

```gleam
import curlify
import gleam/http/request

pub fn main() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  let req = req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body("{\"name\": \"test\"}")

  curlify.from_request(req)
  |> curlify.set_follow_redirects()
  |> curlify.set_timeout(30)
  |> curlify.to_string()

  // → curl -X POST --json '{"name": "test"}' --max-time 30 -L 'https://api.example.com/users'
}
```

### Multi-line output

```gleam
curlify.from_request(req)
|> curlify.to_pretty_string()
// → curl -X POST \
//     --json '{"name": "test"}' \
//     'https://api.example.com/users'
```

### Curl string → Request

```gleam
// Parse a curl command
let assert Ok(curl) = curlify.parse(
  "curl -X POST --json '{\"name\": \"test\"}' 'https://api.example.com/data'",
)

// Parse and convert directly to a request
let assert Ok(req) = curlify.curl_to_request(
  "curl -X POST -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://api.example.com/data'",
)
```

### Raw argument list (no shell escaping)

```gleam
curlify.from_request(req)
|> curlify.to_args()
// → ["-X", "POST", "--json", "{\"name\": \"test\"}", "https://api.example.com/users"]
```

### Direct convenience

```gleam
curlify.request_to_curl(req)  // from_request |> to_string
curlify.curl_to_request(str)  // parse |> to_request
```

## Supported curl flags for parsing

`-X`/`--request`, `-H`/`--header`, `-d`/`--data`, `--data-raw`, `--data-binary`, `--json`, `--data-urlencode`, `-L`/`--location`, `-v`/`--verbose`, `-k`/`--insecure`, `--compressed`, `--max-time`, `-u`/`--user`.

Unsupported flags are silently dropped.

**Notes on behavior:**

- Multiple `-d`/`--data` flags use **last-wins** (real curl concatenates with `&`).
- `--max-time` with a non-integer value returns `Error(BadTimeoutValue)`.
- `from_request` automatically detects `Content-Type: application/json` and stores the body as the `Json(...)` variant, so it renders as `--json`.

## Development

```sh
gleam test     # Run the tests
gleam format   # Format code
```
