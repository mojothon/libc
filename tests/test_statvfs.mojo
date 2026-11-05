"""Tests for `fstatvfs`, the last of `libc.sys.statvfs` to be called.

It is `statvfs` asked about a descriptor rather than about a path,
which is the same question put to something already open.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.fcntl import O_RDONLY, open as open_reading
from libc.sys.statvfs import Statvfs, fstatvfs, statvfs
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


def test_the_room_for_others_and_the_identity_of_the_file_system() raises:
    """`f_favail` is how much inode room is left to a process that is
    not root, and both platforms answer it with the number they
    answer free inodes with — there being no separate reserve of
    inodes for root to be told about. That equality is what says the
    reader is over `f_favail` and not over some other member: every
    neighbor of it answers with a different number on the same call.

    `f_fsid` is the file system's own identifier, and the same
    question asked two ways — of the path, and of a descriptor that
    was opened on it — has to be answered twice with the same number.
    It is the one member two different bindings can be made to
    agree about.
    """
    var path = string_to_char_ptr("/tmp")
    var fd = open_reading(path, O_RDONLY)
    assert_true(fd >= 0, "there is a directory open")

    var here = unsafe_alloc[Statvfs](1)
    here.unsafe_offset(0)[] = Statvfs()
    assert_equal(statvfs(path, here), 0, "statvfs answers about the path")

    assert_equal(
        Int(here.unsafe_offset(0)[].f_favail()),
        Int(here.unsafe_offset(0)[].f_ffree()),
        (
            "the room for others is the room that is free, as both platforms"
            " answer it"
        ),
    )

    var by_descriptor = unsafe_alloc[Statvfs](1)
    by_descriptor.unsafe_offset(0)[] = Statvfs()
    assert_equal(
        fstatvfs(fd, by_descriptor),
        0,
        "and fstatvfs answers about what is open",
    )
    assert_equal(
        Int(here.unsafe_offset(0)[].f_fsid()),
        Int(by_descriptor.unsafe_offset(0)[].f_fsid()),
        "the identity is the same asked of the path and of the descriptor",
    )
    assert_true(
        Int(here.unsafe_offset(0)[].f_fsid()) != 0,
        "and it is not nothing: the file system has an identity",
    )

    here.unsafe_free()
    by_descriptor.unsafe_free()
    _ = close(fd)


def main() raises:
    test_fstatvfs_on_what_is_already_open()
    test_the_room_for_others_and_the_identity_of_the_file_system()
    print("test_statvfs: ok")
