import curlify.{type Curl}
import gleam/http/request
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import wisp

/// Convert a wisp Request into a curlify Curl.
///
/// The body must be provided as a string separately because wisp
/// hasn't read it from the connection yet — use `wisp.require_string_body`
/// or similar to obtain it first.
///
/// If the request has `X-Forwarded-Proto`, `X-Forwarded-Host`, or
/// `X-Forwarded-Port` headers (e.g. from a reverse proxy), they are
/// used to reconstruct the external URL. Otherwise the request's
/// internal URI is used as-is. The forwarded headers are not
/// included in the generated curl command.
pub fn from_request(req: wisp.Request, body: String) -> Result(Curl, Nil) {
  let url = build_external_url(req)
  use http_req <- result.try(request.from_uri(url))
  let http_req =
    http_req
    |> request.set_method(req.method)
    |> request.set_body(body)

  let http_req =
    list.fold(req.headers, http_req, fn(acc, header) {
      let #(key, value) = header
      case should_drop_header(key) {
        True -> acc
        False -> request.set_header(acc, key, value)
      }
    })

  Ok(curlify.from_request(http_req))
}

fn should_drop_header(header_name: String) -> Bool {
  string.starts_with(header_name, "x-forwarded-")
  || header_name == "forwarded"
  || header_name == "host"
  || header_name == "connection"
  || header_name == "keep-alive"
  || header_name == "transfer-encoding"
  || header_name == "content-length"
}

fn build_external_url(req: wisp.Request) -> uri.Uri {
  let base = req |> request.to_uri

  let scheme =
    list.key_find(req.headers, "x-forwarded-proto")
    |> result.unwrap(case base.scheme {
      Some(s) -> s
      None -> "https"
    })

  let forwarded_host = list.key_find(req.headers, "x-forwarded-host")
  let forwarded_port = list.key_find(req.headers, "x-forwarded-port")

  let host = case forwarded_host {
    Ok(h) -> h
    Error(_) ->
      case base.host {
        Some(h) -> h
        None -> "localhost"
      }
  }

  let port = case forwarded_port {
    Ok(p) -> int.parse(p)
    Error(_) -> Error(Nil)
  }

  let port = case port {
    Ok(p) -> Some(p)
    Error(_) -> base.port
  }

  uri.Uri(
    scheme: Some(scheme),
    userinfo: base.userinfo,
    host: Some(host),
    port: port,
    path: base.path,
    query: base.query,
    fragment: base.fragment,
  )
}
