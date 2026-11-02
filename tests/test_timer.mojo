"""Tests for the `libc.sys.timer` bindings.

Linux only: Darwin's `<time.h>` declares none of the five, so the test
is made behind a `comptime if`, which is what `test_sigqueue` does.

The calls are made in a forked child, and this one has a signal in it
even though none is asked for: a timer made with nothing said about
`sigevent` runs out into `SIGALRM`, whose default is to end the
process. So the child is where a mistake about which word of the block
says otherwise would be noticed rather than fatal — it would leave by
signal, and the parent asks whether it left of its own accord.

What makes the test worth having is the pair of reads: a timer armed
for a fifth of a second has time left before the sleep and none after
it. Both are asked of the timer, which is the only thing that knows,
and the sleep is the only clock the test reads.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.stdlib import exit
from libc.sys.timer import (
    SIGEV_NONE,
    itimerspec,
    sigevent,
    timer_create,
    timer_delete,
    timer_getoverrun,
    timer_gettime,
    timer_settime,
    timer_t,
)
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.time import CLOCK_MONOTONIC, nanosleep, timespec
from libc.unistd import fork
from libc.utils import null_ptr

comptime ARM_NANOSECONDS = 200_000_000
comptime SLEEP_NANOSECONDS = 250_000_000


def armed_read_and_taken_away() raises -> Int32:
    """The whole round trip, in the child: a timer made, armed for a
    fifth of a second, read before and after that much time has passed,
    and deleted.

    The overrun between the two reads is asked as well, and it is the
    answer that says the timer ran out once rather than more than once:
    nothing was told about it, it having been made to do nothing.
    """
    var event = unsafe_alloc[sigevent](1)
    event.unsafe_offset(0)[] = sigevent()
    event.unsafe_offset(0)[].set_notify(SIGEV_NONE)
    assert_equal(
        Int(event.unsafe_offset(0)[].notify()),
        Int(SIGEV_NONE),
        "the block is told to do nothing when the timer runs out",
    )

    var id = unsafe_alloc[timer_t](1)
    id.unsafe_offset(0)[] = null_ptr[UInt8]()
    assert_equal(
        timer_create(CLOCK_MONOTONIC, event, id),
        0,
        "a timer is made on the clock that does not jump",
    )
    # A name of 0 is a name: the kernel numbers timers from 0, so the
    # first one a process makes is 0, and reading that as a failure is
    # the one mistake this block is here to warn about.
    var timer = id.unsafe_offset(0)[]

    var armed = unsafe_alloc[itimerspec](1)
    armed.unsafe_offset(0)[] = itimerspec()
    armed.unsafe_offset(0)[].it_value.tv_sec = 0
    armed.unsafe_offset(0)[].it_value.tv_nsec = ARM_NANOSECONDS
    assert_equal(
        timer_settime(timer, 0, armed, null_ptr[itimerspec]()),
        0,
        "and it is armed for a fifth of a second",
    )

    var left = unsafe_alloc[itimerspec](1)
    left.unsafe_offset(0)[] = itimerspec()
    assert_equal(timer_gettime(timer, left), 0, "the time left on it is read")
    assert_true(
        left.unsafe_offset(0)[].it_value.tv_sec > 0
        or left.unsafe_offset(0)[].it_value.tv_nsec > 0,
        "and there is some left, it not having run out yet",
    )

    var pause = unsafe_alloc[timespec](1)
    pause.unsafe_offset(0)[].tv_sec = 0
    pause.unsafe_offset(0)[].tv_nsec = SLEEP_NANOSECONDS
    assert_equal(
        nanosleep(pause, null_ptr[timespec]()),
        0,
        "a quarter of a second passes",
    )

    assert_equal(timer_gettime(timer, left), 0, "and the timer is read again")
    assert_equal(
        Int(left.unsafe_offset(0)[].it_value.tv_sec),
        0,
        "with nothing left of its seconds",
    )
    assert_equal(
        Int(left.unsafe_offset(0)[].it_value.tv_nsec),
        0,
        "and nothing left of its nanoseconds",
    )
    assert_equal(
        Int(timer_getoverrun(timer)), 0, "and it ran out the one time, not more"
    )

    assert_equal(timer_delete(timer), 0, "and the timer is taken away")
    assert_true(
        timer_gettime(timer, left) != 0,
        "after which there is no time left on it to read",
    )
    assert_true(timer_delete(timer) != 0, "and it cannot be taken away twice")

    armed.unsafe_free()
    event.unsafe_free()
    id.unsafe_free()
    left.unsafe_free()
    pause.unsafe_free()
    return 0


def test_a_timer_armed_read_and_taken_away() raises:
    """The parent's half: fork, wait, and ask what the child left with."""
    comptime if not CompilationTarget.is_macos():
        var child = fork()
        if child == 0:
            _ = exit(armed_read_and_taken_away())

        assert_true(child > 0, "there is a child to wait for")

        var status = unsafe_alloc[Int32](1)
        status.unsafe_offset(0)[] = 0
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(
            WIFEXITED(status.unsafe_load()), "and it left of its own accord"
        )
        assert_equal(
            Int(WEXITSTATUS(status.unsafe_load())),
            0,
            "with 0, every assertion in it having held",
        )
        status.unsafe_free()


def main() raises:
    test_a_timer_armed_read_and_taken_away()
    print("test_timer: ok")
