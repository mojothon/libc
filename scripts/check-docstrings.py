#!/usr/bin/env python3
"""Check the things a docstring says about the call it sits above.

A docstring is read by nobody but whoever reads it, which is another way
of saying that whatever is wrong in one stays wrong: nothing compiles
it, nothing tests it, and the binding goes on calling the real function
while the paragraph describes a different one. Three questions found
what was wrong here:

    every name under `Args` is a parameter the function takes

    the prototype names the function the binding actually calls

    the prototype takes as many arguments as C says it does

Every one caught so far was a copy that had moved down a line and kept
the wrong heading. `atan` carried `atan2`'s prototype — `double atan2(
double y, double x)` — and so documented a second argument `y` that it
does not take and cannot be given; `atan2f` carried `atanf`'s, which
says one argument where it takes two; `ldiv`, `lldiv` and `imaxdiv` all
said `div`, so no one of them said which of the three was bound.

None of those break the binding. They break whoever uses it, which is
worse, and the argument does it: something that reads as though it took
the numerator first will be given one.

The prototypes come from `gcc -aux-info`, as in the prototype check, so
this too has nothing to say where there is no compiler to ask.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The prototype check already reads the listing and already walks every
# binding, and asking twice would only give the two room to disagree.
# Loaded by path because the name has a hyphen in it, which is not a
# name Python can import.
_loaded = importlib.util.spec_from_file_location(
    "check_prototypes", ROOT / "scripts" / "check-prototypes.py"
)
_check_prototypes = importlib.util.module_from_spec(_loaded)
_loaded.loader.exec_module(_check_prototypes)

read_prototypes = _check_prototypes.read_prototypes
bindings = _check_prototypes.bindings
ALIASES = _check_prototypes.ALIASES

ENTRY = re.compile(r"^([a-zA-Z_]\w*)\s*:\s*(.*)$")
HEADING = re.compile(r"[A-Za-z][A-Za-z ]*:")

# What C appends to a name to get the one that takes a different width.
# A binding of `atanf` is allowed to show the prototype of `atan`, which
# is the page the man pages give it.
TYPE_SUFFIXES = frozenset({"", "f", "l", "q", "f16", "f32", "f64", "f128"})


def sections(doc: str) -> dict[str, list[tuple[int, str]]]:
    """{heading: [(indent, text)]}, which is how these are written.

    A heading sits four spaces in and may carry its own first line, as in
    `Args: s: A pointer to a C string.`; everything deeper belongs to it
    until the next heading. Keeping the indent is what tells an entry
    apart from the rest of the sentence before it, which is deeper still.
    """
    found: dict[str, list[tuple[int, str]]] = {}
    heading: str | None = None
    for line in doc.splitlines():
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        if indent <= 6 and HEADING.match(stripped):
            heading = stripped.split(":")[0]
            found[heading] = [(indent, stripped[len(heading) + 1 :].strip())]
        elif heading:
            found[heading].append((indent, stripped))
    return found


def nth_definition(text: str, name: str, place: int) -> tuple[str, str] | None:
    """(parameters, docstring) of the nth `def name` here, counting from 0.

    A name can be bound more than once — `fcntl` is, once for each load
    of arguments it takes — and the second one is not described by the
    first one's docstring. Taking them in order is what lets each binding
    be asked about its own.
    """
    spots = [m.start() for m in re.finditer(r"\ndef " + re.escape(name) + r"\(", text)]
    if place >= len(spots):
        return None
    opened = text.index("(", spots[place])
    depth, i = 0, opened
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                break
        i += 1
    params = text[opened + 1 : i]
    doc = re.search(r":\n\s*\"\"\"(.*?)\"\"\"", text[i:], re.S)
    return params, doc.group(1) if doc else ""


def parameter_names(params: str) -> list[str]:
    """The names in `x: Float64, y: Float64`, and `self` is not one."""
    names = []
    for param in params.split(","):
        param = param.strip()
        if not param:
            continue
        name = re.sub(
            r"^(owned|borrowed|inout|mut|read)\s+", "", param.split(":")[0].strip()
        )
        if name and name != "self":
            names.append(name)
    return names


def base_indent(lines: list[tuple[int, str]]) -> int | None:
    """Where entries sit, which is where the ones carrying words sit.

    The heading comes along with whatever was written on its own line,
    at the heading's own indent, so taking the shallowest line at its
    word would say entries are written at four and none would be left.
    """
    said = [indent for indent, line in lines if line]
    return min(said) if said else None


def prototype_call(line: str) -> tuple[str, int] | None:
    """(name, argument count) from `double atan2(double y, double x)`."""
    m = re.search(r"\b([a-zA-Z_]\w*)\s*\(([^)]*)\)", line)
    if not m:
        return None
    params = m.group(2).strip()
    if not params or params == "void":
        return m.group(1), 0
    return m.group(1), len([p for p in params.split(",") if p.strip()])


def documented_prototype(
    secs: dict[str, list[tuple[int, str]]]
) -> tuple[str, int, str] | None:
    """(name, argument count, line) the docstring gives as the prototype."""
    for heading in ("Prototype", "Fn signature"):
        for _indent, line in secs.get(heading, []):
            call = prototype_call(line)
            if call:
                return call[0], call[1], line
    return None


def main() -> int:
    prototypes = read_prototypes()
    if not prototypes:
        return 0

    problems: list[str] = []
    checked = 0
    counted: dict[tuple[str, str], int] = {}

    for path, name, symbol, passed, _return, _params in bindings():
        place = counted.get((path, name), 0)
        counted[(path, name)] = place + 1

        text = (ROOT / path).read_text()
        definition = nth_definition(text, name, place)
        if definition is None:
            continue
        params, doc = definition
        checked += 1
        secs = sections(doc)
        where = f"{path}: {name}()"

        # 1. An `Args` entry naming something the function does not take,
        #    which is how `atan` came to have a `y`.
        signature = parameter_names(params)
        entries = secs.get("Args") or secs.get("Arguments")
        floor = base_indent(entries) if entries else None
        if floor is not None:
            written = []
            for indent, line in entries or []:
                entry = ENTRY.match(line)
                if entry and indent == floor:
                    written.append(entry.group(1))
            if signature:
                for written_name in written:
                    if written_name not in signature:
                        problems.append(
                            f"{where} documents an argument `{written_name}`"
                            f" and takes ({', '.join(signature)}), so it"
                            " carries one it cannot be given"
                        )
                # Missing one it does take is the same mistake read the
                # other way round.
                for signature_name in signature:
                    if signature_name not in written:
                        problems.append(
                            f"{where} takes `{signature_name}` and does not"
                            f" say what it is, having named only"
                            f" ({', '.join(written)})"
                        )
            elif written:
                problems.append(
                    f"{where} takes no arguments and documents"
                    f" ({', '.join(written)})"
                )

        # 2 and 3: a prototype copied from another function, or one that
        # says a different number of arguments than the binding passes.
        # How many it passes is asked rather than looked up in gcc's list,
        # because glibc hides some of these — `imaxabs` among them — and a
        # symbol it says nothing about is not one its prototype is free to
        # be wrong about.
        written_call = documented_prototype(secs)
        if written_call:
            written_name, count, line = written_call
            # `atanf` documented by the page for `atan` is where the man
            # pages put it, and the difference is only the suffix. Nothing
            # else is close enough to be called the same function, least
            # of all `atan2` beside `atan`, which takes a different number
            # of arguments and means a different thing by them.
            same = (
                written_name in (symbol, name)
                or ALIASES.get(name) == written_name
                or name[len(written_name) :] in TYPE_SUFFIXES
            )
            if not same:
                problems.append(
                    f"{where} calls {symbol}(), and its prototype says"
                    f" `{written_name}()`, which is a different function:"
                    " one of the two was copied here"
                )
            # `open` is called through `openat` and a variadic prototype
            # ends in `...`, which is not a count anybody can be held to.
            elif "..." not in line and not line.endswith("..."):
                if count != passed:
                    problems.append(
                        f"{where} calls {symbol}() and passes {passed}"
                        f" argument(s), while its prototype says"
                        f" {count}: {line}"
                    )

    if problems:
        print(f"{len(problems)} docstring(s) describe a call they do not make:\n")
        for problem in sorted(problems):
            print(f"  {problem}")
        print(
            "\nnothing reads these lines but whoever reads them,"
            " so they are worth getting right"
        )
        return 1

    print(f"all {checked} documented bindings describe the call they make")
    return 0


if __name__ == "__main__":
    sys.exit(main())
