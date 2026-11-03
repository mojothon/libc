"""Check that every answer held to a tolerance is held to the distance.

`assert_true(answer - expected < epsilon)` is true of every answer *below* the
expected one, and that is not a small set: it is every call that answers zero,
every call that answers its argument, and every call whose answer is negative.
The assertion looks like a tolerance and is in fact a one-sided bound, and
nothing in the suite said which of the two was meant, so both readings passed.

Two survivors of the full symbol-axis sweep were exactly this. `hypot(3, 4)`
answered by `fmod` is 3, and 3 - 5 is under 1e-9; `ceil(2.1)` answered by `fabs`
is 2.1, and 2.1 - 3 is under 1e-12. Eight lines were written that way, in
`test_math` and `test_stdlib`, and they had been passing since before the probe
existed.

So the question asked here is of the difference itself: when an assertion holds
an answer to a tolerance, the thing compared with the tolerance has to be the
absolute value of the whole difference. `fabs(answer - expected)` is that.
`fabs(answer) - expected` is not: the absolute value went on the answer rather
than on the distance, which is the same one-sided bound with a `fabs` in it.

A line that means to say "this is under that" should say it without a
subtraction, and then it is a comparison between two numbers and not a
tolerance at all. None of those are in the suite; if one is wanted, it goes in
`ONE_SIDED` with the reason.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = sorted((ROOT / "tests").glob("*.mojo"))

# Assertions that deliberately compare one side of a difference, with the
# reason. Nothing is in here: every line the first run found was a bound that
# meant to be a distance.
ONE_SIDED: dict[str, str] = {}

COMPARISON = re.compile(r"<=|>=|==|!=|<|>")
NUMBER = re.compile(r"^-?\d")


def arguments(text: str, open_at: int) -> tuple[str, int]:
    """The inside of the call whose `(` is at `open_at`, and where it ends."""
    depth = 0
    index = open_at
    while index < len(text):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return text[open_at + 1 : index], index
        index += 1
    return "", len(text)


def first_argument(inside: str) -> str:
    """Everything before the first comma that is not inside a call."""
    depth = 0
    for index, character in enumerate(inside):
        if character in "([":
            depth += 1
        elif character in ")]":
            depth -= 1
        elif character == "," and depth == 0:
            return inside[:index]
    return inside


def split_at_comparison(given: str) -> tuple[str, str, str] | None:
    """The two sides of the first comparison at the top level, and which it is."""
    depth = 0
    index = 0
    while index < len(given):
        character = given[index]
        if character in "([":
            depth += 1
        elif character in ")]":
            depth -= 1
        elif depth == 0:
            found = COMPARISON.match(given, index)
            if found:
                return (
                    given[:index].strip(),
                    found.group(0),
                    given[found.end() :].strip(),
                )
        index += 1
    return None


def is_the_distance(left: str) -> bool:
    """Whether the left side is an absolute value covering the whole of it."""
    left = left.strip()
    while left.startswith("(") and left.endswith(")"):
        inside, end = arguments(left, 0)
        if end != len(left) - 1:
            break
        left = inside.strip()
    for name in ("fabs", "abs"):
        if not left.startswith(name + "("):
            continue
        _inside, end = arguments(left, len(name))
        if end == len(left) - 1:
            return True
    return False


def main() -> int:
    wrong = []
    for path in TESTS:
        text = path.read_text()
        for found in re.finditer(r"assert_true\(", text):
            inside, _end = arguments(text, found.end() - 1)
            given = first_argument(inside).strip()
            parts = split_at_comparison(given)
            if parts is None:
                continue
            left, operator, right = parts
            if operator not in ("<", ">", "<=", ">="):
                continue
            if not NUMBER.match(right):
                continue
            if " - " not in left and " - " not in right:
                continue
            if is_the_distance(left) or is_the_distance(right):
                continue
            line = text[: found.start()].count("\n") + 1
            where = f"{path.name}:{line}"
            if where in ONE_SIDED:
                continue
            wrong.append((where, f"{left} {operator} {right}"))

    if not wrong:
        print("every tolerance in the suite is held to the whole difference")
        return 0

    print(f"{len(wrong)} assertion(s) hold an answer to one side of a difference:")
    for where, what in wrong:
        print(f"  {where}: {what}")
    print()
    print("  `answer - expected < epsilon` is true of every answer below the")
    print("  expected one. If a distance is meant, put the `fabs` around the")
    print("  difference rather than around one end of it; if a bound is meant,")
    print("  compare the two numbers and leave the subtraction out.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
