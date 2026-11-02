"""Tests for the `libc.sys.sigqueue` bindings.

Linux only: Darwin's `<signal.h>` declares none of the three, so
every one of these is made behind a `comptime if`, which is what
`test_epoll` does.

The round trip is made in a forked child, and that is the point of
it: a signal queued to a process with several threads in it is
delivered to whichever of them is not blocking it, and this one has
to be blocked before it is queued or there is nothing for the wait to
take. Asked in the child, there is only the one thread, and what the
parent asks is the number the child left with.

What makes it worth having is that number, which is the whole of
what `sigqueue` adds to `kill` and the only part that cannot come
from anywhere else: the signal is sent to this process by this
process, so a test that asked only which signal came back would pass
however the union had been sent. Two are queued and taken in order,
and each is asked for the number it was given.

Neither wait can hang: the first is given no time at all, and the
second is only called once there is a signal waiting for it.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.signal import (
    SIGUSR1,
    SIG_BLOCK,
    SIG_SETMASK,
    siginfo_t,
    sigaddset,
    sigemptyset,
    sigprocmask,
)
from libc.stdlib import exit
from libc.sys.sigqueue import SI_QUEUE, sigqueue, sigtimedwait, sigwaitinfo
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.time import timespec
from libc.unistd import fork, getpid
from libc.utils import null_ptr

comptime SET_BYTES = 128
comptime FIRST = 42
comptime SECOND = 7


def queued_and_taken_back() raises -> Int32:
    """The whole round trip, in the child: a signal blocked, queued
    with a number and taken back out again, twice.

    `sigtimedwait` is given no time at all, so it is a question
    rather than a wait, and `sigwaitinfo` is only called once the
    second signal has been queued.

    What is asked of the answer is the number, and then the two
    things beside it: that it says the signal was queued rather than
    sent by the kernel, and that it names this process as the one
    that sent it.
    """
    var set = unsafe_alloc[UInt8](SET_BYTES)
    var was = unsafe_alloc[UInt8](SET_BYTES)
    assert_equal(sigemptyset(set), 0, "an empty set")
    assert_equal(sigaddset(set, SIGUSR1), 0, "with SIGUSR1 in it")
    assert_equal(
        sigprocmask(SIG_BLOCK, set, was),
        0,
        "and SIGUSR1 is blocked, so that it waits rather than arrives",
    )

    assert_equal(
        sigqueue(getpid(), SIGUSR1, FIRST), 0, "a signal is queued to ourselves"
    )

    var info = unsafe_alloc[siginfo_t](1)
    info.unsafe_offset(0)[] = siginfo_t()
    var no_time = unsafe_alloc[timespec](1)
    no_time.unsafe_offset(0)[].tv_sec = 0
    no_time.unsafe_offset(0)[].tv_nsec = 0

    assert_equal(
        sigtimedwait(set, info, no_time),
        SIGUSR1,
        "sigtimedwait answers with the signal it took",
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_code()),
        Int(SI_QUEUE),
        "and says it was queued rather than sent by the kernel",
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_pid()),
        Int(getpid()),
        "and that it was this process that queued it",
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_value()),
        FIRST,
        "and the number it was given is the number that comes back",
    )

    assert_equal(
        sigqueue(getpid(), SIGUSR1, SECOND), 0, "and a second one is queued"
    )
    assert_equal(
        sigwaitinfo(set, info), SIGUSR1, "sigwaitinfo answers with it too"
    )
    assert_equal(
        Int(info.unsafe_offset(0)[].si_value()),
        SECOND,
        "and with the second number, not the first",
    )

    assert_equal(
        sigprocmask(SIG_SETMASK, was, null_ptr[UInt8]()),
        0,
        "and the mask is put back",
    )

    info.unsafe_free()
    no_time.unsafe_free()
    set.unsafe_free()
    was.unsafe_free()
    return 0


def test_a_signal_sent_with_a_number_and_taken_back() raises:
    """The parent's half: fork, wait, and ask what number the child
    left with.

    The child is where the three are called, and it is a child
    because of the threads: a signal queued to a process is delivered
    to whichever of its threads is not blocking it, so one that has
    to be blocked to be waited for has to be asked somewhere with
    only one thread in it. A `fork` leaves exactly one.
    """
    comptime if not CompilationTarget.is_macos():
        var child = fork()
        if child == 0:
            _ = exit(queued_and_taken_back())

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
    test_a_signal_sent_with_a_number_and_taken_back()
    print("test_sigqueue: ok")
