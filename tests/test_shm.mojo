"""Tests for the `libc.sys.shm` bindings.

A segment is attached twice and left to prove itself. The first
attachment is written into, the second is read out of, and if the two
were ordinary memory the second would find nothing there — so a byte
found at both ends of the segment says three things at once: that
`shmat` gave back a real address, that the two addresses are the same
bytes, and that the size asked for came back whole rather than clipped
to a page.

The read-only attachment is the check on the flags. It reads the same
byte, which a flag that never reached C would also do, so what makes it
worth asking is that it is a different call with a different flag and it
still has to answer with the segment's contents rather than with zero or
a fault.
"""
from std.testing import assert_equal, assert_true

from libc.sys.ipc import IPC_CREAT, IPC_PRIVATE, IPC_RMID
from libc.sys.shm import SHM_RDONLY, shmat, shmctl, shmdt, shmget, shmid_ds
from libc.utils import null_ptr


def test_two_attachments_are_one_segment() raises:
    """A private segment, written once and read back twice.

    The size is a whole page, so what is written at the last byte is
    still inside the segment on both platforms: a size is rounded up, and
    this one is already a multiple of the only rounding either of them
    does.

    The segment is marked for removal before the test ends, attached or
    not — a segment left behind stays until the machine goes down, and a
    test that leaves one is a test that leaks something the kernel will
    not clean up on its own.
    """
    comptime SIZE = 4096

    var segment = shmget(IPC_PRIVATE, SIZE, IPC_CREAT | 0o600)
    assert_true(segment >= 0, "a private segment can always be made")

    var first = shmat(segment, null_ptr[UInt8](), 0)
    # `MAP_FAILED` and its like are `(void *) -1`, and a pointer cannot
    # be written down as a constant here: the failure is known instead by
    # being the one answer that is not a positive number.
    assert_true(
        Int(UInt(first)) > 0, "shmat hands back an address, not a failure"
    )

    first.unsafe_store(0, UInt8(0xAB))
    first.unsafe_store(SIZE - 1, UInt8(0xCD))

    var second = shmat(segment, null_ptr[UInt8](), 0)
    assert_true(Int(UInt(second)) > 0, "and it can be attached a second time")
    assert_equal(
        second.unsafe_load(0),
        UInt8(0xAB),
        "what was written through one attachment is read through the other",
    )
    assert_equal(
        second.unsafe_load(SIZE - 1),
        UInt8(0xCD),
        "and at the far end, so the size was given whole",
    )

    var read_only = shmat(segment, null_ptr[UInt8](), SHM_RDONLY)
    assert_true(
        Int(UInt(read_only)) > 0, "a read-only attachment is a call too"
    )
    assert_equal(
        read_only.unsafe_load(0),
        UInt8(0xAB),
        "and reads the segment rather than zero",
    )
    assert_equal(shmdt(read_only), 0, "and comes off")

    assert_equal(shmdt(second), 0, "the first of the two goes")
    assert_equal(shmdt(first), 0, "and then the other")

    assert_equal(
        shmctl(segment, IPC_RMID, null_ptr[shmid_ds]()),
        0,
        "and the segment is marked for removal without being asked about",
    )
    assert_equal(
        shmctl(segment, IPC_RMID, null_ptr[shmid_ds]()),
        -1,
        "a second removal finds nothing to remove",
    )


def main() raises:
    test_two_attachments_are_one_segment()
    print("test_shm: ok")
