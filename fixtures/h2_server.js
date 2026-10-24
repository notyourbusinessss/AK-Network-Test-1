// HTTP/2 (and HTTP/1.1) fixture: node fixtures/h2_server.js key.pem cert.pem portfile
// replies "<http version> <method> <path> <body bytes>"; /big is 3 MB, /redir redirects to /after; header x-h2 is set only on HTTP/2
const http2 = require('http2'), fs = require('fs');
const [key, cert, portfile] = process.argv.slice(2);
const s = http2.createSecureServer({ key: fs.readFileSync(key), cert: fs.readFileSync(cert), allowHTTP1: true }, (req, res) => {
  const chunks = []; req.on('data', d => chunks.push(d)); req.on('error', () => {});
  req.on('end', () => {
    const n = Buffer.concat(chunks).length, h2 = req.httpVersion === '2.0';
    const hd = { 'x-got': req.headers['x-test'] || '-', 'set-cookie': ['a=1', 'b=2'] }; if (h2) hd['x-h2'] = '1';
    if (req.url === '/big') { res.writeHead(200, { ...hd, 'content-length': '3000000' }); res.end(Buffer.alloc(3000000, 97)); return; }
    if (req.url === '/redir') { res.writeHead(302, { ...hd, location: '/after' }); res.end(); return; }
    const body = `${req.httpVersion} ${req.method} ${req.url} ${n}`;
    res.writeHead(200, { ...hd, 'content-length': String(Buffer.byteLength(body)) }); res.end(body);
  });
});
s.on('tlsClientError', () => {}); s.on('error', () => {});
s.listen(0, '127.0.0.1', () => fs.writeFileSync(portfile, String(s.address().port)));
