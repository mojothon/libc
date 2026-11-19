"""Tests for the `libc.sys.mqueue` bindings.

`mqueue` is Linux's and nobody else's — Darwin has no POSIX message
queues at all — so every one of these is made only where it exists.
The queue each test makes is named for this suite and unlinked at the
end, and unlinked again before it is created, so a run that died mid
test does not leave a queue the next one trips over.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import ENOENT, ETIMEDOUT
from libc.errno import get_errno
from libc.fcntl import O_CREAT, O_EXCL, O_NONBLOCK, O_RDONLY, O_RDWR
from libc.sys.mqueue import (
    MqAttr,
    mq_close,
    mq_getattr,
    mq_open,
    mq_receive,
    mq_send,
    mq_setattr,
    mq_timedreceive,
    mq_timedsend,
    mq_unlink,
)
from libc.time import CLOCK_REALTIME, clock_gettime, timespec
from libc.utils import char_ptr_to_string, string_to_char_ptr


def _sweep():
    """Unlinks the test queue, whether or not it is there."""
    _ = mq_unlink(string_to_char_ptr("/libc-test-mq"))


def test_open_close_unlink() raises:
    """A queue is created, closed, unlinked, and gone."""
    comptime if not CompilationTarget.is_macos():
        _sweep()

        # Created with the shape every test below assumes: room for
        # four messages of forty bytes each.
        var attr = unsafe_alloc[MqAttr](1)
        attr.unsafe_offset(0)[] = MqAttr.of(4, 40)
        var mqd = mq_open(
            string_to_char_ptr("/libc-test-mq"),
            O_CREAT | O_RDWR,
            Int32(0o600),
            attr,
        )
        assert_true(mqd >= 0, "mq_open creates a queue")

        # Created again with O_EXCL, which must refuse: the queue is
        # there, and exclusive creation is the one thing it does not
        # do twice.
        var again = mq_open(
            string_to_char_ptr("/libc-test-mq"),
            O_CREAT | O_EXCL | O_RDWR,
            Int32(0o600),
            attr,
        )
        assert_equal(again, -1, "mq_open with O_EXCL refuses a queue that is")
        _ = mq_close(again)

        assert_equal(mq_close(mqd), 0, "mq_close ends the descriptor")
        assert_equal(
            mq_unlink(string_to_char_ptr("/libc-test-mq")),
            0,
            "mq_unlink ends the queue",
        )
        assert_equal(
            mq_unlink(string_to_char_ptr("/libc-test-mq")),
            -1,
            "and the second unlink finds none",
        )

        # Opened for reading alone, with no O_CREAT, it is not there:
        # the ENOENT the unlink above promised.
        var reader = mq_open(
            string_to_char_ptr("/libc-test-mq"), O_RDONLY, Int32(0), attr
        )
        assert_equal(reader, -1, "mq_open finds nothing after the unlink")
        assert_equal(
            Int(get_errno()), ENOENT, "saying so by the errno it leaves"
        )
        _ = mq_close(reader)
        attr.unsafe_free()


def test_getattr() raises:
    """The shape a queue is created with is the shape it answers."""
    comptime if not CompilationTarget.is_macos():
        _sweep()
        var attr = unsafe_alloc[MqAttr](1)
        attr.unsafe_offset(0)[] = MqAttr.of(4, 40)
        var mqd = mq_open(
            string_to_char_ptr("/libc-test-mq"),
            O_CREAT | O_RDWR,
            Int32(0o600),
            attr,
        )
        assert_true(mqd >= 0, "the queue is made")

        var seen = unsafe_alloc[MqAttr](1)
        assert_equal(mq_getattr(mqd, seen), 0, "mq_getattr answers")
        assert_equal(
            seen.unsafe_offset(0)[].mq_maxmsg,
            4,
            "maxmsg is the shape it was made with",
        )
        assert_equal(seen.unsafe_offset(0)[].mq_msgsize, 40, "msgsize too")
        assert_equal(
            seen.unsafe_offset(0)[].mq_curmsgs,
            0,
            "and the queue holds nothing yet",
        )

        assert_equal(mq_close(mqd), 0, "closed")
        assert_equal(
            mq_unlink(string_to_char_ptr("/libc-test-mq")), 0, "and gone"
        )
        attr.unsafe_free()
        seen.unsafe_free()


def test_send_receive_priority() raises:
    """Two messages go in at different priorities and come out highest
    first, each with the length and the priority it went in with."""
    comptime if not CompilationTarget.is_macos():
        _sweep()
        var attr = unsafe_alloc[MqAttr](1)
        attr.unsafe_offset(0)[] = MqAttr.of(4, 40)
        var mqd = mq_open(
            string_to_char_ptr("/libc-test-mq"),
            O_CREAT | O_RDWR,
            Int32(0o600),
            attr,
        )
        assert_true(mqd >= 0, "the queue is made")

        var hello = string_to_char_ptr("hello")
        var urgent = string_to_char_ptr("urgent")

        # "hello" first, at the plainest priority, then "urgent" above
        # it -- so the order out is the priority's doing and not the
        # arrival's.
        assert_equal(
            mq_send(mqd, hello, UInt64(5), UInt32(1)),
            0,
            "mq_send takes the plain one",
        )
        assert_equal(
            mq_send(mqd, urgent, UInt64(6), UInt32(2)),
            0,
            "and the urgent one above it",
        )

        var seen = unsafe_alloc[MqAttr](1)
        assert_equal(mq_getattr(mqd, seen), 0, "mq_getattr before the read")
        assert_equal(
            seen.unsafe_offset(0)[].mq_curmsgs, 2, "the queue holds both"
        )

        var room = unsafe_alloc[UInt8](40)
        var prio = unsafe_alloc[UInt32](1)
        var n = mq_receive(mqd, room, UInt64(40), prio)
        assert_equal(n, 6, "the urgent message comes out first")
        # `mq_receive` writes the message and nothing else -- no
        # terminator -- so the byte after it is made one by hand.
        room.unsafe_store(Int(n), 0)
        assert_equal(char_ptr_to_string(room), "urgent", "byte for byte")
        assert_equal(Int(prio.unsafe_load(0)), 2, "with its priority")

        n = mq_receive(mqd, room, UInt64(40), prio)
        assert_equal(n, 5, "then the plain one")
        room.unsafe_store(Int(n), 0)
        assert_equal(char_ptr_to_string(room), "hello", "byte for byte")
        assert_equal(Int(prio.unsafe_load(0)), 1, "with its priority")

        assert_equal(mq_close(mqd), 0, "closed")
        assert_equal(
            mq_unlink(string_to_char_ptr("/libc-test-mq")), 0, "and gone"
        )
        attr.unsafe_free()
        seen.unsafe_free()
        room.unsafe_free()
        prio.unsafe_free()


def test_setattr_nonblock() raises:
    """`mq_setattr` turns the descriptor non-blocking and back, and the
    descriptor's before-state comes back through the old slot."""
    comptime if not CompilationTarget.is_macos():
        _sweep()
        var attr = unsafe_alloc[MqAttr](1)
        attr.unsafe_offset(0)[] = MqAttr.of(4, 40)
        var mqd = mq_open(
            string_to_char_ptr("/libc-test-mq"),
            O_CREAT | O_RDWR,
            Int32(0o600),
            attr,
        )
        assert_true(mqd >= 0, "the queue is made")

        var want = unsafe_alloc[MqAttr](1)
        want.unsafe_offset(0)[] = MqAttr()
        want.unsafe_offset(0)[].mq_flags = Int64(O_NONBLOCK)
        var was = unsafe_alloc[MqAttr](1)
        print("about to setattr")
        assert_equal(mq_setattr(mqd, want, was), 0, "mq_setattr answers")
        assert_equal(
            was.unsafe_offset(0)[].mq_flags, 0, "the descriptor was blocking"
        )

        var seen = unsafe_alloc[MqAttr](1)
        assert_equal(mq_getattr(mqd, seen), 0, "mq_getattr after")
        assert_equal(
            seen.unsafe_offset(0)[].mq_flags,
            Int64(O_NONBLOCK),
            "and is not now",
        )

        var back = unsafe_alloc[MqAttr](1)
        back.unsafe_offset(0)[] = MqAttr()
        back.unsafe_offset(0)[].mq_flags = 0
        assert_equal(mq_setattr(mqd, back, was), 0, "set back")
        assert_equal(
            was.unsafe_offset(0)[].mq_flags,
            Int64(O_NONBLOCK),
            "the old slot saw it",
        )

        assert_equal(mq_close(mqd), 0, "closed")
        assert_equal(
            mq_unlink(string_to_char_ptr("/libc-test-mq")), 0, "and gone"
        )
        print("reaching end of setattr test")


