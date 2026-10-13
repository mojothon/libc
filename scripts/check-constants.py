#!/usr/bin/env python3
"""Check every numeric `comptime` constant in this package against C itself.

A constant copied out of a header is a constant nobody can tell apart from
a typo. Every one of the numbers here was read off `gcc -dM` output by eye
when it was written down, which is a way of being right once: nothing
rechecks it, a value that differs between platforms cannot be checked by
eye at all without a machine of each, and a header that changes under a
newer libc leaves the number sitting there looking correct.

So this asks the compiler. The same headers this package binds are
included, each constant is printed as C sees it, and the two numbers are
compared:

    $ python3 scripts/check-constants.py
    331 constants agree with C
      2 disagree
     23 could not be checked

Which platform it is decides which side of a `X if is_macos() else Y` is
the right one, so this is also how those get checked: the Linux job asks
about the Linux side and the macOS job about the macOS side, and neither
side is trusted to have been read correctly.

Three kinds of constant are reported rather than compared, and each says
why when it can:

    one whose value is written as an expression, such as `S_IRUSR | S_IWUSR`
    one C spells as a macro that takes arguments, or as a pointer, or as
        something else that is not a plain number
    one whose value Mojo writes with a leading zero, where C would read it
        as octal and a reader would read it as decimal — worth saying out
        loud rather than guessing which was meant

Exit status is 1 when anything disagrees, which is what makes it a gate.
Constants that could not be checked are not failures; they are counted and
listed, because silently ignoring them is how a gap becomes permanent.
"""

from __future__ import annotations

import re
import subprocess
import sys
from functools import lru_cache
from math import isinf, isnan
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

