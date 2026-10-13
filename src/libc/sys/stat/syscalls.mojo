# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from std.sys import CompilationTarget
from libc.constant import c_int, c_ptr


def chmod(path: c_ptr[UInt8], mode: Int32) -> Int32:
    """Libc POSIX `chmod` function.

    Args:
        path: A path to a file.
        mode: A mode to open the file with.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call[
        "chmod", Int32, c_ptr[UInt8], Int32  # FnName, RetType  # Args
    ](
        path, mode
    )  # Args


def fchmod(fd: Int32, mode: Int32) -> Int32:
    """Libc POSIX `fchmod` function.

    Args:
        fd: A file descriptor.
        mode: A mode to open the file with.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["fchmod", Int32, Int32, Int32](fd, mode)


def fchmodat(fd: Int32, path: c_ptr[UInt8], mode: Int32, flags: Int32) -> Int32:
    """Libc POSIX `fchmodat` function.

    Args:
        fd: A directory descriptor the path is relative to, or `AT_FDCWD`.
        path: A path to a file.
        mode: The permission bits to set.
        flags: 0, or `AT_SYMLINK_NOFOLLOW` to act on the link itself.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["fchmodat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        fd, path, mode, flags
    )


def fstat(fd: Int32, stat: c_ptr[Stat]) -> Int32:
    """Libc POSIX `fstat` function.

    Args:
        fd: A file descriptor.
        stat: A pointer to a `stat` struct.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["fstat", Int32, Int32, c_ptr[Stat]](fd, stat)


def lstat(path: c_ptr[UInt8], stat: c_ptr[Stat]) -> Int32:
    """Libc POSIX `lstat` function.

    Args:
        path: A path to a file.
        stat: A pointer to a `stat` struct.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["lstat", Int32, c_ptr[UInt8], c_ptr[Stat]](path, stat)


def mkdir(path: c_ptr[UInt8], mode: Int32) -> Int32:
    """Libc POSIX `mkdir` function.

    Args:
        path: A path to a directory.
        mode: A mode to create the directory with.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["mkdir", Int32, c_ptr[UInt8], Int32](path, mode)


def mkdirat(fd: Int32, path: c_ptr[UInt8], mode: Int32) -> Int32:
    """Libc POSIX `mkdirat` function.

    Args:
        fd: A file descriptor.
        path: A path to a directory.
        mode: A mode to create the directory with.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["mkdirat", Int32, Int32, c_ptr[UInt8], Int32](
        fd, path, mode
    )


def mknod(path: c_ptr[UInt8], mode: Int32, dev: UInt64) -> Int32:
    """Libc POSIX `mknod` function.

    Args:
        path: A path to a file.
        mode: A mode to create the file with.
        dev: A device number.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["mknod", Int32, c_ptr[UInt8], Int32, UInt64](
        path, mode, dev
    )


