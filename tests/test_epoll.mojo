"""Tests for the `libc.sys.epoll` bindings, none of which had been called.

`epoll` is Linux's and nobody else's — Darwin has `kqueue` instead — so
every one of these is made only where it exists.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import (
    EPOLL_CLOEXEC,
    EPOLL_CTL_ADD,
    EPOLL_CTL_DEL,
    EPOLLIN,
)
from libc.sys.epoll import (
    epoll_create,
    epoll_create1,
    epoll_ctl,
    epoll_event,
    epoll_pwait,
    epoll_pwait2,
    epoll_wait,
    timespec,
)
from libc.unistd import close, pipe, write
from libc.utils import null_ptr


def test_watching_a_pipe() raises:
    """`epoll_create1` makes an instance, `epoll_ctl` is told which
    descriptor to watch and what for, and `epoll_wait` answers how many
    of the watched ones are ready. A pipe is what is watched, being
    ready exactly when something has been written into it and not
    before.
    """
    comptime if not CompilationTarget.is_macos():
        var ep = epoll_create1(EPOLL_CLOEXEC)
        assert_true(ep >= 0, "epoll_create1 makes an instance")

        var ends = unsafe_alloc[Int32](2)
        assert_equal(pipe(ends), 0, "a pipe to watch")
        var reader = ends.unsafe_load(0)
        var writer = ends.unsafe_load(1)

        var wanted = unsafe_alloc[epoll_event](1)
        wanted.unsafe_offset(0)[] = epoll_event(UInt32(EPOLLIN), reader)
        assert_equal(
            epoll_ctl(ep, EPOLL_CTL_ADD, reader, wanted),
            0,
            "epoll_ctl is told to watch the reading end",
        )

        # Nothing written yet, and asked without waiting: nothing ready.
        var found = unsafe_alloc[epoll_event](4)
        assert_equal(
            epoll_wait(ep, found, 4, 0), 0, "an empty pipe is not ready"
        )

        var message = unsafe_alloc[UInt8](1)
        message.unsafe_offset(0)[] = UInt8(65)
        assert_equal(write(writer, message, 1), 1, "one byte written")

        assert_equal(epoll_wait(ep, found, 4, 0), 1, "the pipe is ready now")
        assert_equal(
            found.unsafe_offset(0)[].data_fd(),
            reader,
            "and what is ready is the one that was watched",
        )

        # `epoll_pwait` is `epoll_wait` with a signal mask to wear while
        # it waits; given none, it has nothing to do but the same thing.
        assert_equal(
            epoll_pwait(ep, found, 4, 0, null_ptr[NoneType]()),
            1,
            "epoll_pwait says the same",
        )

        assert_equal(
            epoll_ctl(ep, EPOLL_CTL_DEL, reader, wanted),
            0,
            "and the watch is taken off again",
        )
        assert_equal(
            epoll_wait(ep, found, 4, 0),
            0,
            "after which nothing is being watched",
        )

        wanted.unsafe_free()
        found.unsafe_free()
        message.unsafe_free()
        ends.unsafe_free()
        _ = close(reader)
        _ = close(writer)
        _ = close(ep)


def test_the_two_that_are_left() raises:
    """`epoll_create` is the one that came first: it is given a size and
    ignores it, glibc having stopped needing to be told. `epoll_pwait2`
    takes its timeout as a `timespec` rather than as a number of
    milliseconds, which is the whole of how it differs from `epoll_pwait`.
    """
    comptime if not CompilationTarget.is_macos():
        var old = epoll_create(1)
        assert_true(old >= 0, "epoll_create makes one as well")

        var ends = unsafe_alloc[Int32](2)
        assert_equal(pipe(ends), 0, "a pipe to watch")
        var wanted = unsafe_alloc[epoll_event](1)
        wanted.unsafe_offset(0)[] = epoll_event(
            UInt32(EPOLLIN), ends.unsafe_load(0)
        )
        assert_equal(
            epoll_ctl(old, EPOLL_CTL_ADD, ends.unsafe_load(0), wanted),
            0,
            "and it watches too",
        )

        # This `timespec` has no constructor of its own, so its two
        # fields are set one at a time.
        var no_time = unsafe_alloc[timespec](1)
        no_time.unsafe_offset(0)[].tv_sec = 0
        no_time.unsafe_offset(0)[].tv_nsec = 0
        var found = unsafe_alloc[epoll_event](4)
        assert_equal(
            epoll_pwait2(old, found, 4, no_time, null_ptr[NoneType]()),
            0,
            "epoll_pwait2 is given no time at all, and so waits none",
        )

        no_time.unsafe_free()
        found.unsafe_free()
        wanted.unsafe_free()
        _ = close(ends.unsafe_load(0))
        _ = close(ends.unsafe_load(1))
        ends.unsafe_free()
        _ = close(old)


def main() raises:
    test_watching_a_pipe()
    test_the_two_that_are_left()
    print("test_epoll: ok")
