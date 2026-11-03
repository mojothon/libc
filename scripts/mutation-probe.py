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
the other's symbol and the tests that call it are run. Five answers:

  caught    a test failed, and its assertion is the reason. The suite has
            teeth here.
  crashed   the mutant took the process down without an assertion firing.
            Noticed, but not by anything written for the purpose.
  hung      a test neither passed nor failed: it stopped answering and the run
            was killed at its timeout. A lock taken and never given back does
            this, and it is worse than a survivor -- nothing after it in that
            file is asked at all, and a suite that does this in CI waits for
            the job's own timeout instead of reporting.
  survived  every test passed with the binding calling the wrong function.
            Either the call's answer is never compared with anything, or the
            two functions agree on every input the test uses.
  error     the mutant did not build. Not evidence either way.

`--kind order` asks a different question with the same method: instead of
pointing a binding at a sibling symbol, it hands two arguments of the same type
to C in the other order. `chown(path, owner, group)` and `chown(path, group,
owner)` are the same string, the same return type and the same three argument
types, so nothing but a test with two different numbers in those positions can
tell them apart -- and a test that passes `getuid()` for both has not.

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
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TESTS = sorted((ROOT / "tests").glob("*.mojo"))
# A test file that has not answered in two minutes has stopped answering: the
# suite is seconds per file, and the slowest of them wait on threads and
# sleeps that are bounded. The number is here to end a hang, not to hurry a
# slow machine.
TIMEOUT = 120


# Pairs that survive because the two symbols answer the same thing, not because
# nothing is looking. Each one was read and decided, the way `CANNOT_ASK` is in
# `check-tests.py`: a survivor that is not here is a test to write.
SAME_ANSWER = {
    "scalbn->ldexp": (
        "`ldexp(x, n)` is `scalbn(x, n)` with FLT_RADIX written as 2, and "
        "FLT_RADIX is 2 on both platforms: the same call under two names"
    ),
    "cfgetospeed->cfgetispeed": (
        "a terminal has one speed and not two: on glibc both functions read "
        "the same `CBAUD` bits of `c_cflag` -- a probe printing the flag at "
        "each step shows `cfsetispeed` writing them and `cfsetospeed` "
        "overwriting them -- so the two answer the same number, and "
        "`c_ispeed`, the field only one of them would read, is not read by "
        "either"
    ),
    "endgrent->setgrent": (
        "closing the group database and winding it back are the same thing "
        "from outside: either way the next `getgrent` opens at the first row, "
        "and the descriptor that differs between them is not something the "
        "API hands out"
    ),
    "llrintf->lrintf": (
        "`long` and `long long` are both 64 bits on the two platforms this is "
        "built for, and the two round the same way, so the answer is the same "
        "value under a declared width that happens to agree: a difference "
        "only ILP32 would show"
    ),
    "sched_getscheduler->sched_get_priority_max": (
        "the ordinary policy is numbered 0 and so is the highest priority it "
        "allows, so the wrong call answers 0 on a machine running ordinary "
        "policy -- the test asserts the policy number, and no other number "
        "can be asked for without a privilege"
    ),
}


