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

Five things are checked:

    the symbol is one the headers declare
    the argument count matches, allowing for `...`
    the function is named after the symbol it calls
    nothing in the prototype is `long double`, which Mojo cannot pass
    what is passed and handed back is as wide as C says, and signed
    where C says it is

The last one is the only defence against a binding that names a type of
the right kind and the wrong size, which `external_call` accepts without
a word: `getline` used to say `c_uint` for a `ssize_t`, and so answered
4294967295 where it meant -1, the end of the file, and a caller asking
whether the file was done went on reading forever.

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
    # `open` is `openat` with the directory descriptor filled in as
    # `AT_FDCWD`, which is what POSIX says the two amount to. It is called
    # that way and not by its own name because C's `open` is variadic and
    # arm64 Darwin passes variadic arguments on the stack, which an external
    # call cannot express — so `open` here is the one that works there.
    "open": "openat",
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


# A binding may pass or hand back a type of a different size than C
# says, but only where there is a reason, and the reason goes here.
SIZE_EXCEPTIONS: set[str] = set()


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



# How wide a type is, and whether it holds negatives, measured by the
# compiler rather than written down: `gcc` is already the one being asked
# for the prototypes, and a table of widths guessed here would be wrong
# somewhere.
CHARISH_C = {"char", "signed char", "unsigned char"}
CHARISH_MOJO = {"c_char", "c_uchar", "c_schar", "Int8", "UInt8"}

# What Mojo calls its fixed-width types, which is where every `c_*` name
# in `libc.constant` comes to rest. A `None` sign is a float, which has
# no opinion about negatives.
MOJO_SIZES: dict[str, tuple[int, bool | None]] = {
    "Int8": (1, True),
    "UInt8": (1, False),
    "Int16": (2, True),
    "UInt16": (2, False),
    "Int32": (4, True),
    "UInt32": (4, False),
    "Int64": (8, True),
    "UInt64": (8, False),
    "Int": (8, True),
    "UInt": (8, False),
    "Float16": (2, None),
    "Float32": (4, None),
    "Float64": (8, None),
    "BFloat16": (2, None),
}


def strip_qualifiers(c_type: str) -> str:
    """`const char *__restrict` as `char`, which is what is being sized."""
    return " ".join(
        word
        for word in re.findall(r"\w+", c_type)
        if word not in ("const", "__const", "volatile", "restrict", "__restrict")
    )


def c_base_types(
    prototypes: dict[str, tuple[int, bool, bool, str, tuple[str, ...]]]
) -> set[str]:
    """Every plain type the prototypes mention, without its decorations."""
    found: set[str] = set()
    for _, _, _, returns, params in prototypes.values():
        for c_type in (returns, *params):
            base = strip_qualifiers(c_type)
            if base and c_kind(base) in ("integer", "float"):
                found.add(base)
    return found


def compile_and_run(prelude: str, lines: list[str]) -> str:
    """Build and run the program made of these lines, less what will not build.

    `-aux-info` hands back the odd type that C will not take as one —
    `int char int` was in the listing — so rather than guess which, the
    lines the compiler objects to are dropped and the rest is asked
    again. Only a handful of lines survive that, and they are not types
    anybody is calling with.
    """
    kept = list(lines)
    for _ in range(5):
        source = prelude + "\nint main(void) {\n" + "\n".join(kept)
        source += "\n    return 0;\n}\n"
        with tempfile.TemporaryDirectory() as work:
            c = Path(work) / "sizes.c"
            c.write_text(source)
            exe = Path(work) / "sizes"
            built = subprocess.run(
                ["gcc", str(c), "-o", str(exe)], capture_output=True, text=True
            )
            if built.returncode == 0:
                ran = subprocess.run([str(exe)], capture_output=True, text=True)
                return ran.stdout
            # The first line of the body sits three lines past the last
            # newline of the prelude: the newline that ends its final
            # line, the `int main` line, and the newline ending that.
            offset = prelude.count("\n") + 3
            dropped = {
                int(m.group(1)) - offset
                for m in re.finditer(r":(\d+):\d+: error", built.stderr)
            }
            if not dropped:
                print("skipped: the sizes program did not compile")
                return ""
            kept = [line for i, line in enumerate(kept) if i not in dropped]
    return ""


