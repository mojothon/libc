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
            Noticed, but not by anything written for the purpose -- most of
            these are an exchange of arguments handing a function a buffer
            it will write through or read past, and the death is the
            memory's answer, not the test's. A run that ends in silence is
            one of these too: the crash reporter writes a dump instead of a
            message when its own bookkeeping is stuck, and a buffer lost
            with the process takes the assertion with it. A crash is asked
            a second time, because the same mutant can die on one page
            boundary and answer on the next.
  hung      a test neither passed nor failed: it stopped answering and the run
            was killed at its timeout. A lock taken and never given back does
            this, and it is worse than a survivor -- nothing after it in that
            file is asked at all, and a suite that does this in CI waits for
            the job's own timeout instead of reporting.
  survived  every test passed with the binding calling the wrong function.
            Either the call's answer is never compared with anything, or the
            two functions agree on every input the test uses. A survivor is
            asked a second time before it is reported, because a mistake
            that forks a waiter can pass or fail by interleaving.
  flaky     answered one way on the first asking and another on the second:
            survived and caught, or caught against a table that says nobody
            can see the mistake at all. The second kind is how a failure in
            some other test of the same file lands on a mutant it has
            nothing to do with -- a run is a file, and a file is many
            tests. Either way one run is one sample, and the suite noticing
            there too, just not every time, is worth knowing about the
            test.
  error     the mutant did not build -- the compiler named a line, or the JIT
            could not find the symbol. Not evidence either way.

`--kind order` asks a different question with the same method: instead of
pointing a binding at a sibling symbol, it hands two arguments of the same type
to C in the other order. `chown(path, owner, group)` and `chown(path, group,
owner)` are the same string, the same return type and the same three argument
types, so nothing but a test with two different numbers in those positions can
tell them apart -- and a test that passes `getuid()` for both has not.

`--limit` samples, because each mutant is a full rebuild of the package and a
suite run. The sample is spread over the modules rather than taken from the
front, and it is the same sample every run so two runs can be compared.

`--kind constant` asks it of the numbers the layouts are spelled with: a
`comptime DIRENT_INO_OFFSET = 0` made 1, a `DIRENT_BYTES` made one byte
longer. This is the mistake shape `gl_flags` wore for three releases -- the
right size and the wrong value, read from the wrong place and believed --
and the question is whether anything in `tests/` notices before a caller
does. The constants are the ones `check-layouts` maps to C members, and the
test files asked are the ones importing that module, plus `test_layout`,
which is where the offsets are asserted.

`--jobs` asks several mutants at once, each against its own copy of the tree.
The suite is what takes the time and it is mostly one process compiling, so
this is the only way a sweep of the whole axis is an evening's work rather than
a day's; the answers are the same count, because a mutant is still one mutation
and one run of the tests that call it.

