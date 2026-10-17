#!/bin/sh
# Runs the same four network benchmarks in Ak, Python and C and prints a table (seconds, best of 3). usage: AK=ak bench/run.sh
cd "$(dirname "$0")/.." || exit 1
AK=${AK:-$PWD/ak/bin/ak}
T=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
gcc -O2 -o "$T/bench" bench/c/bench.c || exit 1
python3 fixtures/udp_echo.py "$T/udp" & python3 fixtures/stream.py "$T/stream" & $AK fixtures/httpd.aklang "$T/http" &
for f in udp stream http; do i=0; while [ ! -s "$T/$f" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done; done
UDP=$(cut -d' ' -f1 "$T/udp") STREAM=$(cat "$T/stream") HTTP=$(cat "$T/http")
best() { b=999999; for i in 1 2 3; do v=$("$@" | awk '{print $2}'); [ -n "$v" ] && b=$(echo "$v $b" | awk '{print ($1<$2)?$1:$2}'); done; echo $b; }
printf '%-14s %8s %8s %8s\n' benchmark Ak Python C
for n in tcp_pingpong tcp_stream udp_rtt http_get; do
  case $n in tcp_pingpong) port=;; tcp_stream) port=$STREAM;; udp_rtt) port=$UDP;; http_get) port=$HTTP;; esac
  printf '%-14s %8s %8s %8s\n' $n "$(best $AK bench/$n.aklang $port)" "$(best python3 bench/py.py $n $port)" "$(best "$T/bench" $n $port)"
done
