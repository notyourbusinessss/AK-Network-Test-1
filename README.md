# AK-Network-Test-1

A network test suite written in [Ak](https://github.com/notyourbusinessss/AI-codinglanguage-): the things a typical Python networking demo does (TCP client/server, UDP, DNS, HTTP, HTTPS, concurrency, timeouts), each run against Ak and checked.

**Tested with Ak 0.6.0** (`ak --version`), `AI-codinglanguage-` main at commit `1713fd9`. `lib/` is a copy of that commit's `lib/` (http, tls, crypto, pki, async), so the tests use `lib/` here and need only the `ak` binary.

## Run it
```
AK=/path/to/ak ./run.sh        # AK defaults to `ak` on PATH
```
Needs Linux x86-64, `python3`, `node` and `openssl` (for the fixtures). `run.sh` starts the fixtures on loopback ports, runs `tests/*.aklang`, and prints `ok` or `FAIL` per check and a summary. A test file that finds nothing to run fails.

| test | what it checks | Python equivalent |
|---|---|---|
| `01_tcp` | listen on port 0, connect, accept, request/reply, 1000 byte write, close detection, all 256 byte values, connection refused, connect timeout | `socket`, `connect`, `accept`, `recv`, `settimeout` on connect |
| `02_async` | one task per connection, 50 concurrent clients, channels | `asyncio` / `threading` echo server |
| `03_udp` | UDP client vs echo server: round trips, datagram boundaries, empty and 60000 byte datagrams, NUL bytes, truncation to `n`, receive timeout | `SOCK_DGRAM`, `sendto`, `recvfrom` |
| `04_dns` | A records (one and several), NXDOMAIN, `/etc/hosts`, IPv4 literal, connect by name; fake nameserver via `AK_DNS` | `socket.gethostbyname_ex`, `getaddrinfo` |
| `05_http` | `lib/http` against an HTTP server written in Ak: GET, POST, JSON, query string, custom headers, 302 redirect, chunked, 2 MB body, 404/503, truncated body, refused, bad scheme, bad host | `urllib.request`, `http.client`, `requests` |
| `06_https` | `lib/http` + `lib/tls` against a local Node TLS 1.3 server with a throw-away CA: success, 1 MB body, wrong host name, untrusted CA, TLS 1.2-only server | `ssl`, `urllib` over HTTPS |
| `07_timeouts` | `fdwait` as read timeout, closed peer, silent server | `settimeout`, `select` |
| `08_public` | real DNS, HTTP, HTTPS (example.com, google.com), bad certificates (badssl.com) | the same against the real internet |

## Results (Ak 0.6.0)
`./run.sh`: **8/8 test files pass, 55 checks ok, 0 failed**, in the Linux container this was written in.

`08_public` printed **SKIP**: that container has no direct internet (only an HTTPS proxy, which Ak cannot use), so real DNS, public HTTPS and the system CA bundle are **not verified**. Run `./run.sh` on a machine with internet to exercise them.

## What Ak cannot do yet that Python can
Found while writing the tests. Issue numbers are in `notyourbusinessss/AI-codinglanguage-`.

| Python | Ak 0.6.0 | issue |
|---|---|---|
| `sock.settimeout(s)` on read/write | `fdr`/`fdw` block forever; use `fdwait` before `fdr` (test 07). `lib/http` and `lib/tls` have only a connect timeout (`:ms`), so a server that accepts and never answers hangs a request, and an `https://` URL on a plain HTTP port hangs the handshake | #57 |
| IPv6 (`AF_INET6`, AAAA) | IPv4 only | #56 |
| DNS over TCP, DNS cache | UDP only, no cache | #56 |
| `sock.bind()` on UDP, `recvfrom` returns the sender | UDP client only; `udpfrom` returns just the data | #100 |
| WebSocket (`websockets`) | none | #60 |
| TLS server (`ssl.wrap_socket(server_side=True)`) | TLS 1.3 client only; the HTTPS fixture is Node | not filed |
| TLS 1.2, client certificates, ALPN/HTTP/2 | not supported | not filed |
| `select`/non-blocking sockets, `SO_REUSEADDR` etc. | blocking only; `fdw` of a large buffer blocks the whole process, so a client and a server that exchange megabytes in **one** process deadlock (test 02 therefore only does small messages; big transfers are tested across processes in 05 and 06) | not filed |
| UDP to a bad host | `(udpto u "not an ip" ..)` is silently ignored | #100 |
| Unix socket server | only `unixc` (client) | #60 |
| any socket call on the JS target | raises `sockets are native only` (by design) | #59, closed |

Bug found: `(lo s)` raises `chr: invalid code point` when `s` is not valid UTF-8 (a crash in the test HTTP server when a TLS client hit it): #99.

## Layout
```
run.sh               runs everything
tests/               the Ak programs (t.aklang is the check helper)
fixtures/            udp_echo.py (UDP echo + fake DNS), httpd.aklang (HTTP server in Ak), tls_server.js (HTTPS)
lib/                 copy of Ak's http, tls, crypto, pki, async libraries (Apache-2.0, see LICENSE-Ak)
```
