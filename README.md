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
| TLS server (`ssl.wrap_socket(server_side=True)`) | TLS 1.3 client only; the HTTPS fixture is Node | #101 |
| TLS 1.2, client certificates, ALPN/HTTP/2 | not supported | #102 |
| `select`/non-blocking sockets, `SO_REUSEADDR` etc. | blocking only; `fdw` of a large buffer blocks the whole process, so a client and a server that exchange megabytes in **one** process deadlock (test 02 therefore only does small messages; big transfers are tested across processes in 05 and 06) | #103 |
| UDP to a bad host | `(udpto u "not an ip" ..)` is silently ignored | #100 |
| Unix socket server | only `unixc` (client) | #60 |
| any socket call on the JS target | raises `sockets are native only` (by design) | #59, closed |

Bug found: `(lo s)` raises `chr: invalid code point` when `s` is not valid UTF-8 (a crash in the test HTTP server when a TLS client hit it): #99.

## Ak vs Python vs C
Same four benchmarks written in all three (`bench/`; run `AK=ak bench/run.sh`; needs `gcc`). Seconds, best of 3, one 4-core Linux container, loopback only, Ak 0.6.0, Python 3.13.16, gcc 13.3 `-O2`:

| benchmark | Ak | Python | C |
|---|---:|---:|---:|
| `tcp_pingpong`: 50,000 one-byte round trips, client and server in one process | 0.740 | 0.359 | 0.299 |
| `tcp_stream`: read 256 MB from a Python server | 0.158 | 0.212 | 0.196 |
| `udp_rtt`: 20,000 UDP round trips to a Python echo server | 1.241 | 1.267 | 1.159 |
| `http_get`: 500 sequential GETs against the Ak test server (`lib/http` / `http.client` / hand-written C) | 0.053 | 0.093 | 0.054 |

Read it with care: `tcp_stream`, `udp_rtt` and `http_get` are limited by the server (a Python script or Ak's own single-threaded server), so they mostly show that Ak's client is not the bottleneck, not that Ak is faster than C. `tcp_pingpong` has no outside server and is the fairest speed test: Ak is about 2x Python and 2.5x C there. Cause (measured): `(fdr s)` allocates a 64 KB buffer on every call, which triggers 781 garbage collections in the run; the system calls are identical to C's (`strace -c`: 100,000 sends and 100,000 reads in both). With `(fdr s 1)` Ak takes 0.35 s, level with Python (0.36) and close to C (0.30): issue #104. One run on a shared container; expect noise of tens of percent.

Capability and effort:

| | Ak 0.6.0 | Python 3 | C (POSIX) |
|---|---|---|---|
| TCP client/server, UDP client, DNS (A records) | built in | `socket` | `socket`, `getaddrinfo` |
| UDP server (bind), IPv6, DNS over TCP | no (#100, #56) | yes | yes |
| Read/write timeouts | `fdwait` only (#57) | `settimeout` | `SO_RCVTIMEO`, `poll` |
| Non-blocking / many sockets | `fdwait` + `lib/async` tasks; `fdw` blocks (#103) | `select`, `asyncio`, threads | `poll`, `epoll`, threads |
| HTTP/HTTPS client | `lib/http` (verified TLS 1.3, redirects, chunked) | `urllib`, `http.client` (+ `requests`) | needs libcurl or hand-written; HTTPS needs OpenSSL |
| TLS | 1.3 client only (#101, #102) | TLS 1.2/1.3, client and server | OpenSSL/GnuTLS |
| WebSocket | no (#60) | `websockets` | libraries |
| Dependencies | none (single static binary, TLS and DNS written in Ak) | stdlib; `requests` etc. extra | libc; TLS needs a library |
| Size of the four benchmarks (lines) | 23 in total (5-6 each) | 29 | 41 |
| Memory safety | yes (GC, bounds-checked) | yes | no |

In short: for clients (TCP, UDP, DNS, HTTP, HTTPS) Ak matches Python's features on the cases tested and is close to C in raw speed on the benchmarks above; it falls behind Python and C on servers (UDP bind, TLS server, WebSocket), on timeouts and on non-blocking I/O.

## Layout
```
run.sh               runs everything
tests/               the Ak programs (t.aklang is the check helper)
bench/                the same benchmarks in Ak, Python (py.py) and C (c/bench.c); run.sh prints the table
fixtures/            stream.py (256 MB sender), udp_echo.py (UDP echo + fake DNS), httpd.aklang (HTTP server in Ak), tls_server.js (HTTPS)
lib/                 copy of Ak's http, tls, crypto, pki, async libraries (Apache-2.0, see LICENSE-Ak)
```