def measure_c_types(types: set[str]) -> dict[str, tuple[int, bool]]:
    """What `gcc` says each of these is: how wide, and whether signed.

    Two programs rather than one, because a name ending in `_t` is a
    promise about how a type is meant to be read and not a promise that
    it is a number: `__sigset_t` and `cpu_set_t` are structs, and asking
    one of those whether it is less than zero does not compile. So the
    first pass asks what each type is made of, and only the ones made of
    a number are asked about their sign in the second.
    """
    if not types:
        return {}
    headers = available_headers()
    prelude = "#define _GNU_SOURCE\n#define _DEFAULT_SOURCE\n#include <stdio.h>\n"
    prelude += "\n".join(f"#include <{h}>" for h in headers)

    # `__builtin_classify_type` says what a type is without asking the
    # type any question it cannot answer: 1 is an integer, 8 is a float,
    # and 12, 13 and 14 are a struct, a union and an array.
    names = sorted(types)
    kinds = compile_and_run(
        prelude,
        [
            '    { %s v; printf("%%s %%zu %%d\\n", "%s", sizeof(v),'
            " __builtin_classify_type(v)); }" % (name, name)
            for name in names
        ],
    )
    classified: dict[str, tuple[int, int]] = {}
    for line in kinds.splitlines():
        name, width, kind = line.rsplit(" ", 2)
        classified[name] = (int(width), int(kind))

    numbers = [n for n in names if classified.get(n, (0, 0))[1] in (1, 2, 3, 4)]
    signs = {}
    for line in compile_and_run(
        prelude,
        [
            '    printf("%%s %%d\\n", "%s", (int)((%s)-1 < (%s)0));' % (n, n, n)
            for n in numbers
        ],
    ).splitlines():
        name, value = line.rsplit(" ", 1)
        signs[name] = value == "1"

    # Only a number can be signed, so only a number is worth comparing.
    return {
        name: (width, signs.get(name, True))
        for name, (width, kind) in classified.items()
        if kind in (1, 2, 3, 4)
    }


def mojo_aliases() -> dict[str, str]:
    """The `c_*` and `*_t` names `libc.constant` gives to Mojo types."""
    aliases: dict[str, str] = {}
    for path in sorted((SRC / "constant").rglob("*.mojo")):
        text = path.read_text()
        for m in re.finditer(
            r"^comptime (\w+)\s*(?::[^=]+)?=\s*([A-Za-z_]\w*)$", text, re.M
        ):
            aliases[m.group(1)] = m.group(2)
    return aliases


def mojo_measure(
    mojo_type: str, aliases: dict[str, str]
) -> tuple[int, bool | None] | None:
    """Follow `c_int` to `Int32` to four bytes and signed."""
    seen: set[str] = set()
    name = mojo_type.strip()
    while name in aliases and name not in seen:
        seen.add(name)
        name = aliases[name]
    return MOJO_SIZES.get(name)


def peel(c_type: str, mojo_type: str) -> tuple[str, str]:
    """Follow `T *` and `c_ptr[T]` down together to what they point at.

    `size_t *` against `c_ptr[c_uint]` is the same mistake as `size_t`
    against `c_uint`, one step down: libc writes eight bytes where the
    caller was told to keep four.
    """
    while True:
        inner = re.fullmatch(
            r"(?:c_ptr|Pointer|UnsafePointer)\[(.+)\]", mojo_type.strip()
        )
        if c_type.count("*") and inner:
            c_type = c_type.replace("*", "", 1).strip()
            mojo_type = inner.group(1).strip()
            continue
        return c_type, mojo_type


def declared_structs() -> set[str]:
    """The names of the structs this package declares, lowercased."""
    names: set[str] = set()
    for path in sorted(SRC.rglob("*.mojo")):
        for m in re.finditer(r"^struct (\w+)", path.read_text(), re.M):
            names.add(m.group(1).lower())
    return names


def struct_mismatch(
    c_pointed: str, mojo_pointed: str, structs: set[str]
) -> tuple[str, str] | None:
    """`(wanted, given)` when C points at one named struct and Mojo at
    another one, or None when that is not what is happening.

    A pointer is eight bytes whatever it points at, so the sizes agree
    and nothing above has anything to say: `utime` was handed a
    `timeval` where C asked for a `utimbuf`, and it compiled, ran and
    answered 0 while writing the microseconds field into the modified
    time. Only the name of what is pointed at tells the two apart.

    A pointer to `UInt8` or to nothing in particular is left alone:
    that is how an opaque one is written here, and it is not wrong.
    """
    m = re.search(r"struct\s+(\w+)", c_pointed)
    if not m:
        return None
    given = mojo_pointed.strip()
    if given.lower() not in structs:
        return None
    wanted = m.group(1)
    return None if given.lower() == wanted.lower() else (wanted, given)


