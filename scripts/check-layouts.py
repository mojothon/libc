"""Check every struct this package declares against what C says it is.

A struct here either mirrors a C struct field for field, or it is a block
of bytes big enough to hold whatever arrangement C has for it. Either way
it carries numbers: how wide it is, where it has to start in memory. Get
one wrong and nothing fails here — libc writes past the end of it, or
writes `st_ino` where the layout expects something else, and what comes
back is a number nobody recognises as wrong.

`tests/test_layout.mojo` asserts some of this for some structs, which is
assumed coverage of the ones somebody thought about. This asks instead.

Size and alignment are reachable from Mojo without constructing anything,
so nothing here depends on a struct having a no-argument constructor or
exported fields. Field offsets are not reachable at all: the pointer this
module is written against has no `address_of`, and while `Pointer` does,
asking it for the address of a member asks for a member pointer, which
Mojo does not have. Those stay on trust and are counted below as such.
"""

import importlib.util
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "src" / "libc").rglob("*.mojo"))

CC = ["cc"]
DEFINES = ["-D_GNU_SOURCE", "-D_DEFAULT_SOURCE", "-D_DARWIN_C_SOURCE"]

STRUCT = re.compile(r"^struct (\w+)(?:\([^)]*\))?:\n((?:[ \t].*\n|\n)*)", re.M)
FIELD = re.compile(r"^\s+var (\w+)\s*:\s*(.+)$", re.M)


def mojo() -> list[str]:
    """How to run the compiler, whether this runs inside pixi or not."""
    if shutil.which("mojo"):
        return ["mojo"]
    # Under `pixi run` it is on the path already. Reached any other way it
    # is not, and reaching into `.pixi/envs` for the binary is not enough:
    # called directly like that it cannot find `print`, because what makes
    # the standard library visible to it is the environment pixi sets up.
    if shutil.which("pixi"):
        return ["pixi", "run", "mojo"]
    raise SystemExit("neither mojo nor pixi was found")


def sibling(name: str):
    """Load another script here, whose name has a hyphen in it."""
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), ROOT / "scripts" / f"{name}.py"
    )
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


# `check-constants.py` already worked out which headers have to be included
# and which of them exist here; asking again would be a second list to keep.
CHECK_CONSTANTS = sibling("check-constants")

# Only the ones C spells differently. Everything else here is named after
# the C struct it stands for, which is the point of it. The list itself
# is kept in `check-prototypes`, which `check-constants` and this file
# both load and which cannot load either of them back.
CHECK_PROTOTYPES = sibling("check-prototypes")
SPELLED_DIFFERENTLY = CHECK_PROTOTYPES.SPELLED_DIFFERENTLY

# And the ones with nothing to compare against: opaque handles C never
# finishes describing (`DIR`, `FILE` are only ever seen through a
# pointer), things this package made up, and things C spells as a typedef
# of a struct with some other name. Each is reported rather than skipped
# silently, because "not checked" is a fact about these too.
NOT_A_C_STRUCT = {
    "DIR": "an opaque handle; C never says what is inside it",
    "FILE": "an opaque handle; C never says what is inside it",
    "Locale": "this package's own handle, not a C struct",
    "CString": "this package's own handle, not a C struct",
}


def module_of(path: Path) -> str:
    """The name this file is imported by."""
    relative = path.relative_to(ROOT / "src").with_suffix("")
    return ".".join(relative.parts[:-1] if relative.name == "syscalls" else relative.parts)


def structs() -> list[tuple[str, str, str, list[str]]]:
    """Every struct: (label, module, what C calls it, fields it names)."""
    found = []
    for path in SOURCES:
        module = module_of(path)
        for m in STRUCT.finditer(path.read_text()):
            name = m.group(1)
            fields = [f for f, _ in FIELD.findall(m.group(2))]
            found.append((f"{module}.{name}", module, name, fields))
    # Declared in more than one module — `timespec` four times over — and
    # each one is a separate claim about the same C struct, so all are asked.
    return found


