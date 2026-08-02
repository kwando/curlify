# curlify

[![Package Version](https://img.shields.io/hexpm/v/curlify)](https://hex.pm/packages/curlify)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/curlify/)

Convert `gleam_http` requests to curl commands and back. Useful for debugging, logging, sharing with that one colleague, or recreating requests from captured curl commands.

```sh
gleam add curlify@1
```

## Usage

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

  // → curl -X POST -H 'content-type: application/json' --data '{"name": "test"}' --max-time 30 -L 'https://api.example.com/users'
}
```

### Multi-line output

```gleam
curlify.from_request(req)
|> curlify.to_pretty_string()
// → curl -X POST \
//     -H 'content-type: application/json' \
//     --data '{"name": "test"}' \
//     'https://api.example.com/users'
```

### Curl string → Request

```gleam
let assert Ok(req) = curlify.parse(
  "curl -X POST -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://api.example.com/data'",
)

let assert Ok(req) = curlify.curl_to_request(
  "curl -X POST -H 'content-type: application/json' --data '{\"name\": \"test\"}' 'https://api.example.com/data'",
)
```

### Raw argument list (no shell escaping)

```gleam
curlify.from_request(req)
|> curlify.to_args()
// → ["-X", "POST", "-H", "content-type: application/json", "--data", "{\"name\": \"test\"}", "https://api.example.com/users"]
```

### Direct convenience

```gleam
curlify.request_to_curl(req)  // from_request |> to_string
curlify.curl_to_request(str)  // parse |> to_request
```

## Supported curl flags for parsing

`-X`/`--request`, `-H`/`--header`, `-d`/`--data`, `--data-raw`, `--data-binary`, `--json`, `--data-urlencode`, `-L`/`--location`, `-v`/`--verbose`, `-k`/`--insecure`, `--compressed`, `--max-time`, `-u`/`--user`.

Unsupported flags are silently dropped.

## Development

```sh
gleam test     # Run the tests
gleam format   # Format code
```