def size_problem(
    c_type: str,
    mojo_type: str,
    measures: dict[str, tuple[int, bool]],
    aliases: dict[str, str],
    carrying_back: bool = False,
) -> tuple[str, str] | None:
    """How the two disagree, and how much it matters, or None.

    Handing C fewer bytes than it asks for is the one that breaks: it
    reads the rest of the register, which is whatever was there. Handing
    it more is harmless, because it takes the low end and ignores the
    rest, and so is handing it a sign that differs on the way in — what
    goes in is the same bits either way, and a size nobody means as
    negative is the same number read as either. Those are counted and
    printed, and do not fail the run.

    A sign that differs on the way out is another matter, and the one
    way round that breaks is C saying signed and the binding saying
    unsigned: what C means as -1 comes back as the largest number the
    unsigned type holds, which is how `getline` and `getrandom` both
    lost the end of the file and the failure they were reporting. So
    that one fails the run when `carrying_back` is set, and the other
    way round — a `size_t` read into an `Int` — does not, being the same
    eight bits for every value either can honestly hold.
    """
    base = strip_qualifiers(c_type)
    c_size = measures.get(base)
    m_size = mojo_measure(mojo_type, aliases)
    if c_size is None or m_size is None:
        return None
    c_width, c_signed = c_size
    m_width, m_signed = m_size
    if c_width != m_width:
        return (
            f"{c_width} byte(s) in C and {m_width} in Mojo",
            "narrow" if m_width < c_width else "wide",
        )
    # Whether a `char` is signed is the machine's to say, and a byte is a
    # byte either way, so a char on either side is not a disagreement.
    if m_signed is None or base in CHARISH_C or mojo_type.strip() in CHARISH_MOJO:
        return None
    if c_signed != m_signed:
        return (
            "signed in C and unsigned in Mojo"
            if c_signed
            else "unsigned in C and signed in Mojo",
            "narrow" if c_signed and carrying_back else "sign",
        )
    return None

def main() -> int:
    prototypes = read_prototypes()
    if not prototypes:
        return 0

    problems: list[str] = []
    notes: dict[str, list[str]] = {"wide": [], "sign": []}

    # Asked of `gcc` once, for every plain type the prototypes mention.
    measures = measure_c_types(c_base_types(prototypes))
    aliases = mojo_aliases()

    def record(off: tuple[str, str], line: str) -> None:
        if off[1] == "narrow":
            problems.append(line)
        else:
            notes[off[1]].append(line)

    structs = declared_structs()
    for path, name, symbol, passed, mojo_return, mojo_params in bindings():
        where = f"{path}: {name}() calls {symbol}()"

        # `external_call` is told the type of each thing it is to pass along,
        # and a binding that leaves them out of the list still compiles: it
        # hands the arguments over without knowing what they are. Integers and
        # pointers land in the right registers by luck of the calling
        # convention, which is why twenty-seven here sat that way unnoticed.
        if len(mojo_params) != passed:
            problems.append(
                f"{where} with {passed} argument(s) and {len(mojo_params)}"
                " type(s) in its list, so `external_call` is not told what"
                " it is passing"
            )

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
        elif symbol not in RETURN_EXCEPTIONS:
            # Same kind, so it compiles and runs. That is not the same as
            # agreeing about how much the answer is.
            inner_c, inner_mojo = peel(c_return, mojo_return)
            off = size_problem(
                inner_c, inner_mojo, measures, aliases, carrying_back=True
            )
            if off and symbol not in SIZE_EXCEPTIONS:
                record(
                    off,
                    f"{where}, which returns {c_return} and is told it"
                    f" returns {mojo_return}, which is {off[0]}",
                )

        # The same for each argument. A `double` passed as an `Int32` is
        # accepted and then read as whatever those bits mean, and an address
        # passed as an `Int32` is an address that stops being one.
        for place, (c_param, mojo_param) in enumerate(
            zip(c_params[:fixed], mojo_params[:fixed]), start=1
        ):
            want, got = c_kind(c_param), mojo_kind(mojo_param)
            if (
                want != got
                and "opaque" not in want
                and "struct" not in (want, got)
                and (symbol, place) not in ARGUMENT_EXCEPTIONS
            ):
                problems.append(
                    f"{where} with {mojo_param} as argument {place}, where C"
                    f" takes {c_param} ({want}, not {got})"
                )
                continue
            inner_c, inner_mojo = peel(c_param, mojo_param)
            off = size_problem(inner_c, inner_mojo, measures, aliases)
            if off and (symbol, place) not in ARGUMENT_EXCEPTIONS:
                record(
                    off,
                    f"{where} with {mojo_param} as argument {place}, where C"
                    f" takes {c_param}, which is {off[0]}",
                )

            named = struct_mismatch(inner_c, inner_mojo, structs)
            if named:
                problems.append(
                    f"{where} with {mojo_param} as argument {place}, where C"
                    f" takes {c_param}, which points at `struct {named[0]}`"
                    f" rather than at {named[1]}"
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

    for kind, lines in notes.items():
        if not lines:
            continue
        if kind == "wide":
            print(
                f"{len(lines)} place(s) hand C more bytes than it asks for,"
                " which it takes the low end of and ignores the rest"
            )
        else:
            print(
                f"{len(lines)} place(s) hand C a type of the same width and"
                " the other sign, which reads the same until the value is"
                " past what the signed one can hold"
            )
    if notes:
        print()

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
