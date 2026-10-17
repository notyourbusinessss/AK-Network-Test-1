// C versions of the Ak benchmarks (POSIX sockets). usage: bench name [port]
#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
#include <poll.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static struct sockaddr_in addr(int port) { struct sockaddr_in a = {0}; a.sin_family = AF_INET; a.sin_port = htons(port); inet_pton(AF_INET, "127.0.0.1", &a.sin_addr); return a; }
static int dial(int port) { int s = socket(AF_INET, SOCK_STREAM, 0); struct sockaddr_in a = addr(port); if (connect(s, (void *)&a, sizeof a)) { perror("connect"); exit(1); } return s; }
static double pingpong(void) {
  int l = socket(AF_INET, SOCK_STREAM, 0); struct sockaddr_in a = addr(0); bind(l, (void *)&a, sizeof a); listen(l, 1);
  socklen_t n = sizeof a; getsockname(l, (void *)&a, &n); int c = dial(ntohs(a.sin_port)), s = accept(l, 0, 0); char b;
  double t = now(); for (int i = 0; i < 50000; i++) { write(c, "x", 1); read(s, &b, 1); write(s, "y", 1); read(c, &b, 1); } return now() - t;
}
static double stream(int port) {
  int c = dial(port); static char buf[1 << 20]; long got = 0; ssize_t r; double t = now();
  while ((r = read(c, buf, sizeof buf)) > 0) got += r;
  if (got != 268435456L) { fprintf(stderr, "short read\n"); exit(1); } return now() - t;
}
static double udp(int port) {
  int u = socket(AF_INET, SOCK_DGRAM, 0); struct sockaddr_in a = addr(port); char b[100]; struct pollfd p = {u, POLLIN, 0}; double t = now();
  for (int i = 0; i < 20000; i++) { sendto(u, "ping", 4, 0, (void *)&a, sizeof a); if (poll(&p, 1, 1000) < 1) { fprintf(stderr, "timeout\n"); exit(1); } recv(u, b, sizeof b, 0); } return now() - t;
}
static double http_get(int port) {
  double t = now(); static char buf[65536];
  for (int i = 0; i < 500; i++) {
    int c = dial(port); const char *rq = "GET /echo/hello HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"; write(c, rq, strlen(rq));
    size_t len = 0; ssize_t r; while ((r = read(c, buf + len, sizeof buf - len - 1)) > 0) len += r; buf[len] = 0; close(c);
    if (len < 5 || strcmp(buf + len - 5, "hello")) { fprintf(stderr, "bad body\n"); exit(1); }
  } return now() - t;
}
int main(int argc, char **argv) {
  int port = argc > 2 ? atoi(argv[2]) : 0; double s;
  if (!strcmp(argv[1], "tcp_pingpong")) s = pingpong(); else if (!strcmp(argv[1], "tcp_stream")) s = stream(port);
  else if (!strcmp(argv[1], "udp_rtt")) s = udp(port); else if (!strcmp(argv[1], "http_get")) s = http_get(port); else return 2;
  printf("%s %.3f\n", argv[1], s); return 0;
}
