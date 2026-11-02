# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from std.sys import CompilationTarget
from libc.constant import c_int, c_ptr
from libc.time import timespec


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


# Where each member of C's `struct stat` sits on this platform. Both are
# 144 bytes and neither is the other's prefix: XNU packs `st_dev`,
# `st_mode` and `st_nlink` into the first eight bytes and puts the 64-bit
# `st_ino` after them, where glibc spends those bytes on `st_dev` alone
# and leads with `st_ino` next. The four `timespec` Darwin carries —
# access, modify, status change and birth — are what put `st_size` at 96
# there and 48 on glibc, and what swaps `st_blocks` past `st_blksize`.
#
# Numbers from XNU `bsd/sys/stat.h` and glibc's `bits/struct_stat.h`, and
# every one of them is compared with C's `offsetof` on both platforms by
# `scripts/check-layouts.py`: a member placed by hand is a member placed
# from memory unless something asks the compiler that laid it out.
comptime STAT_SLOTS: Int = 19
comptime STAT_DEV_OFFSET: Int = 0
comptime STAT_INO_OFFSET: Int = 8
comptime STAT_MODE_OFFSET: Int = 4 if CompilationTarget.is_macos() else 24
comptime STAT_NLINK_OFFSET: Int = 6 if CompilationTarget.is_macos() else 16
comptime STAT_UID_OFFSET: Int = 16 if CompilationTarget.is_macos() else 28
comptime STAT_GID_OFFSET: Int = 20 if CompilationTarget.is_macos() else 32
comptime STAT_RDEV_OFFSET: Int = 24 if CompilationTarget.is_macos() else 40
comptime STAT_ATIME_OFFSET: Int = 32 if CompilationTarget.is_macos() else 72
comptime STAT_MTIME_OFFSET: Int = 48 if CompilationTarget.is_macos() else 88
comptime STAT_CTIME_OFFSET: Int = 64 if CompilationTarget.is_macos() else 104
comptime STAT_SIZE_OFFSET: Int = 96 if CompilationTarget.is_macos() else 48
comptime STAT_BLOCKS_OFFSET: Int = 104 if CompilationTarget.is_macos() else 64
comptime STAT_BLKSIZE_OFFSET: Int = 112 if CompilationTarget.is_macos() else 56


