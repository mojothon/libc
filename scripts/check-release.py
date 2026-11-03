"""Check that the version and the toolchain range say the same thing everywhere.

`docs/version.md` says the version lives in three places and that all three
have to be bumped together. It is five, and until this script there was
nothing that noticed when one of them was left behind: the package would
build, the docs would build, every other check here would pass, and a reader
following the install page would be told to ask conda for a release that is
no longer the one being shipped.

The five are the workspace in `pixi.toml`, the context in
`recipe/recipe.yaml`, `comptime __version__` in `src/libc/version.mojo`, and
the two pages that state it — `docs/version.md` in a table and
`docs/install.md` in a specifier. The specifier is not compared as a string:
`>=0.12.0,<0.13` is a claim about which versions can be installed, so the
question asked of it is whether the version this checkout is actually
satisfies it.

The toolchain range is the same kind of fact in four places, and is compared
as the string each of them states, since it is a constraint rather than a
number.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def stated_versions() -> dict[str, str]:
    """{where: the version it says}, for each place one is written."""
    sources = {
        "pixi.toml": (ROOT / "pixi.toml").read_text(),
        "recipe/recipe.yaml": (ROOT / "recipe" / "recipe.yaml").read_text(),
        "src/libc/version.mojo": (ROOT / "src" / "libc" / "version.mojo").read_text(),
        "docs/version.md": (ROOT / "docs" / "version.md").read_text(),
    }
    patterns = {
        "pixi.toml": r"^version = \"([^\"]+)\"",
        "recipe/recipe.yaml": r"^\s*version: \"([^\"]+)\"",
        "src/libc/version.mojo": r"^comptime __version__ = \"([^\"]+)\"",
        "docs/version.md": r"\|\s*`libc\.__version__`\s*\|\s*`([^`]+)`\s*\|",
    }
    found = {}
    for where, text in sources.items():
        m = re.search(patterns[where], text, re.M)
        if m is not None:
            found[where] = m.group(1)
    return found


def stated_toolchain() -> dict[str, str]:
    """{where: the Mojo range it says}, for each place one is written."""
    sources = {
        "pixi.toml": (ROOT / "pixi.toml").read_text(),
        "recipe/recipe.yaml": (ROOT / "recipe" / "recipe.yaml").read_text(),
        "docs/version.md": (ROOT / "docs" / "version.md").read_text(),
        "docs/install.md": (ROOT / "docs" / "install.md").read_text(),
    }
    # `docs/version.md` puts it in a table cell, and the other three write it
    # after the name — `mojo = "..."` in the two TOML blocks and
    # `- mojo >=1.1.0,<2` in the recipe, which quotes nothing.
    patterns = {
        "pixi.toml": r"^mojo\s*=\s*\"([^\"]+)\"",
        "recipe/recipe.yaml": r"^\s*-\s*mojo\s+(>=[\d.]+,<[\d.]+)",
        "docs/version.md": r"\|\s*Mojo\s*\|\s*`([^`]+)`\s*\|",
        "docs/install.md": r"^\s*mojo = \"([^\"]+)\"",
    }
    found: dict[str, str] = {}
    for where, text in sources.items():
        said = set(re.findall(patterns[where], text, re.M))
        if not said:
            continue
        # `recipe/recipe.yaml` writes the same range twice, under `build`
        # and under `run`, and that is one answer said in two places.
        found[where] = said.pop() if len(said) == 1 else " / ".join(sorted(said))
    return found


def triple(version: str) -> tuple[int, ...]:
    """`0.12.0` as (0, 12, 0), so that versions can be ordered."""
    return tuple(int(part) for part in re.findall(r"\d+", version))


def allowed_by(specifier: str, version: str) -> bool:
    """Whether `version` is one `specifier` (`>=a,<b`) allows."""
    here = triple(version)
    for part in specifier.split(","):
        m = re.fullmatch(r"\s*(>=|<=|>|<|==)\s*([\d.]+)\s*", part)
        if m is None:
            return False
        op, there = m.group(1), triple(m.group(2))
        if not {
            ">=": here >= there,
            "<=": here <= there,
            ">": here > there,
            "<": here < there,
            "==": here == there,
        }[op]:
            return False
    return True


def install_specifier() -> str | None:
    """What `docs/install.md` tells a reader to ask conda for."""
    text = (ROOT / "docs" / "install.md").read_text()
    m = re.search(r"^\s*libc = \"([^\"]+)\"", text, re.M)
    return m.group(1) if m is not None else None


def main() -> int:
    versions = stated_versions()
    problems = []

    for where in (
        "pixi.toml",
        "recipe/recipe.yaml",
        "src/libc/version.mojo",
        "docs/version.md",
    ):
        if where not in versions:
            problems.append(f"{where}: no version found, so it cannot be compared")

    if len(set(versions.values())) > 1:
        said = ", ".join(f"{where} {version}" for where, version in versions.items())
        problems.append(f"the version is said more than one way: {said}")

    version = versions.get("pixi.toml")
    specifier = install_specifier()
    if specifier is None:
        problems.append("docs/install.md: no `libc = \"...\"` line to check")
    elif version is not None and not allowed_by(specifier, version):
        problems.append(
            f"docs/install.md: asks for libc {specifier}, which this checkout"
            f" ({version}) does not satisfy"
        )

    toolchains = stated_toolchain()
    for where in ("pixi.toml", "recipe/recipe.yaml", "docs/version.md", "docs/install.md"):
        if where not in toolchains:
            problems.append(f"{where}: no Mojo range found, so it cannot be compared")
    if len(set(toolchains.values())) > 1:
        said = ", ".join(f"{where} {said}" for where, said in toolchains.items())
        problems.append(f"the Mojo range is said more than one way: {said}")

    if problems:
        print("\n  *** the release numbers disagree ***")
        for problem in problems:
            print(f"    {problem}")
        print("  bump all of them together, or say why one of them is different")
        return 1

    print(f"\n  libc {version} and Mojo {toolchains['pixi.toml']}, every")
    print("  place either one is written saying the same, and the install")
    print("  page asking for a libc that includes this one")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