def c_name(name: str) -> str | None:
    return SPELLED_DIFFERENTLY.get(name, name)


def mojo_layouts(batch: list[tuple[str, str, str]]) -> tuple[dict[str, tuple[int, int]], list[str]]:
    """What Mojo says each one measures, and the ones it cannot say about.

    One program for all of them, halved when it will not build, because a
    struct that stopped being importable would otherwise sink everybody
    it was compiled with.
    """
    said: dict[str, tuple[int, int]] = {}
    refused: list[str] = []

    def program(items: list[tuple[str, str, str]]) -> str:
        imports = "\n".join(
            f"from {module} import {name} as _{index}"
            for index, (_label, module, name) in enumerate(items)
        )
        lines = "\n".join(
            f'    print("_{index}", size_of[_{index}](), align_of[_{index}]())'
            for index, (label, _module, _name) in enumerate(items)
        )
        return f"from std.sys import align_of, size_of\n{imports}\n\n\ndef main():\n{lines}\n"

    def ask(items: list[tuple[str, str, str]]) -> None:
        if not items:
            return
        source = ROOT / ".build-check" / "layout.mojo"
        source.parent.mkdir(exist_ok=True)
        source.write_text(program(items))
        ran = subprocess.run(
            [*mojo(), "run", "-I", str(ROOT / "src"), str(source)],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        if ran.returncode == 0 and ran.stdout.strip():
            seen = {}
            for line in ran.stdout.strip().splitlines():
                parts = line.split()
                if len(parts) == 3 and parts[0].startswith("_"):
                    seen[parts[0]] = (int(parts[1]), int(parts[2]))
            if all(f"_{index}" in seen for index in range(len(items))):
                for index, (label, _module, _name) in enumerate(items):
                    said[label] = seen[f"_{index}"]
                return
        if len(items) == 1:
            refused.append(items[0][0])
            return
        middle = len(items) // 2
        ask(items[:middle])
        ask(items[middle:])

    ask(batch)
    return said, refused


def c_layouts(items: list[tuple[str, str]]) -> tuple[dict[str, tuple[int, int]], list[str]]:
    """What C measures for each name given, and what it has nothing to say
    about.

    `struct X` is tried first and `X` second, since a good number of these
    — `fd_set`, `mbstate_t`, `pthread_attr_t` — are typedefs rather than
    structs with a tag, and the difference is invisible from the Mojo side.
    One compilation each, which is slower than batching and much simpler
    than deciding afterwards which of a group failed.
    """
    said: dict[str, tuple[int, int]] = {}
    refused: list[str] = []
    includes = "\n".join(f"#include <{h}>" for h in CHECK_CONSTANTS.headers())

    for label, name in items:
        for spelled in (f"struct {name}", name):
            body = (
                f'    printf("%zu %zu\\n", sizeof({spelled}), '
                f'_Alignof({spelled}));'
            )
            source = ROOT / ".build-check" / "layout.c"
            source.parent.mkdir(exist_ok=True)
            source.write_text(f"#include <stdio.h>\n{includes}\nint main(void) {{\n{body}\n    return 0;\n}}\n")
            built = subprocess.run(
                [*CC, *DEFINES, "-w", "-o", str(ROOT / ".build-check" / "layout"), str(source)],
                capture_output=True,
                text=True,
            )
            if built.returncode != 0:
                continue
            ran = subprocess.run(
                [str(ROOT / ".build-check" / "layout")], capture_output=True, text=True
            )
            size, align = ran.stdout.split()
            said[label] = (int(size), int(align))
            break
        else:
            refused.append(label)
    return said, refused


def main() -> int:
    declared = structs()
    comparable = []
    not_a_struct = []
    for label, module, name, fields in declared:
        if name in NOT_A_C_STRUCT:
            not_a_struct.append((label, NOT_A_C_STRUCT[name]))
            continue
        named = c_name(name)
        if named is None:
            not_a_struct.append((label, "nothing in C is called this"))
            continue
        comparable.append((label, named))

    mine, _ = mojo_layouts([(label, module, name) for label, module, name, _f in declared
                            if label not in {l for l, _ in not_a_struct}])
    theirs, absent = c_layouts(comparable)

    def verdict(
        label: str, size: tuple[int, int], c_size: tuple[int, int], fields: list[str]
    ) -> str:
        """Whether a difference is dangerous, harmless, or none at all.

        A struct with named fields is claiming to be that C struct, so its
        size has to be exact: `qelem` here is twelve bytes short of what
        `insque` writes into, which is a hole punched in whatever sits
        next to it. Most of the opaque ones are deliberately bigger than
        this machine's — a block sized for whichever platform wanted most,
        because they are only ever handed over by pointer and libc writes
        less than it was given — and being generous with bytes costs
        nothing. Being stingy costs memory belonging to somebody else.

        Alignment only has one dangerous direction. Asking for four bytes
        where C asks for eight leaves the pointer the colder half of the
        difference, and `pthread_attr_init` is free to use an instruction
        that cares. Being stricter than C is safe and only worth knowing.
        """
        size_here, align_here = size
        size_c, align_c = c_size
        if align_here % align_c != 0:
            return "under-aligned"
        if len(fields) >= 2 and size_here != size_c:
            return "wrong size"
        if size_here < size_c:
            return "too small"
        if (size_here, align_here) != (size_c, align_c):
            return "loose"
        return ""

    agree = []
    disagree = []
    loose = []
    no_mojo = []
    no_c = []

    for label, module, name, fields in declared:
        if any(label == l for l, _ in not_a_struct):
            continue
        if label not in mine:
            no_mojo.append((label, module))
            continue
        if label not in theirs:
            no_c.append(label)
            continue
        problem = verdict(label, mine[label], theirs[label], fields)
        if problem == "":
            agree.append(label)
        elif problem == "loose":
            loose.append((label, mine[label], theirs[label]))
        else:
            disagree.append((label, mine[label], theirs[label], problem))

    platform = "Darwin" if sys.platform == "darwin" else "Linux"
    print(f"Checking struct sizes against the headers on {platform}.\n")
    print(f"  {len(agree)} agree with C")
    if disagree:
        print(f"  {len(disagree)} disagree, and should not:")
        for label, mine_values, theirs_values, problem in disagree:
            size_m, align_m = mine_values
            size_c, align_c = theirs_values
            print(
                f"      {label:<28} here {size_m:>5}/{align_m}  "
                f"C says {size_c:>5}/{align_c}   {problem}"
            )
    if loose:
        print(f"  {len(loose)} larger or stricter than C needs, which costs bytes "
              f"and breaks nothing:")
        for label, mine_values, theirs_values in loose:
            size_m, align_m = mine_values
            size_c, align_c = theirs_values
            print(
                f"      {label:<28} here {size_m:>5}/{align_m}  "
                f"C says {size_c:>5}/{align_c}"
            )

    if no_mojo or no_c or not_a_struct:
        print(f"\n  {len(no_mojo) + len(no_c) + len(not_a_struct)} could not be checked:")
        for label, module in no_mojo:
            print(f"      {label:<28} Mojo will not say")
        for label in no_c:
            print(f"      {label:<28} C does not have it here")
        for label, why in not_a_struct:
            print(f"      {label:<28} {why}")

    fielded = [f for _l, _m, _n, fields in declared for f in fields]
    if fielded:
        print(
            f"\n  Field offsets are not checked: {len(fielded)} fields across these"
            f" structs rest on the values they were written with."
        )

    print()
    if disagree:
        print("  *** structs that disagree with C ***")
        return 1
    print("  nothing disagrees with C")
    return 0


if __name__ == "__main__":
    sys.exit(main())
