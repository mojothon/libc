"""Tests for the `libc.sys.msg` bindings.

One queue, made private, taken apart again at the end. What is asked of
it is the thing a pipe cannot do: two messages are put on with different
types, and the second type is asked for first. A queue that only kept
order would hand back the first message either way, so the order the two
come off in is the whole assertion.

The buffer is a `long` and some bytes: the type goes first, which is
where C reads it from, and the body starts at the eighth byte on both
platforms because a `long` is eight bytes on both.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_long
from libc.sys.ipc import IPC_CREAT, IPC_NOWAIT, IPC_PRIVATE, IPC_RMID
from libc.sys.msg import msgctl, msgget, msgrcv, msgsnd, msqid_ds
from libc.utils import null_ptr


def test_the_type_comes_off_before_the_order() raises:
    """Two messages on, and the newer type asked for first.

    The queue is made with `IPC_PRIVATE`, so it is one of its own and
    nothing else on the machine can be holding its key. Its permission
    bits are given as 0600 because it is created and nothing else is
    meant to look at it.

    The two bodies are one byte each, and the numbers are put in apart
    from the type so that a body landing on top of a type would show:
    the byte after the type is the only thing either message says.
    """
    var queue = msgget(IPC_PRIVATE, IPC_CREAT | 0o600)
    assert_true(queue >= 0, "a private queue can always be made")

    var out = unsafe_alloc[c_long](8)
    var out_bytes = out.unsafe_bitcast[UInt8]()

    out.unsafe_offset(0)[] = 1
    out_bytes.unsafe_offset(8)[] = UInt8(65)
    assert_equal(msgsnd(queue, out_bytes, 1, 0), 0, "the first message goes on")

    out.unsafe_offset(0)[] = 2
    out_bytes.unsafe_offset(8)[] = UInt8(66)
    assert_equal(msgsnd(queue, out_bytes, 1, 0), 0, "and so does the second")

    var into = unsafe_alloc[c_long](8)
    var into_bytes = into.unsafe_bitcast[UInt8]()

    assert_equal(
        msgrcv(queue, into_bytes, 1, 2, 0),
        1,
        "asking for the second type first gets it, and one byte of it",
    )
    assert_equal(
        Int(into.unsafe_offset(0)[]), 2, "the type came back with the message"
    )
    assert_equal(Int(into_bytes.unsafe_offset(8)[]), 66, "and so did its body")

    assert_equal(
        msgrcv(queue, into_bytes, 1, 0, 0),
        1,
        "the oldest whatever its type is the first message",
    )
    assert_equal(
        Int(into.unsafe_offset(0)[]), 1, "which is the one that went on first"
    )
    assert_equal(Int(into_bytes.unsafe_offset(8)[]), 65, "with its own body")

    assert_equal(
        msgrcv(queue, into_bytes, 1, 0, IPC_NOWAIT),
        -1,
        "an empty queue does not wait when it is told not to",
    )

    assert_equal(
        msgctl(queue, IPC_RMID, null_ptr[msqid_ds]()),
        0,
        "and the queue is removed without being asked about",
    )
    assert_equal(
        msgctl(queue, IPC_RMID, null_ptr[msqid_ds]()),
        -1,
        "a second removal finds nothing to remove",
    )

    out_bytes.unsafe_free()
    into_bytes.unsafe_free()


def main() raises:
    test_the_type_comes_off_before_the_order()
    print("test_msg: ok")