def test_timed_times_out() raises:
    """On an empty queue a receive with a tenth of a second to wait
    stops on the clock, saying `ETIMEDOUT`, and a full queue says the
    same to a send."""
    comptime if not CompilationTarget.is_macos():
        _sweep()
        var attr = unsafe_alloc[MqAttr](1)
        attr.unsafe_offset(0)[] = MqAttr.of(1, 40)
        var mqd = mq_open(
            string_to_char_ptr("/libc-test-mq"),
            O_CREAT | O_RDWR,
            Int32(0o600),
            attr,
        )
        assert_true(mqd >= 0, "a one-message queue is made")

        # Now plus a tenth of a second, on the clock the call reads.
        var deadline = unsafe_alloc[timespec](1)
        assert_equal(clock_gettime(CLOCK_REALTIME, deadline), 0, "the clock")
        var t = deadline.unsafe_offset(0)[]
        t.tv_nsec += 100_000_000
        if t.tv_nsec >= 1_000_000_000:
            t.tv_sec += 1
            t.tv_nsec -= 1_000_000_000
        deadline.unsafe_offset(0)[] = t

        var room = unsafe_alloc[UInt8](40)
        var prio = unsafe_alloc[UInt32](1)
        var n = mq_timedreceive(mqd, room, UInt64(40), prio, deadline)
        assert_equal(n, -1, "an empty queue with a deadline answers -1")
        assert_equal(Int(get_errno()), ETIMEDOUT, "and the clock ran out")

        var hello = string_to_char_ptr("hello")
        assert_equal(
            mq_send(mqd, hello, UInt64(5), UInt32(1)),
            0,
            "the one slot is taken",
        )
        var rc = mq_timedsend(mqd, hello, UInt64(5), UInt32(1), deadline)
        assert_equal(rc, -1, "a full queue with a deadline answers -1")
        assert_equal(Int(get_errno()), ETIMEDOUT, "and the clock ran out again")

        assert_equal(mq_close(mqd), 0, "closed")
        assert_equal(
            mq_unlink(string_to_char_ptr("/libc-test-mq")), 0, "and gone"
        )
        attr.unsafe_free()
        deadline.unsafe_free()
        room.unsafe_free()
        prio.unsafe_free()


def main() raises:
    test_open_close_unlink()
    test_getattr()
    test_send_receive_priority()
    test_setattr_nonblock()
    test_timed_times_out()
    print("test_mqueue: ok")