struct Stat:
    """A C `struct stat`, which `stat`, `fstat` and friends fill in.

    Linux's is 144 bytes and Darwin's is 144 too, but the order differs:
    glibc leads with `st_dev`, `st_ino`, `st_nlink`, `st_mode`, while Darwin
    packs `st_dev`, `st_mode` and `st_nlink` into the first eight bytes and
    puts the 64-bit `st_ino` after them. So the bytes are held as slots and
    every member is read at the offset that fits the platform, the way
    `struct dirent` does it — the offsets are named above rather than in
    the methods, so that they can be read as a layout instead of assembled
    from slot numbers, and so that a script can check them.

    The width is the platform's too: `dev_t` and `blksize_t` are four bytes
    on Darwin and eight on glibc, `mode_t` and `nlink_t` two and eight, and
    a member read at the wrong width is as wrong as one read at the wrong
    place.

    Darwin's `struct stat` (the `_DARWIN_FEATURE_64_BIT_INODE` one that
    `stat` fills) carries **four** `timespec` — access, modify, status
    change, and birth — where Linux has three, and that fourth one is what
    pushes `st_size` down to offset 96 instead of 48.
    """

    var _slots: Array[Int64, STAT_SLOTS]

    def __init__(out self):
        """Zeroes all 152 bytes, which is what `memset` would leave behind.
        Darwin's `struct stat` is 144 bytes; the extra eight are margin
        the buffer holds without being read, so that a `stat` writing
        the C struct never runs past the end of it.
        """
        self._slots = Array[Int64, STAT_SLOTS](fill=0)

    def _u16(self, off: Int) -> Int:
        """The two bytes at a two-aligned `off`, little-endian.

        Little-endian is what both platforms are; this is a reading of the
        bytes C wrote, not a portable decode.
        """
        return Int((self._slots[off // 8] >> Int64((off % 8) * 8)) & 0xFFFF)

    def _u32(self, off: Int) -> Int64:
        """The four bytes at a four-aligned `off`, little-endian."""
        return (self._slots[off // 8] >> Int64((off % 8) * 8)) & 0xFFFFFFFF

    def _u64(self, off: Int) -> Int64:
        """The eight bytes at an eight-aligned `off`, which is all of a slot."""
        return self._slots[off // 8]

    def dev(self) -> Int64:
        """The ID of the device holding the file."""
        # `dev_t` is four bytes on Darwin, eight on glibc.
        comptime if CompilationTarget.is_macos():
            return self._u32(STAT_DEV_OFFSET)
        else:
            return self._u64(STAT_DEV_OFFSET)

    def ino(self) -> Int64:
        """The file serial number, its inode."""
        # A full eight bytes on both: Darwin's `ino_t` is 64-bit under
        # `_DARWIN_FEATURE_64_BIT_INODE`, unlike the 32-bit one in the
        # struct that came before it.
        return self._u64(STAT_INO_OFFSET)

    def nlink(self) -> Int64:
        """How many hard links point at the file."""
        # Sixteen bits on Darwin, in the same word as `st_dev` and
        # `st_mode`; `nlink_t` is a full word on glibc.
        comptime if CompilationTarget.is_macos():
            return Int64(self._u16(STAT_NLINK_OFFSET))
        else:
            return self._u64(STAT_NLINK_OFFSET)

    def mode(self) -> Int:
        """The file type and permission bits."""
        # Sixteen bits on Darwin, four bytes on glibc.
        comptime if CompilationTarget.is_macos():
            return self._u16(STAT_MODE_OFFSET)
        else:
            return Int(self._u32(STAT_MODE_OFFSET))

    def uid(self) -> Int:
        """The user ID of the owner."""
        return Int(self._u32(STAT_UID_OFFSET))

    def gid(self) -> Int:
        """The group ID of the owner."""
        return Int(self._u32(STAT_GID_OFFSET))

    def rdev(self) -> Int64:
        """The device ID, for files that are devices."""
        # Four bytes on Darwin, where the next four are padding before the
        # first `timespec`; eight on glibc.
        comptime if CompilationTarget.is_macos():
            return self._u32(STAT_RDEV_OFFSET)
        else:
            return self._u64(STAT_RDEV_OFFSET)

    def size(self) -> Int64:
        """The file size in bytes."""
        # Behind the `timespec` — four of them on Darwin, three on glibc,
        # which is the whole of the difference between the two offsets.
        return self._u64(STAT_SIZE_OFFSET)

    def blksize(self) -> Int64:
        """The preferred block size for I/O on this file."""
        # Four bytes on Darwin, where `st_flags` sits above it in the same
        # word; eight on glibc.
        comptime if CompilationTarget.is_macos():
            return self._u32(STAT_BLKSIZE_OFFSET)
        else:
            return self._u64(STAT_BLKSIZE_OFFSET)

    def blocks(self) -> Int64:
        """How many 512-byte blocks the file occupies."""
        return self._u64(STAT_BLOCKS_OFFSET)

    def atime(self) -> Int64:
        """The seconds of the last access time."""
        # The `tv_sec` of `st_atimespec` on Darwin, of `st_atim` on glibc;
        # `tv_nsec` is the four bytes after it and is not read here.
        return self._u64(STAT_ATIME_OFFSET)

    def mtime(self) -> Int64:
        """The seconds of the last modification time."""
        return self._u64(STAT_MTIME_OFFSET)

    def ctime(self) -> Int64:
        """The seconds of the last status change."""
        # `st_birthtimespec` follows this one on Darwin, at offset 80, and
        # is read by no method here.
        return self._u64(STAT_CTIME_OFFSET)


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


def utime(path: c_ptr[UInt8], times: c_ptr[utimbuf]) -> Int32:
    """Libc POSIX `utime` function.

    Args:
        path: A path to a file.
        times: A pointer to a `utimbuf` struct, that is to two times in
            seconds, the access time first. Not a `timeval`: that is what
            `utimes` takes, and the two are the same size, which is how a
            `timeval` came to be handed here and its microseconds read as
            the modified time.

    Returns: 0 on success, or -1 with `errno` set.
    """
    return external_call["utime", Int32, c_ptr[UInt8], c_ptr[utimbuf]](
        path, times
    )


struct timeval(TrivialRegisterPassable):
    """A C `struct timeval`: seconds plus microseconds.

    `tv_usec` is a 32-bit `suseconds_t` on Darwin and a 64-bit `long` on Linux,
    so it is stored in a full slot; zero the struct and it reads correctly on
    either platform.
    """

    var tv_sec: Int64
    var tv_usec: Int64


struct utimbuf(TrivialRegisterPassable):
    """A C `struct utimbuf`: the two times `utime` sets, both in seconds.

    It is not a `timeval`, though it is exactly as wide: `utime` takes
    this and `utimes` is the one that takes a `timeval`. Both are two
    8-byte fields, so handing one over where the other is meant is a
    call that compiles and that reads the second field as microseconds
    instead of as the modified time, which leaves `mtime` at whatever
    that came to.
    """

    var actime: Int64
    var modtime: Int64


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


def utimes(path: c_ptr[UInt8], times: c_ptr[timeval]) -> Int32:
    """Libc POSIX `utimes` function.

    Description:
        Sets the two times on a file: when it was last read and when
        it was last written.

    Args:
        path: The file to set them on.
        times: Two `timeval`s, the first for reading and the second
            for writing, or a null pointer for both to be now.

    Returns:
        0 where they were set, and -1 where they were not, with
        `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/utimes.3.html).
        Fn signature: `int utimes(const char *path,
            const struct timeval times[2])`.

        This is `utime` with microseconds on the end, which is what
        the `s` at the end of the name is for. Unlike `utime` it takes
        two of what it is given, and unlike `lutimes` it follows a
        link at the end of the path rather than setting the times on
        the link itself.

        `timeval` is bound in this module, and its `tv_usec` is kept
        in a full slot because the two platforms do not agree on how
        wide that is.
    """
    return external_call["utimes", Int32, c_ptr[UInt8], c_ptr[timeval]](
        path, times
    )


def lutimes(path: c_ptr[UInt8], times: c_ptr[timeval]) -> Int32:
    """Libc BSD `lutimes` function.

    Description:
        Sets the two times on a file, and on a link itself rather than
        on what it points at.

    Args:
        path: The file to set them on.
        times: Two `timeval`s, the first for reading and the second
            for writing, or a null pointer for both to be now.

    Returns:
        0 where they were set, and -1 where they were not, with
        `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/lutimes.3.html).
        Fn signature: `int lutimes(const char *path,
            const struct timeval times[2])`.

        This is `utimes` that does not follow a link, which is the one
        way it is not that, and is what makes it the one for a path
        whose last step may be one: `utimes` would set the times on
        what the link points at, and this sets them on the link.
    """
    return external_call["lutimes", Int32, c_ptr[UInt8], c_ptr[timeval]](
        path, times
    )


def futimes(fd: Int32, times: c_ptr[timeval]) -> Int32:
    """Libc BSD `futimes` function.

    Description:
        Sets the two times on a file already open, by its descriptor.

    Args:
        fd: The descriptor of the file to set them on.
        times: Two `timeval`s, the first for reading and the second
            for writing, or a null pointer for both to be now.

    Returns:
        0 where they were set, and -1 where they were not, with
        `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/futimes.3.html).
        Fn signature: `int futimes(int fd,
            const struct timeval times[2])`.

        This is `utimes` taking a descriptor rather than a path, which
        is what makes it the one where the file is already open: there
        is no name to be changed out from under it between the looking
        and the setting. `futimens` is the same thing in nanoseconds.
    """
    return external_call["futimes", Int32, Int32, c_ptr[timeval]](fd, times)


def fstatat(
    dirfd: Int32, pathname: c_ptr[UInt8], statbuf: c_ptr[Stat], flags: Int32
) -> Int32:
    """Libc POSIX `fstatat` function.

    Description:
        Asks after a file the way `stat` does, but takes the file
        relative to a directory that is open, rather than to this
        process's own working directory.

    Args:
        dirfd: The open directory the path is relative to, which is
            `AT_FDCWD` where it is relative to the working directory
            instead.
        pathname: The path to ask after.
        statbuf: The `Stat` to fill in, which is written to.
        flags: Which of the `AT_` names to ask by, or 0 for none.

    Returns:
        0 where the file was asked after, or -1 with `errno` saying
        why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/fstatat.2.html).
        Fn signature: `int fstatat(int dirfd,
            const char *restrict pathname, struct stat *restrict buf,
            int flags)`.

        With `AT_FDCWD` in `dirfd` this is `stat` itself, and the two
        answer with the same row for the same file. Where a directory
        is given instead, the path is read from that directory even
        where the working directory is somewhere else, which is what
        makes this the one to call in a process that walks trees:
        `open` a directory once and ask after everything in it without
        building a path to each.

        `fstat` is the same question about a descriptor rather than
        about a path, and `lstat` is the one that asks after a link
        rather than after what it points at.
    """
    return external_call[
        "fstatat", Int32, Int32, c_ptr[UInt8], c_ptr[Stat], Int32
    ](dirfd, pathname, statbuf, flags)