# The same table for the second axis: a survivor that is here is one where the
# two arguments are interchangeable, or where the order is nothing the API
# hands back.
SAME_ORDER = {
    "fmax:x <-> y": (
        "the larger of two numbers does not know which was written first: "
        "`fmax` is commutative, including for a NaN, where both orders answer "
        "the one number"
    ),
    "hypot:x <-> y": (
        "the square root of the sum of two squares does not know which addend "
        "came first, and the host order is one addition on top of the other"
    ),
    "openlog:logopt <-> facility": (
        "both are small integers that `syslog` reads, and what it does with "
        "them is write a line to a daemon this process never reads back: the "
        "wrong pair is a line filed under a strange facility, not an answer"
    ),
    "catgets:set_id <-> msg_id": (
        "the only catalog this suite can open is one that did not open, and a "
        "catalog that never opened hands back the string it was given whatever "
        "set and message it is asked for; one with rows in it is a binary "
        "`.cat` file, which is a thing to ship rather than a path to point at"
    ),
    "sscanf:s <-> format": (
        "the format it is given has no conversion in it, because the places a "
        "conversion writes to are in the variadic part and this FFI cannot "
        "pass them -- and a format with nothing to convert answers 0 for any "
        "input at all, so both orders answer 0"
    ),
    "bcmp:s1 <-> s2": (
        "it answers zero or not and nothing else: BSD documents the return as "
        "zero when the blocks are the same and non-zero otherwise, so both "
        "orders answer the same non-zero value and no test can tell them apart "
        "without asserting something the standard does not promise"
    ),
    "fmaxf:x <-> y": (
        "the larger of two numbers does not know which was written first, for "
        "the reason `fmax` does not"
    ),
    "fminf:x <-> y": (
        "the smaller of two numbers does not know which was written first, for "
        "the reason `fmax` does not"
    ),
    "fma:x <-> y": (
        "the first two arguments are multiplied, and a product does not "
        "remember its order: the third argument is the one that is added "
        "rather than multiplied, and it is not the one being swapped"
    ),
    "calloc:nmemb <-> size": (
        "the block is the product of the two, zeroed, and the overflow check "
        "is on the same product: `calloc(2, 8)` and `calloc(8, 2)` are "
        "sixteen zeroed bytes either way"
    ),
    "scandir:selector <-> compar": (
        "both are callbacks, and this FFI has no way to hand C a function "
        "address, so both are NULL here and the swap is the same two zeroes"
    ),
    "fchownat:owner <-> group": (
        "the call this suite can make is refused before the two ids are read: "
        "a path that is not there with `AT_FDCWD`, which answers ENOENT "
        "either way round"
    ),
    "chown:owner <-> group": (
        "every `chown` this suite can ask about is one that fails: the paths do "
        "not exist, and giving a file to somebody else is refused before the "
        "two ids are looked at -- so the ids can be the other way round and "
        "the answer is the same -1 with the same errno"
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


@dataclass(frozen=True)
class Mutant:
    """One deliberate mistake, and what it is called in the report."""

    path: str
    name: str
    kind: str
    what: str
    symbol: str = ""
    into: str = ""
    first: int = -1
    second: int = -1


# The words a parameter can be prefixed with. They say what a caller may do
# with it, not what type it is, so they come off before the two are compared.
MARKERS = ("mut ", "out ", "read ", "var ", "owned ", "borrowed ", "inout ", "deinit ")


def split_arguments(inside: str) -> list[str]:
    """The pieces of a comma-separated list, by counting brackets."""
    parts, depth, current = [], 0, ""
    for char in inside:
        if char in "[(":
            depth += 1
        elif char in "])":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
            continue
        current += char
    parts.append(current)
    return parts


def parameters(text: str, name: str) -> list[tuple[str, str]]:
    """The parameters of one `def name(...)`, as (name, type).

    Types are compared as they are written rather than resolved. Two arguments
    are worth exchanging when the compiler sees one type on both, and the text
    of the type is the nearest thing to that which does not need a compiler.
    """
    start = re.search(rf"(?m)^def {re.escape(name)}\(", text)
    if start is None:
        return []
    close, depth = start.end() - 1, 0
    while close < len(text):
        if text[close] == "(":
            depth += 1
        elif text[close] == ")":
            depth -= 1
            if depth == 0:
                break
        close += 1

    found = []
    for part in split_arguments(text[start.end() : close]):
        part = part.strip()
        if not part or part.startswith("/") or part.startswith("*"):
            continue
        for marker in MARKERS:
            if part.startswith(marker):
                part = part[len(marker) :].strip()
        given, _, kind = part.partition(":")
        kind = kind.split("=")[0].strip()
        if given and kind:
            found.append((given.strip(), kind))
    return found


def reverse_arguments(
    body: str, names: list[str], first: int, second: int
) -> str | None:
    """The same body with two of the call's arguments exchanged.

    Only a call that is handed the parameters themselves, in order, is worth
    doing: anything else is passing an expression, and two expressions of the
    same type are not two arguments a reader could have misplaced.
    """
    call = re.search(r"external_call\[", body)
    if call is None:
        return None
    close, depth = call.end() - 1, 0
    while close < len(body):
        if body[close] == "[":
            depth += 1
        elif body[close] == "]":
            depth -= 1
            if depth == 0:
                break
        close += 1
    opened = re.match(r"\s*\(", body[close + 1 :])
    if opened is None:
        return None
    open_at = close + 1 + opened.end() - 1
    end, depth = open_at, 0
    while end < len(body):
        if body[end] == "(":
            depth += 1
        elif body[end] == ")":
            depth -= 1
            if depth == 0:
                break
        end += 1

    given = [piece.strip() for piece in split_arguments(body[open_at + 1 : end])]
    if given != names or len(given) <= second:
        return None
    given[first], given[second] = given[second], given[first]
    return body[: open_at + 1] + ", ".join(given) + body[end:]


def apply(target: Path, mutant: Mutant) -> bool:
    """Make the mistake in `target`, and say whether it landed."""
    text = target.read_text()
    span = def_block(text, mutant.name)
    if span is None:
        return False
    start, end = span
    body = text[start:end]
    if mutant.kind == "symbol":
        changed = re.sub(
            r'(external_call\[\s*)"' + re.escape(mutant.symbol) + '"',
            r'\1"' + mutant.into + '"',
            body,
        )
    else:
        names = [given for given, _kind in parameters(text, mutant.name)]
        changed = reverse_arguments(body, names, mutant.first, mutant.second)
        if changed is None:
            return False
    if changed == body:
        return False
    target.write_text(text[:start] + changed + text[end:])
    return True


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
        "--kind",
        default="symbol",
        choices=("symbol", "order"),
        help="wrong function, or two arguments the other way round",
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

    mutants: list[Mutant] = []
    if args.kind == "symbol":
        groups: dict[tuple[str, str, tuple[str, ...]], list[tuple[str, str]]] = {}
        for path, name, symbol, _nargs, ret, argtypes in every:
            groups.setdefault((str(here(path)), ret, tuple(argtypes)), []).append(
                (name, symbol)
            )
        for (path, ret, argtypes), members in groups.items():
            if len(members) < 2:
                continue
            for name, symbol in members:
                other = next((s for n, s in members if s != symbol), None)
                if other is None or not callers(name):
                    continue
                mutants.append(
                    Mutant(path, name, "symbol", f"{symbol} -> {other}", symbol, other)
                )
    else:
        for given, name, _symbol, _nargs, _ret, _argtypes in every:
            if not callers(name):
                continue
            path = str(here(given))
            params = parameters(here(given).read_text(), name)
            pair = next(
                (
                    index
                    for index in range(len(params) - 1)
                    if params[index][1] == params[index + 1][1]
                ),
                None,
            )
            if pair is None:
                continue
            # The first pair is asked, not every pair: three arguments of one
            # type are three ways to be wrong about the same three names, and
            # the sample is spread over bindings rather than over one of them.
            mutants.append(
                Mutant(
                    path,
                    name,
                    "order",
                    f"{params[pair][0]} <-> {params[pair + 1][0]}",
                    first=pair,
                    second=pair + 1,
                )
            )

    if args.only:
        wanted = {name.strip() for name in args.only.split(",")}
        mutants = [m for m in mutants if m.name in wanted]

    mutants.sort(key=lambda m: (m.path, m.name))
    random.Random(args.seed).shuffle(mutants)

    # One per module first, so a dozen mutants are a dozen modules rather than
    # a dozen `isw*` comparisons.
    picked, seen = [], set()
    for mutant in mutants:
        module = Path(mutant.path).relative_to(SRC).parts[0]
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
        print(f"{len(picked)} {args.kind} mutant(s), one `mojo run` each\n")
        tally = {
            "caught": 0,
            "crashed": 0,
            "hung": 0,
            "same": 0,
            "survived": 0,
            "error": 0,
        }
        for mutant in picked:
            target = copy / Path(mutant.path).relative_to(SRC)
            pristine = target.read_text()
            if not apply(target, mutant):
                print(f"  ?? {mutant.name}: could not be mutated")
                continue
            tests = callers(mutant.name)
            outs = []
            for test in tests:
                try:
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
                except subprocess.TimeoutExpired:
                    # A mutated lock or wait can leave the file waiting rather
                    # than failing, and that is a verdict of its own: the run
                    # does not stop at it, and the mutant after it still gets
                    # asked.
                    outs.append("hung")
                    continue
                outs.append(classify(result))
            target.write_text(pristine)
            verdict = "caught" if "caught" in outs else outs[0]
            where = f"{Path(mutant.path).relative_to(SRC / 'libc')}:{mutant.name}"
            if mutant.kind == "order":
                where += f" ({mutant.what})"
            known = SAME_ANSWER.get(f"{mutant.symbol}->{mutant.into}")
            if mutant.kind == "order":
                known = SAME_ORDER.get(f"{mutant.name}:{mutant.what}")
            if verdict == "survived" and known:
                verdict = "same"
            tally[verdict] += 1
            if mutant.kind == "symbol":
                print(f"  {verdict:9} {where:44} {mutant.what}")
            else:
                print(f"  {verdict:9} {where}")
            if known:
                print(f"            {known}")
            if verdict == "error":
                tail = (result.stderr or "").strip().splitlines()
                for line in tail[-3:]:
                    print(f"            {line.strip()[:110]}")

        print()
        print(
            f"  caught {tally['caught']}, crashed {tally['crashed']},"
            f" hung {tally['hung']}, same answer {tally['same']},"
            f" survived {tally['survived']}, did not build {tally['error']}"
        )
        if tally["survived"] or tally["hung"]:
            if tally["survived"] and args.kind == "order":
                print("  a survivor is a call whose two arguments nothing tells apart")
            elif tally["survived"]:
                print("  a survivor is a call whose answer nothing compares against")
            if tally["hung"]:
                print("  a hang is a call whose tests wait for it instead: nothing")
                print("  in that file after it was asked, and nothing was compared")
            return 1 if args.strict else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
