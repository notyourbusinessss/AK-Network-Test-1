# HTTP/1.1 keep-alive test server for the connection reuse, gzip and proxy tests: python3 fixtures/web.py portfile
# /hello  /conns (connections accepted so far)  /gz and /deflate (compressed "abc" x 5000)  an absolute-URI request (a proxy request) -> "proxied <uri> auth=<Proxy-Authorization>"
import gzip, zlib, sys, threading
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
conns = [0]
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def setup(self):
        conns[0] += 1; super().setup()
    def log_message(self, *a): pass
    def do_GET(self):
        enc = None
        if self.path.startswith("http://"):
            body = ("proxied %s auth=%s" % (self.path, self.headers.get("Proxy-Authorization"))).encode()
        elif self.path == "/hello": body = b"hello"
        elif self.path == "/conns": body = str(conns[0]).encode()
        elif self.path == "/gz": body, enc = gzip.compress(b"abc" * 5000), "gzip"
        elif self.path == "/deflate": body, enc = zlib.compress(b"abc" * 5000), "deflate"
        else:
            self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers(); return
        self.send_response(200); self.send_header("Content-Length", str(len(body)))
        if enc: self.send_header("Content-Encoding", enc)
        self.end_headers(); self.wfile.write(body)
s = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
