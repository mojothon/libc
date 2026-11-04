"""Ask whether every conda channel the docs name is one that exists.

The install page named the channel three ways and two of them were wrong.
`conda install -c mojo-force libc` and `channels = [..., "mojo-force"]` are
both read as *anaconda.org* channels -- `conda.anaconda.org/mojo-force`, which
does not exist -- while the packages were on prefix.dev, reachable only by
URL. Nothing compiles a shell command, so the page went on saying it for four
releases: the failure a reader met was a 404 for a channel that is not there,
on a package that is, and the page had been read by everyone who wrote it.

What can be asked without the network is whether the name written is a name
that could resolve at all: a URL, or one of the few channels that really do
live on anaconda.org. A bare name outside that list is the mistake above.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Bare names that do resolve: they are anaconda.org channels, hosted where
# conda looks when it is given a name rather than a URL.
ON_ANACONDA = {"conda-forge", "bioconda", "pytorch", "nvidia", "defaults"}

FENCE = re.compile(r"^```(\w*)\s*$")
# The two ways a channel is written in a command or a manifest.
CLI = re.compile(r"(?:^|\s)(?:-c|--channel)[\s=]+(\S+)")
TOML = re.compile(r"^\s*channels\s*=\s*\[(.*)\]\s*$")


def blocks(text: str) -> list[tuple[int, str, list[str]]]:
    """Every fenced block that could hold a command: (line, language, lines)."""
    found: list[tuple[int, str, list[str]]] = []
    language, start, body, inside = "", 0, [], False
    for number, line in enumerate(text.splitlines(), start=1):
        fence = FENCE.match(line)
        if fence is not None:
            if not inside:
                inside, language, start, body = True, fence.group(1), number, []
            else:
                if language in ("bash", "sh", "shell", "toml", "console"):
                    found.append((start, language, body))
                inside = False
            continue
        if inside:
            body.append(line)
    return found


def named(language: str, lines: list[str]) -> list[tuple[int, str]]:
    """The channels a block names, as (line number offset, name)."""
    channels = []
    for offset, line in enumerate(lines):
        if language == "toml":
            m = TOML.match(line)
            if m is not None:
                for name in re.findall(r"\"([^\"]+)\"", m.group(1)):
                    channels.append((offset, name))
            continue
        for m in CLI.finditer(line):
            channels.append((offset, m.group(1).rstrip(".")) )
    return channels


def decides(name: str) -> bool:
    """Whether `name` is something conda or pixi could resolve."""
    if name.startswith(("http://", "https://", "file://")):
        return True
    return name in ON_ANACONDA


def main() -> int:
    problems = []
    count = 0
    for page in sorted((ROOT / "docs").glob("*.md")):
        text = page.read_text()
        for start, language, body in blocks(text):
            for offset, name in named(language, body):
                count += 1
                if not decides(name):
                    problems.append(
                        f"{page.relative_to(ROOT)}:{start + offset + 1}: "
                        f"\"{name}\" is read as an anaconda.org channel, "
                        "which is not where this one lives - write its URL"
                    )

    if problems:
        print("\n  *** a channel the docs name cannot resolve ***")
        for problem in problems:
            print(f"    {problem}")
        print(
            "  a bare name is an anaconda.org channel; prefix.dev needs the URL"
        )
        return 1

    print(f"\n  {count} channel names across the docs, every one a URL or a")
    print("  name that answers on anaconda.org")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
