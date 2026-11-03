"""Check that every C symbol is bound in one file, in one signature.

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

The second half is one file per symbol taken one step further: one
signature per symbol, even inside one file. A symbol declared twice does not
fail to compile either, and not where it is written. C's `fcntl` was bound
with the two arguments a caller may give it and with the three its commands
take; a program calling either form built and ran, and a program calling
both stopped at lowering with `existing function with conflicting
signature` -- one symbol declared twice, in a message that names the symbol
and not the call that was written second. Every check in this directory was
green, because each signature was right about its own form; what was wrong
was that there were two.

So a symbol has one form here, and a form C makes variadic is declared with
the arguments it always takes: `openat` is declared with a mode, and the
form that has none passes 0; `fcntl` is declared with the argument its
commands take, and the commands that read nothing are given 0. The types
are compared as written rather than resolved, so two spellings of one type
are reported as well -- which is a thing to look at and then spell the same
way, not a thing to excuse.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "src" / "libc").rglob("*.mojo"))


def calls(text: str) -> list[tuple[str, str]]:
    """Every `external_call` in `text`, as the name it asks for and its types.

    The name is whatever stands before the first comma: a string for almost
    every call, and a `comptime` constant for the two that ask for one name
    or another depending on the platform. The types are between the bracket
    that opens the call and the one that closes it, and they can hold
    brackets of their own -- `c_ptr[UInt8]` is one -- so the end is found by
    counting rather than by matching, the same way the call is split at its
    own commas.
    """
    found = []
    for start in (m.end() for m in re.finditer(r"external_call\s*\[", text)):
        depth = 1
        end = start
        while end < len(text) and depth:
            depth += {"[": 1, "]": -1}.get(text[end], 0)
            end += 1
        parts = []
        current = ""
        depth = 0
        for character in text[start : end - 1]:
            depth += {"[": 1, "]": -1}.get(character, 0)
            if character == "," and not depth:
                parts.append(current)
                current = ""
            else:
                current += character
        parts.append(current)
        found.append((parts[0].strip(), ",".join(part.strip() for part in parts[1:])))
    return found


def main() -> int:
    homes = {}
    forms = {}
    indirect = {}
    for path in SOURCES:
        where = str(path.relative_to(ROOT / "src" / "libc"))
        for asked, signature in calls(path.read_text()):
            if not asked.startswith('"'):
                # A name chosen by a `comptime` constant: there is nothing
                # here to compare it with, and it is said out loud below
                # rather than counted as a symbol of its own.
                indirect.setdefault(asked, set()).add(where)
                continue
            symbol = asked.strip('"')
            homes.setdefault(symbol, set()).add(where)
            forms.setdefault(symbol, {}).setdefault(signature, set()).add(where)

    split = {symbol: sorted(places) for symbol, places in homes.items() if len(places) > 1}
    disagree = {symbol: by_form for symbol, by_form in forms.items() if len(by_form) > 1}

    if split:
        print(f"{len(split)} symbol(s) are bound in more than one file:")
        for symbol, places in sorted(split.items()):
            print(f"  {symbol}: {', '.join(places)}")
        print()
        print("bind it once, in the module whose header declares it, and")
        print("`from` that module in the others that want to offer the name")

    if disagree:
        print(f"{len(disagree)} symbol(s) are declared with more than one signature:")
        for symbol, by_form in sorted(disagree.items()):
            for signature, places in sorted(by_form.items()):
                print(f"  {symbol}({signature or 'nothing'}) in {', '.join(sorted(places))}")
        print()
        print("a program that calls both of them does not build, and the")
        print("compiler stops at lowering rather than at either call, so")
        print("declare one form and give it the arguments the other would:")
        print("`openat` passes 0 for the mode, `fcntl` passes 0 for a command")
        print("that reads nothing")

    if split or disagree:
        return 1

    print(f"{len(homes)} C symbols, each bound in one file, in one signature")
    for asked, places in sorted(indirect.items()):
        print(
            f"  and {asked} in {', '.join(sorted(places))} is a name the call"
            f" picks at compile time, which is not one of them"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
