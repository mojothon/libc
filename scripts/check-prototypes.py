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
    # C's name for this one is `mempcpy`, which reads as a spelling mistake
    # next to the rest of the `mem*` family, so the binding spells it with
    # the "co" of "copy" that the others do not have.
    "mempcopy": "mempcpy",
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
    # `mempcpy` is declared as a macro over `__mempcpy` here, but the symbol
    # is exported and links.
    "mempcpy",
}

# A binding may say the result is something other than what C says, but only
# when the difference is the point of it.
RETURN_EXCEPTIONS = {
    # `signal` returns the handler that was there before, which is a pointer
    # to a function. Mojo has no type for one, so the binding returns its
    # address instead.
    "signal",
}

# (symbol, argument position) pairs that pass something other than what C
# says, but only where that is the only way to make the call at all.
ARGUMENT_EXCEPTIONS = {
    # `std.io` declares `fclose` itself, and a second `external_call` for
    # the same symbol that takes a `Pointer` fails to lower with "existing
    # function with conflicting signature". The address goes as an `Int`
    # instead, which is the same eight bytes in the same integer register
    # on every ABI this package targets.
    ("fclose", 1),
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


def read_prototypes() -> dict[str, tuple[int, bool, bool, str, tuple[str, ...]]]:
    """{symbol: (fixed count, variadic, long double, returns, parameter types)}."""
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

    table: dict[str, tuple[int, bool, bool, str, tuple[str, ...]]] = {}
    for line in listing.splitlines():
        m = re.search(r"extern\s+(.*?)\b(\w+)\s*\(([^;]*)\)\s*;", line)
        if not m:
            continue
        return_type, name, params = m.group(1).strip(), m.group(2), m.group(3)
        # A parameter carries a comma of its own when it is a pointer to a
        # function, as in the `void (*)(void)` that `atexit` takes.
        parts = [p.strip() for p in split_args(params) if p.strip()]
        variadic = any("..." in p for p in parts)
        fixed_parts = [p for p in parts if "..." not in p]
        fixed = 0 if fixed_parts == ["void"] else len(fixed_parts)
        # `long double` is the 80-bit x87 type on x86-64 and Mojo has nothing
        # to pass for it, so a call to one of these cannot work.
        uses_long_double = "long double" in f"{return_type} {params}"
        # Only the fixed parameters, and only their types: the name a header
        # gave one is not part of the call.
        parameter_types = tuple(
            c_parameter_type(p) for p in ([] if fixed == 0 else fixed_parts)
        )
        table[name] = (
            fixed,
            variadic,
            uses_long_double,
            return_type,
            parameter_types,
        )
    return table


# The words a type can be made of that are not the name of the parameter.
C_TYPE_WORDS = {
    "void", "char", "short", "int", "long", "float", "double", "signed",
    "unsigned", "_Bool", "const", "__const", "volatile", "restrict",
    "__restrict", "struct", "union", "enum", "complex", "_Complex",
}


def c_parameter_type(param: str) -> str:
    """The type in `const char *__restrict __s`, which is `const char *`."""
    stripped = param.strip()
    m = re.match(r"^(?P<type>.*?)\s*(?P<name>\w+)$", stripped)
    if not m:
        return stripped
    type_, name = m.group("type").strip(), m.group("name")
    # With no parameter name to drop, the last word belongs to the type, as
    # in `unsigned int`.
    if not type_ or name in C_TYPE_WORDS or name.endswith("_t"):
        return stripped
    return type_


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


def module_counts() -> dict[str, int]:
    """{package: functions, structs and public constants it defines}.

    What the number in `docs/modules.md` counts. `libc.float` defines no
    function at all and is listed as 30, which is the number of `FLT_*` and
    `DBL_*` limits C puts in the header, so a count of functions alone would
    call it zero.
    """
    counts: dict[str, int] = {}
    for path in sorted(SRC.rglob("*.mojo")):
        if path.name == "__init__.mojo" or path.parent == SRC:
            continue
        text = path.read_text()
        package = "libc." + str(path.parent.relative_to(SRC)).replace("/", ".")
        defined = re.findall(r"^(?:def|struct|comptime) (\w+)", text, re.M)
        # A leading underscore is private and a `c_` prefix is a type, and
        # neither is a thing the package hands out.
        public = [
            name
            for name in defined
            if not name.startswith("_") and not name.startswith("c_")
        ]
        counts[package] = counts.get(package, 0) + len(public)
    return counts


def documented_counts() -> dict[str, int]:
    """What `docs/modules.md` says each package has."""
    counts: dict[str, int] = {}
    for line in (ROOT / "docs" / "modules.md").read_text().splitlines():
        m = re.match(r"^\|\s*`(libc(?:\.\w+)+)`\s*\|.*\|\s*(\d+)\s*\|\s*$", line)
        if m:
            counts[m.group(1)] = int(m.group(2))
    return counts


def bindings() -> list[tuple[str, str, str, int, str, tuple[str, ...]]]:
    """(file, mojo name, symbol, arguments passed, return, argument types)."""
    found: list[tuple[str, str, str, int, str, tuple[str, ...]]] = []
    for path in sorted(SRC.rglob("*.mojo")):
        src = path.read_text()
        for m in re.finditer(r"^def (\w+)\(", src, re.M):
            name = m.group(1)
            # A signature can run over several lines, so count brackets to
            # find the one that closes the argument list.
            end, depth = m.end() - 1, 0
            while end < len(src):
                if src[end] == "(":
                    depth += 1
                elif src[end] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                end += 1

            after = src[end + 1 :]
            returns = re.match(r"\s*->\s*([^:]+?)\s*:", after)
            if returns:
                mojo_return, body_start = (
                    returns.group(1),
                    end + 1 + returns.end(),
                )
            else:
                mojo_return, body_start = "None", end + 1 + after.index(":") + 1

            body = src[body_start:]
            nxt = re.search(r"^def ", body, re.M)
            if nxt:
                body = body[: nxt.start()]
            for call in re.finditer(r"external_call\[", body):
                # The type list runs to the bracket that closes the one that
                # opened it: `"symbol", return type, argument types...`.
                j, depth = call.end() - 1, 0
                while j < len(body):
                    if body[j] == "[":
                        depth += 1
                    elif body[j] == "]":
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                types = split_args(body[call.end() : j])
                if not types or not types[0].startswith('"'):
                    continue
                symbol = types[0].strip().strip('"')
                # What the binding tells `external_call` the result is, which
                # is what decides the value handed back, whatever the `def`
                # says. `get_errno` says `Int32` here and dereferences what
                # comes back, so the pointer is the thing to compare.
                mojo_return = types[1].strip() if len(types) > 1 else "None"

                # Walk to the matching close paren of the call itself.
                i, depth = body.find("(", j), 0
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
                found.append(
                    (
                        str(path.relative_to(ROOT)),
                        name,
                        symbol,
                        len(args),
                        mojo_return,
                        tuple(t.strip() for t in types[2:]),
                    )
                )
    return found


# What a type is for, in the only terms the two languages can be compared
# in. Anything that is none of these is a struct, and a struct returned by
# value is not something this can have an opinion about.
POINTERISH = ("c_ptr", "Pointer", "UnsafePointer", "c_string", "c_immutable")
FLOATISH = ("Float32", "Float64", "c_float", "c_double", "Float16", "BFloat16")
INTISH = (
    "Int", "UInt", "Bool", "c_int", "c_uint", "c_long", "c_short", "c_char",
    "c_uchar", "c_schar", "c_size_t", "c_ssize_t", "size_t", "ssize_t",
)


# Typedefs this cannot see through. A pointer to a function is one of these
# and is an address like any other, so passing a pointer for one is right.
OPAQUE_C = {
    "__compar_fn_t", "__compar_d_fn_t", "__sighandler_t", "va_list",
    "__va_list_tag", "mbstate_t", "fenv_t", "fexcept_t", "FILE",
}
INT_WORDS = {"char", "short", "int", "long", "signed", "unsigned", "_Bool"}


def c_kind(c_type: str) -> str:
    if "*" in c_type:
        return "pointer"
    if c_type == "void":
        return "nothing"
    # A complex is two floats carried as one value, which is what the Mojo
    # side models with a struct.
    if "struct" in c_type or "union" in c_type or "complex" in c_type:
        return "struct"
    words = [
        word
        for word in re.findall(r"\w+", c_type)
        if word not in ("const", "volatile", "restrict", "__restrict")
    ]
    if not words or any(word in OPAQUE_C for word in words):
        return "opaque"
    if "double" in words or "float" in words:
        return "float"
    if all(word in INT_WORDS or word.endswith("_t") for word in words):
        return "integer"
    return "opaque"


def mojo_kind(mojo_type: str) -> str:
    if any(mojo_type.startswith(kind) for kind in POINTERISH):
        return "pointer"
    if mojo_type in ("None", ""):
        return "nothing"
    if mojo_type in FLOATISH:
        return "float"
    if any(mojo_type.startswith(kind) for kind in INTISH):
        return "integer"
    return "struct"


def main() -> int:
    prototypes = read_prototypes()
    if not prototypes:
        return 0

    problems: list[str] = []

    for path, name, symbol, passed, mojo_return, mojo_params in bindings():
        where = f"{path}: {name}() calls {symbol}()"

        if symbol not in prototypes:
            if symbol not in PLATFORM_ONLY | NOT_DECLARED_HERE:
                problems.append(f"{where}, which no header declares")
            continue

        fixed, variadic, long_double, c_return, c_params = prototypes[symbol]
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

        # `external_call` hands back whatever it is told the result is, so a
        # binding that says `Int32` over a C function returning `char *` will
        # hand out a truncated address and never say a word about it.
        want, got = c_kind(c_return), mojo_kind(mojo_return)
        if (
            want != got
            and "struct" not in (want, got)
            and symbol not in RETURN_EXCEPTIONS
        ):
            problems.append(
                f"{where}, which returns {c_return}, so it cannot return"
                f" {mojo_return} ({want}, not {got})"
            )

        # The same for each argument. A `double` passed as an `Int32` is
        # accepted and then read as whatever those bits mean, and an address
        # passed as an `Int32` is an address that stops being one.
        for place, (c_param, mojo_param) in enumerate(
            zip(c_params[:fixed], mojo_params[:fixed]), start=1
        ):
            want, got = c_kind(c_param), mojo_kind(mojo_param)
            if (
                want == got
                or "opaque" in want
                or "struct" in (want, got)
                or (symbol, place) in ARGUMENT_EXCEPTIONS
            ):
                continue
            problems.append(
                f"{where} with {mojo_param} as argument {place}, where C"
                f" takes {c_param} ({want}, not {got})"
            )

        # A function that calls something C spells differently is usually a
        # typo, and every one that is not is listed above with its reason.
        if symbol != name and ALIASES.get(name) != symbol:
            problems.append(
                f"{where}, and is not named after it"
                + (f" (allowed: {ALIASES[name]})" if name in ALIASES else "")
            )

    # `docs/modules.md` puts a number next to every package, and a number
    # nobody checks is a number that stops being true the moment a function
    # is added.
    for package, documented in sorted(documented_counts().items()):
        actual = module_counts().get(package, 0)
        if actual != documented:
            problems.append(
                f"docs/modules.md: {package} is listed as {documented} and"
                f" defines {actual}"
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
