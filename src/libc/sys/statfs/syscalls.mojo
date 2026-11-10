# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


# Where each member of C's `struct statfs` sits. Linux says the members
# in words: `f_type` first, then the block and inode counts, `f_fsid` as
# the two halves the kernel hands over packed into one word, and the
# struct is 120 bytes. Darwin's is the wider shape — four-byte block
# sizes, sixty-four-bit counts, and the two mount paths it carries
# inside itself — so what Linux holds in fifteen words Darwin holds in
# two hundred and sixty-eight, and every accessor that reads a count
# reads a word on one platform and half of one on the other.
#
# Numbers from `bits/statfs.h` and XNU `sys/mount.h`, and every one of
# them is compared with C's `offsetof` on both platforms by
# `scripts/check-layouts.py`.
comptime STATFS_SLOTS: Int = 268 if CompilationTarget.is_macos() else 15
comptime STATFS_TYPE_OFFSET: Int = 60 if CompilationTarget.is_macos() else 0
comptime STATFS_BSIZE_OFFSET: Int = 0 if CompilationTarget.is_macos() else 8
comptime STATFS_BLOCKS_OFFSET: Int = 8 if CompilationTarget.is_macos() else 16
comptime STATFS_BFREE_OFFSET: Int = 16 if CompilationTarget.is_macos() else 24
comptime STATFS_BAVAIL_OFFSET: Int = 24 if CompilationTarget.is_macos() else 32
comptime STATFS_FILES_OFFSET: Int = 32 if CompilationTarget.is_macos() else 40
comptime STATFS_FFREE_OFFSET: Int = 40 if CompilationTarget.is_macos() else 48
comptime STATFS_FSID_OFFSET: Int = 48 if CompilationTarget.is_macos() else 56
comptime STATFS_NAMELEN_OFFSET: Int = 64
comptime STATFS_FRSIZE_OFFSET: Int = 72
comptime STATFS_FLAGS_OFFSET: Int = 64 if CompilationTarget.is_macos() else 80


struct Statfs:
    """A C `struct statfs`: the kernel's own account of a file system.

    Held as bytes and read by offset, the way `statvfs` beside it is:
    the two structures answer the same question with different
    arrangements — Linux's members are all machine words, Darwin's
    alternate four and eight — and the two bindings existing side by
    side is what makes each of them checkable, because a file system
    asked twice, once in each shape, has to answer with the same
    numbers both times.

    The offsets are named above rather than in the methods, so that the
    layout can be read as a layout and so that a script can ask C the
    same question about every one of them.
    """

    var _slots: Array[UInt64, STATFS_SLOTS]

    def __init__(out self):
        """Zeroes every member, which is what `memset` would leave behind."""
        self._slots = Array[UInt64, STATFS_SLOTS](fill=0)

    def _u32(self, off: Int) -> UInt64:
        """The four bytes at a four-aligned `off`, little-endian."""
        return (self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFFFFFFFF

    def _u64(self, off: Int) -> UInt64:
        """The whole word at `off`, which is all of a slot."""
        return self._slots[off // 8]

    def f_type(self) -> UInt64:
        """The file system's type number, the `linux_MAGIC` constants."""
        # A word on both platforms, and first in both.
        return self._u64(STATFS_TYPE_OFFSET)

    def f_bsize(self) -> UInt64:
        """The file system's block size, in bytes."""
        # A word on Linux; Darwin opens with two four-byte members.
        comptime if CompilationTarget.is_macos():
            return self._u32(STATFS_BSIZE_OFFSET)
        else:
            return self._u64(STATFS_BSIZE_OFFSET)

    def f_blocks(self) -> UInt64:
        """How many blocks the file system has."""
        return self._u64(STATFS_BLOCKS_OFFSET)

    def f_bfree(self) -> UInt64:
        """How many blocks are free."""
        return self._u64(STATFS_BFREE_OFFSET)

    def f_bavail(self) -> UInt64:
        """How many blocks are free to a process that is not root."""
        return self._u64(STATFS_BAVAIL_OFFSET)

    def f_files(self) -> UInt64:
        """How many inodes the file system has."""
        return self._u64(STATFS_FILES_OFFSET)

    def f_ffree(self) -> UInt64:
        """How many inodes are free."""
        return self._u64(STATFS_FFREE_OFFSET)

    def f_fsid(self) -> UInt64:
        """The file system's identifier, both halves in one word."""
        # A word on both platforms: Linux packs the two `int` halves of
        # `fsid_t` here, and Darwin carries the id as a `uint64_t`.
        return self._u64(STATFS_FSID_OFFSET)

    def f_namelen(self) -> UInt64:
        """The longest file name this file system allows."""
        # Linux's own member: Darwin answers the same question with
        # `f_namemax` in `statvfs`, and this one is not in its struct.
        comptime if not CompilationTarget.is_macos():
            return self._u64(STATFS_NAMELEN_OFFSET)
        else:
            return 0

    def f_frsize(self) -> UInt64:
        """The fundamental block size, the unit the counts are in."""
        comptime if not CompilationTarget.is_macos():
            return self._u64(STATFS_FRSIZE_OFFSET)
        else:
            return self.f_bsize()

    def f_flags(self) -> UInt64:
        """The mount flags, `ST_RDONLY` and `ST_NOSUID` among them."""
        comptime if not CompilationTarget.is_macos():
            return self._u64(STATFS_FLAGS_OFFSET)
        else:
            return 0


def statfs(path: c_ptr[UInt8], buf: c_ptr[Statfs]) -> Int32:
    """Libc `statfs`, the kernel's own account of a file system.

    Args:
        path: Any file on the file system to describe.
        buf: Where to store the description.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/statfs.2.html).
        Fn signature: `int statfs(const char *path, struct statfs *buf)`.
    """
    return external_call["statfs", Int32, c_ptr[UInt8], c_ptr[Statfs]](
        path, buf
    )


def fstatfs(fd: Int32, buf: c_ptr[Statfs]) -> Int32:
    """Libc `fstatfs`, the same as `statfs` but for an open file.

    Args:
        fd: A descriptor on the file system to describe.
        buf: Where to store the description.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/fstatfs.2.html).
        Fn signature: `int fstatfs(int fd, struct statfs *buf)`.
    """
    return external_call["fstatfs", Int32, Int32, c_ptr[Statfs]](fd, buf)