def mknodat(fd: Int32, path: c_ptr[UInt8], mode: Int32, dev: UInt64) -> Int32:
    """Libc POSIX `mknodat` function.

    Args:
        fd: A file descriptor.
        path: A path to a file.
        mode: A mode to create the file with.
        dev: A device number.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["mknodat", Int32, Int32, c_ptr[UInt8], Int32, UInt64](
        fd, path, mode, dev
    )


struct Stat:
    """A C `struct stat`, which `stat`, `fstat` and friends fill in.

    Linux's is 144 bytes and Darwin's 128, and the order differs: glibc leads
    with `st_dev`, `st_ino`, `st_nlink`, Darwin packs `st_dev`, `st_mode`,
    `st_nlink` into the first eight bytes and puts `st_ino` after them. So the
    bytes are held as slots and every member is read at the offset that fits
    the platform, the way `struct dirent` does it.
    """

    var _slots: Array[Int64, 18]

    def __init__(out self):
        """Zeroes all 144 bytes, which is what `memset` would leave behind."""
        self._slots = Array[Int64, 18](fill=0)

    def dev(self) -> Int64:
        """The ID of the device holding the file."""
        comptime if CompilationTarget.is_macos():
            return (self._slots[0] << 32) >> 32
        else:
            return self._slots[0]

    def ino(self) -> Int64:
        """The file serial number, its inode."""
        return self._slots[1]

    def nlink(self) -> Int64:
        """How many hard links point at the file."""
        comptime if CompilationTarget.is_macos():
            return (self._slots[0] >> 48) & 0xFFFF
        else:
            return self._slots[2]

    def mode(self) -> Int:
        """The file type and permission bits."""
        comptime if CompilationTarget.is_macos():
            return Int((self._slots[0] >> 32) & 0xFFFF)
        else:
            return Int(self._slots[3] & 0xFFFFFFFF)

    def uid(self) -> Int:
        """The user ID of the owner."""
        comptime if CompilationTarget.is_macos():
            return Int(self._slots[2] & 0xFFFFFFFF)
        else:
            return Int(self._slots[3] >> 32)

    def gid(self) -> Int:
        """The group ID of the owner."""
        comptime if CompilationTarget.is_macos():
            return Int(self._slots[2] >> 32)
        else:
            return Int(self._slots[4] & 0xFFFFFFFF)

    def rdev(self) -> Int64:
        """The device ID, for files that are devices."""
        comptime if CompilationTarget.is_macos():
            return (self._slots[3] << 32) >> 32
        else:
            return self._slots[5]

    def size(self) -> Int64:
        """The file size in bytes."""
        comptime if CompilationTarget.is_macos():
            return self._slots[10]
        else:
            return self._slots[6]

    def blksize(self) -> Int64:
        """The preferred block size for I/O on this file."""
        comptime if CompilationTarget.is_macos():
            # A 32-bit `blksize_t`, with `st_flags` in the half above it.
            return Int64(self._slots[12] & 0xFFFFFFFF)
        else:
            return self._slots[7]

    def blocks(self) -> Int64:
        """How many 512-byte blocks the file occupies."""
        comptime if CompilationTarget.is_macos():
            return self._slots[11]
        else:
            return self._slots[8]

    def atime(self) -> Int64:
        """The seconds of the last access time."""
        comptime if CompilationTarget.is_macos():
            return self._slots[4]
        else:
            return self._slots[9]

    def mtime(self) -> Int64:
        """The seconds of the last modification time."""
        comptime if CompilationTarget.is_macos():
            return self._slots[6]
        else:
            return self._slots[11]

    def ctime(self) -> Int64:
        """The seconds of the last status change."""
        comptime if CompilationTarget.is_macos():
            return self._slots[8]
        else:
            return self._slots[13]


def stat(pathname: c_ptr[UInt8], statbuf: c_ptr[Stat]) -> Int32:
    """Libc POSIX `stat` function.

    Args:
        pathname: A pathname to a file.
        statbuf: A pointer to a `stat` struct.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["stat", Int32, c_ptr[UInt8], c_ptr[Stat]](
        pathname, statbuf
    )


def umask(mask: Int32) -> Int32:
    """Libc POSIX `umask` function.

    Args:
        mask: A mask to apply to file creation modes.

    Returns: The previous umask.
    """
    return external_call["umask", Int32, Int32](mask)


def utime(path: c_ptr[UInt8], times: c_ptr[timeval]) -> Int32:
    """Libc POSIX `utime` function.

    Args:
        path: A path to a file.
        times: A pointer to a `timeval` struct.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["utime", Int32, c_ptr[UInt8], c_ptr[timeval]](
        path, times
    )


struct timespec(TrivialRegisterPassable):
    var tv_sec: Int64
    var tv_nsec: Int64


struct timeval(TrivialRegisterPassable):
    """A C `struct timeval`: seconds plus microseconds.

    `tv_usec` is a 32-bit `suseconds_t` on Darwin and a 64-bit `long` on Linux,
    so it is stored in a full slot; zero the struct and it reads correctly on
    either platform.
    """

    var tv_sec: Int64
    var tv_usec: Int64


def utimensat(
    fd: Int32, path: c_ptr[UInt8], times: c_ptr[timespec], flag: Int32
) -> Int32:
    """Libc POSIX `utimensat` function.

    Args:
        fd: A file descriptor.
        path: A path to a file.
        times: A pointer to a `timespec` struct.
        flag: A flag to modify the behavior of the function.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call[
        "utimensat", Int32, Int32, c_ptr[UInt8], c_ptr[timespec], Int32
    ](fd, path, times, flag)


def futimens(fd: Int32, times: c_ptr[timespec]) -> Int32:
    """Libc POSIX `futimens` function.

    Args:
        fd: A file descriptor.
        times: A pointer to a `timespec` struct.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["futimens", Int32, Int32, c_ptr[timespec]](fd, times)


def mkfifo(path: c_ptr[UInt8], mode: c_int) -> c_int:
    """Libc POSIX `mkfifo` function.

    Args:
        path: Where to make it.
        mode: The permissions to give it, such as 0o644, before `umask`.

    Returns:
        0 on success. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mkfifo.3.html).
        Fn signature: `int mkfifo(const char *path, mode_t mode)`.

        The mode is the one argument `open` cannot be trusted with on macOS
        — see `open` for why — but `mkfifo` is not variadic and takes it
        like any other argument, so it arrives on both platforms.
    """
    return external_call["mkfifo", c_int, c_ptr[UInt8], c_int](path, mode)
