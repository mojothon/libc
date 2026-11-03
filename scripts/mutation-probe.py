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
import importlib.util
import random
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
# slow machine.
TIMEOUT = 120


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
        "before the two ids are read, for the reason `chown`'s is"
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


def unobservable_for(mutant: Mutant) -> str:
    """The reason no defined observation separates this one, from either end."""
    if mutant.kind != "symbol":
        return ""
    key = key_of(mutant)
    return NO_OBSERVATION.get(key) or NO_OBSERVATION.get(reverse_key(key), "")


def classify(result: subprocess.CompletedProcess) -> str:
    if result.returncode == 0:
        return "survived"
    both = (result.stdout or "") + (result.stderr or "")
    if "AssertionError" in both or "Unhandled exception" in both:
        return "caught"
    if "execution crashed" in both or result.returncode < 0:
        return "crashed"
    return "error"


def build(kind: str) -> list[Mutant]:
    """Every mutant of one kind that can still be made."""
    prototypes = load("check-prototypes")
    every = prototypes.bindings()

    def here(path: str) -> Path:
        """`check-prototypes` walks relative to the root; this needs the file."""
        given = Path(path)
        return given if given.is_absolute() else ROOT / given

    mutants: list[Mutant] = []
    if kind == "symbol":
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
    return mutants


def check_tables() -> int:
    """Every reason in the two tables still has a mutant to be a reason about."""
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

    if not stale:
        print(
            f"all {len(SAME_ANSWER)} symbol, {len(SAME_ORDER)} order and"
            f" {len(NO_OBSERVATION)} unobservable reasons are about pairs that"
            " can still be made, each read both ways round"
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
        choices=("symbol", "order"),
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
            "error": 0,
        }
        answered: list[str] = []
        # The workers print as they finish, so the report is in the order the
        # answers came back rather than the order they were asked in -- which is
        # the order a reader of a sweep wants anyway.
        say = threading.Lock()

        def ask(mutant: Mutant):
            copy = copies.get()
            try:
                target = copy / Path(mutant.path).relative_to(SRC)
                pristine = target.read_text()
                if not apply(target, mutant):
                    with say:
                        print(f"  ?? {mutant.name}: could not be mutated")
                    return
                outs = []
                for test in callers(mutant.name):
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
                        # A mutated lock or wait can leave the file waiting
                        # rather than failing, and that is a verdict of its own:
                        # the run does not stop at it, and the mutant after it
                        # still gets asked.
                        outs.append("hung")
                        continue
                    outs.append(classify(result))
                target.write_text(pristine)
                verdict = "caught" if "caught" in outs else outs[0]
                where = f"{Path(mutant.path).relative_to(SRC / 'libc')}:{mutant.name}"
                if mutant.kind == "order":
                    where += f" ({mutant.what})"
                known = reason_for(mutant)
                if verdict == "survived" and known:
                    verdict = "same"
                unseen = unobservable_for(mutant)
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
                        tail = (result.stderr or "").strip().splitlines()
                        for line in tail[-3:]:
                            print(f"            {line.strip()[:110]}")
            finally:
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
            f" survived {tally['survived']}, did not build {tally['error']}"
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
