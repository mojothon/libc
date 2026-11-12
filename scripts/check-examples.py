"""Check that the Mojo in the documentation still compiles.

Every fenced `mojo` block in `README.md` and `docs/*.md` is a claim about
this package's API: that `string_to_char_ptr` returns something `strlen`
takes, that `CString` is still spelled that way, that `opendir` still
answers a pointer. Nothing compiles them, so the claim is only checked by
whoever next copies one out and finds it broken — which is a reader, and
later than it should be.

So each block is written to a file and built against `src/`. Built, not
run: two of these open a directory and print whichever entry is first, one
prints a pid, and none of them asserts an answer. What they are worth
knowing is that the names and signatures in them are the ones this package
has, and that is what the compiler can say.

A block that is a fragment rather than a program — one line of a `comptime`
declaration, an expression quoted to show its shape — says so with a fence
of `mojo fragment`, and is counted rather than compiled. Skipping has to be
written down to happen: the point of the check is the block somebody adds
next, and a block nothing compiles passes for correct in exactly the way the
docs this has already found were.

A block with no `def main` gets one, because the compiler wants a program
whether or not the example is one. That is the only edit made to a block:
what is compiled is what the reader sees, plus an empty entry point.

The fenced `bash` blocks are claims of the same kind -- commands a reader
can type and run -- and the install commands among them are asked
something the compiler cannot say: that the ones the README gives are
the ones the install page gives. The README said `pixi add --from ...`
for four releases, a command pixi has no flag for, because it stood
where a reader would copy it and nobody had typed it. The install
page's commands are the ones the release walks as a reader walks it,
so the page is the source and the README must say what it says.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGES = [ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md"))]
BUILD = ROOT / ".build-check" / "examples"

BLOCK = re.compile(r"^```mojo( +fragment)?\n(.*?)^```", re.M | re.S)
BASH = re.compile(r"^```bash\n(.*?)^```", re.M | re.S)
INSTALL = re.compile(r"^(pixi (?:init|add) .+)$", re.M)
MAIN = re.compile(r"^def main\(", re.M)


def blocks(path: Path) -> list[tuple[int, bool, str]]:
    """(ordinal, is a fragment, source) for each fenced block on the page."""
    found = []
    for index, m in enumerate(BLOCK.finditer(path.read_text()), 1):
        found.append((index, m.group(1) is not None, m.group(2)))
    return found


def as_program(source: str) -> str:
    """The block, with an empty `main` if it does not have one."""
    if MAIN.search(source):
        return source
    return source.rstrip("\n") + "\n\n\ndef main():\n    pass\n"


def compile(name: str, source: str) -> str:
    """What the compiler said, or "" if it had nothing to say."""
    BUILD.mkdir(parents=True, exist_ok=True)
    path = BUILD / f"{name}.mojo"
    path.write_text(as_program(source))
    built = subprocess.run(
        ["mojo", "build", "-I", str(ROOT / "src"), str(path), "-o", str(BUILD / name)],
        capture_output=True,
        text=True,
    )
    if built.returncode == 0:
        return ""
    # The first error is the one worth quoting: the rest are usually it. Its
    # line number is the block's own, the generated file being the block plus
    # an entry point at the end, so it points into the page.
    for line in built.stderr.splitlines():
        if "error:" not in line:
            continue
        where, said = line.split("error:", 1)
        spot = where.strip().rstrip(":").rsplit(":", 2)
        if len(spot) == 3 and spot[1].isdigit():
            return f"line {spot[1]}: {said.strip()}"
        return said.strip()
    return built.stderr.strip().splitlines()[0] if built.stderr.strip() else "failed"


def install_commands(path: Path) -> set[str]:
    """The `pixi init`/`pixi add` lines the page's bash blocks spell out."""
    said = set()
    for block in BASH.finditer(path.read_text()):
        for line in block.group(1).splitlines():
            line = line.split("#")[0].strip()
            if INSTALL.match(line):
                said.add(line)
    return said


def main() -> int:
    failed = []
    fragments = []
    compiled = 0
    for page in PAGES:
        where = page.relative_to(ROOT)
        for index, is_fragment, source in blocks(page):
            name = f"{where.stem}-{index}"
            if is_fragment:
                fragments.append(f"{where} block {index}")
                continue
            compiled += 1
            said = compile(name, source)
            if said:
                failed.append((f"{where} block {index}", said))

    # The install page's commands are the ones the release walks; the
    # README's must be the page's, not a paraphrase nobody has typed.
    walked = install_commands(ROOT / "docs" / "install.md")
    told = install_commands(ROOT / "README.md")
    off_page = sorted(told - walked)
    if off_page:
        print("\n  install commands the README gives that the install")
        print("  page does not -- and only the page's are walked:")
        for line in off_page:
            print(f"    {line}")

    if failed:
        print("\n  examples that no longer compile:")
        for where, said in failed:
            print(f"    {where}: {said}")
    if fragments:
        print(
            f"\n  {len(fragments)} block(s) are fenced as fragments and not"
            f" compiled: {', '.join(fragments)}"
        )

    print()
    if failed or off_page:
        print("  *** examples the package has outgrown ***")
        return 1
    print(f"  all {compiled} examples compile against this package")
    return 0


if __name__ == "__main__":
    sys.exit(main())
