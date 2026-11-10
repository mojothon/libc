"""Tests for the `libc.sys.inotify` bindings.

Linux only: the header is not on the other side, so every one of
these is made behind a `comptime if`, which is what `test_epoll`
does.

What makes them worth having is that an event names its own watch:
what is asserted is that the number in the event is the number
`inotify_add_watch` answered with, which is the only part that is
not a foregone conclusion — a mask read out of the wrong place is
still a mask, and four 32-bit fields read in the wrong order are
still four numbers.

`IN_MODIFY` is proved by writing to the file after the queue has been
shown empty, and `IN_IGNORED` by the event that taking a watch off
puts on the queue: the one thing that tells "removed" apart from
"nothing happened". `IN_CLOEXEC` is asked about through `fcntl`,
because a wrong one still makes a queue, only one that survives
`exec`.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.fcntl import FD_CLOEXEC, F_GETFD, fcntl
from libc.stdlib import mkstemp
from libc.sys.inotify import (
    IN_CLOEXEC,
    IN_IGNORED,
    IN_MODIFY,
    IN_NONBLOCK,
    inotify_add_watch,
    inotify_event,
    inotify_init,
    inotify_init1,
    inotify_rm_watch,
)
from libc.unistd import close, read, unlink, write
from libc.utils import string_to_char_ptr


def test_a_queue_that_says_what_happened() raises:
    """The whole round trip on one queue: a file put under it, the
    queue shown empty, the file written to, and the event read out
    and asked which watch it came from.

    The empty read first is what makes the event mean something: a
    queue that had something on it from the beginning would answer
    the same afterwards whether or not the write had been noticed.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_inotify_XXXXXX")
        var file = mkstemp(path)
        assert_true(file >= 0, "a file to watch is made")

        var queue = inotify_init1(IN_NONBLOCK)
        assert_true(queue >= 0, "a queue is made")

        var watch = inotify_add_watch(queue, path, IN_MODIFY)
        # The machine's watches spent by something else is a question
        # the environment is asking, not this package's -- the suite did
        # not spend them. A test that cannot be set up says so and
        # goes, instead of failing on a machine that has none left.
        if watch < 0:
            print("test_inotify: skipped, the machine's watches are spent")
            return

        var buf = unsafe_alloc[UInt8](512)
        assert_equal(
            Int(read(queue, buf, 512)), -1, "and nothing has happened to it yet"
        )

        var one = string_to_char_ptr("x")
        assert_equal(Int(write(file, one, 1)), 1, "the file is written to")
        one.unsafe_free()

        assert_true(Int(read(queue, buf, 512)) >= 16, "and that is an event")
        var ev = buf.unsafe_bitcast[inotify_event]()
        assert_equal(Int(ev[].wd), Int(watch), "naming the watch it came from")
        assert_true(ev[].mask & IN_MODIFY != 0, "and saying it was modified")
        assert_equal(
            Int(ev[].len), 0, "with no name, being about the file itself"
        )

        # Taking a watch off is itself an event, and the last one it
        # ever puts on the queue.
        assert_equal(
            Int(inotify_rm_watch(queue, watch)), 0, "the watch comes off"
        )
        assert_true(
            Int(read(queue, buf, 512)) >= 16, "and that is an event too"
        )
        assert_true(
            ev[].mask & IN_IGNORED != 0,
            "IN_IGNORED: the last thing that watch says",
        )

        assert_equal(
            Int(read(queue, buf, 512)), -1, "and then the queue is empty"
        )

        assert_equal(Int(close(queue)), 0, "the queue closes")
        assert_equal(Int(close(file)), 0, "the file closes")
        assert_equal(Int(unlink(path)), 0, "and the file goes")
        buf.unsafe_free()
        path.unsafe_free()


def test_a_watch_that_can_only_be_taken_off_once() raises:
    """`inotify_init` and the second half of `inotify_rm_watch`: a
    watch descriptor that has been taken off is not one this queue
    knows, and the second attempt says so rather than doing it again.

    The read here waits, there being no `IN_NONBLOCK`, and that is
    the difference between the two `inotify_init` calls: it comes
    back because the write has already happened.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_inotify_XXXXXX")
        var file = mkstemp(path)
        assert_true(file >= 0, "a file to watch is made")

        var queue = inotify_init()
        assert_true(queue >= 0, "a plain queue is made")

        var watch = inotify_add_watch(queue, path, IN_MODIFY)
        # The same guard the first asking carries.
        if watch < 0:
            print("test_inotify: skipped, the machine's watches are spent")
            return

        var one = string_to_char_ptr("y")
        assert_equal(Int(write(file, one, 1)), 1, "the file is written to")
        one.unsafe_free()

        var buf = unsafe_alloc[UInt8](512)
        assert_true(
            Int(read(queue, buf, 512)) >= 16, "and the queue has an event"
        )
        var ev = buf.unsafe_bitcast[inotify_event]()
        assert_equal(Int(ev[].wd), Int(watch), "from that watch")

        assert_equal(
            Int(inotify_rm_watch(queue, watch)), 0, "the watch comes off"
        )
        assert_equal(
            Int(inotify_rm_watch(queue, watch)),
            -1,
            "and it is not one to take off twice",
        )

        assert_equal(Int(close(queue)), 0, "the queue closes")
        assert_equal(Int(close(file)), 0, "the file closes")
        assert_equal(Int(unlink(path)), 0, "and the file goes")
        buf.unsafe_free()
        path.unsafe_free()


def test_the_flag_is_a_descriptor_flag_by_another_name() raises:
    """`IN_CLOEXEC` asked about through `fcntl`, which is where the
    difference it makes shows.

    A wrong one still makes a queue, only one that is left open
    across `exec`, and nothing in the first two tests would notice.
    """
    comptime if not CompilationTarget.is_macos():
        var queue = inotify_init1(IN_CLOEXEC)
        assert_true(queue >= 0, "a queue is made with IN_CLOEXEC")
        assert_true(
            Int(fcntl(queue, F_GETFD, 0)) & Int(FD_CLOEXEC) != 0,
            "and it is one that does not survive exec",
        )
        assert_equal(Int(close(queue)), 0, "the queue closes")


def main() raises:
    test_a_queue_that_says_what_happened()
    test_a_watch_that_can_only_be_taken_off_once()
    test_the_flag_is_a_descriptor_flag_by_another_name()
    print("test_inotify: ok")
