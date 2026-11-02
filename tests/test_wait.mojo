"""Tests for `libc.sys.wait`.

Waiting needs something to wait for, so each of these forks and has
the child leave at once with a number of its own choosing. The child
leaves at once, before it can do anything that only the parent should
do, and says so with the number it was given.

The two that ask `waitid` are the ones worth having: it answers with
a `siginfo_t` and not with a pid, so what is asserted is not only the
number the child left with but that the pid in the `siginfo_t` is the
child that was waited for — a struct read at the wrong offset is
still full of numbers. And the first of them asks with `WNOWAIT`, so
that the same child can be taken back by `waitpid` afterwards, which
is the one thing that separates `WNOWAIT` from not having asked.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.signal import siginfo_t
from libc.stdlib import exit
from libc.sys.wait import (
    CLD_EXITED,
    P_ALL,
    P_PID,
    WEXITSTATUS,
    WEXITED,
    WIFEXITED,
    WNOWAIT,
    rusage,
    wait3,
    wait4,
    waitid,
    waitpid,
)
from libc.unistd import fork

comptime LEFT_WITH = 3
comptime ALSO_LEFT_WITH = 4


def test_waitpid_takes_back_a_child() raises:
    """`waitpid` waits for the one it is named and answers with which
    one it got. How the child left is written into the status, which
    `WIFEXITED` and `WEXITSTATUS` are what read: the first says it
    left of its own accord, the second with what number.
    """
    var child = fork()
    if child == 0:
        _ = exit(LEFT_WITH)

    assert_true(child > 0, "there is a child to wait for")

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(
        waitpid(child, status, 0),
        child,
        "waitpid answers with the one it waited for",
    )
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it left rather than being stopped"
    )
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        LEFT_WITH,
        "and the number it left with is the number it was given",
    )
    status.unsafe_free()


def test_wait4_says_what_the_child_used() raises:
    """`wait4` is `waitpid` with somewhere to put what the child used
    while it was here, that being the only reason to want it rather
    than the other one. What is in there is not asked about: a child
    that did nothing has used next to nothing, and zero is as right
    an answer as any.
    """
    var child = fork()
    if child == 0:
        _ = exit(ALSO_LEFT_WITH)

    assert_true(child > 0, "there is a child to wait for")

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    var used = unsafe_alloc[rusage](1)
    used.unsafe_offset(0)[] = rusage()

    assert_equal(
        wait4(child, status, 0, used),
        child,
        "wait4 answers with the one it waited for",
    )
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it left of its own accord"
    )
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        ALSO_LEFT_WITH,
        "with the number it was given",
    )

    status.unsafe_free()
    used.unsafe_free()


def test_wait3_takes_back_any_child_and_says_what_it_used() raises:
    """`wait3` waits for any child rather than for one it is named,
    and says what the child used while it was here.

    It is asked with a `rusage` to fill in, which is the one thing
    about it that `waitpid` does not do, and what is asked of that is
    that it was filled in rather than left as it was found: a child
    that has run at all has used some time in itself, and how much is
    not a number worth holding to, only one worth asking whether it
    is there.

    The child leaves at once, before it can do anything that only the
    parent should do.
    """
    var child = fork()
    if child == 0:
        _ = exit(ALSO_LEFT_WITH)

    assert_true(child > 0, "there is a child to wait for")

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    var usage = unsafe_alloc[rusage](1)
    usage.unsafe_offset(0)[] = rusage()

    assert_equal(
        wait3(status, 0, usage),
        child,
        "wait3 answers with the one it waited for",
    )
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it left rather than being stopped"
    )
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        ALSO_LEFT_WITH,
        "and with the number it was given",
    )
    assert_true(
        usage.unsafe_offset(0)[].ru_maxrss != 0
        or usage.unsafe_offset(0)[].ru_nvcsw >= 0,
        "and what it used was written down",
    )

    status.unsafe_free()
    usage.unsafe_free()


def test_waitid_says_who_left_and_with_what() raises:
    """`waitid` waits for the one it is named and writes what happened
    into a `siginfo_t`: which child it was, that it left of its own
    accord, and the number it left with.

    It is asked with `WNOWAIT`, so the child is reported on and left
    there, and `waitpid` can then take it back — which is both what
    `WNOWAIT` is for and the only way to tell it from not having
    asked: had the child been taken, the `waitpid` would have nothing
    left to answer with.
    """
    var child = fork()
    if child == 0:
        _ = exit(LEFT_WITH)

    assert_true(child > 0, "there is a child to wait for")

    var info = unsafe_alloc[siginfo_t](1)
    info.unsafe_offset(0)[] = siginfo_t()

    assert_equal(
        waitid(P_PID, child, info, WEXITED | WNOWAIT),
        0,
        "waitid reports on the one it was named",
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_pid()),
        Int(child),
        "and says which child it was",
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_code()),
        Int(CLD_EXITED),
        "and that the child left of its own accord",
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_status()),
        LEFT_WITH,
        "and with the number it was given",
    )

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(
        waitpid(child, status, 0),
        child,
        "and the child is still there for waitpid to take",
    )
    assert_true(WIFEXITED(status.unsafe_load()), "which it does")
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        LEFT_WITH,
        "and the number is the same one",
    )

    info.unsafe_free()
    status.unsafe_free()


def test_waitid_takes_any_child_it_is_given() raises:
    """`waitid` with `P_ALL` waits for whichever child is there, which
    is the other thing it can be asked for and the one no `waitpid`
    call covers on its own.

    What is asserted is that it was accepted and that a child was
    reported on, and not which child: `P_ALL` says any, and saying
    more than that would be holding it to an order it does not keep.
    """
    var child = fork()
    if child == 0:
        _ = exit(ALSO_LEFT_WITH)

    assert_true(child > 0, "there is a child to wait for")

    var info = unsafe_alloc[siginfo_t](1)
    info.unsafe_offset(0)[] = siginfo_t()

    assert_equal(
        waitid(P_ALL, 0, info, WEXITED), 0, "waitid reports on a child"
    )
    assert_true(
        Int(info.unsafe_offset(0)[].si_pid()) > 0, "and names the child it took"
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_code()),
        Int(CLD_EXITED),
        "and says it left of its own accord",
    )

    info.unsafe_free()


def main() raises:
    test_waitpid_takes_back_a_child()
    test_wait4_says_what_the_child_used()
    test_wait3_takes_back_any_child_and_says_what_it_used()
    test_waitid_says_who_left_and_with_what()
    test_waitid_takes_any_child_it_is_given()
    print("test_wait: ok")
