"""Tests for the `libc.sys.mman` bindings, none of which had been called."""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.fcntl import O_CREAT, O_RDWR
from libc.constant import (
    MADV_WILLNEED,
    MAP_ANONYMOUS,
    MAP_PRIVATE,
    MAP_SHARED,
    POSIX_MADV_NORMAL,
    PROT_READ,
    PROT_WRITE,
    MS_SYNC,
)
from libc.sys.mman import (
    madvise,
    mincore,
    mmap,
    mprotect,
    msync,
    munmap,
    posix_madvise,
    shm_open,
    shm_unlink,
)
from libc.unistd import close, ftruncate
from libc.utils import null_ptr, string_to_char_ptr


def test_mmap_hands_back_memory() raises:
    """`mmap` is given the address, the length, the protection, the flags,
    the descriptor and the offset, in that order, and three of those six
    are one type. What says the arguments landed where they were meant to
    is that what is written into it comes back out of it.
    """
    comptime SIZE = 4096
    comptime RW: Int32 = PROT_READ | PROT_WRITE
    comptime PRIVATE_ANON: Int32 = MAP_PRIVATE | MAP_ANONYMOUS

    var p = mmap(null_ptr[UInt8](), SIZE, RW, PRIVATE_ANON, -1, 0)
    # `MAP_FAILED` is `(void *) -1`, a pointer, so it cannot be written
    # down as a constant here; it is known instead by being the one
    # answer that is not a positive number.
    assert_true(Int(UInt(p)) > 0, "mmap hands back an address, not a failure")

    p.unsafe_store(0, UInt8(65))
    p.unsafe_store(1, UInt8(66))
    assert_equal(
        p.unsafe_load(0), UInt8(65), "and what is written is what is there"
    )
    assert_equal(p.unsafe_load(1), UInt8(66), "at the place it was written")

    assert_equal(
        mprotect(p, SIZE, PROT_READ),
        0,
        "mprotect takes the address, the length and the protection",
    )
    assert_equal(
        p.unsafe_load(0), UInt8(65), "and what was written can still be read"
    )
    assert_equal(
        mprotect(p, SIZE, RW), 0, "and the writing of it is given back"
    )

    assert_equal(
        msync(p, SIZE, MS_SYNC), 0, "msync takes the same two, and flags"
    )
    assert_equal(madvise(p, SIZE, MADV_WILLNEED), 0, "madvise takes an advice")
    assert_equal(
        posix_madvise(p, SIZE, POSIX_MADV_NORMAL),
        0,
        "and posix_madvise takes one of its own",
    )

    var vec = unsafe_alloc[UInt8](1)
    vec.unsafe_store(0, 0)
    assert_equal(
        mincore(p, SIZE, vec), 0, "mincore writes into the vector it is handed"
    )
    vec.unsafe_free()

    assert_equal(munmap(p, SIZE), 0, "and munmap takes the two back")


def test_shm_open_makes_an_object() raises:
    """A name, some flags and a mode, and what comes back is a descriptor
    that can be mapped like any other.
    """
    comptime SIZE = 4096
    comptime RW: Int32 = PROT_READ | PROT_WRITE
    var name = string_to_char_ptr("/mojo_libc_mman_shm")

    var fd = shm_open(name, Int32(O_CREAT | O_RDWR), 0o600)
    assert_true(fd >= 0, "shm_open hands back a descriptor")
    assert_equal(ftruncate(fd, SIZE), 0, "and it can be given a length")

    var p = mmap(null_ptr[UInt8](), SIZE, RW, Int32(MAP_SHARED), fd, 0)
    assert_true(Int(UInt(p)) > 0, "and the descriptor can be mapped")
    p.unsafe_store(0, UInt8(90))
    assert_equal(p.unsafe_load(0), UInt8(90), "through the mapping")

    assert_equal(munmap(p, SIZE), 0, "and unmapped again")
    assert_equal(close(fd), 0, "the descriptor closes")
    assert_equal(shm_unlink(name), 0, "and the name is taken away")


def main() raises:
    test_mmap_hands_back_memory()
    test_shm_open_makes_an_object()
    print("test_mman: ok")
