#!/bin/sh
# Runs every test in tests/ against the Ak binary in $AK (default: ak/bin/ak, the pinned submodule). Starts the fixtures, runs the tests, stops the fixtures.
cd "$(dirname "$0")" || exit 1
AK=${AK:-$PWD/ak/bin/ak}
[ -x "$AK" ] || git submodule update --init ak >&2
T=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
echo "Ak: $($AK --version)"
python3 fixtures/udp_echo.py "$T/udp" & $AK fixtures/httpd.aklang "$T/http" & $AK fixtures/httpd.aklang "$T/slow" &
# throw-away CA and a leaf for localhost; Ak is given only this CA
(cd "$T" && for n in ca other; do openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout $n.key -out $n.pem -subj "/CN=$n" -days 2 -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign" 2>/dev/null; done
 printf 'basicConstraints=CA:FALSE\nsubjectAltName=DNS:localhost\n' > leaf.ext
 openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out leaf.key 2>/dev/null
 openssl req -new -key leaf.key -subj "/CN=localhost" -out leaf.csr
 openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 -extfile leaf.ext -out leaf.pem 2>/dev/null)
(cd "$T" && printf 'basicConstraints=CA:FALSE\nextendedKeyUsage=clientAuth\n' > cli.ext
 openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out client.key 2>/dev/null
 openssl req -new -key client.key -subj "/CN=client" -out client.csr
 openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 -extfile cli.ext -out client.pem 2>/dev/null)
printf 'nameserver 127.0.0.1\nsearch lab.test\noptions ndots:2\n' > "$T/resolv.conf"
: > "$T/pxtls.log"; : > "$T/pxplain.log"
python3 fixtures/web.py "$T/web" & node fixtures/h2_server.js "$T/leaf.key" "$T/leaf.pem" "$T/h2" &
$AK fixtures/proxy.aklang tls "$T/leaf.pem" "$T/leaf.key" "$T/pxtls" "$T/pxtls.log" & $AK fixtures/proxy.aklang plain - - "$T/pxplain" "$T/pxplain.log" &
$AK fixtures/httpd_tls.aklang "$T/leaf.pem" "$T/leaf.key" "$T/httpdtls" & $AK fixtures/ws_echo.aklang "$T/ws" & $AK fixtures/tls_ak.aklang "$T/leaf.pem" "$T/leaf.key" "$T/aktls" h2,http/1.1 - & $AK fixtures/tls_ak.aklang "$T/leaf.pem" "$T/leaf.key" "$T/mtls" - "$T/ca.pem" &
node fixtures/tls_server.js "$T/leaf.key" "$T/leaf.pem" "$T/tls" & node fixtures/tls_server.js "$T/leaf.key" "$T/leaf.pem" "$T/tls12" tls12 &
for f in udp http slow tls tls12 web aktls mtls h2 pxtls pxplain httpdtls ws; do i=0; while [ ! -s "$T/$f" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done; done
export ECHO_PORT=$(cut -d' ' -f1 "$T/udp") AK_DNS=127.0.0.1:$(cut -d' ' -f2 "$T/udp")
export HTTP_PORT=$(cat "$T/http") SLOW_PORT=$(cat "$T/slow") TLS_PORT=$(cat "$T/tls") TLS12_PORT=$(cat "$T/tls12") WEB_PORT=$(cat "$T/web") AKTLS_PORT=$(cat "$T/aktls") MTLS_PORT=$(cat "$T/mtls") CLIENT_PEM=$T/client.pem CLIENT_KEY=$T/client.key H2_PORT=$(cat "$T/h2") PXTLS_PORT=$(cat "$T/pxtls") PXPLAIN_PORT=$(cat "$T/pxplain") HTTPDTLS_PORT=$(cat "$T/httpdtls") WS_PORT=$(cat "$T/ws") PXTLS_LOG=$T/pxtls.log PXPLAIN_LOG=$T/pxplain.log AK_RESOLV=$T/resolv.conf CA_PEM=$T/ca.pem OTHER_PEM=$T/other.pem
pass=0 fail=0 n=0
for f in tests/${TESTS:-[0-9]*}.aklang; do
  n=$((n+1)); echo "== $f"
  if [ "$f" = tests/08_public.aklang ]; then unset AK_DNS AK_RESOLV; fi
  timeout 120 $AK "$f"; rc=$?
  if [ $rc -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "-- exit $rc"; fi
done
echo; echo "$pass/$n test files passed"
[ $n -gt 0 ] && [ $fail -eq 0 ]
