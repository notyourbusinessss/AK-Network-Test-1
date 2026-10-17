# Python versions of the Ak benchmarks. usage: py.py name [port]
import socket, sys, time, http.client
def pingpong(_):
    n = 50000
    l = socket.socket(); l.bind(("127.0.0.1", 0)); l.listen(1)
    c = socket.create_connection(l.getsockname()); s, _ = l.accept()
    t = time.time()
    for _ in range(n): c.sendall(b"x"); s.recv(1); s.sendall(b"y"); c.recv(1)
    return time.time() - t
def stream(port):
    c = socket.create_connection(("127.0.0.1", port)); got = 0; t = time.time()
    while True:
        d = c.recv(1 << 20)
        if not d: break
        got += len(d)
    assert got == 268435456
    return time.time() - t
def udp(port):
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); u.settimeout(1); t = time.time()
    for _ in range(20000): u.sendto(b"ping", ("127.0.0.1", port)); u.recvfrom(100)
    return time.time() - t
def http_get(port):
    t = time.time()
    for _ in range(500):
        c = http.client.HTTPConnection("127.0.0.1", port); c.request("GET", "/echo/hello"); r = c.getresponse()
        assert r.read() == b"hello"; c.close()
    return time.time() - t
name = sys.argv[1]; port = int(sys.argv[2]) if len(sys.argv) > 2 else 0
print(name, "%.3f" % {"tcp_pingpong": pingpong, "tcp_stream": stream, "udp_rtt": udp, "http_get": http_get}[name](port))
