"""Point a binding at a sibling's symbol, and see whether any test notices.

`check-tests.py` asks that every binding be called by a test. It cannot ask
whether the answer was looked at: `_ = f(...)` counts the same as a test that
compares what came back with what C's own page says it should be, and a test
that asks a call for its answer and then throws the answer away passes just
as quietly when the binding is calling the wrong function.

That is the bug this repository has had: `gamma` called `tgamma`, which is the
gamma function rather than its logarithm, and every check was green. Nothing
compares one binding against another, so the only witness is a test failing
when the symbol underneath it changes.

This makes that change on purpose. Two bindings in the same file with the same
signature are interchangeable as far as the compiler is concerned -- same
return type, same argument types, both symbols exported -- so one is pointed at
the other's symbol and the tests that call it are run. Three answers:

  caught    a test failed, and its assertion is the reason. The suite has
            teeth here.
  crashed   the mutant took the process down without an assertion firing.
            Noticed, but not by anything written for the purpose.
  survived  every test passed with the binding calling the wrong function.
            Either the call's answer is never compared with anything, or the
            two functions agree on every input the test uses.
  error     the mutant did not build. Not evidence either way.

`--limit` samples, because each mutant is a full rebuild of the package and a
suite run. The sample is spread over the modules rather than taken from the
front, and it is the same sample every run so two runs can be compared.
"""

import argparse
import importlib.util
import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TESTS = sorted((ROOT / "tests").glob("*.mojo"))
TIMEOUT = 300


# Pairs that survive because the two symbols answer the same thing, not because
# nothing is looking. Each one was read and decided, the way `CANNOT_ASK` is in
# `check-tests.py`: a survivor that is not here is a test to write.
SAME_ANSWER = {
    "scalbn->ldexp": (
        "`ldexp(x, n)` is `scalbn(x, n)` with FLT_RADIX written as 2, and "
        "FLT_RADIX is 2 on both platforms: the same call under two names"
    ),
    "sched_getscheduler->sched_get_priority_max": (
        "the ordinary policy is numbered 0 and so is the highest priority it "
        "allows, so the wrong call answers 0 on a machine running ordinary "
        "policy -- the test asserts the policy number, and no other number "
        "can be asked for without a privilege"
    ),
}


def load(name: str):
    path = ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def callers(name: str) -> list[Path]:
    """Test files whose body mentions `name(` once the imports are gone.

    An import is an `from libc.x import (...)` that can run over several lines,
    and `test_import_all.mojo` is nothing but imports: counting it would make
    every binding "asked" by that file and run the wrong test.
    """
    hits = []
    for path in TESTS:
        lines = path.read_text().splitlines()
        kept, index = [], 0
        while index < len(lines):
            line = lines[index]
            if re.match(r"^\s*(from|import)\s", line):
                depth = line.count("(") - line.count(")")
                while depth > 0 and index + 1 < len(lines):
                    index += 1
                    depth += lines[index].count("(") - lines[index].count(")")
                index += 1
                continue
            kept.append(line)
            index += 1
        if re.search(rf"\b{re.escape(name)}\s*\(", "\n".join(kept)):
            hits.append(path)
    return hits


def def_block(text: str, name: str) -> tuple[int, int] | None:
    """Where one `def name(...)` runs, from the keyword to the next def."""
    start = re.search(rf"(?m)^def {re.escape(name)}\(", text)
    if start is None:
        return None
    close, depth = start.end() - 1, 0
    while close < len(text):
        if text[close] == "(":
            depth += 1
        elif text[close] == ")":
            depth -= 1
            if depth == 0:
                break
        close += 1
    nxt = re.search(r"(?m)^def ", text[close:])
    return start.start(), close + nxt.start() if nxt else len(text)


def mutate(path: Path, name: str, symbol: str, into: str) -> bool:
    text = path.read_text()
    span = def_block(text, name)
    if span is None:
        return False
    start, end = span
    body = text[start:end]
    swapped = re.sub(
        r'(external_call\[\s*)"' + re.escape(symbol) + '"', r'\1"' + into + '"', body
    )
    if swapped == body:
        return False
    path.write_text(text[:start] + swapped + text[end:])
    return True


