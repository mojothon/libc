"""Every constant mutant changes the literal the mistake names.

`mutation-probe` finds a branch's answer after the branch before it,
because a short answer is a substring of a longer one earlier in the
chain -- `4` is the first digit of `4103`, and a walk that takes the
first hit lands inside the branch the compiling machine never reads.
The mutant then names one literal and changes another, and every
verdict about it is a verdict about a number nothing adds up: a
survivor that was never a survivor, a caught that was never asked.

This asks the invariant `apply` goes on -- the `first` number in the
block is the literal the mutant names -- of every constant mutant,
which is a question of regexes and costs seconds. The full walk of
tables beside which this sits is `mutation-tables`, which is minutes.
"""

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
path = ROOT / "scripts" / "mutation-probe.py"
spec = importlib.util.spec_from_file_location("mutation-probe", path)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def main() -> int:
    mutants = probe.build("constant")
    wrong = probe.walk_problems(mutants)
    if not wrong:
        print(
            f"all {len(mutants)} constant mutants land on the literal"
            " the mistake names"
        )
        return 0
    print(f"{len(wrong)} mutant(s) whose mistake lands somewhere else:")
    for problem in wrong:
        print(f"  {problem}")
    print()
    print("  A mutant that names one literal and changes another is a verdict")
    print("  about a number no run reads -- the branch the machine compiles")
    print("  out was the one mistaken instead.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
