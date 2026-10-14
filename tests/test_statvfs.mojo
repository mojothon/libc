"""Tests for `fstatvfs`, the last of `libc.sys.statvfs` to be called.

It is `statvfs` asked about a descriptor rather than about a path,
which is the same question put to something already open.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.fcntl import O_RDONLY, open as open_reading
from libc.sys.statvfs import Statvfs, fstatvfs
from libc.unistd import close
from libc.utils import string_to_char_ptr


def test_fstatvfs_on_what_is_already_open() raises:
    """What `fstatvfs` says of a file is what it says of the file
    system holding it: how much room there is, and how much of it is
    going.

    Nothing is checked against a number, these being numbers that
    change as the disk does. What is asked is only that the block
    size and the number of blocks are both more than nothing, which
    is true of every file system that has room for a file at all.
    """
    var fd = open_reading(string_to_char_ptr("/tmp"), O_RDONLY)
    assert_true(fd >= 0, "there is a directory open")

    var here = unsafe_alloc[Statvfs](1)
    here.unsafe_offset(0)[] = Statvfs()
    assert_equal(fstatvfs(fd, here), 0, "fstatvfs answers")

    assert_true(
        Int(here.unsafe_offset(0)[].f_bsize()) > 0,
        "and the block size is not nothing",
    )
    assert_true(
        Int(here.unsafe_offset(0)[].f_blocks()) > 0,
        "and there are blocks to speak of",
    )

    here.unsafe_free()
    _ = close(fd)


def main() raises:
    test_fstatvfs_on_what_is_already_open()
    print("test_statvfs: ok")
