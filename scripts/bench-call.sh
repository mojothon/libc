#!/usr/bin/env bash
#
# What one call through this binding costs, next to what one call from C
# costs.
#
# The row that makes the rest readable is the first one, `nothing`: the same
# loop with the same bookkeeping and no call in it. What a call costs is the
# distance between that row and the one below it, and without it the other
# rows are the loop's own cost plus a call of unknown size.
#
# Three cheap calls and one that is not: a string scan that walks memory, a
# comparison that takes two pointers, and `getpid`, which is a syscall and
# says what a call costs when the call itself is the work.
#
# Each program runs each loop once and is then run five times over, and what
# is printed is the *fastest* of the five. Interference only ever adds time,
# so the fastest run is the closest thing to the cost of the code with the
# machine out of the way — and the version of this that timed one run of ten
# million reported an empty loop at anywhere from 343 to 894 ps on the same
# machine, which was not a number to compare anything against.
#
# Both sides are built so that the loop measures a call and not the
# arithmetic around it. The C side is built with -fno-builtin, or gcc
# replaces `strlen` with its own idea of it and the loop measures nothing.
# The Mojo side walks a string from a moving offset and keeps the answers in
# a running sum, or the compiler folds the loop into a constant — the first
# version of this reported 3e-05 ns per call, which is a loop that never ran.
# A call whose arguments do not move with the loop is not in here: a loop of
# `getenv("PATH")` was hoisted out of itself by the Mojo side and left a row
# of zeros, which measures the optimizer and not the binding.
#
# Run with `bash scripts/bench-call.sh`.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat >"${WORK}/c.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define ROUNDS 100000000L

static double now(void){
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec / 1e9; }

/* `sink` is an ordinary local and not a `volatile` one: a volatile sum costs
   a store on every iteration, which the other side of this benchmark does
   not pay, and an earlier version blamed Mojo for being a quarter faster
   than C because of it. What keeps the loops from being folded is that the
   calls are extern under -fno-builtin, so gcc cannot know they are pure,
   and every row's sum is added into one that is printed at the end. */
static size_t total;

#define BENCH(label, body) do { \
  size_t sink = 0; long i; double a, b; \
  a = now(); for (i = 0; i < ROUNDS; i++) { sink += (body); } b = now(); \
  printf("%s %ld\n", label, (long)((b - a) * 1e12 / ROUNDS)); \
  total += sink; \
} while (0)

int main(void){
  const char *s = "0123456789abcdefghijklmnopqrstuvwxyz";
  BENCH("nothing", (size_t)(i % 32));
  BENCH("strlen", strlen(s + (i % 32)));
  BENCH("strcmp", (size_t)strcmp(s + (i % 32), s + ((i + 1) % 32)));
  BENCH("getpid", (size_t)getpid());
  printf("# sums %zu\n", total);
  return 0; }
EOF

cat >"${WORK}/mojo.mojo" <<'EOF'
from std.memory.alloc import unsafe_alloc

from libc.string import strcmp, strlen
from libc.time import CLOCK_MONOTONIC, clock_gettime, timespec
from libc.unistd import getpid
from libc.utils import string_to_char_ptr


comptime ROUNDS = 100_000_000


def nanos() -> Int:
    """The clock, as a number of nanoseconds since somewhere."""
    var buf = unsafe_alloc[timespec](1)
    buf[] = timespec()
    _ = clock_gettime(CLOCK_MONOTONIC, buf)
    var out = Int(buf[].tv_sec) * 1_000_000_000 + Int(buf[].tv_nsec)
    buf.unsafe_free()
    return out


def report(label: StringLiteral, ns: Int) raises:
    """One line, in picoseconds per call."""
    print(label, " ", ns * 1000 // ROUNDS)


def main() raises:
    var s = string_to_char_ptr("0123456789abcdefghijklmnopqrstuvwxyz")
    var sink: UInt64 = 0

    var t0 = nanos()
    for i in range(ROUNDS):
        sink += UInt64(UInt32(i % 32))
    var t1 = nanos()
    report("nothing", t1 - t0)

    t0 = nanos()
    for i in range(ROUNDS):
        sink += strlen(s.unsafe_offset(i % 32))
    t1 = nanos()
    report("strlen", t1 - t0)

    t0 = nanos()
    for i in range(ROUNDS):
        sink += UInt64(
            UInt32(strcmp(s.unsafe_offset(i % 32), s.unsafe_offset((i + 1) % 32)))
        )
    t1 = nanos()
    report("strcmp", t1 - t0)

    t0 = nanos()
    for _ in range(ROUNDS):
        sink += UInt64(UInt32(getpid()))
    t1 = nanos()
    report("getpid", t1 - t0)

    print("# sums ", sink)
EOF

fastest() {
  # Five runs in, the fastest of them out, labels in the order they appeared.
  awk '
    { if (!($1 in seen)) { seen[$1] = 1; order[++n] = $1 }
      if (!($1 in best) || $2 < best[$1]) best[$1] = $2 }
    END { for (i = 1; i <= n; i++) print order[i], best[order[i]] }
  '
}

echo "One call, a hundred million times, the fastest of five runs:"
echo
echo "  call      through C          through the binding"

if command -v gcc >/dev/null 2>&1; then
  gcc -O2 -fno-builtin -o "${WORK}/c" "${WORK}/c.c" || exit 1
  for _ in 1 2 3 4 5; do "${WORK}/c"; done | grep -v '^#' | fastest >"${WORK}/c.txt"
  have_c=1
else
  echo "  (no gcc, so no C number)"
  have_c=0
fi

# `mojo` lives in the pixi environment when it is not on the PATH at all.
if command -v mojo >/dev/null 2>&1; then
  for _ in 1 2 3 4 5; do
    mojo run -I "${ROOT}/src" "${WORK}/mojo.mojo"
  done 2>/dev/null | grep -v '^#' | fastest >"${WORK}/mojo.txt"
else
  for _ in 1 2 3 4 5; do
    (cd "${ROOT}" && pixi run mojo run -I "${ROOT}/src" "${WORK}/mojo.mojo")
  done 2>/dev/null | grep -v '^#' | fastest >"${WORK}/mojo.txt"
fi

if [ "${have_c}" -eq 1 ]; then
  awk 'NR == FNR { c[$1] = $2; next }
       { printf "  %-9s %7d ps   %7d ps\n", $1, c[$1], $2 }' \
      "${WORK}/c.txt" "${WORK}/mojo.txt"
else
  awk '{ printf "  %-9s %7s      %7d ps\n", $1, "-", $2 }' "${WORK}/mojo.txt"
fi

echo
echo "Read the rows against the first one: what a call costs is the distance"
echo "from \`nothing\`, and the syscall row is the one with room in it — it"
echo "costs what a syscall costs on either side, which is the claim being"
echo "made. The two cheap rows come out within a few hundred picoseconds of"
echo "each other, in the direction of the binding, for the reason the C side"
echo "pays for a jump through the procedure linkage table that an external"
echo "call does not; that is a small enough difference to be an artifact of"
echo "two different loops, so it is stated and not claimed."
echo
echo "One thing this does not settle: the Mojo side runs at whatever"
echo "optimization level \`mojo run\` picks."
