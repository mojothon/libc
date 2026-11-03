"""Check that every C symbol is bound in one file, and only one.

Two modules can bind the same symbol to two signatures that look alike and
are not, and both compile. `strlen` answered `UInt64` in `libc.string` and
`Int` in `libc.utils`; `read` took `c_ptr[c_void]` in one and `c_ptr[UInt8]`
in the other; `ldiv` read `long` in one module and `Int64` in the other, and
the two `ldiv_t` structs that went with them were separate types. Nothing
here compared one binding with another, so the second copy was read by
nobody and drifted at its own pace: the copy a bug was found in got fixed,
the other kept the bug.

A module that wants to offer a call another module owns can import it. The
name is then in both modules and there is one `external_call` behind it, so
the two cannot disagree -- which is the rule this checks: one file per
symbol, and a re-export where a second door is wanted.

An alias inside one file is allowed: `gamma` and `lgamma` are the same
symbol under two names, and a file that offers both says so where a reader
can see it. What is not allowed is the same pair in two files, where
neither reader sees the other.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "src" / "libc").rglob("*.mojo"))

# `external_call` is sometimes split over lines, and the symbol is the first
# thing after the bracket, so the pattern has to be able to cross them.
CALL = re.compile(r'external_call\[\s*"(\w+)"', re.S)


def main() -> int:
    homes = {}
    for path in SOURCES:
        where = path.relative_to(ROOT / "src" / "libc")
        for symbol in CALL.findall(path.read_text()):
            homes.setdefault(symbol, set()).add(str(where))

    split = {symbol: sorted(places) for symbol, places in homes.items() if len(places) > 1}

    if split:
        print(f"{len(split)} symbol(s) are bound in more than one file:")
        for symbol, places in sorted(split.items()):
            print(f"  {symbol}: {', '.join(places)}")
        print()
        print("bind it once, in the module whose header declares it, and")
        print("`from` that module in the others that want to offer the name")
        return 1

    print(f"{len(homes)} C symbols, each bound in one file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
