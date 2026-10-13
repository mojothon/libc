#!/usr/bin/env python3
"""Check what each binding says it hands back against what C hands back.

A wrong return value does not fail to compile. Nothing about a docstring
is checked by the compiler either, so a binding can promise "0 on
success" for a function whose answer is a number of bytes, a descriptor,
or which branch of `fork` you are now in, and every test written against
that promise passes. Fifteen here did exactly that:

    read / write / writev   answered with bytes, said 0 meant success
    lseek                   answered with the new offset, said the same
    readlink / readlinkat   answered with bytes, and write no NUL either
    fcntl                   answers with whatever its command asked for
    shm_open                answers with a descriptor, like every open
    dup / dup2 / dup3       answered with a descriptor, and 0 is one
    fork                    returns twice: 0 in the child, a pid outside
    isatty                  0 means "not a terminal", not that it failed

The ones of those that mislead worst are not the ones that are merely
wrong. `write` stopping short is a success that left part of what was
handed over unsent, and a caller told to look for 0 loses the tail
without anything anywhere going wrong. `fork` told a parent it had
failed, in a branch it had every intention of going on in.

Three things are checked, in increasing order of opinion:

    C says it hands back bytes, so it cannot be answering yes or no
    C says it hands back a pointer, so -1 cannot be its failure value
    the call is one whose answer is a thing rather than a yes, and it
    says 0 anyway

The last of those is the only one gcc cannot settle, and it is the only
one carrying a list of names put here by hand: a descriptor, a time, a
process id and a wait status are what they are by the meaning of the
call, which no type in a header says. Everything settled by a type is
settled by the same `gcc -aux-info` listing the prototype check uses.

Like that check, this reports nothing where there is no compiler to ask.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "libc"

# The prototype check's own helpers, which read the same `gcc -aux-info`
# listing and walk the same bindings. It is loaded by path because its
# name has a hyphen in it, which is not a name Python can import.
_loaded = importlib.util.spec_from_file_location(
    "check_prototypes", ROOT / "scripts" / "check-prototypes.py"
)
_check_prototypes = importlib.util.module_from_spec(_loaded)
_loaded.loader.exec_module(_check_prototypes)

read_prototypes = _check_prototypes.read_prototypes
bindings = _check_prototypes.bindings

# A size is a count, and a count is never a yes. `size_t` cannot hold -1
# at all and `ssize_t` uses it for "nothing read", so neither of them
# answers yes-or-no questions; something like `getcwd`, which hands back
# its own `buf` or nothing, is a pointer and is settled below instead.
COUNTS = {"size_t", "ssize_t", "off_t"}

# Calls whose answer is a thing, which is the one sort of thing a header
# cannot say: their type is a plain `int` and so is `close`'s, and it is
# only the meaning of the call that tells them apart. Each entry is what
# the answer actually is, written out in the report.
ANSWERS_WITH = {
    "open": "a descriptor",
    "openat": "a descriptor",
    "creat": "a descriptor",
    "socket": "a descriptor",
    "accept": "a descriptor",
    "dup": "a descriptor, and 0 is one",
    "dup2": "a descriptor, and 0 is one",
    "dup3": "a descriptor, and 0 is one",
    "fileno": "a descriptor",
    "mkstemp": "a descriptor",
    "shm_open": "a descriptor",
    "epoll_create1": "a descriptor",
    "timer_create": "a descriptor",
    "eventfd": "a descriptor",
    "fcntl": "whatever its command asks for",
    "time": "the time",
    "clock": "clock ticks used",
    "times": "clock ticks elapsed",
    "alarm": "how many seconds the last alarm had left",
    "fork": "0 in the child and the child's pid in the parent",
    "wait": "the pid it waited for",
    "waitpid": "the pid it waited for",
    "getpid": "a pid",
    "getppid": "a pid",
    "getsid": "a session id",
    "setsid": "a session id",
    "getpgid": "a process group id",
    "system": "a wait status, which `libc.sys.wait` reads",
    "rand": "the number it drew",
    "rand_r": "the number it drew",
    "abs": "the number",
    "atoi": "the number",
    "isatty": "1 or 0 for yes or no, and 0 is no",
}

# Ways of saying failure is -1. Only these count, because a docstring
# explaining that it is *not* -1 says the word too, and it is right.
SAYS_MINUS_ONE = re.compile(
    r"(?:-1|minus one)\s+(?:on|for|with|means|to mean)\s+(?:error|failure|an error)",
    re.IGNORECASE,
)
SAYS_ZERO_SUCCESS = re.compile(r"0\s+on\s+success", re.IGNORECASE)


def returns_sections() -> dict[tuple[str, str], str]:
    """{(file, function): what its docstring says under Returns}.

    Two spellings of the heading are in use here and both mean it, and a
    `Return Value:` written out is the same thing as a `Returns:`.
    """
    found: dict[tuple[str, str], str] = {}
    for path in sorted(SRC.rglob("*.mojo")):
        src = path.read_text()
        for m in re.finditer(r"\ndef (\w+)\((?:[^)]|\n)*?\)(?:\s*->\s*[^:]+?)?:\n\s*\"\"\"(.*?)\"\"\"", src, re.S):
            name, doc = m.group(1), m.group(2)
            rv = re.search(
                r"(?:^|\n)\s*Return(?:s| Value):\s*\n((?:\s+.*\n?)+)", doc
            )
            if rv:
                found[(str(path.relative_to(ROOT)), name)] = " ".join(
                    rv.group(1).split()
                )
    return found


def main() -> int:
    prototypes = read_prototypes()
    if not prototypes:
        return 0

    said = returns_sections()
    problems: list[str] = []
    asked = 0

    for path, name, symbol, _passed, _mojo_return, _params in bindings():
        section = said.get((path, name))
        if not section:
            continue
        if symbol not in prototypes:
            continue
        asked += 1
        where = f"{path}: {name}() calls {symbol}()"
        c_return = prototypes[symbol][3].strip()
        plain = c_return.lstrip("_")

        # gcc settles this one: a count cannot be a yes.
        if plain in COUNTS and SAYS_ZERO_SUCCESS.search(section):
            problems.append(
                f"{where}, which returns {c_return}: a number of bytes or an"
                " offset, so '0 on success' sends a caller away thinking it"
                " failed, or worse, that it finished"
            )
            continue

        # And this one: a pointer has no -1 to hand back, it has NULL.
        if "*" in c_return and SAYS_MINUS_ONE.search(section):
            problems.append(
                f"{where}, which returns {c_return}: -1 is not a value a"
                " pointer can hold, and nothing this one does sets it"
            )
            continue

        # Which leaves the ones only the meaning of the call can settle.
        if name in ANSWERS_WITH and SAYS_ZERO_SUCCESS.search(section):
            problems.append(
                f"{where}, which answers with {ANSWERS_WITH[name]}, so 0 is"
                " not it reporting having worked"
            )

    if problems:
        print(f"{len(problems)} binding(s) describe a return value they do not have:\n")
        for problem in problems:
            print(f"  {problem}")
        print("\nwhat each of them hands back is what its callers test")
        return 1

    print(f"all {asked} documented bindings describe the value they hand back")
    return 0


if __name__ == "__main__":
    sys.exit(main())
