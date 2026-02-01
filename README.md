# curlify

[![Package Version](https://img.shields.io/hexpm/v/curlify)](https://hex.pm/packages/curlify)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/curlify/)

Turn your gleam_http requests into curl commands. Useful for debugging, documentation, or sharing with that one colleague who insists everything should be done in bash.

```sh
gleam add curlify@1
```

```gleam
import curlify
import gleam/http/request

pub fn main() {
  let assert Ok(req) = request.to("https://api.example.com/users")
  curlify.to_curl(req)
  // Returns: curl "https://api.example.com/users"
}
```

Further documentation can be found at <https://hexdocs.pm/curlify>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
