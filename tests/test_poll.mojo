from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_short, c_ulong
from libc.time import timespec
from libc.poll import POLLIN, POLLNVAL, POLLOUT, poll, pollfd, ppoll
from libc.unistd import close, pipe, write
from libc.utils import null_ptr


def test_poll_reports_a_pipe_with_data() raises:
    """A pipe whose write end has been written to is ready to read."""
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "pipe succeeded")
    var watch = unsafe_alloc[pollfd](1)
    watch.unsafe_offset(0)[] = pollfd(fds.unsafe_load(0), c_short(POLLIN))

    # Nothing written yet, so asking without waiting answers nothing.
    assert_equal(poll(watch, c_ulong(1), 0), 0, "an empty pipe is not ready")
    assert_equal(
        Int(watch.unsafe_offset(0)[].revents), 0, "revents is left clear"
    )

    var message = unsafe_alloc[UInt8](1)
    message.unsafe_offset(0)[] = UInt8(65)
    assert_equal(write(fds.unsafe_load(1), message, 1), 1, "one byte written")

    assert_equal(poll(watch, c_ulong(1), 0), 1, "the pipe is ready now")
    assert_true(
        (Int(watch.unsafe_offset(0)[].revents) & POLLIN) != 0,
        "revents says there is data to read",
    )

    _ = close(fds.unsafe_load(0))
    _ = close(fds.unsafe_load(1))


def test_poll_reports_a_closed_descriptor() raises:
    """A descriptor that is not open answers POLLNVAL, whether asked or not."""
    var watch = unsafe_alloc[pollfd](1)
    watch.unsafe_offset(0)[] = pollfd(Int32(987), c_short(POLLOUT))

    # Nothing to ask: -1 and anything the process does not have are skipped,
    # and an already-closed one is answered rather than ignored.
    assert_equal(
        poll(watch, c_ulong(1), 0), 1, "one of them had something to say"
    )
    assert_true(
        (Int(watch.unsafe_offset(0)[].revents) & POLLNVAL) != 0,
        "POLLNVAL comes back without anyone asking for it",
    )


def test_poll_waiting_on_nothing_times_out() raises:
    """Waiting past the timeout gives 0 and clears errno's business."""
    var watch = unsafe_alloc[pollfd](1)
    watch.unsafe_offset(0)[] = pollfd(Int32(-1), c_short(POLLIN))

    # A negative fd is skipped entirely, so this waits out the whole ten
    # milliseconds with nothing to find, which is what a timeout looks like.
    assert_equal(poll(watch, c_ulong(1), 10), 0, "the timeout expired")
    assert_equal(
        Int(watch.unsafe_offset(0)[].revents), 0, "nothing was reported"
    )


def test_ppoll_waits_in_nanoseconds() raises:
    """`ppoll` is `poll` with the wait given as a `timespec` rather
    than as a number of milliseconds, which is how it asks for less
    than a millisecond, and with a signal mask to wear while it waits.
    Given none, it has nothing to wear and waits as `poll` does.
    """
    comptime if not CompilationTarget.is_macos():
        var fds = unsafe_alloc[Int32](2)
        assert_equal(pipe(fds), 0, "pipe succeeded")
        var watch = unsafe_alloc[pollfd](1)
        watch.unsafe_offset(0)[] = pollfd(fds.unsafe_load(0), c_short(POLLIN))

        var none = unsafe_alloc[timespec](1)
        none.unsafe_offset(0)[] = timespec(0, 0)

        assert_equal(
            ppoll(watch, c_ulong(1), none, null_ptr[NoneType]()),
            0,
            "an empty pipe is not ready",
        )

        var message = unsafe_alloc[UInt8](1)
        message.unsafe_offset(0)[] = UInt8(65)
        assert_equal(
            write(fds.unsafe_load(1), message, 1), 1, "one byte written"
        )

        assert_equal(
            ppoll(watch, c_ulong(1), none, null_ptr[NoneType]()),
            1,
            "the pipe is ready now",
        )
        assert_true(
            (Int(watch.unsafe_offset(0)[].revents) & POLLIN) != 0,
            "revents says there is data to read",
        )

        none.unsafe_free()
        message.unsafe_free()
        watch.unsafe_free()
        _ = close(fds.unsafe_load(0))
        _ = close(fds.unsafe_load(1))
        fds.unsafe_free()


def main() raises:
    test_poll_reports_a_pipe_with_data()
    test_poll_reports_a_closed_descriptor()
    test_poll_waiting_on_nothing_times_out()
    test_ppoll_waits_in_nanoseconds()
    print("poll ok")
