"""Tests for `fstatvfs`, the last of `libc.sys.statvfs` to be called.

It is `statvfs` asked about a descriptor rather than about a path,
which is the same question put to something already open.
"""
from std.memory.alloc import unsafe_alloc
from std.collections.list import List
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import O_RDONLY, open as open_reading
from libc.sys.statfs import Statfs, fstatfs, statfs
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


def test_the_kernel_s_own_account_agrees_with_the_posix_one() raises:
    """The same file system asked in both shapes, answering with the
    same numbers.

    `statvfs` and `statfs` are two spellings of one question, and the
    kernel fills both from the same superblock: the block size, the
    counts of blocks and inodes total and free and free to the
    unprivileged. A struct whose member is read one word away from
    where it lives answers with its neighbour, and the neighbour is
    another occupancy counter of the same kind -- which is why the
    numbers alone could never be pressed. But the two structures do
    not slide the same way: the member that sits at one offset in
    `statvfs` sits at another in `statfs`, so a mistake in one binding
    moves its answer and the other binding does not move with it. The
    equalities below are witnesses that do not go through the constant
    they are checking.

    Two members are not asked to agree, because glibc does not carry
    the kernel's word over unchanged: `f_frsize` is `f_bsize` in the
    POSIX shape and the kernel's own fundamental size in the other,
    and `f_fsid` is packed by the library out of the two halves in one
    shape and by this binding in the other. `/proc` is asked beside
    `/`: a file system whose counters answer zero is a second shape of
    truth, and a slide that lands on a zero where a count should be is
    caught by the file system that has none.
    """
    comptime if not CompilationTarget.is_macos():
        var by_path = unsafe_alloc[Statvfs](1)
        var by_kernel = unsafe_alloc[Statfs](1)

        var places = List[String]()
        places.append("/")
        places.append("/proc")
        for place in places:
            var there = string_to_char_ptr(place)
            assert_equal(
                statvfs(there, by_path), 0, "statvfs answers about the place"
            )
            assert_equal(
                statfs(there, by_kernel), 0, "and statfs answers about it too"
            )
            assert_equal(
                Int(by_path.unsafe_offset(0)[].f_bsize()),
                Int(by_kernel.unsafe_offset(0)[].f_bsize()),
                "the block size is the same number in both shapes",
            )
            assert_equal(
                Int(by_path.unsafe_offset(0)[].f_blocks()),
                Int(by_kernel.unsafe_offset(0)[].f_blocks()),
                "the blocks there are the same count both ways",
            )
            assert_equal(
                Int(by_path.unsafe_offset(0)[].f_bfree()),
                Int(by_kernel.unsafe_offset(0)[].f_bfree()),
                "and the free blocks",
            )
            assert_equal(
                Int(by_path.unsafe_offset(0)[].f_bavail()),
                Int(by_kernel.unsafe_offset(0)[].f_bavail()),
                "and the blocks free to others",
            )
            assert_equal(
                Int(by_path.unsafe_offset(0)[].f_files()),
                Int(by_kernel.unsafe_offset(0)[].f_files()),
                "the file slots are the same count both ways",
            )
            assert_equal(
                Int(by_path.unsafe_offset(0)[].f_ffree()),
                Int(by_kernel.unsafe_offset(0)[].f_ffree()),
                "and the slots free",
            )
            # The mount flags are not the same numbers in the two
            # shapes -- glibc re-encodes them for `statvfs` -- so the
            # flag is not asked to agree. But a mount has options:
            # procfs is put up with nosuid and nodev and noexec, and
            # the flags answering zero would be a reader over
            # `f_namemax`, which is 255 everywhere.
            if place == "/proc":
                assert_true(
                    Int(by_path.unsafe_offset(0)[].f_flag()) != 0,
                    "the flags of a mounted file system are not nothing",
                )

        var fd = open_reading(string_to_char_ptr("/tmp"), O_RDONLY)
        assert_true(fd >= 0, "there is a directory open")
        var by_descriptor = unsafe_alloc[Statfs](1)
        assert_equal(fstatfs(fd, by_descriptor), 0, "fstatfs answers too")
        assert_equal(
            Int(by_descriptor.unsafe_offset(0)[].f_bsize()),
            Int(by_kernel.unsafe_offset(0)[].f_bsize()),
            "and says of the open file what statfs says of its path",
        )
        by_descriptor.unsafe_free()
        _ = close(fd)

        by_path.unsafe_free()
        by_kernel.unsafe_free()


def main() raises:
    test_fstatvfs_on_what_is_already_open()
    test_the_room_for_others_and_the_identity_of_the_file_system()
    test_the_kernel_s_own_account_agrees_with_the_posix_one()
    print("test_statvfs: ok")
