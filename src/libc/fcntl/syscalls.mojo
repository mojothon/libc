# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import c_ptr


# What `lockf` is asked for. The same numbers on both platforms.
comptime F_ULOCK: Int32 = 0
comptime F_LOCK: Int32 = 1
comptime F_TLOCK: Int32 = 2
comptime F_TEST: Int32 = 3

# Linux's own, and glibc only says so under _GNU_SOURCE: Darwin's <fcntl.h>
# has no O_TMPFILE.
comptime O_TMPFILE: Int32 = 4259840

# What `fcntl` is asked for when the flags are the thing being set, and the
# flag `open` and `fcntl` both take. `F_SETFL` is 4 on both platforms;
# `O_NONBLOCK` is 2048 here and 4 there, which is the one of the two that
# differs.
comptime F_SETFL: Int32 = 4
comptime O_NONBLOCK: Int32 = 4 if CompilationTarget.is_macos() else 2048


def creat(path: c_ptr[UInt8], mode: UInt32) -> Int32:
    """Libc POSIX `creat` function.

    Args:
        path: A path to a file.
        mode: A mode to open the file with.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/creat.3p.html).
        Fn signature: `int creat(const char *path, mode_t mode)`.
    """
    return external_call["creat", Int32, c_ptr[UInt8], UInt32](path, mode)


def fcntl(fildes: Int32, cmd: Int32) -> Int32:
    """Libc POSIX `fcntl` function.

    Args:
        fildes: A File Descriptor to close.
        cmd: A command to execute.

    Returns:
        Value 0 on success, -1 on error and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/close.3p.html).
        Fn signature: `int fcntl(int fildes, int cmd, ...)`.
    """
    return external_call["fcntl", Int32, Int32, Int32](fildes, cmd)


def fcntl(fildes: Int32, cmd: Int32, arg: Int32) -> Int32:
    """Libc POSIX `fcntl` function, with the argument some commands take.

    C's is variadic and `external_call` wants each type written out, so it
    is the int-argument form that is bound, which covers `F_SETFL`,
    `F_GETFL` and the commands that set a descriptor. A command that wants
    a pointer or a lock has nothing here to give it one.

    Args:
        fildes: A File Descriptor to close.
        cmd: A command to execute.
        arg: What the command works on, a flags word for `F_SETFL`, and
            ignored by the commands that take nothing.

    Returns:
        Value 0 on success, -1 on error and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fcntl.3p.html).
        Fn signature: `int fcntl(int fildes, int cmd, ...)`.
    """
    return external_call["fcntl", Int32, Int32, Int32, Int32](fildes, cmd, arg)


def open(path: c_ptr[UInt8], oflag: Int32) -> Int32:
    """Libc POSIX `open` function.

    Args:
        path: A path to a file.
        oflag: A flag to open the file with.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int open(const char *path, int oflag, ...)`.
    """
    return external_call["open", Int32, c_ptr[UInt8], Int32](path, oflag)


def open(path: c_ptr[UInt8], oflag: Int32, mode: Int32) -> Int32:
    """Libc POSIX `open`, with the mode that `O_CREAT` and `O_TMPFILE` need.

    Args:
        path: A path to a file.
        oflag: A flag to open the file with.
        mode: The permissions to create the file with, such as 0o644.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int open(const char *path, int oflag, ...)`.

        `open` is variadic, and C reads the mode only when a creating flag is
        set — but it still reads it, so the two-argument form above is unusable
        with `O_CREAT`: what C picks up as the mode is whatever happens to be
        in the argument register.

        arm64 Darwin passes variadic arguments on the stack rather than in
        registers, which an external call cannot express, so creating a file
        this way does not work there. Open a path that exists instead.
    """
    return external_call["open", Int32, c_ptr[UInt8], Int32, Int32](
        path, oflag, mode
    )


def openat(fd: Int32, path: c_ptr[UInt8], oflag: Int32) -> Int32:
    """Libc POSIX `open` function.

    Args:
        fd: A File Descriptor to open the file with.
        path: A path to a file.
        oflag: A flag to open the file with.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int openat(int fd, const char *path, int oflag, ...)`.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32](
        fd, path, oflag
    )


def openat(fd: Int32, path: c_ptr[UInt8], oflag: Int32, mode: Int32) -> Int32:
    """Libc POSIX `openat`, with the mode that `O_CREAT` needs.

    Args:
        fd: A File Descriptor to open the file with.
        path: A path to a file.
        oflag: A flag to open the file with.
        mode: The permissions to create the file with, such as 0o644.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int openat(int fd, const char *path, int oflag, ...)`.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        fd, path, oflag, mode
    )


def lockf(fd: Int32, cmd: Int32, len: Int64) -> Int32:
    """Libc POSIX `lockf` function.

    Reference:
        https://man7.org/linux/man-pages/man3/lockf.3.html

    Description:
        lockf() takes a lock on part of an open file, gives one up, or asks
        whether one is free.

    Args:
        fd: A descriptor for the file, which has to be open for writing to
            take a lock on it.
        cmd: `F_LOCK` to take one and wait, `F_TLOCK` to take one and fail
            instead of waiting, `F_ULOCK` to give it up, or `F_TEST` to ask
            whether it is free.
        len: How many bytes from the current position, which can be
            negative to reach backwards, or 0 for the rest of the file.

    Returns:
        0 on success, -1 on error with `errno` set. `F_TEST` answers 0 when
        the range is free and -1 when somebody has it.

    Notes:
        This is `fcntl` over the same locks, with `F_LOCK` meaning wait and
        `F_TLOCK` meaning do not. The lock belongs to the file and not to
        the descriptor, so closing any descriptor for the file lets go of
        every lock this process holds on it.
    """
    return external_call["lockf", Int32, Int32, Int32, Int64](fd, cmd, len)
