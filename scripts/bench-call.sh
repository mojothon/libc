#!/usr/bin/env bash
#
# What one call through this binding costs, next to what one call from C
# costs.
#
# Two numbers, and the point is that they are close. The C side is built
# with -fno-builtin, or gcc replaces `strlen` with its own idea of it and
# the loop measures arithmetic instead of a call. The Mojo side walks a
# longer string from a moving offset, or the compiler folds the whole loop
# into a constant and measures nothing at all — the first version of this
# reported 3e-05 ns per call, which is a loop that never ran.
#
# Run with `bash scripts/bench-call.sh`.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat >"${WORK}/c.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <time.h>
int main(void){
  const char *s = "0123456789abcdefghijklmnopqrstuvwxyz";
  volatile size_t sum = 0;
  struct timespec a, b;
  clock_gettime(CLOCK_MONOTONIC, &a);
  for (long i = 0; i < 20000000L; i++) sum += strlen(s + (i % 32));
  clock_gettime(CLOCK_MONOTONIC, &b);
  double t = (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9;
  printf("  C, a real call          %6.3f ns/call   (sum %zu)\n", t * 1e9 / 2e7, sum);
  return 0; }
EOF

cat >"${WORK}/mojo.mojo" <<'EOF'
from libc.string import strlen
from libc.time import CLOCK_MONOTONIC, clock_gettime, timespec
from libc.utils import string_to_char_ptr
from std.memory.alloc import unsafe_alloc


def nanos() -> Int:
    var buf = unsafe_alloc[timespec](1)
    buf[] = timespec()
    _ = clock_gettime(CLOCK_MONOTONIC, buf)
    var out = Int(buf[].tv_sec) * 1_000_000_000 + Int(buf[].tv_nsec)
    buf.unsafe_free()
    return out


def main() raises:
    var p = string_to_char_ptr("0123456789abcdefghijklmnopqrstuvwxyz")
    var n = 20_000_000
    var sink: UInt64 = 0
    var t0 = nanos()
    for i in range(n):
        sink += strlen(p.unsafe_offset(i % 32))
    var t1 = nanos()
    print(
        "  Mojo, through the binding",
        Float64(t1 - t0) / Float64(n),
        "ns/call   (sum",
        sink,
        ")",
    )
EOF

echo "One call, 20 million times:"

if command -v gcc >/dev/null 2>&1; then
  gcc -O2 -fno-builtin -o "${WORK}/c" "${WORK}/c.c" && "${WORK}/c"
else
  echo "  (no gcc, so no C number)"
fi

# `mojo` lives in the pixi environment when it is not on the PATH at all.
if command -v mojo >/dev/null 2>&1; then
  mojo run -I "${ROOT}/src" "${WORK}/mojo.mojo"
else
  (cd "${ROOT}" && pixi run mojo run -I "${ROOT}/src" "${WORK}/mojo.mojo")
fi

echo
echo "Two things this does not settle: the Mojo side runs at whatever"
echo "optimization level `mojo run` picks, and the difference between the"
echo "two is small enough that a slower machine moves both."
