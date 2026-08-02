import curlify
import curlify_wisp
import gleam/erlang/process
import gleam/io
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  let secret_key_base = "32898238923489242989"
  let _ =
    wisp_mist.handler(
      fn(req) {
        echo req

        let assert Ok(curl) = curlify_wisp.from_request(req, "")

        io.println_error("to retry the request")

        curl
        |> curlify.set_timeout(32)
        |> curlify.to_pretty_string
        |> io.println
        wisp.ok()
      },
      secret_key_base,
    )
    |> mist.new()
    |> mist.port(4924)
    |> mist.start

  process.sleep_forever()
}
