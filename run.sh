#!/bin/sh
# Runs every test in tests/ against the Ak binary in $AK (default: ak on PATH). Starts the fixtures, runs the tests, stops the fixtures.
AK=${AK:-ak}
cd "$(dirname "$0")" || exit 1
T=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
echo "Ak: $($AK --version)"
python3 fixtures/udp_echo.py "$T/udp" & $AK fixtures/httpd.aklang "$T/http" & $AK fixtures/httpd.aklang "$T/slow" &
# throw-away CA and a leaf for localhost; Ak is given only this CA
(cd "$T" && for n in ca other; do openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout $n.key -out $n.pem -subj "/CN=$n" -days 2 -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign" 2>/dev/null; done
 printf 'basicConstraints=CA:FALSE\nsubjectAltName=DNS:localhost\n' > leaf.ext
 openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out leaf.key 2>/dev/null
 openssl req -new -key leaf.key -subj "/CN=localhost" -out leaf.csr
 openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 -extfile leaf.ext -out leaf.pem 2>/dev/null)
node fixtures/tls_server.js "$T/leaf.key" "$T/leaf.pem" "$T/tls" & node fixtures/tls_server.js "$T/leaf.key" "$T/leaf.pem" "$T/tls12" tls12 &
for f in udp http slow tls tls12; do i=0; while [ ! -s "$T/$f" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done; done
export ECHO_PORT=$(cut -d' ' -f1 "$T/udp") AK_DNS=127.0.0.1:$(cut -d' ' -f2 "$T/udp")
export HTTP_PORT=$(cat "$T/http") SLOW_PORT=$(cat "$T/slow") TLS_PORT=$(cat "$T/tls") TLS12_PORT=$(cat "$T/tls12") CA_PEM=$T/ca.pem OTHER_PEM=$T/other.pem
pass=0 fail=0 n=0
for f in tests/[0-9]*.aklang; do
  n=$((n+1)); echo "== $f"
  if [ "$f" = tests/08_public.aklang ]; then unset AK_DNS; fi
  timeout 120 $AK "$f"; rc=$?
  if [ $rc -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "-- exit $rc"; fi
done
echo; echo "$pass/$n test files passed"
[ $n -gt 0 ] && [ $fail -eq 0 ]
