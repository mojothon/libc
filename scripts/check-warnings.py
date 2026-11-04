"""Ask that the package compiles without the compiler complaining.

`mojo precompile` reads the docstrings, and prints a warning for each one
it cannot read the way the file meant it. An argument description that
wraps back to the argument's own margin is read as a second argument --
`asked for, anything else to go on complaining` is not one -- and a
`Returns` on a function with no results is told so. Sixteen of these had
collected across four files: every build printed them, every build exited
0, and a build that is always noisy is a build where the warning that
matters goes past as the seventeenth.

`check-docstrings` reads the same sections with a parser that stops at a
colon, which is why it never saw them; the compiler is the one that has
to be asked. What it costs is a precompile, which is five seconds warm.
"""

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    with tempfile.TemporaryDirectory() as out:
        result = subprocess.run(
            [
                "mojo",
                "precompile",
                str(ROOT / "src" / "libc"),
                "-o",
                str(Path(out) / "libc.mojoc"),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
    said = result.stdout + result.stderr

    if result.returncode != 0:
        print("\n  *** the package does not compile ***")
        print("\n".join(said.splitlines()[-20:]))
        return 1

    warnings = [line for line in said.splitlines() if "warning:" in line]
    if warnings:
        print("\n  *** a docstring the compiler cannot read ***")
        for warning in warnings:
            print(f"    {warning.replace(str(ROOT) + '/', '')}")
        print("  wrap the description under its argument, or say it another way")
        return 1

    print("\n  the package compiles, and the compiler has nothing to say")
    print("  about how the docstrings are written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
