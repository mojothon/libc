# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


struct Statvfs:
    """A C `struct statvfs`: what a file system says about itself.

    The members come in the same order on both platforms, but not in the same
    width: Linux's block and inode counts are 64-bit and its struct is 112
    bytes, while Darwin's are 32-bit and its struct is 64 bytes. So the bytes
    are held in slots and each member is read at the offset and width that fit
    the platform, the way `struct stat` does it.
    """

    var _slots: Array[UInt64, 14]

    def __init__(out self):
        """Zeroes every member, which is what `memset` would leave behind."""
        self._slots = Array[UInt64, 14](fill=0)

    def f_bsize(self) -> UInt64:
        """The preferred block size for I/O on this file system."""
        return self._slots[0]

    def f_frsize(self) -> UInt64:
        """The fundamental block size, the unit the counts below are in."""
        return self._slots[1]

    def f_blocks(self) -> UInt64:
        """How many blocks the file system has, in `f_frsize` units."""
        comptime if CompilationTarget.is_macos():
            return self._slots[2] & 0xFFFFFFFF
        else:
            return self._slots[2]

    def f_bfree(self) -> UInt64:
        """How many blocks are free."""
        comptime if CompilationTarget.is_macos():
            return self._slots[2] >> 32
        else:
            return self._slots[3]

    def f_bavail(self) -> UInt64:
        """How many blocks are free to a process that is not root."""
        comptime if CompilationTarget.is_macos():
            return self._slots[3] & 0xFFFFFFFF
        else:
            return self._slots[4]

    def f_files(self) -> UInt64:
        """How many inodes the file system has."""
        comptime if CompilationTarget.is_macos():
            return self._slots[3] >> 32
        else:
            return self._slots[5]

    def f_ffree(self) -> UInt64:
        """How many inodes are free."""
        comptime if CompilationTarget.is_macos():
            return self._slots[4] & 0xFFFFFFFF
        else:
            return self._slots[6]

    def f_favail(self) -> UInt64:
        """How many inodes are free to a process that is not root."""
        comptime if CompilationTarget.is_macos():
            return self._slots[4] >> 32
        else:
            return self._slots[7]

    def f_fsid(self) -> UInt64:
        """An identifier for the file system."""
        comptime if CompilationTarget.is_macos():
            return self._slots[5]
        else:
            return self._slots[8]

    def f_flag(self) -> UInt64:
        """The mount flags, `ST_RDONLY` and `ST_NOSUID` among them."""
        comptime if CompilationTarget.is_macos():
            return self._slots[6]
        else:
            return self._slots[9]

    def f_namemax(self) -> UInt64:
        """The longest file name the file system allows."""
        comptime if CompilationTarget.is_macos():
            return self._slots[7]
        else:
            return self._slots[10]


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
