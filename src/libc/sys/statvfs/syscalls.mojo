# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr


struct Statvfs:
    """A C `struct statvfs`: what the file system says about itself.

    The eleven members sit at the same offsets on Linux and Darwin. The sizes
    do not match — Linux's is 112 bytes because it ends in six spare ints,
    Darwin's stops at 88 — so this declares the members and pads to the
    larger, which means libc cannot overrun it on either platform.
    """

    var f_bsize: UInt64
    """The preferred block size for I/O on this file system."""
    var f_frsize: UInt64
    """The fundamental block size, the unit the counts below are in."""
    var f_blocks: UInt64
    """How many blocks the file system has, in `f_frsize` units."""
    var f_bfree: UInt64
    """How many blocks are free."""
    var f_bavail: UInt64
    """How many blocks are free to a process that is not root."""
    var f_files: UInt64
    """How many inodes the file system has."""
    var f_ffree: UInt64
    """How many inodes are free."""
    var f_favail: UInt64
    """How many inodes are free to a process that is not root."""
    var f_fsid: UInt64
    """An identifier for the file system."""
    var f_flag: UInt64
    """The mount flags, `ST_RDONLY` and `ST_NOSUID` among them."""
    var f_namemax: UInt64
    """The longest file name the file system allows."""
    var _spare: Array[UInt8, 24]
    """The room glibc's six spare ints need; Darwin leaves it alone."""

    def __init__(out self):
        """Zeroes every member and the spare room."""
        self.f_bsize = 0
        self.f_frsize = 0
        self.f_blocks = 0
        self.f_bfree = 0
        self.f_bavail = 0
        self.f_files = 0
        self.f_ffree = 0
        self.f_favail = 0
        self.f_fsid = 0
        self.f_flag = 0
        self.f_namemax = 0
        self._spare = Array[UInt8, 24](fill=0)


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
