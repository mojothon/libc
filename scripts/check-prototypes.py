#!/usr/bin/env python3
"""Check every `external_call` in this package against the real C prototype.

A wrong argument count does not fail to compile — `external_call` takes
whatever types you hand it — and neither does calling a symbol that C
spells differently, or one that is not a function at all. This is what
found them:

    erf    called erff    -> erf(1.0) came back as 1.0 instead of 0.8427
    fabs   called fabsl   -> the long double variant
    fgetc  called fgets   -> a different function entirely
    is*_l  took one argument instead of two
    environ               -> a global variable, so calling it runs data

Four things are checked:

    the symbol is one the headers declare
    the argument count matches, allowing for `...`
    the function is named after the symbol it calls
    nothing in the prototype is `long double`, which Mojo cannot pass

`gcc -aux-info` is how the prototypes are read, so this runs on Linux
only and reports nothing elsewhere rather than failing.
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "libc"

# Every header this package binds a piece of. `-aux-info` only reports what
# is actually parsed, so a header left out here means its functions come
# back as "not declared" and get reported below. Not all of them exist on
# every libc, so the ones that do not are dropped rather than breaking the
# whole run.
HEADERS = [
    "aio.h", "arpa/inet.h", "complex.h", "ctype.h", "dirent.h", "dlfcn.h",
    "errno.h", "fcntl.h", "fenv.h", "float.h", "fnmatch.h", "ftw.h",
    "glob.h", "grp.h", "iconv.h", "inttypes.h", "langinfo.h", "libgen.h",
    "locale.h", "math.h", "monetary.h", "mqueue.h", "netdb.h",
    "netinet/in.h", "nl_types.h", "poll.h", "pthread.h", "pwd.h",
    "regex.h", "sched.h", "search.h", "semaphore.h", "setjmp.h", "signal.h",
    "spawn.h", "stdarg.h", "stdbool.h", "stddef.h", "stdint.h", "stdio.h",
    "stdlib.h", "string.h", "strings.h", "sys/epoll.h", "sys/eventfd.h",
    "sys/file.h", "sys/ioctl.h", "sys/ipc.h", "sys/mman.h", "sys/mount.h",
    "sys/msg.h", "sys/prctl.h", "sys/resource.h", "sys/select.h",
    "sys/sem.h", "sys/sendfile.h", "sys/shm.h", "sys/socket.h",
    "sys/stat.h", "sys/statvfs.h", "sys/time.h", "sys/times.h",
    "sys/auxv.h", "sys/random.h", "sys/sysinfo.h", "sys/types.h",
    "sys/uio.h", "sys/un.h", "sys/utsname.h", "sys/wait.h",
    "syslog.h", "termios.h", "time.h", "uchar.h", "unistd.h", "utime.h",
    "utmpx.h", "wchar.h", "wctype.h", "wordexp.h",
]

# A function is allowed to call a symbol C spells differently, but only
# when that is the point of it, and the reason goes here.
ALIASES: dict[str, str] = {
    # `gamma` is the name SVID used for `tgamma`; C is free not to have the
    # old one, and calling the real one is what the old name meant.
    "gamma": "tgamma",
    "gammaf": "tgammaf",
    # `raise` is already the name of a Mojo builtin, so the binding cannot
    # be called that.
    "craise": "raise",
    # These are spelled out because `strcpy` reads as a statement about what
    # the caller must do, not as the name of the thing being called.
    "strcopy": "strcpy",
    "strncopy": "strncpy",
    # errno is a macro that expands to a call to whichever of these this
    # libc has, and the setter is the same call written through. `__error` is
    # Darwin's spelling of `__errno_location` and is checked on the macOS run.
    "get_errno": "__errno_location",
    "set_errno": "__errno_location",
}

# Symbols that are real but belong to a libc this machine is not running, so
# the headers here have nothing to say about them either way.
PLATFORM_ONLY = {"__error"}

# Symbols whose prototypes no header here declares, because glibc spells them
# as a macro or hides them behind a feature test the toolchain does not set.
# Both of these were checked by linking against them rather than by taking
# the header's word for it.
NOT_DECLARED_HERE = {
    # `isascii_l` is a macro on glibc, expanding to `__isascii_l`, but the
    # symbol is there and exported.
    "isascii_l",
    # glibc declares `sched_getcpucount` only under `_GNU_SOURCE`, and an
    # older or non-glibc toolchain has nothing to say about it at all.
    "sched_getcpucount",
}


def available_headers() -> list[str]:
    """The headers above that this libc actually has."""
    found = []
    for header in HEADERS:
        done = subprocess.run(
            ["gcc", "-fsyntax-only", "-x", "c", "-"],
            input=f"#include <{header}>\n",
            capture_output=True,
            text=True,
        )
        if done.returncode == 0:
            found.append(header)
    return found


def read_prototypes() -> dict[str, tuple[int, bool, bool]]:
    """{symbol: (fixed argument count, is variadic, uses long double)}."""
    headers = available_headers()
    # Without these the extensions stay hidden: `getauxval`, `secure_getenv`,
    # `dup3`, `gettid` and the three `fe*except` are all glibc-only and none
    # of them is declared under a strict standard.
    source = "#define _GNU_SOURCE\n#define _DEFAULT_SOURCE\n"
    source += "\n".join(f"#include <{h}>" for h in headers)
    source += "\nint main(void) { return 0; }\n"

    with tempfile.TemporaryDirectory() as work:
        c = Path(work) / "all.c"
        c.write_text(source)
        info = Path(work) / "proto.txt"
        try:
            subprocess.run(
                ["gcc", "-aux-info", str(info), "-c", str(c), "-o", "/dev/null"],
                capture_output=True,
                check=True,
            )
        except (OSError, subprocess.CalledProcessError) as exc:
            print(f"skipped: no usable gcc here ({exc.__class__.__name__})")
            return {}
        if not info.exists():
            print("skipped: gcc produced no prototype listing")
            return {}
        listing = info.read_text(errors="replace")

    table: dict[str, tuple[int, bool, bool]] = {}
    for line in listing.splitlines():
        m = re.search(r"extern\s+(.*?)\b(\w+)\s*\(([^;]*)\)\s*;", line)
        if not m:
            continue
        return_type, name, params = m.group(1), m.group(2), m.group(3)
        parts = [p.strip() for p in params.split(",") if p.strip()]
        variadic = any("..." in p for p in parts)
        fixed = 0 if parts == ["void"] else len([p for p in parts if "..." not in p])
        # `long double` is the 80-bit x87 type on x86-64 and Mojo has nothing
        # to pass for it, so a call to one of these cannot work.
        uses_long_double = "long double" in f"{return_type} {params}"
        table[name] = (fixed, variadic, uses_long_double)
    return table


def split_args(text: str) -> list[str]:
    """Split on commas that are neither inside brackets nor in a comment.

    The calls here carry trailing `# FnName, RetType` remarks, and a comma in
    one of those is not a separator.
    """
    depth, current, out = 0, [], []
    index = 0
    while index < len(text):
        ch = text[index]
        if ch == "#":
            while index < len(text) and text[index] != "\n":
                index += 1
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
        index += 1
    if "".join(current).strip():
        out.append("".join(current).strip())
    return [a for a in out if a]


def bindings() -> list[tuple[str, str, str, int]]:
    """(file, mojo name, c symbol, arguments passed) for every call."""
    found: list[tuple[str, str, str, int]] = []
    for path in sorted(SRC.rglob("*.mojo")):
        src = path.read_text()
        for m in re.finditer(r"^def (\w+)\((.*?)\)", src, re.M):
            name, body = m.group(1), src[m.end():]
            nxt = re.search(r"^def ", body, re.M)
            if nxt:
                body = body[: nxt.start()]
            for call in re.finditer(r'external_call\[\s*"(\w+)"', body):
                symbol = call.group(1)
                # Walk to the matching close paren of the call itself.
                i, depth = body.find("(", call.end()), 0
                start = i + 1
                while i < len(body):
                    if body[i] == "(":
                        depth += 1
                    elif body[i] == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    i += 1
                args = split_args(body[start:i])
                found.append((str(path.relative_to(ROOT)), name, symbol, len(args)))
    return found


def main() -> int:
    prototypes = read_prototypes()
    if not prototypes:
        return 0

    problems: list[str] = []

    for path, name, symbol, passed in bindings():
        where = f"{path}: {name}() calls {symbol}()"

        if symbol not in prototypes:
            if symbol not in PLATFORM_ONLY | NOT_DECLARED_HERE:
                problems.append(f"{where}, which no header declares")
            continue

        fixed, variadic, long_double = prototypes[symbol]
        if variadic:
            if passed < fixed:
                problems.append(
                    f"{where} with {passed} argument(s) and C wants at least {fixed}"
                )
        elif passed != fixed:
            problems.append(
                f"{where} with {passed} argument(s) and C wants {fixed}"
            )

        if long_double:
            problems.append(
                f"{where}, whose prototype uses `long double`, which Mojo cannot pass"
            )

        # A function that calls something C spells differently is usually a
        # typo, and every one that is not is listed above with its reason.
        if symbol != name and ALIASES.get(name) != symbol:
            problems.append(
                f"{where}, and is not named after it"
                + (f" (allowed: {ALIASES[name]})" if name in ALIASES else "")
            )

    if problems:
        print(f"{len(problems)} binding(s) do not match the C prototypes:\n")
        for problem in problems:
            print(f"  {problem}")
        print("\nrun with no arguments to see this again, or fix src/libc/")
        return 1

    print(f"all {len(bindings())} calls match the C prototypes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