def classify(result: subprocess.CompletedProcess) -> str:
    if result.returncode == 0:
        return "survived"
    both = (result.stdout or "") + (result.stderr or "")
    if "AssertionError" in both or "Unhandled exception" in both:
        return "caught"
    if "execution crashed" in both or result.returncode < 0:
        return "crashed"
    return "error"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=12, help="how many mutants")
    parser.add_argument("--seed", type=int, default=1, help="which sample")
    parser.add_argument(
        "--only", default="", help="comma separated binding names to keep"
    )
    parser.add_argument(
        "--strict", action="store_true", help="fail the run if a mutant survives"
    )
    args = parser.parse_args()

    prototypes = load("check-prototypes")
    every = prototypes.bindings()

    def here(path: str) -> Path:
        """`check-prototypes` walks relative to the root; this needs the file."""
        given = Path(path)
        return given if given.is_absolute() else ROOT / given

    groups: dict[tuple[str, str, tuple[str, ...]], list[tuple[str, str]]] = {}
    for path, name, symbol, _nargs, ret, argtypes in every:
        groups.setdefault((str(here(path)), ret, tuple(argtypes)), []).append(
            (name, symbol)
        )

    mutants = []
    for (path, ret, argtypes), members in groups.items():
        if len(members) < 2:
            continue
        for name, symbol in members:
            other = next((s for n, s in members if s != symbol), None)
            if other is None or not callers(name):
                continue
            mutants.append((path, name, symbol, other, ret, argtypes))

    if args.only:
        wanted = {name.strip() for name in args.only.split(",")}
        mutants = [m for m in mutants if m[1] in wanted]

    mutants.sort(key=lambda m: (m[0], m[1]))
    random.Random(args.seed).shuffle(mutants)

    # One per module first, so a dozen mutants are a dozen modules rather than
    # a dozen `isw*` comparisons.
    picked, seen = [], set()
    for mutant in mutants:
        module = Path(mutant[0]).relative_to(SRC).parts[0]
        if module in seen:
            continue
        seen.add(module)
        picked.append(mutant)
        if len(picked) == args.limit:
            break
    for mutant in mutants:
        if len(picked) == args.limit:
            break
        if mutant not in picked:
            picked.append(mutant)

    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / "src"
        shutil.copytree(SRC, copy)
        print(f"{len(picked)} mutant(s), one `mojo run` each\n")
        tally = {"caught": 0, "crashed": 0, "same": 0, "survived": 0, "error": 0}
        for path, name, symbol, other, ret, argtypes in picked:
            target = copy / Path(path).relative_to(SRC)
            pristine = target.read_text()
            if not mutate(target, name, symbol, other):
                print(f"  ?? {name}: could not be mutated")
                continue
            tests = callers(name)
            outs = []
            for test in tests:
                result = subprocess.run(
                    [
                        "pixi",
                        "run",
                        "mojo",
                        "run",
                        "-I",
                        str(copy),
                        "-I",
                        "tests",
                        str(test.relative_to(ROOT)),
                    ],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    timeout=TIMEOUT,
                )
                outs.append(classify(result))
            target.write_text(pristine)
            verdict = "caught" if "caught" in outs else outs[0]
            where = f"{Path(path).relative_to(SRC / 'libc')}:{name}"
            known = SAME_ANSWER.get(f"{symbol}->{other}")
            if verdict == "survived" and known:
                verdict = "same"
            tally[verdict] += 1
            print(f"  {verdict:9} {where:44} {symbol} -> {other}")
            if known:
                print(f"            {known}")
            if verdict == "error":
                tail = (result.stderr or "").strip().splitlines()
                for line in tail[-3:]:
                    print(f"            {line.strip()[:110]}")

        print()
        print(
            f"  caught {tally['caught']}, crashed {tally['crashed']},"
            f" same answer {tally['same']}, survived {tally['survived']},"
            f" did not build {tally['error']}"
        )
        if tally["survived"]:
            print("  a survivor is a call whose answer nothing compares against")
            return 1 if args.strict else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
