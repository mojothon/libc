# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import AT_FDCWD, c_ptr


# What `open` is given. The three access modes are the same everywhere and
# almost nothing else is: both number the flags from bit 0 and assign them
# differently, so O_CREAT is 64 here and 512 there, and O_APPEND is 1024 here
# and 8 there. The Linux values were read out of <fcntl.h> and the Darwin ones
# out of XNU's bsd/sys/fcntl.h. Three are Linux's own and have no number on
# Darwin at all.
comptime O_RDONLY: Int32 = 0
comptime O_WRONLY: Int32 = 1
comptime O_RDWR: Int32 = 2
comptime O_ACCMODE: Int32 = 3
comptime O_CREAT: Int32 = 512 if CompilationTarget.is_macos() else 64
comptime O_EXCL: Int32 = 2048 if CompilationTarget.is_macos() else 128
comptime O_NOCTTY: Int32 = 131072 if CompilationTarget.is_macos() else 256
comptime O_TRUNC: Int32 = 1024 if CompilationTarget.is_macos() else 512
comptime O_APPEND: Int32 = 8 if CompilationTarget.is_macos() else 1024
comptime O_NONBLOCK: Int32 = 4 if CompilationTarget.is_macos() else 2048
comptime O_DSYNC: Int32 = 4194304 if CompilationTarget.is_macos() else 4096
comptime O_DIRECTORY: Int32 = 1048576 if CompilationTarget.is_macos() else 65536
comptime O_NOFOLLOW: Int32 = 256 if CompilationTarget.is_macos() else 131072
comptime O_CLOEXEC: Int32 = 16777216 if CompilationTarget.is_macos() else 524288
comptime O_SYNC: Int32 = 128 if CompilationTarget.is_macos() else 1052672
# Linux's own: Darwin's <fcntl.h> has no number for these.
comptime O_DIRECT: Int32 = 16384
comptime O_NOATIME: Int32 = 262144
comptime O_PATH: Int32 = 2097152

# The `fcntl` commands. The first five are the same on both platforms, and the
# rest are not: Linux numbers the lock commands 5, 6 and 7 and the ownership
# ones 8 and 9, where Darwin does it the other way round.
comptime F_DUPFD: Int32 = 0
comptime F_GETFD: Int32 = 1
comptime F_SETFD: Int32 = 2
comptime F_GETFL: Int32 = 3
comptime F_SETFL: Int32 = 4
comptime F_GETLK: Int32 = 7 if CompilationTarget.is_macos() else 5
comptime F_SETLK: Int32 = 8 if CompilationTarget.is_macos() else 6
comptime F_SETLKW: Int32 = 9 if CompilationTarget.is_macos() else 7
comptime F_GETOWN: Int32 = 5 if CompilationTarget.is_macos() else 9
comptime F_SETOWN: Int32 = 6 if CompilationTarget.is_macos() else 8

# What a descriptor's own flags can be, and what a lock is asked to be. Both
# the same on the two platforms.
comptime FD_CLOEXEC: Int32 = 1
comptime F_RDLCK: Int32 = 1
comptime F_UNLCK: Int32 = 2
comptime F_WRLCK: Int32 = 3

# What `flock` is given, also the same on both.
comptime LOCK_SH: Int32 = 1
comptime LOCK_EX: Int32 = 2
comptime LOCK_NB: Int32 = 4
comptime LOCK_UN: Int32 = 8

# What `lockf` is asked for. The same numbers on both platforms.
comptime F_ULOCK: Int32 = 0
comptime F_LOCK: Int32 = 1
comptime F_TLOCK: Int32 = 2
comptime F_TEST: Int32 = 3

# Linux's own, and glibc only says so under _GNU_SOURCE: Darwin's <fcntl.h>
# has no O_TMPFILE.
comptime O_TMPFILE: Int32 = 4259840


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
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        AT_FDCWD, path, oflag, 0
    )


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

        C's `open` is variadic, and it reads the mode whether a creating flag
        is set or not, so the two-argument form is unusable with `O_CREAT`.
        Two things follow, and both are why these call `openat` instead: two
        `external_call`s under the one name do not agree on a signature, and
        arm64 Darwin passes variadic arguments on the stack, which an external
        call cannot express at all.

        `openat` takes the same arguments with the directory descriptor in
        front, so `open(path, oflag, mode)` is `openat(AT_FDCWD, path, oflag,
        mode)`. That is an improvement and not a cure, `openat` being
        variadic in the same way: on macOS the mode does not arrive, and a
        file asked for with 0o644 came out as 0o150, which is no umask of
        0o644 but a different number — whatever was on the stack where the
        argument should have been. Ask with `fchmod` afterwards when the
        permissions matter, which is what the test for this does.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        AT_FDCWD, path, oflag, mode
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
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        fd, path, oflag, 0
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

        Variadic, and so is `open`, and the mode is the argument after the
        named ones: on macOS it does not arrive, and the file comes out with
        whatever was on the stack instead. `fchmod` afterwards is the way to
        be sure of the permissions. `open` says more about this.
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
