"""Check that every binding is asked something by a test.

`gl_flags` was read from the wrong half of a word for three releases. Every
check in `scripts/` passed the whole time: the offset was the one the module
named, the name was the one the header has, the symbol was exported, the
size was right. What was missing was a test that gave `glob` a flag and
looked at what came back, and no list said which calls had nobody looking at
them.

This is that list. It walks the same bindings `check-prototypes.py` does and
asks `tests/` which ones it calls, ignoring imports — `test_import_all.mojo`
imports every symbol the package has, which would otherwise make the answer
"all of them".

Two things keep this from being a wall of names. A test that reads stdin,
waits for a signal or ends the process cannot be written in a suite that
runs after the test before it, and those are listed with the reason. The
rest is `NOT_YET`: bindings that could be asked something and have not been.
That list is a debt rather than a failure, and it fails the run only if it
grows — a new binding with no test is the thing this is for, and a debt that
counts down is one somebody is paying.
"""

import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = sorted((ROOT / "tests").glob("*.mojo"))


def load(name: str):
    """Both scripts need the same walk, and only one of them should hold it."""
    path = ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# A test cannot ask these, and each answer is a different reason why. Every
# one of them is in the package on purpose — a binding is not only for the
# calls this suite can make — so the point is that the reason is written
# down rather than that the call is gone.
CANNOT_ASK = {
    "pthread_atfork": "the suite is run just-in-time, and the JIT run does not resolve this one — a built binary links and answers fine",
    "putwchar": "standard output is process-wide and narrow-oriented by the suite already, and a forked child inherits that orientation — a wide write to it is not defined by C",
    "ioctl": "variadic: what it does is decided by its second argument",
}

# Bindings that could be asked something and have not been. This is the list
# to empty, and the run fails if it grows: a binding nobody calls is how the
# `gl_flags` bug survived three releases.
# Empty at the moment, which is not the same as gone: a new binding with
# nobody asking it anything goes here, and the run fails if that happens.
# What paid the last six off was noticing that four of the reasons were
# not reasons — the suite already had a lock, a thread (the initial one),
# and a process whose policy it could ask to keep.
NOT_YET = {}

# `docs/modules.md` ends with what the suite does not ask, and it names calls
# while it says it. That section had drifted a long way: it was still calling
# `sigwait` and `getchar` unasked after both had been asked, and it still
# counted 977 asked and 17 not when the numbers were 989 and 11. Prose about
# calls is prose about state, so it is read back here: every call named in
# that section has to be one `CANNOT_ASK` is holding, and the two numbers it
# states have to be the two counted above. The section is found by heading,
# so a page that stops having one fails rather than silently unhooks.
STATED_ASKED = re.compile(
    r"(\d+) bindings are asked something, and the (\d+) that are not"
)
BACKTICKED = re.compile(r"`([\w.]+)`")


def stale_page(names: set[str], asked: list[str], unasked: list[str]) -> list[str]:
    """Where `docs/modules.md` and this file disagree about what is unasked."""
    text = (ROOT / "docs" / "modules.md").read_text()
    start = text.find("## What the suite does not ask")
    if start < 0:
        return ["no longer has a section saying what the suite does not ask"]
    end = text.find("\n## ", start + 1)
    section = text[start:] if end < 0 else text[start:end]

    wrong = []
    named = 0
    for token in BACKTICKED.findall(section):
        call = token.rsplit(".", 1)[-1]
        if call not in names and call not in CANNOT_ASK:
            continue
        named += 1
        if call in asked:
            wrong.append(f"{call}: the page says it is not asked, and a test asks it")
    if named == 0:
        wrong.append("names no call, so the section is not saying anything")

    said = STATED_ASKED.search(section)
    if said is None:
        wrong.append("no longer says how many bindings are asked")
    else:
        if int(said.group(1)) != len(asked):
            wrong.append(
                f"says {said.group(1)} bindings are asked, and {len(asked)} are"
            )
        if int(said.group(2)) != len(unasked):
            wrong.append(
                f"says {said.group(2)} are not asked, and {len(unasked)} are not"
            )
    return wrong


def called_by_tests() -> set[str]:
    """Every name a test calls, with the imports taken out."""
    text = []
    for path in TESTS:
        lines = path.read_text().splitlines()
        index = 0
        while index < len(lines):
            line = lines[index]
            if re.match(r"^\s*(from|import)\s", line):
                depth = line.count("(") - line.count(")")
                while depth > 0 and index + 1 < len(lines):
                    index += 1
                    depth += lines[index].count("(") - lines[index].count(")")
                index += 1
                continue
            text.append(line)
            index += 1
    body = "\n".join(text)
    return set(re.findall(r"\b(\w+)\s*\(", body))