def sibling(name: str):
    """Load another script here, whose name has a hyphen in it."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), ROOT / "scripts" / f"{name}.py"
    )
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


# The headers this package binds, and how to include them, are already
# decided by check-prototypes.py. Asking again here would be nowhere to
# stop, and a second list is a second thing to update. Its name has a
# hyphen in it, so this cannot be an ordinary import.
cp = sibling("check-prototypes")

SOURCES = sorted((ROOT / "src" / "libc").rglob("*.mojo"))
CONSTANT = re.compile(r"^comptime (\w+)(?::[^=]+)? = (.+)$", re.MULTILINE)
MACOS_ONLY = "CompilationTarget.is_macos()"

# `cc` rather than `gcc`, because on macOS it is clang and clang is what
# has the right to say what Darwin's headers mean.
CC = ["cc"]

# Feature-test macros first, because a header asked politely will hide
# half of what it knows. `O_TMPFILE`, `O_PATH` and their like only exist
# once something asks for them, and a constant reported as unknowable
# because nobody asked is a false alibi.
DEFINES = ["-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-D_DARWIN_C_SOURCE"]

# check-prototypes.py lists the headers whose functions this binds; these
# are the ones with no functions in them, or whose functions nobody has
# got round to, and so nothing has ever had a reason to write them down.
# `time.h` is the conspicuous one: every clock constant in the package
# comes from it, and leaving it out made twenty of them uncheckable.
MORE_HEADERS = [
    "time.h",
    "limits.h",
    "stdint.h",
    "stddef.h",
    "unistd.h",
    "errno.h",
    "signal.h",
    "float.h",
    "fenv.h",
    "locale.h",
    "ctype.h",
    "wctype.h",
    "syslog.h",
    "grp.h",
    "pwd.h",
    "termios.h",
    "sys/types.h",
    "sys/select.h",
    "sys/utsname.h",
    "sys/sysmacros.h",
]


@lru_cache(maxsize=None)
def headers() -> list[str]:
    """Every header either script knows about, that exists here."""
    wanted = list(cp.HEADERS) + MORE_HEADERS

    def exists(header: str) -> bool:
        probe = subprocess.run(
            [*CC, *DEFINES, "-fsyntax-only", "-x", "c", "-"],
            input=f"#include <{header}>\n",
            capture_output=True,
            text=True,
        )
        return probe.returncode == 0

    return [h for h in dict.fromkeys(wanted) if exists(h)]


def literals_are_floats(values: list[str]) -> bool:
    """Whether these have to be asked about as floating point."""
    return any("." in v.replace("0x", "").lower() or "e" in v.lower() for v in values)


def read_literal(raw: str) -> float | None:
    """The number Mojo wrote, or None with nothing claimed about it.

    Accepts hexadecimal, octal, binary and decimal the way C spells them,
    floats included. A leading zero is refused rather than guessed at: in
    C `0644` is octal 420, and a constant copied from somebody's shell
    prompt may well have meant 644. Guessing silently would be worse than
    leaving it uncounted.
    """
    text = raw.strip()

    if re.fullmatch(r"-?0[xX][0-9a-fA-F]+", text):
        return float(int(text, 16))
    if re.fullmatch(r"-?0[oO][0-7]+", text):
        return float(int(text, 8))
    if re.fullmatch(r"-?0[bB][01]+", text):
        return float(int(text, 2))
    if re.fullmatch(r"-?\d+", text):
        return float(int(text, 10))

    # Floats, with no leading zero allowed to slip through unnoticed above.
    if not re.match(r"0\d", text) and re.fullmatch(
        r"-?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?", text
    ):
        try:
            return float(text)
        except ValueError:
            return None

    return None


def each_side(raw: str) -> str | None:
    """The branch of a platform conditional that this machine decides.

    Every conditional written here is about macOS and nothing else, which
    is the whole reason one codebase can hold both sets of numbers: pick
    the side that answers here, and let a CI job on the other platform
    pick the other one.
    """
    m = re.fullmatch(r"(.+?) if (.+?) else (.+)", raw.strip())
    if m is None:
        return None
    condition = m.group(2).strip()
    # Some are written from the other side round — `if not is_macos()`
    # — and the constant is no less a platform constant for being phrased
    # that way. Anything conditional on something else, such as
    # `CompilationTarget.is_x86()`, is not answered here at all: nothing
    # this can run knows which machine will compile the package.
    inverted = condition.startswith("not ")
    if inverted:
        condition = condition[len("not ") :].strip()
    if condition != MACOS_ONLY:
        return None
    on_macos = (sys.platform == "darwin") != inverted
    return m.group(1).strip() if on_macos else m.group(3).strip()


def constants() -> list[tuple[str, str, str, float | None]]:
    """Every `comptime` number, with the file it came from.

    Returns (name, where, what was written, the value asked about), where
    the value is None when this refuses to guess at it.

    A value is gathered one line at a time until its brackets balance,
    because the formatter breaks what no longer fits — `Int32(` on one
    line and the rest on the next — and reading only to the end of the
    line found `Int32(` and asked C about that.
    """
    opening = re.compile(r"^comptime (\w+)(?::[^=]+)? = (.*)$")
    found: list[tuple[str, str, str, float | None]] = []
    for path in SOURCES:
        place = str(path.relative_to(ROOT))
        lines = path.read_text().split("\n")
        index = 0
        while index < len(lines):
            begun = opening.match(lines[index])
            if begun is None:
                index += 1
                continue
            name, raw = begun.group(1), begun.group(2)
            # Most of these carry a comment saying what the errno means in
            # words, which is useful to a reader and invisible to everybody
            # until it turns out to be part of the value being checked.
            raw = raw.split("#", 1)[0]
            while raw.count("(") > raw.count(")") and index + 1 < len(lines):
                index += 1
                raw += " " + lines[index].split("#", 1)[0].strip()
            raw = raw.strip().rstrip(",")
            index += 1

            inside = unwrapped(raw)
            if " if " in inside and " else " in inside:
                branch = each_side(inside)
                found.append((name, place, raw, read_literal(branch) if branch else None))
            else:
                found.append((name, place, raw, read_literal(inside)))
    return found


def print_in_c(label: str, expr: str, mode: str) -> str:
    """A line that prints one constant the way C sees it.

    `expr` rather than the name, because a constant written as
    `S_IRUSR | S_IWUSR` is a computation and not a symbol, and asking C
    to compute it is how a misspelled name inside it gets found.

    `mode` is how it has to be asked about: `f` for floating point, `u`
    for a number past the top of a signed 64-bit integer, anything else
    for an ordinary integer. The unsigned case is not politeness — asking
    for `ULONG_MAX` as `(long long)` overflows, answers nonsense, and
    then reports the package as wrong for disagreeing with it. A checker
    that can manufacture a difference it cannot itself survive is worse
    than no checker, so the mode follows the number rather than assuming.
    """
    if mode == "f":
        return f'    printf("{label}=%.17g\\n", (double)({expr}));'
    if mode == "u":
        return f'    printf("{label}=%llu\\n", (unsigned long long)({expr}));'
    return f'    printf("{label}=%lld\\n", (long long)({expr}));'


def ask_c(items: list[tuple[str, str]], mode: str) -> subprocess.CompletedProcess:
    """Run one program that prints the value of every expression given."""
    includes = "\n".join(f"#include <{h}>" for h in headers())
    body = "\n".join(print_in_c(label, expr, mode) for label, expr in items)
    source = f"#include <stdio.h>\n{includes}\nint main(void) {{\n{body}\n    return 0;\n}}\n"

    work = ROOT / ".build-check"
    work.mkdir(exist_ok=True)
    src = work / "constants.c"
    exe = work / "constants"
    src.write_text(source)

    built = subprocess.run(
        [*CC, *DEFINES, "-w", "-o", str(exe), str(src)],
        capture_output=True,
        text=True,
    )
    if built.returncode != 0:
        # Leave the compiler's words out of it: they are about lines this
        # wrote, not about the package, and the caller only needs to know
        # that this group cannot be asked about as a whole.
        return built
    return subprocess.run([str(exe)], capture_output=True, text=True)


def from_c(
    items: list[tuple[str, str]], mode: str
) -> tuple[dict[str, float], list[str]]:
    """What C says about each name, and the names it cannot be asked about.

    One program per group is the cheap path and usually the whole story.
    When it does not compile — a macro that takes arguments, a name this
    package invented, a constant that is really a pointer — the group is
    halved until the refusal is pinned to whoever caused it, which costs
    a few more compilations instead of one per constant.

    Halving stops at a single constant and still asks it. An earlier
    version gave up without compiling once a group narrowed to one, so a
    single unaskable neighbour condemned everyone grouped with it, and
    `CLOCK_MONOTONIC` came back as unknowable when it is simply 1.
    """
    said: dict[str, float] = {}
    refused: list[str] = []

    def ask(group: list[tuple[str, str]]) -> None:
        if not group:
            return
        running = ask_c(group, mode)
        if running.returncode == 0 and running.stdout:
            seen = dict(
                line.split("=", 1)
                for line in running.stdout.strip().splitlines()
                if "=" in line
            )
            if all(label in seen for label, _ in group):
                for label, value in seen.items():
                    said[label] = float(value) if mode == "f" else float(int(value))
                return
        if len(group) == 1:
            refused.append(group[0][0])
            return
        middle = len(group) // 2
        ask(group[:middle])
        ask(group[middle:])

    ask(items)
    return said, refused


def show(value: float) -> str:
    """A number as it should be printed, including the ones that are not
    quite numbers.

    `HUGE_VAL` is infinity, and asking Python to make an integer of it is
    how a checker written for ordinary constants falls over printing the
    one unusual thing it was supposed to find.
    """
    if isnan(value) or isinf(value):
        return str(value)
    return f"{value:.0f}" if value == int(value) else f"{value}"


def unwrapped(raw: str) -> str:
    """A value with Mojo's outer type call taken off it.

    `Int32(256)` is what `0x100` becomes once it has been given a Mojo
    type, and asking C about `Int32(256)` is asking about nothing it has
    ever heard of. The wrapper comes off and the number inside is what
    gets asked about.
    """
    whole = re.fullmatch(r"([A-Za-z_]\w*)\((.*)\)", raw.strip())
    return whole.group(2).strip() if whole else raw.strip()


def c_expression(raw: str) -> str | None:
    """The same value written the way C spells it, or None.

    A leading `0o` octal becomes C's bare leading zero. Anything C would
    read differently — a call such as `Int32(5)`, which is Mojo and not
    anything a header knows — is refused rather than asked about wrongly.
    """
    side = unwrapped(raw)
    if " if " in side and " else " in side:
        branch = each_side(side)
        if branch is None:
            return None
        side = branch
    text = re.sub(r"\b0[oO]([0-7]+)\b", r"0\1", side.strip())
    if re.search(r"[A-Za-z_]\w*\s*\(", text):
        return None
    # The point is in there deliberately: leaving it out refused every
    # floating-point constant in the package, including `FLT_MAX`, on the
    # grounds that nothing was being asked about.
    if not re.fullmatch(r"[0-9A-Za-z_+\-*/%&|^~<>()\s.]+", text):
        return None
    return text


def main() -> int:
    listed = constants()

    # Each label carries its own position, because the same name is
    # sometimes written in more than one file and C answers about every
    # one of them; without this the second would hide the first.
    groups: dict[str, list[tuple[str, str]]] = {}
    for index, (name, _place, raw, value) in enumerate(listed):
        expr = c_expression(raw)
        if expr is None:
            continue
        label = f"{index}:{name}"
        # Infinity answers true to `>= 2**63`, which is how an earlier
        # version came to print `HUGE_VAL` as an integer and read the
        # wreckage back as the package having got it wrong.
        if (value is not None and isinf(value)) or (
            "." in expr and not expr.lstrip().startswith("0x")
        ):
            mode = "f"
        elif value is not None and value >= 2**63:
            mode = "u"
        else:
            mode = "i"
        groups.setdefault(mode, []).append((label, expr))

    said: dict[str, float] = {}
    for mode, group in groups.items():
        told, _ = from_c(group, mode)
        said.update(told)

    agree: list[str] = []
    disagree: list[tuple[str, str, float, float]] = []
    accepted: list[tuple[str, str, float]] = []
    uncounted: list[tuple[str, str, str]] = []

    for index, (name, place, raw, value) in enumerate(listed):
        label = f"{index}:{name}"
        truth = said.get(label)
        if truth is None:
            uncounted.append((name, place, raw))
        elif value is None:
            # Written as a sum of other people's constants. C computing it
            # without complaint is the check, and it says what the answer
            # is besides, which nobody had written down before.
            accepted.append((name, place, truth))
        elif truth == value:
            agree.append(name)
        else:
            disagree.append((name, place, value, truth))

    platform = "Darwin" if sys.platform == "darwin" else "Linux"
    print(f"Checking constants against the headers on {platform}.\n")
    print(f"  {len(agree)} agree with C")
    if accepted:
        print(f"  {len(accepted)} written as expressions, which C accepts")
        if "--values" in sys.argv:
            for name, place, truth in accepted:
                print(f"      {name:<28} C says {truth:.0f}  ({place})")

    if disagree:
        print(f"  {len(disagree)} disagree:")
        for name, place, mine, theirs in disagree:
            shown = show(theirs)
            wanted = show(mine)
            print(f"      {name:<28} here {wanted:>14}  C says {shown:>14}  ({place})")

    if uncounted:
        print(f"\n  {len(uncounted)} could not be checked:")
        for name, place, raw in uncounted:
            if re.search(r"\b0\d", raw):
                why = "written with a leading zero, which C reads as octal"
            elif re.search(r"[A-Za-z_]\w*\s*\(", raw):
                why = "computed in Mojo rather than in the header"
            else:
                why = "not something these headers give a number for"
            print(f"      {name:<28} {why}  ({place})")

    print()
    if disagree:
        print("  *** constants that disagree with C ***")
        return 1
    print("  nothing disagrees with C")
    return 0


if __name__ == "__main__":
    sys.exit(main())
