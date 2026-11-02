"""Tests for the `libc.sys.eventfd` bindings.

Linux only: the header is not on the other side, so every one of
these is made behind a `comptime if`, which is what `test_epoll`
does.

Two of the three flags are `open` flags by another name, and those
are checked against `fcntl` rather than against the number written
here — a wrong `EFD_CLOEXEC` still makes a descriptor, only one that
survives `exec`. The third is not a flag at all but a different way
of counting, and what checks it is what it does to the count: a
semaphore read takes one out of three, a plain read takes all three.
A test that only ever made a descriptor and read it back would pass
with every flag set to 0.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import FD_CLOEXEC, F_GETFD, F_GETFL, O_NONBLOCK, fcntl
from libc.sys.eventfd import (
    EFD_CLOEXEC,
    EFD_NONBLOCK,
    EFD_SEMAPHORE,
    eventfd,
    eventfd_read,
    eventfd_write,
)
from libc.unistd import close


def test_a_counter_that_keeps_what_is_put_in() raises:
    """The round trip, and how wide the counter is while it makes it.

    The count is 64 bits and unsigned: the largest number a signed
    64-bit integer can hold is an ordinary count here, and comes back
    as itself. The one value the kernel keeps back is the very
    largest, which is refused rather than added.
    """
    comptime if not CompilationTarget.is_macos():
        var fd = eventfd(0, 0)
        assert_true(fd >= 0, "an eventfd is made")

        var got = unsafe_alloc[UInt64](1)
        got.unsafe_store(0, 0)
        assert_equal(Int(eventfd_write(fd, 5)), 0, "five is added to it")
        assert_equal(Int(eventfd_read(fd, got)), 0, "and taken back out")
        assert_equal(Int(got.unsafe_load(0)), 5, "the five that went in")

        # Sixty-four bits wide, and unsigned: this one needs the top
        # bit of a signed 64-bit number to be free.
        var wide: UInt64 = 9223372036854775807
        assert_equal(
            Int(eventfd_write(fd, wide)), 0, "the widest count is taken"
        )
        assert_equal(Int(eventfd_read(fd, got)), 0, "and comes back")
        assert_equal(got.unsafe_load(0), wide, "as the same eight bytes")

        # And the one value that is not a count at all.
        var largest: UInt64 = 0xFFFFFFFFFFFFFFFF
        assert_equal(
            Int(eventfd_write(fd, largest)), -1, "the largest of all is refused"
        )

        assert_equal(Int(close(fd)), 0, "and the descriptor closes")
        got.unsafe_free()


def test_the_flags_are_open_flags_by_another_name() raises:
    """`EFD_CLOEXEC` and `EFD_NONBLOCK` asked about through `fcntl`,
    which is where the difference they make shows.

    One descriptor made with neither and one made with both, and each
    asked twice: `F_GETFD` for whether it survives `exec`, and
    `F_GETFL` for whether a read of nothing waits. The nonblocking
    one is then read while it stands at zero, which is the test that
    would never come back if the flag had not taken.
    """
    comptime if not CompilationTarget.is_macos():
        var plain = eventfd(0, 0)
        assert_true(plain >= 0, "a plain eventfd is made")
        assert_equal(
            Int(fcntl(plain, F_GETFD, 0)) & Int(FD_CLOEXEC),
            0,
            "and it is one that survives exec",
        )
        assert_equal(
            Int(fcntl(plain, F_GETFL, 0)) & Int(O_NONBLOCK),
            0,
            "and a read of nothing on it waits",
        )

        var flagged = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK)
        assert_true(flagged >= 0, "a flagged eventfd is made")
        assert_true(
            Int(fcntl(flagged, F_GETFD, 0)) & Int(FD_CLOEXEC) != 0,
            "EFD_CLOEXEC: this one is closed on exec",
        )
        assert_true(
            Int(fcntl(flagged, F_GETFL, 0)) & Int(O_NONBLOCK) != 0,
            "EFD_NONBLOCK: a read of nothing on it does not wait",
        )

        var got = unsafe_alloc[UInt64](1)
        got.unsafe_store(0, 0)
        assert_equal(
            Int(eventfd_read(flagged, got)), -1, "and such a read answers -1"
        )

        assert_equal(Int(close(plain)), 0, "both close")
        assert_equal(Int(close(flagged)), 0, "both close")
        got.unsafe_free()


def test_a_semaphore_takes_one_and_a_counter_takes_all() raises:
    """`EFD_SEMAPHORE` proved by what it does to the count: the same
    three put into each, and one comes back out of one and three out
    of the other.

    Two descriptors rather than one, so that the difference is not
    something one of them was made with on its own — the flag is the
    only thing they do not share.
    """
    comptime if not CompilationTarget.is_macos():
        var semaphore = eventfd(0, EFD_SEMAPHORE)
        var counter = eventfd(0, 0)
        assert_true(semaphore >= 0, "a semaphore eventfd is made")
        assert_true(counter >= 0, "and a plain one")

        assert_equal(Int(eventfd_write(semaphore, 3)), 0, "three into each")
        assert_equal(Int(eventfd_write(counter, 3)), 0, "three into each")

        var got = unsafe_alloc[UInt64](1)
        got.unsafe_store(0, 0)
        assert_equal(Int(eventfd_read(semaphore, got)), 0, "one is read")
        assert_equal(Int(got.unsafe_load(0)), 1, "and it is one of the three")

        assert_equal(Int(eventfd_read(counter, got)), 0, "the other is read")
        assert_equal(Int(got.unsafe_load(0)), 3, "and it is all three")

        # Two left in the semaphore, and one read takes one of them.
        assert_equal(Int(eventfd_read(semaphore, got)), 0, "and again")
        assert_equal(Int(got.unsafe_load(0)), 1, "one at a time")

        assert_equal(Int(close(semaphore)), 0, "both close")
        assert_equal(Int(close(counter)), 0, "both close")
        got.unsafe_free()


def main() raises:
    test_a_counter_that_keeps_what_is_put_in()
    test_the_flags_are_open_flags_by_another_name()
    test_a_semaphore_takes_one_and_a_counter_takes_all()
    print("test_eventfd: ok")