# The two files in `tests/` that the suite does not start. `test_main.mojo`
# is the suite, and `test_smoke.mojo` is the check `recipe/recipe.yaml` runs
# against a built package, where it cannot print anything (its docstring says
# why). Both are entries rather than tests, so the count below is not for them.
NOT_SUITE = {"test_main.mojo", "test_smoke.mojo"}


def unrun_tests() -> tuple[list[str], list[str]]:
    """Tests that nothing calls, and test files the runner does not start.

    A test function that no line in its own `main` calls is a test that has
    never run, and it reads exactly like one that has: it is there in the file,
    it has a docstring saying what it asks, and `all tests passed` says nothing
    about it either way. Two were found in this state — a `killpg` test in
    `test_signal.mojo` and a `clock_nanosleep` one in `test_time.mojo` — and
    both passed the first time they were made to run, which is the harmless
    version of the same story.

    The file-level half is the same argument one step up: a `tests/test_x.mojo`
    whose `main` the runner never imports is a whole suite that does not run.
    """
    orphans: list[str] = []
    for path in TESTS:
        text = path.read_text()
        defined = re.findall(r"^def (test_\w+)", text, re.M)
        called = set(re.findall(r"^\s+(test_\w+)\(\)", text, re.M))
        orphans += [f"{path.name}: {name}" for name in defined if name not in called]

    runner = (ROOT / "tests" / "test_main.mojo").read_text()
    started = set(re.findall(r"^\s+run_(\w+)\(\)", runner, re.M))
    unstarted = [
        path.name
        for path in TESTS
        if path.name not in NOT_SUITE
        and path.stem.removeprefix("test_") not in started
    ]
    return orphans, unstarted


def main() -> int:
    prototypes = load("check-prototypes")
    names = {name for _path, name, _symbol, _args, _ret, _params in prototypes.bindings()}
    called = called_by_tests()

    asked = sorted(name for name in names if name in called)
    unasked = sorted(name for name in names if name not in called)
    unexplained = [name for name in unasked if name not in CANNOT_ASK and name not in NOT_YET]
    paid = sorted(
        name for name in (*CANNOT_ASK, *NOT_YET) if name in asked or name not in names
    )
    still = [name for name in unasked if name in NOT_YET]

    if unasked:
        print(f"\n  {len(unasked)} of {len(names)} bindings are called by no test:")
        for name in unasked:
            why = CANNOT_ASK.get(name) or NOT_YET.get(name) or ""
            print(f"    {name:34} {why}")

    print(
        f"\n  {len(asked)} asked, {len(unasked)} not:"
        f" {len(CANNOT_ASK)} that a test cannot ask,"
        f" {len(still)} that no test has asked yet"
    )
    if not still:
        print("  nothing a test could ask is left unasked")

    orphans, unstarted = unrun_tests()
    if orphans:
        plural = "" if len(orphans) == 1 else "s"
        print(f"\n  {len(orphans)} test{plural} that no line calls, so never run:")
        for name in orphans:
            print(f"    {name}")
    if unstarted:
        plural = "" if len(unstarted) == 1 else "s"
        print(f"\n  {len(unstarted)} test file{plural} the runner does not start:")
        for name in unstarted:
            print(f"    {name}")

    print()
    page = stale_page(names, asked, unasked)
    if page:
        print("  *** docs/modules.md and this file disagree ***")
        for line in page:
            print(f"    {line}")
        print("  the page says what is not asked, and this is where it is counted")
        return 1
    if unexplained:
        print("  *** bindings with no test and no reason ***")
        for name in unexplained:
            print(f"    {name}")
        print("  write the test, or say here why there cannot be one")
        return 1
    if paid:
        print("  *** bindings listed here that a test now calls ***")
        for name in paid:
            print(f"    {name}")
        print("  take them out of the list, so that the count stays honest")
        return 1
    if orphans or unstarted:
        print("  *** tests that are written and never run ***")
        print("  a test nothing calls has not been keeping anything honest")
        return 1
    print("  every binding is asked something, or says why it cannot be")
    print("  and every test in tests/ is called by the suite that holds it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
