// HTTPS fixture: node fixtures/tls_server.js key.pem cert.pem portfile [tls12] -- serves "hello over tls" for GET /, a 1 MB body on /big
const tls = require('tls'), fs = require('fs');
const [key, cert, portfile, mode] = process.argv.slice(2);
const opts = { key: fs.readFileSync(key), cert: fs.readFileSync(cert), minVersion: mode === 'tls12' ? 'TLSv1.2' : 'TLSv1.3', maxVersion: mode === 'tls12' ? 'TLSv1.2' : 'TLSv1.3' };
const s = tls.createServer(opts, sock => {
  let buf = '';
  sock.on('error', () => {});
  sock.on('data', d => {
    buf += d; if (!buf.includes('\r\n\r\n')) return;
    const big = buf.startsWith('GET /big');
    const body = big ? 'z'.repeat(1 << 20) : 'hello over tls';
    sock.end('HTTP/1.1 200 OK\r\nContent-Length: ' + body.length + '\r\nConnection: close\r\n\r\n' + body);
  });
});
s.on('tlsClientError', () => {});
s.listen(0, '127.0.0.1', () => fs.writeFileSync(portfile, String(s.address().port)));
