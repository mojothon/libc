"""Ask each check to fail on a tree that is wrong in exactly one way.

A check is a claim that something bad would be caught, and nothing checks
the claim. `check-channels` was written this morning and its first
version walked the docs, found no channel names at all, and printed a
cheerful summary: the block scanner had a bug, every fenced block went
unseen, and the check that exists to catch a wrong channel name passed
by looking at nothing. It would have gone on passing for as long as
nobody broke a channel name on purpose.

So each case here takes a copy of the tree, breaks one thing in it the
way a person would, and asks the check that owns that thing to say so.
Broken and still green is the failure this reports; the copy is thrown
away, and the tree being checked is the one in the working directory, so
a case that no longer applies -- because the line it edits was rewritten
-- is a failure too, rather than a case that quietly stops running.

Three of the thirty-five are slow -- the one that builds every example, the
one that asks gcc about every constant, and the one that walks the
constants' table against what the sweep can still make -- which is why
this runs as its own job rather than as one more step of the lint job.
The assurance is the same for all thirty-five: a page of examples that compiles
nothing prints `all 0 examples compile`, which is the sentence this is
here to make impossible to earn honestly.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

IGNORED = shutil.ignore_patterns(
    ".git",
    ".pixi",
    ".codebuddy",
    "site",
    "dist",
    "output",
    "__pycache__",
    ".build-check",
)


class Break:
    """One wrong tree: what to change, and what the change is saying."""

    def __init__(
        self,
        check: str,
        broke: str,
        where: str,
        old: str,
        new: str,
        append: bool = False,
        args: tuple[str, ...] = (),
    ) -> None:
        self.check = check
        self.broke = broke
        self.where = where
        self.old = old
        self.new = new
        self.append = append
        self.args = args


BREAKS = [
    Break(
        "check-release",
        "the README says a version the checkout is not",
        "README.md",
        "`{version}`",
        "`0.0.1`",
    ),
    Break(
        "check-channels",
        "the install page names the channel without its URL",
        "docs/install.md",
        "-c https://prefix.dev/mojo-force",
        "-c mojo-force",
    ),
    Break(
        "check-channels",
        "the README names the channel the way the install page used to",
        "README.md",
        "-c https://prefix.dev/mojo-force",
        "-c mojo-force",
    ),
    Break(
        "check-examples",
        "the README gives an install command the install page does not",
        "README.md",
        "pixi add libc",
        "pixi add libc-extras",
    ),
    Break(
        "mutation-probe",
        "a constants' reason about a name the sweep does not carry",
        "scripts/mutation-probe.py",
        '"SYSINFO_FREERAM": "free memory',
        '"SYSINFO_FREERAM_NOT_HERE": "free memory',
        args=("--check-tables",),
    ),
    Break(
        "check-duplicates",
        "a symbol the library already binds is bound in a second file",
        "src/libc/sched/syscalls.mojo",
        "",
        'def L_second_getpid() -> Int32:\n'
        '    """getpid again, from here."""\n'
        '    return external_call["getpid", Int32]()\n',
        append=True,
    ),
    Break(
        "check-tests",
        "a binding nothing asks anything of",
        "src/libc/unistd/syscalls.mojo",
        "",
        'def L_unasked_probe() -> Int32:\n'
        '    """A binding no test knows about."""\n'
        '    return external_call["L_unasked_probe", Int32]()\n',
        append=True,
    ),
    Break(
        "check-docstrings",
        "an argument the function does not take",
        "src/libc/unistd/syscalls.mojo",
        "        buf: Where to write it, which has to hold `PATH_MAX`",
        "        buffer: Where to write it, which has to hold `PATH_MAX`",
    ),
    Break(
        "check-return-values",
        "a call that answers with a count, saying 0 means success",
        "src/libc/unistd/syscalls.mojo",
        "        How many bytes were read, or -1 on failure with `errno` set."
        " Fewer\n"
        "        than were asked for is ordinary rather than failure: a pipe"
        " hands\n"
        "        over whatever has arrived so far and a terminal stops at the"
        " end\n"
        "        of a line, so asking for 4096 and getting 11 is a read that\n"
        "        worked. Zero is the end of the file, and -1 is the only"
        " failure.",
        "        0 on success, or -1 on failure.",
    ),
    Break(
        "check-prototypes",
        "a call handing C an argument its prototype does not take",
        "src/libc/unistd/syscalls.mojo",
        'return external_call["getpid", Int32]()',
        'return external_call["getpid", Int32, Int32](0)',
    ),
    Break(
        "check-symbols",
        "a binding pointed at a symbol no library exports",
        "src/libc/string/syscalls.mojo",
        'external_call["strcat",',
        'external_call["strcatx",',
    ),
    Break(
        "check-comparisons",
        "the only sign assertion of a comparison flattened to zero or not",
        "tests/test_string.mojo",
        'Int(strcasecmp(abc, abd)) < 0, "abc sorts before abd ignoring case"',
        'Int(strcasecmp(abc, abd)) == 0, "abc sorts before abd ignoring case"',
    ),
    Break(
        "check-magnitudes",
        "a tolerance held to one side of the distance, `fabs` dropped",
        "tests/test_math.mojo",
        "assert_true(fabs(ceil(2.1) - 3.0) < 1e-12)",
        "assert_true(ceil(2.1) - 3.0 < 1e-12)",
    ),
    Break(
        "check-warnings",
        "an argument description wrapped back to the argument's margin",
        "src/libc/getopt/syscalls.mojo",
        "\n            asked for, anything else to go on complaining.",
        "\n        asked for, anything else to go on complaining.",
    ),
    Break(
        "check-examples",
        "a quick-start example importing a name the package does not have",
        "docs/index.md",
        "from libc.string import strlen",
        "from libc.string import strlen_not_here",
    ),
    Break(
        "check-constants",
        "a constant holding a number the header does not give it",
        "src/libc/constant/errno.mojo",
        "comptime EACCES = 13",
        "comptime EACCES = 14",
    ),
    Break(
        "check-constants",
        "an enumeration constant the header numbers differently",
        "src/libc/pthread/syscalls.mojo",
        "comptime PTHREAD_MUTEX_NORMAL: Int32 = 0",
        "comptime PTHREAD_MUTEX_NORMAL: Int32 = 1",
    ),
    Break(
        "check-constants",
        "an alias of another constant that the header does not make",
        "src/libc/pthread/syscalls.mojo",
        "comptime PTHREAD_MUTEX_DEFAULT = PTHREAD_MUTEX_NORMAL",
        "comptime PTHREAD_MUTEX_DEFAULT = PTHREAD_MUTEX_ERRORCHECK",
    ),
    Break(
        "check-constants",
        "a wrong number in the inner branch of a nested conditional",
        "src/libc/fenv/syscalls.mojo",
        "Int32(0x3D) if CompilationTarget.is_x86() else Int32(0x1F)",
        "Int32(0x2D) if CompilationTarget.is_x86() else Int32(0x1F)",
    ),
    Break(
        "check-constants",
        "a type alias half the width of the C type it stands for",
        "src/libc/constant/file.mojo",
        "comptime off_t = Int64",
        "comptime off_t = Int32",
    ),
    Break(
        "check-constants",
        "a type alias with C's width and not C's signedness",
        "src/libc/constant/ctype.mojo",
        "comptime ptrdiff_t = Int64",
        "comptime ptrdiff_t = UInt64",
    ),
    Break(
        "check-layouts",
        "an offset named in the source that nobody listed",
        "src/libc/dirent/syscalls.mojo",
        "comptime DIRENT_RECLEN_OFFSET = 16",
        "comptime DIRENT_RECLEN_OFFSET = 16\ncomptime DIRENT_PAD_OFFSET = 17",
    ),
    Break(
        "check-layouts",
        "a member read at a number rather than at a named offset",
        "src/libc/dirent/syscalls.mojo",
        "return self._u64(DIRENT_INO_OFFSET)",
        "return self._u64(0)",
    ),
    Break(
        "check-layouts",
        "a member read at a width C does not agree with",
        "src/libc/sys/stat/syscalls.mojo",
        "        return self._u64(STAT_SIZE_OFFSET)",
        "        return self._u32(STAT_SIZE_OFFSET)",
    ),
    Break(
        "check-layouts",
        "a member read from the wrong half of its slot",
        "src/libc/pwd/syscalls.mojo",
        "        return UInt32(self._member(PASSWD_GID_OFFSET) >> 32)",
        "        return UInt32(self._member(PASSWD_GID_OFFSET) & 0xFFFFFFFF)",
    ),
    Break(
        "check-layouts",
        "an ancillary header built in the other platform's shape",
        "src/libc/sys/socket/syscalls.mojo",
        "comptime CMSGHDR_HEADER_BYTES: Int = 12 if CompilationTarget.is_macos() else 16",
        "comptime CMSGHDR_HEADER_BYTES: Int = 12",
    ),
    Break(
        "check-layouts",
        "a derived size C's own arithmetic does not come to",
        "src/libc/sys/un/syscalls.mojo",
        "comptime SOCKADDR_UN_BYTES: Int = 106 if CompilationTarget.is_macos() else 110",
        "comptime SOCKADDR_UN_BYTES: Int = 106 if CompilationTarget.is_macos() else 109",
    ),
    Break(
        "check-layouts",
        "a member written at a number rather than at a named offset",
        "src/libc/utmpx/syscalls.mojo",
        "self._set_u32(UT_PID_OFFSET, UInt32(pid))",
        "self._set_u32(4, UInt32(pid))",
    ),
    Break(
        "check-layouts",
        "a member written narrower than the member is",
        "src/libc/utmpx/syscalls.mojo",
        "self._set_u32(UT_PID_OFFSET, UInt32(pid))",
        "self._set_u16(UT_PID_OFFSET, UInt16(pid))",
    ),
    Break(
        "check-layouts",
        "a room given to a member that is wider than the member",
        "src/libc/utmpx/syscalls.mojo",
        "comptime UT_LINE_ROOM: Int = 32",
        "comptime UT_LINE_ROOM: Int = 64",
    ),
    Break(
        "check-layouts",
        "a constant that says a C type is wider than it is",
        "src/libc/termios/syscalls.mojo",
        "comptime TERMIOS_FLAG_BYTES: Int = 8 if CompilationTarget.is_macos() else 4",
        "comptime TERMIOS_FLAG_BYTES: Int = 8",
    ),
    Break(
        "check-tests",
        "a call moved inside a platform guard, the way putwchar's test used to be",
        "tests/test_time.mojo",
        "    ts[] = timespec()\n"
        "    assert_equal(Int(timespec_get(ts, TIME_UTC)), Int(TIME_UTC))\n"
        '    assert_true(ts[].tv_sec > 1_700_000_000, "C11 time is now")',
        "    comptime if not CompilationTarget.is_macos():\n"
        "        ts[] = timespec()\n"
        "        assert_equal(Int(timespec_get(ts, TIME_UTC)), Int(TIME_UTC))\n"
        '        assert_true(ts[].tv_sec > 1_700_000_000, "C11 time is now")',
    ),
    Break(
        "check-tests",
        "the one-platform page saying a number the count does not",
        "docs/modules.md",
        "Linux asks 10 bindings that Darwin passes over",
        "Linux asks 11 bindings that Darwin passes over",
    ),
    Break(
        "check-tests",
        "a one-platform binding starting to be asked without a guard",
        "tests/test_unistd.mojo",
        "    comptime if not CompilationTarget.is_macos():\n"
        "        # The main thread of a process has that process's own number, and\n"
        "        # `fork` -- the call one line away with the same answer of a positive\n"
        "        # number -- would have made a process instead of answering.\n"
        "        assert_equal(\n"
        '            Int(gettid()), Int(getpid()), "and it is this process\'s own"\n'
        "        )",
        "    assert_equal(\n"
        '        Int(gettid()), Int(getpid()), "and it is this process\'s own"\n'
        "    )",
    ),
    Break(
        "check-walk",
        "the probe's branch walk taking a short answer as a substring of a"
        " longer one -- `4` is the first digit of `4103`, and the mutation"
        " lands in the branch the machine never reads",
        "scripts/mutation-probe.py",
        "            at = block.find(branch_value, cursor)",
        "            at = block.find(branch_value, equals + 1)",
    ),

]


def version(tree: Path) -> str:
    """What `src/libc/version.mojo` says this is."""
    text = (tree / "src" / "libc" / "version.mojo").read_text()
    return text.split('__version__ = "')[1].split('"')[0]


def run(check: str, tree: Path, args: tuple[str, ...] = ()) -> int:
    """The exit status of `check`, run against `tree`."""
    done = subprocess.run(
        [sys.executable, str(tree / "scripts" / f"{check}.py"), *args],
        cwd=tree,
        capture_output=True,
        text=True,
    )
    return done.returncode


def unowned() -> list[str]:
    """The checks on the tree that no case of this one breaks.

    Every check is a claim, and a check with no case is a claim this
    file does not collect on -- the same silence `check-channels` spent
    its first morning inside. The one exception is this check itself:
    breaking the tree in a way check-checks would miss means writing a
    second one of these, and the tree cannot hold both.
    """
    owned = {b.check for b in BREAKS}
    on_disk = sorted(p.stem for p in (ROOT / "scripts").glob("check-*.py"))
    return [
        name
        for name in on_disk
        if name != "check-checks" and name not in owned
    ]


def main() -> int:
    missing = unowned()
    if missing:
        print("\n  *** a check no case of this one breaks ***")
        for name in missing:
            print(f"    {name}")
        print("  a check with no case is a claim nobody collects on")
        return 1

    with tempfile.TemporaryDirectory() as work:
        tree = Path(work) / "tree"
        shutil.copytree(ROOT, tree, ignore=IGNORED)

        problems = []
        # A red on a broken tree means nothing if the tree was red already,
        # so the copy is asked once for each check before anything is broken.
        for check in dict.fromkeys((b.check, b.args) for b in BREAKS):
            if run(check[0], tree, check[1]) != 0:
                problems.append(f"{check}: fails before anything is broken")
        if problems:
            print("\n  *** a check disagrees with the tree as it is ***")
            for problem in problems:
                print(f"    {problem}")
            return 1

        for case in BREAKS:
            path = tree / case.where
            original = path.read_text()
            if case.append:
                broken = original + "\n\n" + case.new
            else:
                old = case.old
                if "{version}" in old:
                    old = old.format(version=version(tree))
                if old not in original:
                    problems.append(
                        f"{case.check}: {case.where} no longer holds the line"
                        " this case breaks"
                    )
                    continue
                broken = original.replace(old, case.new, 1)
            path.write_text(broken)

            status = run(case.check, tree, case.args)
            path.write_text(original)
            if status == 0:
                problems.append(f"{case.check}: stayed green with {case.broke}")
            else:
                print(f"  {case.check:<22} {case.broke}")

    if problems:
        print("\n  *** a check that did not catch what it is for ***")
        for problem in problems:
            print(f"    {problem}")
        print("  a check that passes on a broken tree is a check that is not run")
        return 1

    print(f"\n  {len(BREAKS)} ways of being wrong, each caught by the check")
    print("  that owns it, on a copy of this tree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
