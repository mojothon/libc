# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from libc.constant import c_ptr


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
