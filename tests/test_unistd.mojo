"""Tests for the `libc.unistd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.unistd import getcwd, getpid, swab


def test_getcwd() raises:
    """`getcwd` hands back the buffer it filled, not 0 or -1."""
    var buf = unsafe_alloc[UInt8](256)
    var got = getcwd(buf, 256)

    # An absolute path starts with `/`, and what comes back is the pointer
    # that was passed in, so it has to be readable as bytes.
    assert_equal(got[0], UInt8(0x2F))

    var length = 0
    while got[length] != 0:
        length += 1
    assert_true(length > 1)


def test_swab() raises:
    """`swab` copies and swaps each pair of bytes."""
    var src = unsafe_alloc[UInt8](4)
    var dst = unsafe_alloc[UInt8](4)
    src[0] = 0x01
    src[1] = 0x02
    src[2] = 0x03
    src[3] = 0x04

    swab(src, dst, 4)

    assert_equal(dst[0], UInt8(0x02))
    assert_equal(dst[1], UInt8(0x01))
    assert_equal(dst[2], UInt8(0x04))
    assert_equal(dst[3], UInt8(0x03))


def test_getpid() raises:
    """This process has an id, and it is not zero."""
    assert_true(getpid() > 0)


def main() raises:
    test_getcwd()
    test_swab()
    test_getpid()
    print("test_unistd: ok")
