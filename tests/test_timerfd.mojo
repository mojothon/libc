"""Tests for the `libc.sys.timerfd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import EAGAIN, c_ptr
from libc.errno import get_errno
from libc.sys.timer import itimerspec
from libc.sys.timerfd import (
    TFD_NONBLOCK,
    timerfd_create,
    timerfd_gettime,
    timerfd_settime,
)
from libc.time import CLOCK_MONOTONIC, timespec
from libc.unistd import close, read, usleep
from libc.utils import null_ptr


def test_the_timer_becomes_readable_when_it_runs_out() raises:
    """`timerfd_create` and `timerfd_settime`: a timer armed for
    fifty milliseconds and then read -- the reading waits, and
    the eight bytes it brings back are the count of run-outs,
    which is one: the timer went once and stopped, the
    interval being zero.
    """
    comptime if not CompilationTarget.is_macos():
        var fd = timerfd_create(CLOCK_MONOTONIC, 0)
        assert_true(fd >= 0, "the timer is made, as a descriptor")

        var arm = unsafe_alloc[itimerspec](1)
        arm.unsafe_offset(0)[].it_interval = timespec(0, 0)
        arm.unsafe_offset(0)[].it_value = timespec(0, 50_000_000)
        assert_equal(
            timerfd_settime(fd, 0, arm, null_ptr[itimerspec]()),
            0,
            "the timer is armed for fifty milliseconds",
        )

        var count = unsafe_alloc[UInt8](8)
        assert_equal(
            Int(read(fd, count, 8)), 8, "the run-out is readable, eight bytes"
        )
        assert_equal(
            Int(count.unsafe_bitcast[UInt64]().unsafe_offset(0)[]),
            1,
            "and it says the timer ran out once",
        )

        _ = close(fd)
        arm.unsafe_free()
        count.unsafe_free()


def test_the_reading_that_answers_rather_than_waits() raises:
    """`timerfd_create` and `TFD_NONBLOCK`: a timer armed for half a
    second, read before it has run out -- the reading answers
    rather than waits, and the answer is `EAGAIN`, which is the
    word for "nothing to read yet, ask again".
    """
    comptime if not CompilationTarget.is_macos():
        var fd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK)
        assert_true(fd >= 0, "the timer is made, nonblocking")

        var arm = unsafe_alloc[itimerspec](1)
        arm.unsafe_offset(0)[].it_interval = timespec(0, 0)
        arm.unsafe_offset(0)[].it_value = timespec(0, 500_000_000)
        assert_equal(
            timerfd_settime(fd, 0, arm, null_ptr[itimerspec]()),
            0,
            "the timer is armed for half a second",
        )

        var count = unsafe_alloc[UInt8](8)
        assert_equal(
            Int(read(fd, count, 8)),
            -1,
            "the reading before the run-out answers at once",
        )
        assert_equal(
            Int(get_errno()), Int(EAGAIN), "and the word it answers is EAGAIN"
        )

        _ = close(fd)
        arm.unsafe_free()
        count.unsafe_free()


def test_the_time_it_has_left_is_the_part_that_moves() raises:
    """`timerfd_gettime`: the same ask twice in a row is answered
    with less the second time, which is the clock's word that
    the timer is running -- the time it has left being the
    part that moves.
    """
    comptime if not CompilationTarget.is_macos():
        var fd = timerfd_create(CLOCK_MONOTONIC, 0)
        assert_true(fd >= 0, "the timer is made")

        var arm = unsafe_alloc[itimerspec](1)
        arm.unsafe_offset(0)[].it_interval = timespec(0, 0)
        arm.unsafe_offset(0)[].it_value = timespec(0, 400_000_000)
        assert_equal(
            timerfd_settime(fd, 0, arm, null_ptr[itimerspec]()),
            0,
            "the timer is armed",
        )

        var now = unsafe_alloc[itimerspec](1)
        assert_equal(timerfd_gettime(fd, now), 0, "the ask is answered")
        var first = Int(now.unsafe_offset(0)[].it_value.tv_nsec)
        assert_true(first > 0, "there is time left, and some of it")

        _ = usleep(100_000)
        assert_equal(timerfd_gettime(fd, now), 0, "the ask is answered again")
        var second = Int(now.unsafe_offset(0)[].it_value.tv_nsec)
        assert_true(second < first, "and there is less left than there was")

        _ = close(fd)
        arm.unsafe_free()
        now.unsafe_free()


def test_the_interval_keeps_the_timer_going() raises:
    """An interval beside the value: the timer that goes every fifty
    milliseconds does not stop after the first run-out -- two
    readings, taken with a hundred milliseconds between them,
    each find a count, the second as fresh as the first.
    """
    comptime if not CompilationTarget.is_macos():
        var fd = timerfd_create(CLOCK_MONOTONIC, 0)
        assert_true(fd >= 0, "the timer is made")

        var arm = unsafe_alloc[itimerspec](1)
        arm.unsafe_offset(0)[].it_interval = timespec(0, 50_000_000)
        arm.unsafe_offset(0)[].it_value = timespec(0, 50_000_000)
        assert_equal(
            timerfd_settime(fd, 0, arm, null_ptr[itimerspec]()),
            0,
            "the timer is armed, every fifty milliseconds",
        )

        var count = unsafe_alloc[UInt8](8)
        assert_equal(Int(read(fd, count, 8)), 8, "the first run-out is read")
        assert_true(
            Int(count.unsafe_bitcast[UInt64]().unsafe_offset(0)[]) >= 1,
            "and it says it ran out",
        )

        _ = usleep(120_000)
        assert_equal(
            Int(read(fd, count, 8)),
            8,
            "the run-outs since the last read are read",
        )
        assert_true(
            Int(count.unsafe_bitcast[UInt64]().unsafe_offset(0)[]) >= 1,
            "and the interval kept it going",
        )

        _ = close(fd)
        arm.unsafe_free()
        count.unsafe_free()


def main() raises:
    test_the_timer_becomes_readable_when_it_runs_out()
    test_the_reading_that_answers_rather_than_waits()
    test_the_time_it_has_left_is_the_part_that_moves()
    test_the_interval_keeps_the_timer_going()
    print("test_timerfd: ok")
