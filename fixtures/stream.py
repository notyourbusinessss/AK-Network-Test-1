# TCP fixture for the benchmarks: sends 256 MB to every client that connects, then closes. usage: stream.py portfile
import socket, sys, threading
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", 0)); s.listen(8)
open(sys.argv[1], "w").write(str(s.getsockname()[1]))
chunk = b"x" * 65536
def serve(c):
    try:
        for _ in range(4096): c.sendall(chunk)
    except OSError: pass
    c.close()
while True: threading.Thread(target=serve, args=(s.accept()[0],), daemon=True).start()
