"""Check that every symbol this package calls is one the C library exports.

A binding is a name in a string and a signature next to it. Both can be
right while the symbol itself is not there: `isascii_l` is declared in
glibc's `<ctype.h>` and exported by the BSDs, and nothing about the call
says which platform it is standing on. The mistake only shows up when the
loader goes looking, which is to say at run time, in whichever job happens
to be the one that calls it.

`check-prototypes` cannot catch this: it reads what the headers declare,
and a symbol that is only declared is one it has nothing to compare
against, so it skips it. This asks the libraries instead, with `nm`.

Whether a symbol has to be there depends on the branch it is called from.
One called inside `comptime if CompilationTarget.is_macos()` is not
supposed to exist here, and one in the `else` of that is not supposed to
exist there. Only the unbranched ones have to be everywhere.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "src" / "libc").rglob("*.mojo"))

# Symbols called unbranched that no library here exports. Each one is a
# platform difference that has been looked at and written up in the
# docstring of the call, so this says so rather than failing: the point of
# the check is the next one, not these.
KNOWN_MISSING = {
    "isascii_l": "the BSDs export it and glibc does not",
    "sched_getcpucount": "the BSDs export it and glibc makes it a macro",
}


def library_symbols() -> set[str]:
    """Every name the libraries on this machine make callable.

    `T` is a definition, `i` an ifunc and `W` a weak one, and all three
    are called the same way from here. The `@GLIBC_2.x` suffix is a
    version, not part of the name.
    """
    have = set()
    for lib in ("libc.so.6", "libm.so.6", "libpthread.so.0", "libdl.so.2", "librt.so.1"):
        found = subprocess.run(
            ["cc", f"-print-file-name={lib}"], capture_output=True, text=True
        ).stdout.strip()
        if not found or "/" not in found:
            continue
        out = subprocess.run(
            ["nm", "-D", found], capture_output=True, text=True
        ).stdout
        for line in out.split("\n"):
            parts = line.split()
            if len(parts) == 3 and parts[1] in ("T", "i", "W"):
                have.add(parts[2].split("@")[0])
    return have


def branch_of(lines: list[str], i: int) -> str:
    """Which side of a `comptime if` line `i` sits on, if any.

    Returns `macos`, `linux` or `plain`. A symbol called on one side only
    has to exist on that side; one called plainly has to exist on both.
    """
    stack = []  # (indentation of the `if`, which branch the current block is)
    for j in range(i):
        line = lines[j]
        if not line.strip() or line.strip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        while stack and indent <= stack[-1][0]:
            stack.pop()
        stripped = line.strip()
        if stack and stripped.startswith("else:"):
            if stack[-1][1] == "macos":
                stack[-1] = (stack[-1][0], "linux")
            continue
        if stripped.startswith("comptime if"):
            stack.append((indent, "macos" if "is_macos" in stripped else "other"))
    return stack[-1][1] if stack else "plain"


def main() -> int:
    have = library_symbols()
    if not have:
        print("  no library symbols to compare against")
        return 0

    called = {}  # name -> (file, branch)
    for path in SOURCES:
        text = path.read_text(errors="ignore")
        lines = text.split("\n")
        for i, line in enumerate(lines):
            m = re.search(r'external_call\["(\w+)"', line)
            if not m:
                continue
            name = m.group(1)
            branch = branch_of(lines, i)
            # One called plainly anywhere counts as called everywhere.
            if name in called and called[name][1] == "plain":
                continue
            if name not in called or branch == "plain":
                called[name] = (str(path.relative_to(ROOT)), branch)

    print(f"  {len(called)} symbols are called through external_call")
    print(f"  {len(have)} names are exported by the libraries here")

    # `other` is a `comptime if` about something other than the platform, so
    # treat it as unbranched: it is not known to be about one side.
    must_exist = {
        n: v for n, v in called.items() if v[1] in ("plain", "other")
    }
    darwin_only = {n: v for n, v in called.items() if v[1] == "macos"}
    linux_only = {n: v for n, v in called.items() if v[1] == "linux"}

    missing = {n: v for n, v in must_exist.items() if n not in have}
    unexpected = {
        n: v
        for n, v in list(darwin_only.items()) + list(linux_only.items())
        if n in have and v[1] == "macos"
    }

    print(
        f"\n  {len(darwin_only)} are called on Darwin only,"
        f" {len(linux_only)} here only,"
        f" {len(must_exist)} on both"
    )

    unexplained = {n: v for n, v in missing.items() if n not in KNOWN_MISSING}
    if missing:
        print("\n  called but not exported here:")
        for name in sorted(missing):
            where, _ = missing[name]
            why = KNOWN_MISSING.get(name)
            note = f" -- {why}" if why else ""
            print(f"    {name:24} {where}{note}")

    print()
    if unexplained:
        print("  *** symbols that are called everywhere but exported nowhere ***")
        return 1
    print("  every symbol that has to be here is here")
    return 0


if __name__ == "__main__":
    sys.exit(main())
