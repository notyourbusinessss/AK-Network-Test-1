# AK-Network-Test-1

A network test suite written in [Ak](https://github.com/notyourbusinessss/AI-codinglanguage-): the things a typical Python networking demo does (TCP client/server, UDP, DNS, HTTP, HTTPS, concurrency, timeouts), each run against Ak and checked.

**Dependency:** Ak is a git submodule in `ak/`, pinned to `AI-codinglanguage-` main at `6347680` (Ak 0.7.31). The tests use `ak/bin/ak` and `ak/lib/` (http, tls, crypto, pki, async). The test results are from Ak 0.7.31. The benchmark tables were measured with Ak 0.6.0 and not re-measured.

## Run it
```
git clone --recurse-submodules https://github.com/notyourbusinessss/AK-Network-Test-1
cd AK-Network-Test-1 && ./run.sh     # uses ak/bin/ak; run `git submodule update --init` if ak/ is empty
AK=/path/to/other/ak ./run.sh        # test another Ak build
```
To move to a newer Ak: `git -C ak fetch && git -C ak checkout <commit> && git add ak`, and put the same commit hash in `package.json`.

`package.json` declares the same Ak commit as a dependency so that GitHub's dependency graph lists it (a git submodule alone does not show up there). The tests use the submodule in `ak/`; `package.json` is not used to run anything and `npm install` is not needed.
Needs Linux x86-64, `python3`, `node` and `openssl` (for the fixtures). `run.sh` starts the fixtures on loopback ports, runs `tests/*.aklang`, and prints `ok` or `FAIL` per check and a summary. A test file that finds nothing to run fails.

| test | what it checks | Python equivalent |
|---|---|---|
| `01_tcp` | listen on port 0, connect, accept, request/reply, 1000 byte write, close detection, all 256 byte values, connection refused, connect timeout | `socket`, `connect`, `accept`, `recv`, `settimeout` on connect |
| `02_async` | one task per connection, 50 concurrent clients, channels | `asyncio` / `threading` echo server |
| `03_udp` | UDP client vs echo server: round trips, datagram boundaries, empty and 60000 byte datagrams, NUL bytes, truncation to `n`, receive timeout | `SOCK_DGRAM`, `sendto`, `recvfrom` |
| `04_dns` | A records (one and several), NXDOMAIN, `/etc/hosts`, IPv4 literal, connect by name, `search` domains from resolv.conf (`AK_RESOLV`), reverse DNS; fake nameserver via `AK_DNS` | `socket.gethostbyname_ex`, `getaddrinfo` |
| `05_http` | `lib/http` against an HTTP server written in Ak: GET, POST, JSON, query string, custom headers, 302 redirect, chunked, 2 MB body, 404/503, truncated body, refused, bad scheme, bad host | `urllib.request`, `http.client`, `requests` |
| `06_https` | `lib/http` + `lib/tls` against a local Node TLS server with a throw-away CA: success, 1 MB body, wrong host name, untrusted CA, TLS 1.2-only server (works since Ak 0.7) | `ssl`, `urllib` over HTTPS |
| `07_timeouts` | `fdwait` as read timeout, closed peer, silent server | `settimeout`, `select` |
| `08_public` | real DNS, HTTP, HTTPS (example.com, google.com), bad certificates (badssl.com) | the same against the real internet |
| `09_tls_server` | Ak as a TLS server (`fixtures/tls_ak.aklang`) and its client: SNI, ALPN (pick, no overlap), client certificates (required, missing, accepted), TLS 1.3 session resumption, TLS 1.2 tickets and resumption against Node | `ssl.wrap_socket(server_side=True)`, `SSLContext.set_alpn_protocols`, `load_verify_locations`, `session=` |
| `10_ipv6` | TCP and UDP over `::1`, a `::` listener that also takes IPv4, IPv6 literal in `dns`. Skips (and checks the clean error) when the machine has no IPv6 loopback | `AF_INET6` |
| `11_http_extras` | `lib/http` connection reuse (`:pool`), `:gzip` (gzip and deflate), proxies (`:proxy`, credentials), against a Python keep-alive server | `requests.Session`, `Accept-Encoding`, `proxies=` |

## Results (Ak 0.7.31)
`./run.sh`: **11/11 test files pass** in the Linux container this was written in. `08_public` printed **SKIP** (no direct internet there, only an HTTPS proxy that the test cannot use) and `10_ipv6` printed **SKIP** (no IPv6 loopback), so real DNS, public HTTPS, the system CA bundle and the IPv6 paths are **not verified** here. Run `./run.sh` on a machine with internet and IPv6 to exercise them.

Not tested: HTTPS through a proxy (`CONNECT` tunnel), reverse-DNS PTR queries over the network (only the hosts file), HTTP/2, TLS 1.3 0-RTT, SNI-selected certificates.

**Fixed in this suite:** the checks never failed the test files. Since Ak 0.6.x a function of a namespace with no arguments has to be called as `t.done()`; `(t.done)` only names the function, so every test file exited 0 whatever its checks said. `tests/*.aklang` now call `t.done()`.

## What Ak could not do in 0.6.0 and does now
Found while writing the first version of these tests. Issue numbers are in `notyourbusinessss/AI-codinglanguage-`.

| Python | Ak 0.6.0 | Ak 0.7.31 |
|---|---|---|
| `sock.settimeout(s)` | `fdr`/`fdw` block forever (#57) | `ms` argument on `fdr`, `fdw`, `fdline`, `fdreadn`; `:rms` / `:wms` in `lib/http` (`07_timeouts` still tests `fdwait`) |
| IPv6, AAAA | IPv4 only (#56) | TCP, UDP, `dns` (A and AAAA, over TCP when truncated, TTL cache), `[::1]` URLs |
| `bind()` and `recvfrom` on UDP | client only (#100) | `udpl`, `udpfrom2` |
| WebSocket | none (#60) | `lib/ws` |
| TLS server | TLS 1.3 client only (#101) | `t.creds` / `t.accept`, SNI certificates, ALPN, client CA |
| TLS 1.2, client certificates, ALPN | not supported (#102) | TLS 1.2 client, client certificates, ALPN, session tickets and resumption |
| non-blocking I/O, `SO_REUSEADDR` | blocking only (#103) | `fdwp`, `fdpoll`, `sockopt` (`reuseaddr`, `nodelay` ...), `shutw`/`shutr` |
| Unix socket server | client only | `unixl` |
| `Session` connection reuse, `Accept-Encoding: gzip` | none | `{:pool}`, `{:gzip}` |
| proxy environment, `socket.gethostbyaddr`, resolv.conf `search` | none | `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY`, `rdns`, search domains |
| UDP to a bad host | silently ignored (#100) | an io error |

Bug found with the first version: `(lo s)` raised `chr: invalid code point` when `s` is not valid UTF-8 (#99).

Still missing compared with Python: HTTP/2, a TLS 1.2 server, `lib/httpd` over TLS, HTTPS proxies (TLS over TLS), TLS 1.1 and older.

## Ak vs Python vs C
This section is from the first version of the suite (Ak 0.6.0); the capability table below is out of date where it says "no" for features listed above. Same four benchmarks written in all three (`bench/`; run `bench/run.sh`; needs `gcc`). Seconds, best of 3, one 4-core Linux container, loopback only, Ak 0.6.0, Python 3.13.16, gcc 13.3 `-O2`:

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

### File sizes
Source (bytes, the same four benchmarks; Ak is one file per benchmark, Python and C one file for all four):

| | Ak | Python | C |
|---|---:|---:|---:|
| source, all four benchmarks | 1,094 (273 + 272 + 229 + 320) | 1,294 | 2,672 |
| lines | 23 | 29 | 41 |

Built program (`ak build x.aklang out` vs `gcc -O2`; one Ak executable per benchmark, one C executable holding all four):

| | size | needs at run time |
|---|---:|---|
| Ak executable, TCP/UDP benchmarks | about 902 KB each | nothing (static, no libc, runtime and GC included) |
| Ak executable with `lib/http` and TLS | 1.4 MB | nothing |
| C, dynamically linked | 17 KB | glibc and the dynamic loader |
| C, stripped | 14 KB | glibc |
| C, `-static -s` | 743 KB | nothing (glibc linked in) |
| Python | 1.3 KB script | the Python interpreter: 6.5 MB binary plus its standard library |
| `ak` compiler itself | 4.9 MB | nothing |

So Ak source is the shortest, and a built Ak program is about as large as a statically linked C program and runs on a bare Linux kernel, while Python needs its interpreter installed. Dynamically linked C is the smallest because the C library is not in the file. Sizes from the container this was written in (Ak 0.6.0, gcc 13.3, Python 3.13).

## Layout
```
run.sh               runs everything
tests/               the Ak programs (t.aklang is the check helper)
bench/                the same benchmarks in Ak, Python (py.py) and C (c/bench.c); run.sh prints the table
fixtures/            stream.py (256 MB sender), udp_echo.py (UDP echo + fake DNS), httpd.aklang (HTTP server in Ak), tls_server.js (HTTPS, Node), tls_ak.aklang (TLS server in Ak), web.py (keep-alive, gzip and proxy server)
ak/                  git submodule: the Ak repository (compiler binary bin/ak and lib/), pinned
```