`--check-tables` asks nothing of the suite and takes seconds: it reads the two
reasons tables back against the mutants that can still be built, because a
reason that outlives the pair it was written for is worse than no reason at
all. Renaming a parameter, adding a third binding to a file, changing a
signature so a call is no longer handed its own parameters -- any of those
leaves an entry standing that excuses a mistake nothing makes any more, and the
table is then a list of things nobody has checked. The same goes the other way
round and only a run can see it: an entry whose mutant is now caught is an
entry that has been answered, and the run says so.
"""

import argparse
import concurrent.futures
import ctypes
import functools
import importlib.util
import os
import platform
import random
import signal
import re
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TESTS = sorted((ROOT / "tests").glob("*.mojo"))
# A test file that has not answered in two minutes has stopped answering: the
# suite is seconds per file, and the slowest of them wait on threads and
# sleeps that are bounded. The number is here to end a hang, not to hurry a
# slow machine -- but a worker asking `jobs` runs at once is asking for a
# fraction of the machine each, and on a four-core runner four compilations
# share it whole, where a run that answers in half a minute alone can need
# five. The environment that makes the machine busy is the one that says how
# long an answer may take to arrive.
TIMEOUT = int(os.environ.get("MUTATION_TIMEOUT", "120"))


# Pairs that survive because the two symbols answer the same thing, not because
# nothing is looking. Each one was read and decided, the way `CANNOT_ASK` is in
# `check-tests.py`: a survivor that is not here is a test to write.
#
# The key is written one way round and read both: the claim it carries is that
# these two are the same call, and that claim has no direction. It is read
# this way because the probe points each member of a group at one other, so a
# group of two makes two mutants -- writing the reason twice would say the same
# thing twice, and writing it once, as this table did, left the other direction
# excused by nothing.
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
    "llround->lround": (
        "`long` and `long long` are both 64 bits on the two platforms this is "
        "built for, and both round a half away from zero, so the answer is the "
        "same value under a declared width that happens to agree: a difference "
        "only ILP32 would show, for the reason `llrintf->lrintf` is here"
    ),
    # Measured with dlsym in this process: one address each.
    "memcpy->memmove": (
        "glibc resolves `memcpy` and `memmove` to one address on this "
        "platform -- `dlsym` says so -- so the two names run one routine, and "
        "that routine is the overlap-safe one. The test that asks `memmove` to "
        "survive an overlap still passes, because what ran was the code that "
        "promises it"
    ),
    "mktime->timelocal": (
        "`timelocal` is a weak alias of `mktime` in glibc, one address, so "
        "the call that runs is the call that was meant"
    ),
    "htonl->ntohl": (
        "the same arithmetic on every input, which is what these two are: on "
        "a little-endian machine both byte-swap, on a big-endian one both do "
        "nothing, and neither looks at where the bytes came from. The names "
        "differ in what they are for"
    ),
    "htons->ntohs": (
        "the same for the sixteen-bit pair, for the same reason"
    ),
    "cfsetspeed->cfsetispeed": (
        "the same one storage, which is what setting both at once comes to "
        "here: the input and the output speed are the same bits, and either "
        "setter writes them"
    ),
    # One routine under two names, measured: `nm` puts `strtoll` and `strtoq` at
    # the same address in glibc, and `strtoull` and `strtouq` at another one.
    "strtoll->strtoq": (
        "glibc's `strtoq` is a weak alias of `strtoll` -- the two are one "
        "address in the library -- so the call that runs is the call that was "
        "meant. The pair is BSD's older spelling, and both platforms this "
        "package targets make them the same routine"
    ),
    "strtoull->strtouq": (
        "the same for the unsigned pair: `strtouq` and `strtoull` are one "
        "address in glibc, and Darwin spells the older name over the newer "
        "one the same way"
    ),
    "fputwc->putwc": (
        "glibc's header spells `putwc` as `fputwc` -- the macro is the whole "
        "of it -- and the symbol the library exports under that name writes "
        "the same wide character to the same stream and answers it back"
    ),
    "fgetwc->getwc": (
        "the same spelling the other way: `getwc` is `fgetwc` in the header, "
        "and the exported symbol reads the same character with the same lock "
        "held"
    ),
    "ldexpf->scalbnf": (
        "`ldexpf(x, n)` is `scalbnf(x, n)` with FLT_RADIX written as 2, and "
        "FLT_RADIX is 2 on both platforms: the same call under two names, the "
        "way `scalbn->ldexp` above is"
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
    "fmin:x <-> y": (
        "the smaller of two numbers does not know which was written first, for "
        "the reason `fmax` does not"
    ),
    "hypotf:x <-> y": (
        "the float twin of `hypot`, and a sum of squares does not remember "
        "which addend came first"
    ),
    "fmaf:x <-> y": (
        "the float twin of `fma`: the first two are multiplied, and a product "
        "does not remember its order"
    ),
    "pthread_equal:t1 <-> t2": (
        "whether two handles name the same thread is the same question with "
        "them either way round, and the answer is zero or not"
    ),
    "thrd_equal:lhs <-> rhs": (
        "the C11 spelling of the same question: equality of two handles is a "
        "symmetric ask, and swapping the operands asks it of the same pair "
        "either way"
    ),
    "setreuid:ruid <-> euid": (
        "this process has no privilege, so the only ids it may ask for are the "
        "pair it already has -- and they are the same number, so the swap is "
        "the same pair. The pair that differs is the one a privileged process "
        "would be refused"
    ),
    "setregid:rgid <-> egid": (
        "the group ids this process may ask for are its own, and the two are "
        "the same number, for the reason `setreuid`'s are"
    ),
    "lchown:owner <-> group": (
        "every `lchown` a suite without a privilege can ask about is refused "
        "before the two ids are read: the paths do not exist, and changing a "
        "file's owner is not for this user -- either way round the answer is "
        "the same -1 with the same errno"
    ),
    "sched_setscheduler:pid <-> policy": (
        "the only policy this suite may ask for is the one it is already on, "
        "`SCHED_OTHER`, which is 0 -- and 0 is also the pid that means this "
        "process, so the swap is the same call"
    ),
    "adjtime:delta <-> olddelta": (
        "the adjustment asked for is a zero timeval, because moving the clock "
        "needs a privilege this suite does not have, and both arguments are "
        "then the same two zeroed structs"
    ),
    "getnetgrent:host <-> user": (
        "the walk finds no triple, so nothing is written to any of the three "
        "outputs and the three are interchangeable"
    ),
    "innetgr:group <-> host": (
        "there is no netgroup on this machine, so every triple answers 0, "
        "whichever way round it is asked"
    ),
    "aligned_alloc:alignment <-> size": (
        "every pair POSIX allows has the second a multiple of the first and "
        "both powers of two, so the swap is allowed as well -- and memory on "
        "128 bytes is on 64 as well, which is all the test looks at. Asking "
        "for a size that is not a multiple is asking for something the "
        "standard leaves undefined"
    ),
    "mbsnrtowcs:nmc <-> length": (
        "both arguments are limits -- bytes to read and wide characters of "
        "room -- and every character here is one byte wide, so both limits are "
        "reached at the same place and the answer is the same either way round"
    ),
    "wcsnrtombs:nwc <-> length": (
        "the same two limits as `mbsnrtowcs`, in the other direction, and one "
        "byte per character here as well"
    ),
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
    package: str = ""


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


# A number a mistake can be made in. The lookbehind keeps the digits of
# a type's own name -- `Int32` -- out of the sweep: they are spelling,
# not value.
NUMBER = re.compile(r"(?<![A-Za-z_])0x[0-9a-fA-F]+|(?<![A-Za-z0-9_])\d+")


def block_of(text: str, name: str) -> str | None:
    """The whole `comptime name` definition, however many lines it runs.

    A value the machines took different sides of is written as a chain
    of `if`s that the formatter keeps on separate lines, and the mutant
    has to reach the branch the compiling machine reads -- the numbers
    are indexed through whatever this returns, so the build and the
    applying of a mistake must both come through here and see the same
    block.
    """
    found = re.search(
        rf"(?ms)^comptime {re.escape(name)}\b.*?(?=^comptime |^def |^struct |^# |^\"\"\"|\Z)",
        text,
    )
    return found.group(0) if found else None


def branch_taken(condition: str) -> bool:
    """Whether the machine running this takes the branch asked about.

    The conditions are this package's own spellings of what the machine
    is, and the mapping is the same answer the compiler gives: the
    silicon question by the architecture this interpreter runs on, the
    operating system by `sys.platform`. A condition nothing here
    recognises answers nothing -- the constant is left alone rather
    than mutated blind.
    """
    machine = platform.machine().lower()
    predicates = {
        "CompilationTarget.is_macos()": sys.platform == "darwin",
        "CompilationTarget.is_linux()": sys.platform.startswith("linux"),
        "CompilationTarget.is_arm()": machine.startswith(("arm", "aarch")),
        "CompilationTarget.is_x86_64()": machine == "x86_64",
        "CompilationTarget.is_x86()": machine.startswith("x86"),
        "CompilationTarget.is_64bit()": machine in ("x86_64", "aarch64", "arm64"),
    }
    expr = condition.replace("\n", " ").strip()
    for spelling, answer in predicates.items():
        expr = expr.replace(spelling, repr(answer))
    if "CompilationTarget" in expr or not expr:
        return False
    try:
        return bool(eval(expr))  # noqa: S307 -- the conditions are our own
    except Exception:
        return False


def conditional_branches(expression: str) -> list[tuple[str, str]]:
    """A value's branches: the answer each one gives, and what asks for it.

    `A if C else B` is two; `A if C else B if D else E` is three, and
    the formatter puts each on its own line. The split is by the
    outermost `if`s, brackets having been counted, because a condition
    of its own can carry a parenthesised branch inside it.
    """

    def split(expr: str) -> list[tuple[str, str]]:
        expr = expr.strip()
        # The formatter wraps a branch in its own parentheses when the
        # branch carries a condition of its own; the wrap is not part of
        # the answer.
        while expr.startswith("("):
            depth, close = 0, None
            for i, ch in enumerate(expr):
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        close = i
                        break
            if close == len(expr) - 1:
                expr = expr[1:close].strip()
            else:
                break
        depth = 0
        # Find the first top-level ` if `.
        depth = 0
        top = None
        for i in range(len(expr) - 3):
            ch = expr[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif depth == 0 and expr[i : i + 4] == " if ":
                top = i
                break
        if top is None:
            return [(expr, "")]
        head = expr[:top]
        rest = expr[top + 4 :]
        # The `else` at the same depth closes this condition.
        depth, mark = 0, None
        for i in range(len(rest) - 4):
            ch = rest[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif depth == 0 and rest[i : i + 5] == " else":
                mark = i
                break
        if mark is None:
            return [(expr, "")]
        condition, tail = rest[:mark], rest[mark + 5 :]
        # What follows a `#` on the line is a remark about the answer,
        # and its numbers -- `Darwin's is 0x400000` -- are nobody's value.
        head = head.split(" #")[0]
        tail = tail.split(" #")[0]
        branches = [(head, condition)]
        for value, cond in split(tail):
            branches.append((value, cond))
        return branches

    return split(expression)


def apply(target: Path, mutant: Mutant) -> bool:
    """Make the mistake in `target`, and say whether it landed."""
    text = target.read_text()
    if mutant.kind == "constant":
        # The constant is a `comptime` definition rather than a call
        # inside a def, so it is found by its name and its nth literal --
        # which branch's literal is the mutant's to say. The block is
        # the whole definition, since a machine's answer may sit three
        # lines below the name that asks for it.
        block = block_of(text, mutant.name)
        if block is None:
            return False
        numbers = list(NUMBER.finditer(block))
        if mutant.first >= len(numbers):
            return False
        literal = numbers[mutant.first]
        changed = block[: literal.start()] + mutant.into + block[literal.end() :]
        target.write_text(text.replace(block, changed, 1))
        return True
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


def key_of(mutant: Mutant) -> str:
    """What this mutant is called in `SAME_ANSWER` or `SAME_ORDER`."""
    if mutant.kind == "symbol":
        return f"{mutant.symbol}->{mutant.into}"
    return f"{mutant.name}:{mutant.what}"


# Not the same call, and that is the point of keeping them apart from the table
# above: these are calls whose *effect* differs and whose answer is the same, in
# a case where no use of the object afterwards is defined. `pthread_attr_destroy`
# and `pthread_attr_init` both answer 0; what separates them is that one leaves
# an object that may not be used and the other leaves one that may -- and using
# the object after a destroy is undefined, so there is nothing to assert. Saying
# so is not the same as saying the two are the same call, and a table that said
# it would be the kind of entry that reads as an answer when it is a hole.
# The constants no test can pin, with the reason written per family. These
# are fields whose value is the machine's own state at the moment of the
# call -- free memory, process counts, filesystem occupancy -- where a
# misaligned read lands on a neighbouring field of the same kind of number
# and no second source names the true one to compare against. An assertion
# here would have to invent a number the machine did not report, which is
# how a test starts passing by coincidence; the reason is the honest form,
# and a constant that grows a real cross-check comes off this list.
SAME_CONSTANT = {
    "SYSINFO_FREERAM": "free memory the moment the call returns; the misaligned reader lands on a neighbouring counter of the same kind, and no call answers what free memory is twice",
    "SYSINFO_SHAREDRAM": "shared memory, which on this kernel is a counter most machines leave at a small number; no second source names it",
    "SYSINFO_BUFFERRAM": "buffer memory, a kernel estimate with no second source; the neighbouring fields are the same kind of estimate",
    "SYSINFO_TOTALHIGH": "high memory, which is zero on the 64-bit machines this runs on -- and zero is the one number a misaligned read can also answer",
    "SYSINFO_FREESWAP": "free swap the moment of the call; the swap total is asked beside it, but free is the machine's own count twice over",
    "TERMIOS_IFLAG_OFFSET": "the mode is written through this constant and read back through it, so a read one byte away is matched by a write one byte away and the round trip agrees with itself; the kernel's own behaviour is the only outside witness, and that is a behavioural test of a line discipline, not an assertion",
    "TERMIOS_CFLAG_OFFSET": "written and read back through the same constant, so the round trip agrees with a mistake; what the kernel does with the modes is behaviour, not a number to compare",
    "TERMIOS_CC_OFFSET": "the subscript is the constant plus the index, and both the setter and the reader do that arithmetic through the one constant -- shifted together, they still agree",
    "SIGACTION_HANDLER_OFFSET": "the handler is written through this constant and read back through it by the enquiry; the round trip agrees with itself, and the handler running is behaviour the tables of this axis do not reach",
    "UTSNAME_VERSION_OFFSET": "the version is a compiler signature of whatever shape the builder chose; a read one byte into the field is still a string of the same shape, and no property pins where it must begin",
    "STAT_BLKSIZE_OFFSET": "the block size the kernel chose for this file, which is the filesystem's own decision; the neighbour is a count of blocks, and no second source names the chosen size",
    "SCHED_PARAM_PRIORITY_OFFSET": "the priority is only observed by the kernel's scheduler, and asking for it back needs the real-time policies this suite does not assume it may use",
    "IFNAMEINDEX_NAME_OFFSET": "the name of the interface the kernel numbered, read as a string from the kernel's own table; a read one byte into the field is still the name of some interface",
    "SOCKADDR_LEN_OFFSET": "the length byte of an address the kernel wrote, whose neighbour is the low byte of the family; the family this suite uses is small enough that both answers are small numbers",
    "PASSWD_EXPIRE_OFFSET": "a shadow-field Darwin's row carries and glibc's does not: on this platform the bytes are padding the C row never filled, and padding reads as zero to a right read and to most wrong ones",
    "PASSWD_CHANGE_OFFSET": "a shadow-field Darwin's row carries and glibc's does not; on this platform it is padding, and a wrong offset reads more padding",
    "PASSWD_CLASS_OFFSET": "a Darwin login-class field with no glibc counterpart; on this platform it is padding, and nothing here can name what padding should have been",
    "CMSGHDR_LEN_OFFSET": "the constant is mapped against the C header but nothing in this tree reads it yet -- the ancillary data goes by in the kernel's hands. A constant with no reader is not a test the suite is failing; it is a reader not written",
    "CMSGHDR_LEVEL_OFFSET": "mapped against the C header, read by nothing here yet; see its sibling",
    "CMSGHDR_TYPE_OFFSET": "mapped against the C header, read by nothing here yet; see its sibling",
    "STAT_DEV_OFFSET": "the device number the kernel encodes for the mount, with no second source; the neighbour is the inode, and `is not zero` -- the shape the tests can afford -- is true of both",
    "SYSINFO_UPTIME": "seconds since boot, asked beside the clock `sysconf` answers elsewhere; the misaligned reader lands in the load averages, which are also just the machine's own count",
    "MTX_SLOTS": "the extra slot is room the lock never writes: init fills the C size, and every read goes back through the same struct, so a slot of slack changes no answer -- the mistake that means something is a slot too few, which is the other machine's branch and that machine's runner to ask",
    "UT_ID_OFFSET": "the field is written by this package's setter and read by this package's reader, both through the one constant -- shifted together they still agree, and the kernel's own entry is one the tests have no login to make",
    "B150": "a line speed this suite has no line to run at: the value is written through the termios and read back through it, and the round trip agrees with a mistake, the wire being the only witness that would not",
    "B2400": "same shape as `B150` -- written and read back through the one termios, with no line attached to be set at the wrong speed",
    "B4800": "same shape as `B150` -- the speed the tests can only store and read back, no line being theirs to run it at",
    "TCION": "a flag whose effect is on characters not yet typed: the tests can write it and read it back and nothing else, there being no terminal input in the suite for it to restart",
    "GLOB_NOESCAPE": "the pattern the tests ask with carries no backslash for the flag to change the reading of, so the answers agree with the mistake; exercising it needs a pattern with an escaped character in it, which is a test not written",
    "GLOB_NOMATCH": "the tests ask for matches that exist; the flag's work shows only where none do, and no test asks that yet",
    "GLOB_TILDE": "a flag whose work is in expanding a name the tests never pass, the pattern having no tilde in it to expand",
    "REG_NEWLINE": "the flag's work is in where an anchor matches, and the patterns the tests ask match the same either way; telling the answers apart needs a pattern with a newline in it, which is a test not written",
    "SYSINFO_LOADS": "load averages, the machine's own running count; no second source names them at the moment of the call",
    "SYSINFO_TOTALSWAP": "total swap, which grows and shrinks as swap is configured; the free count beside it is bounded by it, but a bound is not an identity and the misaligned reader can satisfy it too",
    "SYSINFO_PROCS": "processes running at the moment of the call, a number that moves while it is being read; the misaligned reader answers another counter that is also plausible",
    "STATVFS_BSIZE_OFFSET": "the filesystem's preferred block size, reported by the filesystem itself; the neighbour is `f_frsize`, which is usually the same number, so even the comparison agrees with the mistake",
    "STATVFS_FRSIZE_OFFSET": "the fundamental block size the filesystem reports; no call answers it twice",
    "STATVFS_BLOCKS_OFFSET": "total blocks the filesystem reports now, a number that moves as the machine works; the misaligned reader lands on another occupancy counter",
    "STATVFS_BFREE_OFFSET": "free blocks now; the total is asked beside it but free is the filesystem's own count",
    "STATVFS_BAVAIL_OFFSET": "blocks free to unprivileged users now, a counter that moves; the misaligned reader answers `f_bfree`, which bounds it",
    "STATVFS_FILES_OFFSET": "total file slots the filesystem reports; no second source",
    "STATVFS_FFREE_OFFSET": "free file slots now, moving as the machine works",
    "STATVFS_FAVAIL_OFFSET": "file slots free to unprivileged users, moving; bounds are not identities",
    "STATVFS_FLAG_OFFSET": "mount flags, a bitmap the mount chose; the misaligned reader answers another word of the same struct and nothing here can name the true one",
    "STATVFS_FSID_OFFSET": "the filesystem id, opaque by definition; two reads of the same field agree with a mistake, since both go through the one constant",
    "STATVFS_NAMEMAX_OFFSET": "maximum filename length, reported by the filesystem; the neighbour answers another limit of the same kind",
    "AIOCB_OFFSET": "the offset field is the caller's own bookkeeping: what was written is only checked by the kernel doing the read, and a test asserting the struct agrees with itself proves nothing",
    "AIOCB_REQPRIO": "the priority hint the caller wrote; the kernel is free to ignore it, so no behaviour separates a right read from a wrong one",
    "SIGINFO_ERRNO_OFFSET": "`si_errno` is zero unless the signal's generator wrote an error there, and nothing this suite does writes one; zero is also what a misaligned read of the padding beside it answers",
    "STACK_SP_OFFSET": "the stack pointer the caller handed over, only meaningful as the address `sigaltstack` was given; reading it back through the same constant agrees with the mistake",
    "STACK_SIZE_OFFSET": "the stack size the caller set, which the kernel rounds; the rounded answer is what the neighbouring slot cannot be told apart from",
    "STACK_FLAGS_OFFSET": "flag bits the kernel may normalize (`SS_DISABLE` clearing the rest), so the value read back is the kernel's, not the caller's",
    "IFADDRS_NEXT_OFFSET": "the next link of a list the kernel built; it is walked, and walking proves only that it points somewhere or ends",
    "UT_HOST_OFFSET": "the host field of a login record this suite writes and reads back through the same constant; both sides of the comparison share the mistake",
    "GLOB_OFFS_OFFSET": "the offset slot `glob` fills only when `GLOB_DOOFFS` was asked, which nothing here asks; the slot is padding to the test",
    "GLOB_PATHV_OFFSET": "the string table `glob` built, whose entries are checked by the matches they name -- the names, not the pointer arithmetic",
    "GLOB_PATHC_OFFSET": "the match count, which the test knows from its own pattern and the struct reports back through the same constants; a shifted read answers a plausible count",
}

NO_OBSERVATION = {
    "pthread_attr_destroy->pthread_attr_init": (
        "`_destroy` gives the object back and `_init` fills it in, and both "
        "answer 0. The difference is what may be done with the object after, "
        "and after a destroy nothing is defined -- so every observation this "
        "suite is allowed to make is the same one"
    ),
    "pthread_rwlockattr_destroy->pthread_rwlockattr_init": (
        "the same pair as the attribute object above: glibc's `_destroy` for a "
        "read-write lock's attributes is a return of 0 and nothing else, and "
        "the object it leaves behind is not one that may be read"
    ),
    "pthread_condattr_destroy->pthread_condattr_init": (
        "the same pair again for the condition's attributes, for the same "
        "reason and with the same measurement behind it"
    ),
    # The locked and the unlocked spelling of one byte in and one byte out, five
    # times over. What they differ in is whether the stream's lock is held for
    # the length of the move, and the only way to see a lock is to have someone
    # else contending for it -- a second thread, which this package cannot make
    # (pthread_create wants a function pointer, and the runtime does not hand
    # one out). A single-threaded process cannot tell them apart, and neither
    # can this suite.
    "getchar->getchar_unlocked": (
        "one byte from standard input, with the stream's lock held or not "
        "held. In a process with one thread nothing contends for that lock, "
        "so the two are the same call here"
    ),
    "getc->getc_unlocked": (
        "the same for the byte in from a stream the caller names: the lock "
        "is what differs, and a second thread is what would show it"
    ),
    "putchar->putchar_unlocked": (
        "the same the other way, one byte out to standard input's stream: "
        "without a second thread the lock is never contended"
    ),
    "putc->putc_unlocked": (
        "and the same for the byte out to a named stream"
    ),
    "flockfile->funlockfile": (
        "one takes the stream's lock and the other gives it back, and the "
        "lock is per-thread and recursive -- so a thread asking for it always "
        "gets it, and giving it back when it is not held changes nothing that "
        "can be seen. It is the same wall the four above run into: what a "
        "lock does is only visible to whoever cannot have it"
    ),
    "pthread_mutexattr_destroy->pthread_mutexattr_init": (
        "the same pair as the attribute objects above, for the mutex's: "
        "`_destroy` answers 0 and hands the object back, `_init` answers 0 "
        "and fills one in, and after a destroy no read of the object is "
        "defined -- so no observation this suite may make separates them"
    ),
    "sync->setusershell": (
        "neither answers anything, and what each does happens outside this "
        "address space: `sync` starts the kernel's held-back writes, and "
        "`setusershell` opens the shells file for the next `getusershell`, "
        "which this suite only reads from the top -- the walk starts the "
        "same way however many times the file was opened before"
    ),
    "getenv->secure_getenv": (
        "measured in a process that is not privileged, which is every process "
        "this suite runs in: `secure_getenv` answers nothing only when the "
        "process's credentials changed on the way in, which is a property of "
        "the binary and its file mode rather than of the call. There is no "
        "way to be insecure from inside a test"
    ),
    "malloc->valloc": (
        "`valloc` answers with room that begins on a page boundary and is at "
        "least as aligned as `malloc` promises, and no other promise of "
        "`malloc` is broken by getting better alignment than asked for. The "
        "other direction is caught -- the test asks `valloc` where its room "
        "begins and the heap does not begin there"
    ),
    "btowc->wctob": (
        "measured in the C locale, which is the one this suite runs in: both "
        "answer the byte itself for ASCII, both answer EOF for everything "
        "else, and the two are inverses of one another over exactly that "
        "range. A locale where a byte above 0x7F maps to a wide character "
        "would separate them, and setting one is a different question from "
        "this one"
    ),
    "wcscoll->wcscmp": (
        "also measured: under the C locale, `wcscoll` answers the same -1 "
        "that `wcscmp` answers, because code-point order is the collation "
        "there. The `_l` forms are separated by a locale object the test "
        "makes; this one has no such argument to hold the difference"
    ),
    "setpwent->endpwent": (
        "measured: whichever of the two is called, the next `getpwent` reads "
        "the first entry of the file again -- one puts the walk back at its "
        "beginning and the other shuts the file and the next call opens it "
        "again at the top. Both answer nothing, and the walk after them is "
        "the same walk"
    ),
    "setutxent->endutxent": (
        "the same for the login walk, measured: after either call the next "
        "`getutxent` reads the first record again, and neither answers "
        "anything"
    ),
    "tcsendbreak->tcflush": (
        "measured on a pty: a break leaves nothing on either side of the "
        "line that a read finds, and the flush that stands in for it empties "
        "a queue that was empty by then -- the two answers of 0 and the two "
        "silences are the same silence"
    ),
    "tcsendbreak->tcflow": (
        "the same measurement: the flow call the mutant points at is given "
        "the break's argument of 0, which suspends output rather than "
        "starting it, and nothing arrives on the other end either way"
    ),
    "posix_spawnattr_destroy->posix_spawnattr_init": (
        "pointed the other way round, `init` only makes the block usable "
        "that `destroy` was going to take apart, and both answer 0 -- the "
        "test cannot see the block become clean. The other direction is "
        "caught: the block is filled with bytes no allocator made before "
        "`init` is called, and pointed at `destroy` that dies"
    ),
    "posix_spawn_file_actions_destroy->posix_spawn_file_actions_init": (
        "the same for the list of file actions: the direction that makes a "
        "mess first is caught, and this one only answers 0 about a block "
        "that was going to be taken apart anyway"
    ),
    "endnetgrent->endprotoent": (
        "both take nothing and answer nothing, and what each shuts is a "
        "stream the other test does not have its hand in: this machine has "
        "no netgroup database to be walking, and the protocol stream is "
        "read by no test that an emptying would disturb"
    ),
    "endprotoent->endservent": (
        "the same for the two enumeration streams that are left open: both "
        "calls answer nothing, and no test reads either stream after the "
        "call, so there is nothing the shutting could move"
    ),
    "endrpcent->endprotoent": (
        "the same, and there is no rpc database on this machine at all"
    ),
    "endservent->endprotoent": (
        "the same for the service stream, which no test walks far enough "
        "for the closing of it to move anything"
    ),
    "sethostent->setprotoent": (
        "both put an enumeration back at its beginning and both answer "
        "nothing, and the test that reads the hosts walk reads it through "
        "its own calls -- which work the same whether the protocol stream "
        "was the one rewound"
    ),
    "setusershell->endusershell": (
        "measured: the walk over the shells starts again whether the list is "
        "put back at its beginning or shut, because the next `getusershell` "
        "reads the file again from the top in either case. Both answer "
        "nothing, and the walk after them is the same walk"
    ),
    "strcoll->strcmp": (
        "measured in the C locale, which is the one this suite runs in: "
        "collation there is code-point order, and `strcoll` answers the same "
        "number `strcmp` answers. The `_l` form is separated by a locale "
        "object the test makes; this one has no such argument"
    ),
    "get_nprocs->get_nprocs_conf": (
        "measured on a machine with every processor online, which is the only "
        "kind this suite can run on: a configured processor that has been "
        "taken offline is the whole of the difference between the two, and "
        "arranging one is not something a test can do without the machine to "
        "itself"
    ),
    "pthread_cond_destroy->pthread_cond_signal": (
        "glibc's `pthread_cond_destroy` changes nothing and answers 0 -- "
        "measured, with a waiter sitting on the condition -- so there is no "
        "call left in this package that can see the difference, and any use of "
        "a destroyed condition is undefined in any case"
    ),
    "cnd_init->cnd_signal": (
        "glibc's zeroed cnd_t is a usable condition variable -- "
        "PTHREAD_COND_INITIALIZER is all zeros -- so a call that skips "
        "cnd_init and signals nothing behaves like one that initialised "
        "and was never signaled: the tests see the same wait. Only "
        "libc's own zero is that forgiving, and it is not a fact this "
        "side can observe."
    ),
}


def reverse_key(key: str) -> str:
    """The same pair the other way round, which is the same claim.

    `a->b` and `b->a` are two mutants of one group -- each member points at the
    other -- and `x <-> y` is one mutant that would be the same mutant if the
    two names were written the other way round. A reason says the two are the
    same call, so it excuses both directions or neither.
    """
    if "->" in key:
        left, _, right = key.partition("->")
        return f"{right}->{left}"
    if " <-> " in key:
        left, _, right = key.partition(" <-> ")
        return f"{right} <-> {left}"
    return key


def reason_for(mutant: Mutant) -> str:
    """The reason this mutant is excused, from either direction."""
    table = SAME_ANSWER if mutant.kind == "symbol" else SAME_ORDER
    key = key_of(mutant)
    return table.get(key) or table.get(reverse_key(key), "")


# Test files that are entries rather than tests: the runner, the two
# built-package checks, and the file that is nothing but imports. A
# constant is asked of the files importing its module, and none of these
# imports anything for its own sake.
NOT_UNITS = {"test_main.mojo", "test_smoke.mojo", "test_atfork.mojo", "test_import_all.mojo"}


def targets(mutant: Mutant) -> list[Path]:
    """Which test files get asked about this mutant.

    A binding mutant is asked of the files whose bodies call it. A layout
    constant has no callers to find: what it is for shows in the module's
    own tests, so those are the files that import the module, plus
    `test_layout`, which is where the offsets are asserted against C.
    """
    if mutant.kind != "constant":
        return callers(mutant.name)
    wanted = f"from {mutant.package} import"
    hits = [
        path
        for path in TESTS
        if path.name not in NOT_UNITS and wanted in path.read_text()
    ]
    layout = ROOT / "tests" / "test_layout.mojo"
    if layout not in hits:
        hits.append(layout)
    return hits


def unobservable_for(mutant: Mutant) -> str:
    """The reason no defined observation separates this one, from either end."""
    if mutant.kind == "constant":
        return SAME_CONSTANT.get(mutant.name, "")
    if mutant.kind != "symbol":
        return ""
    key = key_of(mutant)
    return NO_OBSERVATION.get(key) or NO_OBSERVATION.get(reverse_key(key), "")


@functools.lru_cache(maxsize=None)
def exported(symbol: str) -> bool:
    """Whether this machine's C library exports `symbol` at all.

    The library binds both C libraries, so a fair share of the names in it
    are one platform's and not the other's. Pointing a binding at a name the
    linker here has never heard of asks for a symbol that cannot be
    materialized, which is not a mistake any test could catch.
    """
    return hasattr(ctypes.CDLL(None), symbol)


def reachable(name: str, symbol: str) -> bool:
    """Whether a call through `symbol` can be made here at all.

    `exported` answers it, with one written-down exception: a call the suite
    already documents as one the JIT cannot look up is still a call the
    linker makes, and its binding is a mutant worth asking about.
    """
    return exported(symbol) or name in load("check-tests").CANNOT_ASK


# What the compiler says when it is the compiler that said no. A file that
# does not build names the line it stopped at; a symbol the platform does not
# export fails later, when the JIT looks for it. Everything else that ends a
# run without an assertion is a crash, whether or not the crash reporter was
# able to say so out loud -- it writes a dump instead when its own bookkeeping
# is stuck, and the run then ends with nothing in its output at all.
BUILD_FAILURE = re.compile(
    r"\.mojo:\d+:\d+: error:|Failed to materialize symbols|Symbols not found"
)


def classify(returncode: int, text: str) -> str:
    if returncode == 0:
        return "survived"
    if "AssertionError" in text or "Unhandled exception" in text:
        return "caught"
    if BUILD_FAILURE.search(text):
        return "error"
    return "crashed"


def sweep(copy: Path) -> None:
    """Kill whatever the run started and the run did not outlive.

    A test that forks a waiter has a child blocked on a lock or a
    condition; when the mutant under it is the mistake that never gives
    the lock back, the test fails and exits, and the waiter is still
    there -- blocked forever, orphaned to init, holding memory for the
    rest of the sweep. It is found by the copy it was started from,
    which belongs to this worker alone, so nothing else can be hit.
    """
    if not Path("/proc").is_dir():
        return # Not Linux: nothing to read the command lines from.
    needle = str(copy).encode()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if needle in (entry / "cmdline").read_bytes():
                os.kill(int(entry.name), signal.SIGKILL)
        except OSError:
            continue


def build(kind: str) -> list[Mutant]:
    """Every mutant of one kind that can still be made."""
    prototypes = load("check-prototypes")
    every = prototypes.bindings()

    def here(path: str) -> Path:
        """`check-prototypes` walks relative to the root; this needs the file."""
        given = Path(path)
        return given if given.is_absolute() else ROOT / given

    mutants: list[Mutant] = []

    def emit(
        into_list: list[Mutant],
        path_str: str,
        const: str,
        block: str,
        step: int,
        package: str,
    ) -> None:
        """One mistake, in the branch of the answer this machine reads.

        A value the machines took different sides of is a chain of `if`s,
        and only the branch the compiling machine answers to is a number
        any run here adds up -- the others are silent words on a line.
        What lands is the whole value moved by the reader's step, the
        indexing going through the same block `apply` will read it back
        from.
        """
        equals = block.index("=")
        branches = conditional_branches(block[equals + 1 :])
        chosen = next(
            (
                (value_text, condition)
                for value_text, condition in branches
                if not condition or branch_taken(condition)
            ),
            None,
        )
        if chosen is None or not chosen[0].strip():
            return
        value_text, _condition = chosen
        # A whole number is a mistake one away from itself. A floating
        # answer is not: its digits are a spelling of a fraction, `+ 1`
        # on the mantissa means nothing, and the regex's pieces of
        # `1.9e-34` are not numbers to add to. The tests pin the floats
        # by parsing them; this sweep leaves the spelling alone.
        if re.search(r"\d\.\d|[eE][+-]\d", value_text):
            return
        span_start = block.find(value_text, equals + 1)
        if span_start < 0:
            return
        span_end = span_start + len(value_text)
        numbers = list(NUMBER.finditer(block))
        before = sum(1 for m in numbers if m.end() <= span_start)
        # A negative branch spells its minus outside the digits the
        # regex sees, so the value moved is the one the sign belongs to.
        signed = value_text.strip().startswith("-")
        suffix = (
            f" (branch {branches.index(chosen) + 1} of {len(branches)},"
            " the one this machine reads)"
            if len(branches) > 1
            else ""
        )
        for offset, literal in enumerate(
            NUMBER.finditer(block[span_start:span_end])
        ):
            try:
                old = int(literal.group(0), 0)
            except ValueError:
                try:
                    old = int(literal.group(0), 8)  # Mojo's C-style octal
                except ValueError:
                    continue
            # The mistake moves the value down, not up. A flag the tests
            # hand to the call beside other flags is or-ed in, and one
            # more sets a bit the or had set already -- the call reads
            # the same word and agrees with the mistake. One less clears
            # a bit, and what the call then reads is not the word the
            # tests meant.
            moved = (-(old) if signed else old) - step
            # The minus is already in the text the digits sit inside, so
            # the replacement carries only the magnitude -- writing the
            # sign again would spell `--127`, which compiles to nothing.
            into = hex(moved) if (
                literal.group(0).startswith("0x") and not signed
            ) else str(abs(moved))
            into_list.append(
                Mutant(
                    path_str,
                    const,
                    "constant",
                    f"{literal.group(0)} -> {into}{suffix}",
                    symbol=literal.group(0),
                    into=into,
                    first=before + offset,
                    package=package,
                )
            )

    if kind == "constant":
        layouts = load("check-layouts")
        for (package, const), _member in sorted(layouts.OFFSETS.items()):
            where = ROOT / "src" / package.replace(".", "/")
            source, line = None, None
            for path in sorted(where.glob("*.mojo")):
                told = next(
                    (
                        line
                        for line in path.read_text().splitlines()
                        if re.match(rf"comptime {re.escape(const)}\b", line)
                    ),
                    None,
                )
                if told is not None:
                    source, line = path, told
                    break
            if line is None:
                continue
            # How far the mistake moves the read depends on how the constant
            # is read. A reader that goes through `_member(NAME)` takes whole
            # words -- `self._bytes[offset // 8]` -- and so does `_u64(NAME)`
            # (`self._slots[offset // 8]`, the docstring saying so): one byte
            # of mistake lands inside the slot it already read, and the value
            # is the same; the mistake that means something there is a whole
            # field away. `_text_at(NAME)` reaches the same `_member` through
            # its own parameter, which is why the search is for the constant
            # in any of the three. `_u32(NAME)` and `_u16(NAME)` really do
            # shift by the unaligned remainder, so a reader at a byte offset
            # moves with one -- and what the shift then reads can still be
            # zero if the field was zero, which is the test's business.
            body = source.read_text() if source else ""
            word_read = re.search(
                rf"_member\(\s*{const}\b|_text_at\(\s*{const}\b|_u64\(\s*{const}\b",
                body,
            )
            if not word_read and re.search(rf"_at\(\s*{const}\b", body):
                # `_at` is a name two files use for different mechanics: the
                # socket one reads a whole slot (`self._slots[off // 8]`,
                # same as `_member` and `_u64` elsewhere), the utsname one
                # walks bytes looking for the NUL. What settles it is the
                # definition in the file the constant lives in.
                at_def = re.search(
                    r"(?s)def _at\(.*?(?=\n    def |\n\ndef |\nstruct |\Z)",
                    body,
                )
                word_read = bool(at_def and "// 8" in at_def.group(0))
            u32_read = re.search(rf"_u32\(\s*{const}\b", body)
            step = 1
            if word_read:
                step = 8
            elif u32_read:
                # `_u32` moves with the slot width of the struct it belongs
                # to. Stat's slots are 64 bits, so the unaligned remainder
                # really shifts and a byte of mistake is a byte of
                # different bytes. Socketaddr's slots are 16 bits, and its
                # `_u32` is `self._slots[off // 2]` beside the next half --
                # a mistake of one lands inside the half it already read,
                # and only a whole address moves the read. The nearest
                # slot declaration above the reader is the struct it
                # belongs to.
                grain = None
                for declared in re.finditer(
                    r"_slots: Array\[(\w+)", body[: u32_read.start()]
                ):
                    grain = declared.group(1)
                step = 4 if grain == "UInt16" else 1
            block = block_of(source.read_text(), const)
            if block is None:
                continue
            emit(mutants, str(source), const, block, step, package)
        # The other kind of answer the machines took sides on: a value,
        # not an offset, written as a chain of `if`s the formatter keeps
        # on separate lines -- `SYS_getpid`'s three-way numbering,
        # `O_DIRECTORY`'s flags the thirty-two-bit ABI chose, the quad
        # `long double`'s `float.h` answers. These are the constants the
        # last three mistakes were made in, and no mutant touched one:
        # the offset sweep reads a single line, and these do not live on
        # one. The branch the compiling machine reads is the only one a
        # mistake can be made in -- the others are numbers no run here
        # ever adds up.
        seen = {m.name for m in mutants}
        for path in sorted((ROOT / "src" / "libc").rglob("*.mojo")):
            text = path.read_text()
            # The package is what a test imports: the directory the file
            # sits in, spelled with dots. It is what `targets` matches on,
            # and a mutant with no package is a question no test file is
            # ever asked -- a survivor by silence, which is the worst
            # kind.
            under = path.relative_to(ROOT / "src" / "libc")
            package = "libc." + ".".join(under.with_suffix("").parts[:-1]) if len(under.parts) > 1 else "libc"
            for told in re.finditer(
                r"(?m)^comptime (\w+)(?:\s*:\s*[\w\.]+)?\s*=\s*\S", text
            ):
                name = told.group(1)
                if name in seen or name.endswith("_OFFSET"):
                    continue
                block = block_of(text, name)
                if block is None or " if " not in block:
                    continue
                emit(mutants, str(path), name, block, 1, package)
                seen.add(name)
    elif kind == "symbol":
        groups: dict[tuple[str, str, tuple[str, ...]], list[tuple[str, str]]] = {}
        for path, name, symbol, _nargs, ret, argtypes in every:
            groups.setdefault((str(here(path)), ret, tuple(argtypes)), []).append(
                (name, symbol)
            )
        for (path, ret, argtypes), members in groups.items():
            if len(members) < 2:
                continue
            for name, symbol in members:
                # Another *binding*, not another spelling of this one. A
                # binding written for two platforms names two symbols and is
                # one call either way -- `errno` reads through
                # `__errno_location` here and `__error` on Darwin -- so the
                # branch that is not this platform's is not a call at all
                # here, and neither is a symbol the linker has never heard of.
                if not reachable(name, symbol):
                    continue
                other = next(
                    (
                        s
                        for n, s in members
                        if n != name and s != symbol and reachable(n, s)
                    ),
                    None,
                )
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
    return mutants


def check_tables() -> int:
    """Every reason in the tables still has a mutant to be a reason about."""
    stale = []
    for kind, table in (
        ("symbol", SAME_ANSWER),
        ("order", SAME_ORDER),
        ("symbol", NO_OBSERVATION),
    ):
        keys = {key_of(mutant) for mutant in build(kind)}
        # Either way round, which is how `reason_for` reads them: a pair that
        # only one direction of the sweep produced is still a pair, and the
        # reason written for it excuses whichever direction turns up.
        stale += [
            (kind, key)
            for key in table
            if key not in keys and reverse_key(key) not in keys
        ]
    # The constants' table is keyed by the constant's own name, and the
    # name is the whole of it: twice now a family was written without the
    # `_OFFSET` ending it really carries, and the reason sat there being
    # right about a mutant the sweep had already named differently. The
    # build is the spelling to agree with.
    stale += [
        ("constant", name)
        for name in SAME_CONSTANT
        if name not in {mutant.name for mutant in build("constant")}
    ]

    if not stale:
        print(
            f"all {len(SAME_ANSWER)} symbol, {len(SAME_ORDER)} order and"
            f" {len(NO_OBSERVATION)} unobservable reasons are about pairs that"
            " can still be made, each read both ways round; the constants'"
            f" table names {len(SAME_CONSTANT)} that can still be made too"
        )
        return 0

    print(f"{len(stale)} reason(s) about a pair that can no longer be made:")
    for kind, key in stale:
        print(f"  {kind}: {key}")
    print()
    print("  A reason is worth keeping only while the mistake it excuses can still")
    print("  be made: the pair was renamed, a sibling was added to the file, or the")
    print("  call is no longer handed its own parameters.")
    return 1


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
        choices=("symbol", "order", "constant"),
        help="wrong function, or two arguments the other way round",
    )
    parser.add_argument(
        "--strict", action="store_true", help="fail the run if a mutant survives"
    )
    parser.add_argument(
        "--jobs", type=int, default=1, help="how many mutants to ask at once"
    )
    parser.add_argument(
        "--check-tables",
        action="store_true",
        help="ask nothing of the suite: only that the two tables still apply",
    )
    args = parser.parse_args()

    if args.check_tables:
        return check_tables()

    mutants: list[Mutant] = build(args.kind)

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
        # One copy of the tree per worker: two mutants in one tree would be two
        # mutations in one file, and the second would be asked against the
        # first one's mistake.
        copies: queue.Queue[Path] = queue.Queue()
        for index in range(max(1, args.jobs)):
            made = Path(tmp) / f"src{index}"
            shutil.copytree(SRC, made)
            copies.put(made)
        how = f"{len(picked)} {args.kind} mutant(s), one `mojo run` each"
        if args.jobs > 1:
            how += f", {args.jobs} at a time"
        print(how + "\n")
        tally = {
            "caught": 0,
            "crashed": 0,
            "hung": 0,
            "same": 0,
            "unobservable": 0,
            "survived": 0,
            "flaky": 0,
            "error": 0,
        }
        answered: list[str] = []
        # The workers print as they finish, so the report is in the order the
        # answers came back rather than the order they were asked in -- which is
        # the order a reader of a sweep wants anyway.
        say = threading.Lock()

        def run_one(copy: Path, test: Path) -> str:
            """Ask one test file one question, and read the answer back."""
            # The answer is written to a file, not a pipe, and the run
            # is a session of its own. Both halves of one lesson: a run
            # that the verdict `hung` ends in is killed as a whole --
            # every process its forks left behind -- and a run that a
            # forked child outlives would hold a pipe open until
            # somebody reading it died with it, which turns an answer
            # the run gave into one the probe waits for forever.
            with tempfile.NamedTemporaryFile(
                mode="w+b", suffix=".out", delete=True
            ) as answer:
                proc = subprocess.Popen(
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
                    stdout=answer,
                    stderr=answer,
                    stdin=subprocess.DEVNULL,
                    start_new_session=True,
                )
                try:
                    returncode = proc.wait(timeout=TIMEOUT)
                except subprocess.TimeoutExpired:
                    # A mutated lock or wait can leave the file waiting
                    # rather than failing, and that is a verdict of its
                    # own: the run does not stop at it, and the mutant
                    # after it still gets asked.
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                    return "hung"
                answer.seek(0)
                return classify(returncode, answer.read().decode(errors="replace"))

        def ask(mutant: Mutant):
            copy = copies.get()
            try:
                target = copy / Path(mutant.path).relative_to(SRC)
                pristine = target.read_text()
                if not apply(target, mutant):
                    with say:
                        print(f"  ?? {mutant.name}: could not be mutated")
                    return
                said_text = ""
                outs = [run_one(copy, test) for test in targets(mutant)]
                verdict = "caught" if "caught" in outs else outs[0]
                if verdict == "survived":
                    # A survivor is the one answer that says a test is
                    # missing, and it is also the one answer a mistake that
                    # forks a waiter can give by interleaving: the child's
                    # wrong answer and the parent's assertion race, and one
                    # run is one sample. Ask again before believing it --
                    # survived twice is a gap, once each way is a race, and
                    # the two are not the same report.
                    if "caught" in [run_one(copy, t) for t in targets(mutant)]:
                        verdict = "flaky"
                # A verdict that contradicts the tables is one sample too,
                # and it is the mirror of the survivor's problem: the run is
                # a file of many tests, and a failure in any one of them
                # lands on every mutant that file is asked about -- which is
                # how a mutant with a written reason saying nobody can see
                # it was once reported caught. What the tables say this
                # mutant answers is a prediction, and a run against the
                # prediction is asked a second time; once each way is the
                # same report as any other that changed its mind.
                known = reason_for(mutant)
                unseen = unobservable_for(mutant)
                if verdict == "caught" and (known or unseen):
                    if "caught" not in [
                        run_one(copy, t) for t in targets(mutant)
                    ]:
                        verdict = "flaky"
                if verdict == "crashed":
                    # A crash is the mutant's own doing most of the time --
                    # an exchange of arguments that hands a function a read
                    # -only buffer to write through, or a small one to read
                    # past -- and that is a death with no page to land on
                    # but the one the allocator happens to give. Ask again
                    # before believing it: the same mutant can die on one
                    # boundary and answer on the next, and the two are not
                    # the same report.
                    again = [run_one(copy, t) for t in targets(mutant)]
                    again_verdict = "caught" if "caught" in again else again[0]
                    if again_verdict != "crashed":
                        verdict = "flaky"
                target.write_text(pristine)
                where = f"{Path(mutant.path).relative_to(SRC / 'libc')}:{mutant.name}"
                if mutant.kind != "symbol":
                    where += f" ({mutant.what})"
                if verdict == "survived" and known:
                    verdict = "same"
                if verdict == "survived" and unseen:
                    verdict = "unobservable"
                    known = unseen
                with say:
                    tally[verdict] += 1
                    if mutant.kind == "symbol":
                        print(f"  {verdict:12} {where:44} {mutant.what}")
                    else:
                        print(f"  {verdict:12} {where}")
                    if known:
                        print(f"            {known}")
                    if verdict == "caught" and known:
                        answered.append(where)
                    if verdict == "error":
                        tail = said_text.strip().splitlines()
                        for line in tail[-3:]:
                            print(f"            {line.strip()[:110]}")
            finally:
                sweep(copy)
                copies.put(copy)

        if args.jobs > 1:
            with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
                list(pool.map(ask, picked))
        else:
            for mutant in picked:
                ask(mutant)

        print()
        print(
            f"  caught {tally['caught']}, crashed {tally['crashed']},"
            f" hung {tally['hung']}, same answer {tally['same']},"
            f" unobservable {tally['unobservable']},"
            f" survived {tally['survived']}, flaky {tally['flaky']},"
            f" did not build {tally['error']}"
        )
        if tally["flaky"]:
            print(
                "  a flaky one was survived once and caught on the asking"
                " again, which is"
            )
            print(
                "  a race between a forked child and the assertion, not a"
                " missing test"
            )
        if answered:
            print()
            print(
                f"  {len(answered)} reason(s) in the table are about a mutant that"
                " is now caught,"
            )
            print("  so the reason can go:")
            for where in answered:
                print(f"    {where}")
        if answered:
            return 1 if args.strict else 0
        if tally["survived"]:
            if args.kind == "order":
                print("  a survivor is a call whose two arguments nothing tells apart")
            else:
                print("  a survivor is a call whose answer nothing compares against")
            return 1 if args.strict else 0
        # A hung mutant is not a survivor: its tests sat waiting for
        # something the mistake never made happen, which is the tests
        # refusing to pass on a wrong behaviour — the same verdict as a
        # crash, wearing a timeout instead of one. It is counted apart so
        # the ones worth a look are visible, and a hang that came from a
        # test that waits by design will say so in the run above it.
    return 0


if __name__ == "__main__":
    sys.exit(main())
