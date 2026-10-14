"""Tests for `libc.sys.wait`, neither of which had been called.

Waiting needs something to wait for, so each of these forks and has
the child leave at once with a number of its own choosing. The child
leaves at once, before it can do anything that only the parent should
do, and says so with the number it was given.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.stdlib import exit
from libc.sys.wait import (
    WEXITSTATUS,
    WIFEXITED,
    rusage,
    wait4,
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


def main() raises:
    test_waitpid_takes_back_a_child()
    test_wait4_says_what_the_child_used()
    print("test_wait: ok")
