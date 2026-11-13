#!/usr/bin/env bash
# Walk the front page the way a reader walks it: take the commands and
# the example out of README.md itself, run them in an empty directory,
# and expect the example to print its answers.
#
# The patrol's other walk goes by the install page, which asks one
# channel. The front page asks three -- max, conda-forge, and this
# package's own -- and three channels resolve together in ways one
# channel does not: whichever of them carries the `mojo` a reader
# resolves is the compiler the frozen package meets. Nothing here
# rewrites what the README says; the blocks are lifted out of it, so a
# README that changes its commands changes what the patrol walks.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$(mktemp -d)"

README="$(git -C "$ROOT" show HEAD:README.md 2>/dev/null ||
  cat "$ROOT/README.md")"

# The install block: the first fenced bash block that asks for a
# `pixi init` -- the later one is the maintainers' commands, and a
# reader does not run those to try the package.
INSTALL_BLOCK="$(python3 - "$README" <<'PY'
import re
import sys

text = sys.argv[1]
for block in re.findall(r"```bash\n(.*?)```", text, re.S):
    if "pixi init" in block:
        print(block)
        break
else:
    raise SystemExit("the README gives no install block to walk")
PY
)"

# The example: the first fenced mojo block, which is what the front
# page tells a reader their first program looks like.
EXAMPLE_BLOCK="$(python3 - "$README" <<'PY'
import re
import sys

text = sys.argv[1]
blocks = re.findall(r"```mojo\n(.*?)```", text, re.S)
if not blocks:
    raise SystemExit("the README gives no mojo example to walk")
print(blocks[0])
PY
)"

printf '%s\n' "$INSTALL_BLOCK" | bash -e
printf '%s\n' "$EXAMPLE_BLOCK" > main.mojo

# The example prints the square root it was given and the process it
# is -- the first number is what the page's own arithmetic predicts
# (`sqrt(2.0)` to double precision), the second is whatever the
# machine answers.
OUTPUT="$(pixi run mojo run main.mojo)"
echo "$OUTPUT"
echo "$OUTPUT" | head -1 | grep -Eq "^1\.4142135623730951 [0-9]+$" || {
  echo "the front page's example did not print what it promises"
  exit 1
}
echo "the front page's walk ends where it says it does"
