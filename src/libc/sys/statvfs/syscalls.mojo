# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


# Where each member of C's `struct statvfs` sits. The order is the same on
# both platforms and the widths are not, which is unusual enough to be worth
# saying twice: glibc's block and inode counts are `unsigned long` and its
# struct is 112 bytes, XNU's are `unsigned int` — see `fsblkcnt_t` in
# `sys/_types.h` — so four of its members fit where glibc spends one, and
# its struct is 64 bytes. `f_fsid` is where the difference lands: at 64 on
# glibc, at 40 on Darwin, four bytes after `f_favail` rather than two, since
# it needs an eight-byte boundary of its own.
#
# Numbers from `bits/statvfs.h` and XNU `sys/statvfs.h`, and every one of
# them is compared with C's `offsetof` on both platforms by
# `scripts/check-layouts.py`.
comptime STATVFS_SLOTS: Int = 14
comptime STATVFS_BSIZE_OFFSET: Int = 0
comptime STATVFS_FRSIZE_OFFSET: Int = 8
comptime STATVFS_BLOCKS_OFFSET: Int = 16
comptime STATVFS_BFREE_OFFSET: Int = 20 if CompilationTarget.is_macos() else 24
comptime STATVFS_BAVAIL_OFFSET: Int = 24 if CompilationTarget.is_macos() else 32
comptime STATVFS_FILES_OFFSET: Int = 28 if CompilationTarget.is_macos() else 40
comptime STATVFS_FFREE_OFFSET: Int = 32 if CompilationTarget.is_macos() else 48
comptime STATVFS_FAVAIL_OFFSET: Int = 36 if CompilationTarget.is_macos() else 56
comptime STATVFS_FSID_OFFSET: Int = 40 if CompilationTarget.is_macos() else 64
comptime STATVFS_FLAG_OFFSET: Int = 48 if CompilationTarget.is_macos() else 72
comptime STATVFS_NAMEMAX_OFFSET: Int = 56 if CompilationTarget.is_macos() else 80


struct Statvfs:
    """A C `struct statvfs`: what a file system says about itself.

    The members come in the same order on both platforms, but not in the same
    width: Linux's block and inode counts are 64-bit and its struct is 112
    bytes, while Darwin's are 32-bit and its struct is 64 bytes. So the bytes
    are held in slots and each member is read at the offset and width that fit
    the platform, the way `struct stat` does it.

    The offsets are named above rather than in the methods, so that the
    layout can be read as a layout — and so that a script can ask C the same
    question, which is the only way to know that the four members packed into
    two words on one platform and the four words they become on the other
    were packed the right way round.
    """

    var _slots: Array[UInt64, STATVFS_SLOTS]

    def __init__(out self):
        """Zeroes every member, which is what `memset` would leave behind."""
        self._slots = Array[UInt64, STATVFS_SLOTS](fill=0)

    def _u32(self, off: Int) -> UInt64:
        """The four bytes at a four-aligned `off`, little-endian."""
        return (self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFFFFFFFF

    def _u64(self, off: Int) -> UInt64:
        """The eight bytes at an eight-aligned `off`, which is all of a slot."""
        return self._slots[off // 8]

    def f_bsize(self) -> UInt64:
        """The preferred block size for I/O on this file system."""
        # A word on both platforms.
        return self._u64(STATVFS_BSIZE_OFFSET)

    def f_frsize(self) -> UInt64:
        """The fundamental block size, the unit the counts below are in."""
        return self._u64(STATVFS_FRSIZE_OFFSET)

    def f_blocks(self) -> UInt64:
        """How many blocks the file system has, in `f_frsize` units."""
        # Four bytes on Darwin, eight on glibc, as are the three below it.
        comptime if CompilationTarget.is_macos():
            return self._u32(STATVFS_BLOCKS_OFFSET)
        else:
            return self._u64(STATVFS_BLOCKS_OFFSET)

    def f_bfree(self) -> UInt64:
        """How many blocks are free."""
        comptime if CompilationTarget.is_macos():
            return self._u32(STATVFS_BFREE_OFFSET)
        else:
            return self._u64(STATVFS_BFREE_OFFSET)

    def f_bavail(self) -> UInt64:
        """How many blocks are free to a process that is not root."""
        comptime if CompilationTarget.is_macos():
            return self._u32(STATVFS_BAVAIL_OFFSET)
        else:
            return self._u64(STATVFS_BAVAIL_OFFSET)

    def f_files(self) -> UInt64:
        """How many inodes the file system has."""
        comptime if CompilationTarget.is_macos():
            return self._u32(STATVFS_FILES_OFFSET)
        else:
            return self._u64(STATVFS_FILES_OFFSET)

    def f_ffree(self) -> UInt64:
        """How many inodes are free."""
        comptime if CompilationTarget.is_macos():
            return self._u32(STATVFS_FFREE_OFFSET)
        else:
            return self._u64(STATVFS_FFREE_OFFSET)

    def f_favail(self) -> UInt64:
        """How many inodes are free to a process that is not root."""
        comptime if CompilationTarget.is_macos():
            return self._u32(STATVFS_FAVAIL_OFFSET)
        else:
            return self._u64(STATVFS_FAVAIL_OFFSET)

    def f_fsid(self) -> UInt64:
        """An identifier for the file system."""
        # A word on both. It follows `f_favail` directly on glibc, at 64;
        # on Darwin that member ends at 36 and this one needs an eight-byte
        # boundary, so four bytes of padding sit between them.
        return self._u64(STATVFS_FSID_OFFSET)

    def f_flag(self) -> UInt64:
        """The mount flags, `ST_RDONLY` and `ST_NOSUID` among them."""
        return self._u64(STATVFS_FLAG_OFFSET)

    def f_namemax(self) -> UInt64:
        """The longest file name the file system allows."""
        return self._u64(STATVFS_NAMEMAX_OFFSET)


def statvfs(path: c_ptr[UInt8], buf: c_ptr[Statvfs]) -> Int32:
    """Libc POSIX `statvfs`.

    Args:
        path: Any file on the file system to describe.
        buf: Where to store the description.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/statvfs.3.html).
        Fn signature: `int statvfs(const char *path, struct statvfs *buf)`.
    """
    return external_call["statvfs", Int32, c_ptr[UInt8], c_ptr[Statvfs]](
        path, buf
    )


def fstatvfs(fd: Int32, buf: c_ptr[Statvfs]) -> Int32:
    """Libc POSIX `fstatvfs`, the same as `statvfs` but for an open file.

    Args:
        fd: A descriptor on the file system to describe.
        buf: Where to store the description.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/statvfs.3.html).
        Fn signature: `int fstatvfs(int fd, struct statvfs *buf)`.
    """
    return external_call["fstatvfs", Int32, Int32, c_ptr[Statvfs]](fd, buf)
