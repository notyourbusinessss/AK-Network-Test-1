# UDP echo + fake DNS responder for the tests (Python on purpose: the clients under test are Ak's).
# usage: udp_echo.py portfile  -> binds two ephemeral ports on 127.0.0.1, writes "echo_port dns_port" to portfile
import socket, struct, sys, selectors
echo = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); echo.bind(("127.0.0.1", 0))
dns = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); dns.bind(("127.0.0.1", 0))
open(sys.argv[1], "w").write("%d %d\n" % (echo.getsockname()[1], dns.getsockname()[1]))
RECORDS = {"one.test": ["192.0.2.1"], "multi.test": ["192.0.2.1", "192.0.2.2", "192.0.2.3"], "db.lab.test": ["192.0.2.60"]}
def answer(q):
    i = 12; labels = []
    while q[i]:
        labels.append(q[i + 1:i + 1 + q[i]].decode()); i += 1 + q[i]
    name = ".".join(labels); qend = i + 5
    ips = RECORDS.get(name)
    if ips is None:   # NXDOMAIN
        return q[:2] + struct.pack(">HHHHH", 0x8183, 1, 0, 0, 0) + q[12:qend]
    out = q[:2] + struct.pack(">HHHHH", 0x8180, 1, len(ips), 0, 0) + q[12:qend]
    for ip in ips:
        out += b"\xc0\x0c" + struct.pack(">HHIH", 1, 1, 60, 4) + socket.inet_aton(ip)
    return out
sel = selectors.DefaultSelector(); sel.register(echo, 1, "echo"); sel.register(dns, 1, "dns")
while True:
    for k, _ in sel.select():
        d, a = k.fileobj.recvfrom(70000)
        if k.data == "echo": k.fileobj.sendto(d, a)
        else: k.fileobj.sendto(answer(d), a)
