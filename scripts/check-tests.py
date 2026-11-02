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
    "getchar": "reads standard input, which a suite cannot promise has an end",
    "getchar_unlocked": "reads standard input, as `getchar` does",
    "getwchar": "reads standard input a wide character at a time",
    "scanf": "reads standard input, and takes its arguments after them",
    "pause": "waits for a signal, which is a suite that stops",
    "sigsuspend": "waits for a signal to arrive",
    "sigwait": "the same, and glibc waits rather than refusing an empty set",
    "pthread_cond_wait": "waits for another thread, and a test that waits is one that hangs",
    "_Exit": "ends the process, so nothing after it in the same suite runs",
    "system": "starts a shell, and hands back its exit status rather than an answer",
    "setsid": "takes the process out of its terminal session, for every test after it",
    "pthread_cancel": "cancels a thread that the rest of the suite is sharing",
    "pthread_atfork": "asks for a fork, and this suite has one process to lose",
    "prctl": "Linux only, and the interesting requests change the running process",
    "ioctl": "variadic: what it does is decided by its second argument",
    "sched_getcpucount": "glibc does not export it, so calling it would not link",
    "isascii_l": "glibc does not export it, so calling it would not link",
}

# Bindings that could be asked something and have not been. This is the list
# to empty, and the run fails if it grows: a binding nobody calls is how the
# `gl_flags` bug survived three releases.
NOT_YET = {
    "fdopen": "writes through a stream, as `puts` does",
    "fflush": "writes through a stream, as `puts` does",
    "perror": "writes to standard error, which the suite's own output goes to",
    "puts": "writes to standard output, and the suite prints its progress there",
    "putchar_unlocked": "writes to standard output, as `puts` does",
    "putwchar": "writes to standard output, as `puts` does",
    "posix_spawn_file_actions_addopen": "needs a spawn to observe",
    "pthread_detach": "needs a thread whose ending nothing waits for",
    "pthread_mutex_getprioceiling": "needs a priority-ceiling mutex, and the privilege to make one",
    "pthread_mutex_setprioceiling": "the same, and it asks for the privilege again",
    "sched_rr_get_interval": "answers only for a process already running round-robin",
    "sched_setscheduler": "asks for a privilege the suite does not have",
}


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

    print()
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
    print("  every binding is asked something, or says why it cannot be")
    return 0


if __name__ == "__main__":
    sys.exit(main())
