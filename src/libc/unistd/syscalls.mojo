# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_int, c_long, c_ptr, c_size_t


# The number `syscall` takes for `getpid`. Linux numbers it 39 and
# Darwin 20.
comptime SYS_getpid: Int64 = 20 if CompilationTarget.is_macos() else 39


# Which knob `sysconf` is asked about. Every one of the eighty both
# platforms have is numbered differently on each: glibc counts them from
# 0 in the order POSIX lists them, XNU from 1 in an order of its own, so
# `_SC_ARG_MAX` is 0 here and 1 there, `_SC_PAGESIZE` 30 and 29, and
# `_SC_NPROCESSORS_ONLN` 84 and 58. Nothing agrees, which is why a
# caller asking `sysconf` about anything has to be given the name.
#
# C spells these with a leading underscore, which makes a name private to
# a Mojo module, so it is `SC_ARG_MAX` here.
#
# `_SC_AVPHYS_PAGES` is left out: glibc has it and XNU does not, and a
# knob that only one side answers is a knob this package would be
# claiming to bind.
comptime SC_2_CHAR_TERM: Int32 = 20 if CompilationTarget.is_macos() else 95
comptime SC_2_C_BIND: Int32 = 18 if CompilationTarget.is_macos() else 47
comptime SC_2_C_DEV: Int32 = 19 if CompilationTarget.is_macos() else 48
comptime SC_2_FORT_DEV: Int32 = 21 if CompilationTarget.is_macos() else 49
comptime SC_2_FORT_RUN: Int32 = 22 if CompilationTarget.is_macos() else 50
comptime SC_2_LOCALEDEF: Int32 = 23 if CompilationTarget.is_macos() else 52
comptime SC_2_SW_DEV: Int32 = 24 if CompilationTarget.is_macos() else 51
comptime SC_2_UPE: Int32 = 25 if CompilationTarget.is_macos() else 97
comptime SC_2_VERSION: Int32 = 17 if CompilationTarget.is_macos() else 46
comptime SC_AIO_LISTIO_MAX: Int32 = 42 if CompilationTarget.is_macos() else 23
comptime SC_AIO_MAX: Int32 = 43 if CompilationTarget.is_macos() else 24
comptime SC_AIO_PRIO_DELTA_MAX: Int32 = 44 if CompilationTarget.is_macos() else 25
comptime SC_ARG_MAX: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime SC_ASYNCHRONOUS_IO: Int32 = 28 if CompilationTarget.is_macos() else 12
comptime SC_ATEXIT_MAX: Int32 = 107 if CompilationTarget.is_macos() else 87
comptime SC_BC_BASE_MAX: Int32 = 9 if CompilationTarget.is_macos() else 36
comptime SC_BC_DIM_MAX: Int32 = 10 if CompilationTarget.is_macos() else 37
comptime SC_BC_SCALE_MAX: Int32 = 11 if CompilationTarget.is_macos() else 38
comptime SC_BC_STRING_MAX: Int32 = 12 if CompilationTarget.is_macos() else 39
comptime SC_CHILD_MAX: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime SC_CLK_TCK: Int32 = 3 if CompilationTarget.is_macos() else 2
comptime SC_COLL_WEIGHTS_MAX: Int32 = 13 if CompilationTarget.is_macos() else 40
comptime SC_DELAYTIMER_MAX: Int32 = 45 if CompilationTarget.is_macos() else 26
comptime SC_EXPR_NEST_MAX: Int32 = 14 if CompilationTarget.is_macos() else 42
comptime SC_FSYNC: Int32 = 38 if CompilationTarget.is_macos() else 15
comptime SC_GETGR_R_SIZE_MAX: Int32 = 70 if CompilationTarget.is_macos() else 69
comptime SC_GETPW_R_SIZE_MAX: Int32 = 71 if CompilationTarget.is_macos() else 70
comptime SC_HOST_NAME_MAX: Int32 = 72 if CompilationTarget.is_macos() else 180
comptime SC_IOV_MAX: Int32 = 56 if CompilationTarget.is_macos() else 60
comptime SC_JOB_CONTROL: Int32 = 6 if CompilationTarget.is_macos() else 7
comptime SC_LINE_MAX: Int32 = 15 if CompilationTarget.is_macos() else 43
comptime SC_LOGIN_NAME_MAX: Int32 = 73 if CompilationTarget.is_macos() else 71
comptime SC_MAPPED_FILES: Int32 = 47 if CompilationTarget.is_macos() else 16
comptime SC_MEMLOCK: Int32 = 30 if CompilationTarget.is_macos() else 17
comptime SC_MEMLOCK_RANGE: Int32 = 31 if CompilationTarget.is_macos() else 18
comptime SC_MEMORY_PROTECTION: Int32 = 32 if CompilationTarget.is_macos() else 19
comptime SC_MESSAGE_PASSING: Int32 = 33 if CompilationTarget.is_macos() else 20
comptime SC_MQ_OPEN_MAX: Int32 = 46 if CompilationTarget.is_macos() else 27
comptime SC_MQ_PRIO_MAX: Int32 = 75 if CompilationTarget.is_macos() else 28
comptime SC_NGROUPS_MAX: Int32 = 4 if CompilationTarget.is_macos() else 3
comptime SC_NPROCESSORS_CONF: Int32 = 57 if CompilationTarget.is_macos() else 83
comptime SC_NPROCESSORS_ONLN: Int32 = 58 if CompilationTarget.is_macos() else 84
comptime SC_OPEN_MAX: Int32 = 5 if CompilationTarget.is_macos() else 4
comptime SC_PAGESIZE: Int32 = 29 if CompilationTarget.is_macos() else 30
comptime SC_PHYS_PAGES: Int32 = 200 if CompilationTarget.is_macos() else 85
comptime SC_PRIORITIZED_IO: Int32 = 34 if CompilationTarget.is_macos() else 13
comptime SC_PRIORITY_SCHEDULING: Int32 = 35 if CompilationTarget.is_macos() else 10
comptime SC_REALTIME_SIGNALS: Int32 = 36 if CompilationTarget.is_macos() else 9
comptime SC_RE_DUP_MAX: Int32 = 16 if CompilationTarget.is_macos() else 44
comptime SC_RTSIG_MAX: Int32 = 48 if CompilationTarget.is_macos() else 31
comptime SC_SAVED_IDS: Int32 = 7 if CompilationTarget.is_macos() else 8
comptime SC_SEMAPHORES: Int32 = 37 if CompilationTarget.is_macos() else 21
comptime SC_SEM_NSEMS_MAX: Int32 = 49 if CompilationTarget.is_macos() else 32
comptime SC_SEM_VALUE_MAX: Int32 = 50 if CompilationTarget.is_macos() else 33
comptime SC_SHARED_MEMORY_OBJECTS: Int32 = 39 if CompilationTarget.is_macos() else 22
comptime SC_SIGQUEUE_MAX: Int32 = 51 if CompilationTarget.is_macos() else 34
comptime SC_STREAM_MAX: Int32 = 26 if CompilationTarget.is_macos() else 5
comptime SC_SYMLOOP_MAX: Int32 = 120 if CompilationTarget.is_macos() else 173
comptime SC_SYNCHRONIZED_IO: Int32 = 40 if CompilationTarget.is_macos() else 14
comptime SC_THREAD_ATTR_STACKADDR: Int32 = 82 if CompilationTarget.is_macos() else 77
comptime SC_THREAD_ATTR_STACKSIZE: Int32 = 83 if CompilationTarget.is_macos() else 78
comptime SC_THREAD_DESTRUCTOR_ITERATIONS: Int32 = 85 if CompilationTarget.is_macos() else 73
comptime SC_THREAD_KEYS_MAX: Int32 = 86 if CompilationTarget.is_macos() else 74
comptime SC_THREAD_PRIORITY_SCHEDULING: Int32 = 89 if CompilationTarget.is_macos() else 79
comptime SC_THREAD_PRIO_INHERIT: Int32 = 87 if CompilationTarget.is_macos() else 80
comptime SC_THREAD_PRIO_PROTECT: Int32 = 88 if CompilationTarget.is_macos() else 81
comptime SC_THREAD_PROCESS_SHARED: Int32 = 90 if CompilationTarget.is_macos() else 82
comptime SC_THREAD_SAFE_FUNCTIONS: Int32 = 91 if CompilationTarget.is_macos() else 68
comptime SC_THREAD_STACK_MIN: Int32 = 93 if CompilationTarget.is_macos() else 75
comptime SC_THREAD_THREADS_MAX: Int32 = 94 if CompilationTarget.is_macos() else 76
comptime SC_TIMERS: Int32 = 41 if CompilationTarget.is_macos() else 11
comptime SC_TIMER_MAX: Int32 = 52 if CompilationTarget.is_macos() else 35
comptime SC_TTY_NAME_MAX: Int32 = 101 if CompilationTarget.is_macos() else 72
comptime SC_TZNAME_MAX: Int32 = 27 if CompilationTarget.is_macos() else 6
comptime SC_VERSION: Int32 = 8 if CompilationTarget.is_macos() else 29
comptime SC_XOPEN_CRYPT: Int32 = 108 if CompilationTarget.is_macos() else 92
comptime SC_XOPEN_ENH_I18N: Int32 = 109 if CompilationTarget.is_macos() else 93
comptime SC_XOPEN_SHM: Int32 = 113 if CompilationTarget.is_macos() else 94
comptime SC_XOPEN_VERSION: Int32 = 116 if CompilationTarget.is_macos() else 89
comptime SC_XOPEN_XCU_VERSION: Int32 = 121 if CompilationTarget.is_macos() else 90


# Which knob `pathconf` and `fpathconf` are asked about. The numbers are
# not the same on the two sides: glibc starts the list at 0 and XNU at 1,
# so the first nine are shifted one along and the rest are scattered. C
# spells these with a leading underscore, which makes a name private to a
# Mojo module, so it is `PC_LINK_MAX` here.
#
# `_PC_LINK_MAX` and `_PC_MAX_CANON` through `_PC_VDISABLE` are the POSIX
# ones and exist on both; `_PC_SYNC_IO` onwards are the optional ones,
# and are here because a caller asking `pathconf` about anything has to
# name it somehow.
comptime PC_LINK_MAX: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime PC_MAX_CANON: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime PC_MAX_INPUT: Int32 = 3 if CompilationTarget.is_macos() else 2
comptime PC_NAME_MAX: Int32 = 4 if CompilationTarget.is_macos() else 3
comptime PC_PATH_MAX: Int32 = 5 if CompilationTarget.is_macos() else 4
comptime PC_PIPE_BUF: Int32 = 6 if CompilationTarget.is_macos() else 5
comptime PC_CHOWN_RESTRICTED: Int32 = 7 if CompilationTarget.is_macos() else 6
comptime PC_NO_TRUNC: Int32 = 8 if CompilationTarget.is_macos() else 7
comptime PC_VDISABLE: Int32 = 9 if CompilationTarget.is_macos() else 8
comptime PC_SYNC_IO: Int32 = 25 if CompilationTarget.is_macos() else 9
comptime PC_ASYNC_IO: Int32 = 17 if CompilationTarget.is_macos() else 10
comptime PC_PRIO_IO: Int32 = 19 if CompilationTarget.is_macos() else 11
comptime PC_FILESIZEBITS: Int32 = 18 if CompilationTarget.is_macos() else 13
comptime PC_SYMLINK_MAX: Int32 = 24 if CompilationTarget.is_macos() else 19


def access(path: c_ptr[UInt8], mode: Int32) -> Int32:
    """Libc POSIX `access` function.

    Reference:
        https://man7.org/linux/man-pages/man2/access.2.html

    Description:
        access() checks whether the calling process can access the file specified by path.

    Args:
        path: Path to the file.
        mode: Mode to check access.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["access", Int32, c_ptr[UInt8], Int32](path, mode)


def chdir(path: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `chdir` function.

    Reference:
        https://man7.org/linux/man-pages/man2/chdir.2.html

    Description:
        chdir() changes the current working directory of the calling process to the directory
        referenced by path.

    Args:
        path: Path to the directory.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["chdir", Int32, c_ptr[UInt8]](path)


def close(fd: Int32) -> Int32:
    """Libc POSIX `close` function.

    Reference:
        https://man7.org/linux/man-pages/man2/close.2.html

    Description:
        close() closes a file descriptor.

    Args:
        fd: File descriptor to close.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["close", Int32, Int32](fd)


def dup(oldfd: Int32) -> Int32:
    """Libc POSIX `dup` function.

    Reference:
        https://man7.org/linux/man-pages/man2/dup.2.html

    Description:
        dup() duplicates a file descriptor.

    Args:
        oldfd: File descriptor to duplicate.

    Returns:
        The new descriptor, or -1 on failure with `errno` set. Success is a
        number here and not a yes, and zero is one of the numbers: it is
        stdin's, and it is what this hands back when stdin was closed
        before `oldfd` was made. Only -1 went wrong.
    """
    return external_call["dup", Int32, Int32](oldfd)


def dup2(oldfd: Int32, newfd: Int32) -> Int32:
    """Libc POSIX `dup2` function.

    Reference:
        https://man7.org/linux/man-pages/man2/dup2.2.html

    Description:
        dup2() duplicates a file descriptor, closing the original file descriptor.

    Args:
        oldfd: File descriptor to duplicate.
        newfd: File descriptor to duplicate to.

    Returns:
        The new descriptor, which is `newfd`, or -1 on failure with `errno`
        set. Zero is a descriptor here rather than a yes, so whether this
        failed is asked for by asking for -1.
    """
    return external_call["dup2", Int32, Int32, Int32](oldfd, newfd)


def dup3(oldfd: Int32, newfd: Int32, flags: Int32) -> Int32:
    """Libc POSIX `dup3` function.

    Reference:
        https://man7.org/linux/man-pages/man2/dup3.2.html

    Description:
        dup3() duplicates a file descriptor, closing the original file descriptor.

    Args:
        oldfd: File descriptor to duplicate.
        newfd: File descriptor to duplicate to.
        flags: Flags to set on the new file descriptor.

    Returns:
        The new descriptor, which is `newfd`, or -1 on failure with `errno`
        set. As with `dup`, zero is a descriptor and not a success code.
    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call["dup3", Int32, Int32, Int32, Int32](
            oldfd, newfd, flags
        )


def execve(
    path: c_ptr[UInt8], argv: c_ptr[c_ptr[UInt8]], envp: c_ptr[c_ptr[UInt8]]
) -> Int32:
    """Libc POSIX `execve` function.

    Reference:
        https://man7.org/linux/man-pages/man2/execve.2.html

    Description:
        execve() replaces the calling process with a new process image.

    Args:
        path: Path to the file.
        argv: Array of arguments.
        envp: Array of environment variables.

    Returns:
        0 on success, -1 on error.
    """
    return external_call[
        "execve", Int32, c_ptr[UInt8], c_ptr[c_ptr[UInt8]], c_ptr[c_ptr[UInt8]]
    ](path, argv, envp)


def execv(path: c_ptr[UInt8], argv: c_ptr[c_ptr[UInt8]]) -> Int32:
    """Libc POSIX `execv` function.

    Reference:
        https://man7.org/linux/man-pages/man2/execv.2.html

    Description:
        execv() replaces the calling process with a new process image.

    Args:
        path: Path to the file.
        argv: Array of arguments.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["execv", Int32, c_ptr[UInt8], c_ptr[c_ptr[UInt8]]](
        path, argv
    )


def execvp(file: c_ptr[UInt8], argv: c_ptr[c_ptr[UInt8]]) -> Int32:
    """Libc POSIX `execvp` function.

    Reference:
        https://man7.org/linux/man-pages/man2/execvp.2.html

    Description:
        execvp() searches for the file specified by path in the directories specified by the PATH
        environment variable, and executes the program with the specified arguments.

    Args:
        file: Path to the file.
        argv: Array of arguments.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["execvp", Int32, c_ptr[UInt8], c_ptr[c_ptr[UInt8]]](
        file, argv
    )


def fork() -> Int32:
    """Libc POSIX `fork` function.

    Reference:
        https://man7.org/linux/man-pages/man2/fork.2.html

    Description:
        fork() creates a new process by duplicating the calling process.

    Returns:
        Twice over, which nothing else here does: 0 in the child, and in
        the parent the child's own process id. Failure is -1 and is only
        ever answered once, with `errno` set. Getting 0 is not this
        reporting that it worked — that is the child carrying on — and a
        parent reading it that way takes itself for a failure.
    """
    return external_call["fork", Int32]()


def ftruncate(fd: Int32, length: Int64) -> Int32:
    """Libc POSIX `ftruncate` function.

    Reference:
        https://man7.org/linux/man-pages/man2/ftruncate.2.html

    Description:
        ftruncate() changes the size of the file associated with the file descriptor fd to the
        specified length.

    Args:
        fd: File descriptor.
        length: New size of the file.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["ftruncate", Int32, Int32, Int64](fd, length)


def fchdir(fd: Int32) -> Int32:
    """Libc POSIX `fchdir` function.

    Reference:
        https://man7.org/linux/man-pages/man2/fchdir.2.html

    Description:
        fchdir() changes the current working directory of the calling process to the directory
        referenced by the file descriptor fd.

    Args:
        fd: File descriptor.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["fchdir", Int32, Int32](fd)


def fpathconf(fd: Int32, name: Int32) -> Int64:
    """Libc POSIX `fpathconf` function.

    Reference:
        https://man7.org/linux/man-pages/man3/fpathconf.3.html

    Description:
        fpathconf() returns the value of the configuration variable associated with the file
        descriptor fd.

    Args:
        fd: File descriptor.
        name: Name of the configuration variable.

    Returns:
        The value of the configuration variable.
    """
    return external_call["fpathconf", Int64, Int32, Int32](fd, name)


def fsync(fd: Int32) -> Int32:
    """Libc POSIX `fsync` function.

    Reference:
        https://man7.org/linux/man-pages/man2/fsync.2.html

    Description:
        fsync() flushes the data and metadata of the file referenced by the file descriptor fd
        to the disk.

    Args:
        fd: File descriptor.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["fsync", Int32, Int32](fd)


def getcwd(buf: c_ptr[UInt8], size: UInt64) -> c_ptr[UInt8]:
    """Libc POSIX `getcwd` function.

    Reference:
        https://man7.org/linux/man-pages/man3/getcwd.3.html

    Description:
        Writes the absolute path of the current working directory into `buf`
        and returns it.

    Args:
        buf: Pointer to the buffer to store the current working directory.
        size: The size of the buffer in bytes, which has to leave room for
            the path and the byte that ends it.

    Returns:
        `buf` on success, or null on failure with `errno` set: `ERANGE` if
        the path is longer than `size`, `EACCES` if a parent directory
        cannot be read. It is not the 0 or -1 that most of these give back.
    """
    return external_call["getcwd", c_ptr[UInt8], c_ptr[UInt8], UInt64](
        buf, size
    )


def geteuid() -> Int32:
    """Libc POSIX `geteuid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/geteuid.2.html

    Description:
        geteuid() returns the effective user ID of the calling process.

    Returns:
        The effective user ID.
    """
    return external_call["geteuid", Int32]()


def getopt(
    argc: Int32, argv: c_ptr[c_ptr[UInt8]], optstring: c_ptr[UInt8]
) -> Int32:
    """Libc POSIX `getopt` function.

    Reference:
        https://man7.org/linux/man-pages/man3/getopt.3.html

    Description:
        getopt() parses the command line arguments.

    Args:
        argc: Number of arguments.
        argv: Array of arguments.
        optstring: String of options.

    Returns:
        0 on success, -1 on error.
    """
    return external_call[
        "getopt", Int32, Int32, c_ptr[c_ptr[UInt8]], c_ptr[UInt8]
    ](argc, argv, optstring)


def getpid() -> Int32:
    """Libc POSIX `getpid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/getpid.2.html

    Description:
        getpid() returns the process ID of the calling process.

    Returns:
        The process ID.
    """
    return external_call["getpid", Int32]()


def getppid() -> Int32:
    """Libc POSIX `getppid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/getppid.2.html

    Description:
        getppid() returns the process ID of the parent process of the calling process.

    Returns:
        The process ID of the parent process.
    """
    return external_call["getppid", Int32]()


def getuid() -> Int32:
    """Libc POSIX `getuid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/getuid.2.html

    Description:
        getuid() returns the real user ID of the calling process.

    Returns:
        The real user ID.
    """
    return external_call["getuid", Int32]()


def gettid() -> Int32:
    """Libc POSIX `gettid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/gettid.2.html

    Description:
        gettid() returns the thread ID of the calling process.

    Returns:
        The thread ID.
    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call["gettid", Int32]()


def isatty(fd: Int32) -> Int32:
    """Libc POSIX `isatty` function.

    Reference:
        https://man7.org/linux/man-pages/man2/isatty.2.html

    Description:
        isatty() checks whether the file descriptor fd is a terminal.

    Args:
        fd: File descriptor.

    Returns:
        1 if `fd` is a terminal, 0 if it is not, which is an answer rather
        than a failure even though `errno` is set to `ENOTTY` alongside it.
        The two kinds of no are not told apart by what comes back either:
        something that is not a terminal and something that is not even
        open both give 0, and only errno says which.
    """
    return external_call["isatty", Int32, Int32](fd)


def link(oldpath: c_ptr[UInt8], newpath: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `link` function.

    Reference:
        https://man7.org/linux/man-pages/man2/link.2.html

    Description:
        link() creates a hard link.

    Args:
        oldpath: Path to the existing file.
        newpath: Path to the new link.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["link", Int32, c_ptr[UInt8], c_ptr[UInt8]](
        oldpath, newpath
    )


def linkat(
    olddirfd: Int32,
    oldpath: c_ptr[UInt8],
    newdirfd: Int32,
    newpath: c_ptr[UInt8],
    flags: Int32,
) -> Int32:
    """Libc POSIX `linkat` function.

    Reference:
        https://man7.org/linux/man-pages/man2/linkat.2.html

    Description:
        linkat() creates a hard link.

    Args:
        olddirfd: File descriptor for the old path.
        oldpath: Path to the existing file.
        newdirfd: File descriptor for the new path.
        newpath: Path to the new link.
        flags: Flags to set on the new link.

    Returns:
        0 on success, -1 on error.
    """
    return external_call[
        "linkat", Int32, Int32, c_ptr[UInt8], Int32, c_ptr[UInt8], Int32
    ](olddirfd, oldpath, newdirfd, newpath, flags)


def lseek(fd: Int32, offset: Int64, whence: Int32) -> Int64:
    """Libc POSIX `lseek` function.

    Reference:
        https://man7.org/linux/man-pages/man2/lseek.2.html

    Description:
        lseek() repositions the file pointer of the file associated with the file descriptor fd
        to the argument offset according to the directive whence.

    Args:
        fd: File descriptor.
        offset: Offset.
        whence: Whence.

    Returns:
        The offset the file now sits at, in bytes from its start, or -1 on
        failure with `errno` set. What comes back is where this landed and
        not whether it landed, so anything wanting to know where the file
        was has to ask before asking this to move it.
    """
    return external_call["lseek", Int64, Int32, Int64, Int32](
        fd, offset, whence
    )


def pipe(fds: c_ptr[Int32]) -> Int32:
    """Libc POSIX `pipe` function.

    Reference:
        https://man7.org/linux/man-pages/man2/pipe.2.html

    Description:
        pipe() creates a pipe.

    Args:
        fds: Pointer to an array of two file descriptors.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["pipe", Int32, c_ptr[Int32]](fds)


def pread(fd: Int32, buf: c_ptr[UInt8], count: UInt64, offset: Int64) -> Int:
    """Libc POSIX `pread` function.

    Reference:
        https://man7.org/linux/man-pages/man2/pread.2.html

    Description:
        pread() reads count bytes from the file associated with the file descriptor fd into the
        buffer starting at the location pointed to by buf, starting at the file position
        specified by offset.

    Args:
        fd: File descriptor.
        buf: Buffer to read into.
        count: Number of bytes to read.
        offset: Offset.

    Returns:
        How many bytes were read, which is short only at the end of the
        file, or -1 on failure with `errno` set. Where the file position
        was is left alone either way, which is the whole difference
        between this and reading after `lseek`.
    """
    return external_call["pread", Int, Int32, c_ptr[UInt8], UInt64, Int64](
        fd, buf, count, offset
    )


def pwrite(fd: Int32, buf: c_ptr[UInt8], count: UInt64, offset: Int64) -> Int:
    """Libc POSIX `pwrite` function.

    Reference:
        https://man7.org/linux/man-pages/man2/pwrite.2.html

    Description:
        pwrite() writes count bytes from the buffer starting at the location pointed to by buf
        into the file associated with the file descriptor fd, starting at the file position
        specified by offset.

    Args:
        fd: File descriptor.
        buf: Buffer to write from.
        count: Number of bytes to write.
        offset: Offset.

    Returns:
        How many bytes were written, which can be short for the reasons
        `write` lists, or -1 on failure with `errno` set. Where the file
        position was is left alone either way, so writing the same offset
        twice is not what happens next.
    """
    return external_call["pwrite", Int, Int32, c_ptr[UInt8], UInt64, Int64](
        fd, buf, count, offset
    )


def read(fd: Int32, buf: c_ptr[UInt8], count: UInt32) -> Int:
    """Libc POSIX `read` function.

    Reference:
        https://man7.org/linux/man-pages/man2/read.2.html

    Description:
        read() reads count bytes from the file associated with the file descriptor fd into the
        buffer starting at the location pointed to by buf.

    Args:
        fd: File descriptor.
        buf: Buffer to read into.
        count: Number of bytes to read.

    Returns:
        How many bytes were read, or -1 on failure with `errno` set. Fewer
        than were asked for is ordinary rather than failure: a pipe hands
        over whatever has arrived so far and a terminal stops at the end
        of a line, so asking for 4096 and getting 11 is a read that
        worked. Zero is the end of the file, and -1 is the only failure.
    """
    return external_call["read", Int, Int, c_ptr[NoneType], Int](
        Int(fd), buf.unsafe_bitcast[NoneType](), Int(count)
    )


def readlink(path: c_ptr[UInt8], buf: c_ptr[UInt8], size: UInt64) -> Int:
    """Libc POSIX `readlink` function.

    Reference:
        https://man7.org/linux/man-pages/man2/readlink.2.html

    Description:
        readlink() reads the contents of the file specified by path into the buffer starting at
        the location pointed to by buf.

    Args:
        path: Path to the file.
        buf: Buffer to read into.
        size: Size of the buffer.

    Returns:
        How many bytes went into the buffer, or -1 on failure with
        `errno` set. It puts down the target and stops there: there is no
        NUL at the end and no room made for one, so reading the buffer as
        a string runs on into whatever bytes follow it. Take how many it
        says and use that much, or leave a byte spare and put one there.
    """
    return external_call["readlink", Int, c_ptr[UInt8], c_ptr[UInt8], UInt64](
        path, buf, size
    )


def readlinkat(
    dirfd: Int32, path: c_ptr[UInt8], buf: c_ptr[UInt8], size: UInt64
) -> Int:
    """Libc POSIX `readlinkat` function.

    Reference:
        https://man7.org/linux/man-pages/man2/readlinkat.2.html

    Description:
        readlinkat() reads the contents of the file specified by path into the buffer starting at
        the location pointed to by buf.

    Args:
        dirfd: File descriptor.
        path: Path to the file.
        buf: Buffer to read into.
        size: Size of the buffer.

    Returns:
        How many bytes went into the buffer, or -1 on failure with
        `errno` set, with the same absence of a NUL that `readlink`
        leaves: how much came back is how much of the buffer means
        anything, and treating it as a string reads past the end of that.
    """
    return external_call[
        "readlinkat", Int, Int32, c_ptr[UInt8], c_ptr[UInt8], UInt64
    ](dirfd, path, buf, size)


def rmdir(path: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `rmdir` function.

    Reference:
        https://man7.org/linux/man-pages/man2/rmdir.2.html

    Description:
        rmdir() removes the directory specified by path.

    Args:
        path: Path to the directory.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["rmdir", Int32, c_ptr[UInt8]](path)


def swab(a: c_ptr[UInt8], b: c_ptr[UInt8], size: Int64):
    """Libc POSIX `swab` function.

    Reference:
        https://man7.org/linux/man-pages/man3/swab.3.html

    Description:
        Copies `size` bytes from `a` to `b`, swapping each pair of adjacent
        bytes on the way. An odd `size` is allowed and the last byte is
        copied as it is.

    Args:
        a: The buffer to read from.
        b: The buffer to write to, which must not overlap `a`.
        size: How many bytes to copy.

    Notes:
        There is no result to report: C declares this one `void`, and it is
        not one of the calls that reports failure in `errno` either.
    """
    external_call["swab", NoneType, c_ptr[UInt8], c_ptr[UInt8], Int64](
        a, b, size
    )


def symlink(oldpath: c_ptr[UInt8], newpath: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `symlink` function.

    Reference:
        https://man7.org/linux/man-pages/man2/symlink.2.html

    Description:
        symlink() creates a symbolic link.

    Args:
        oldpath: Path to the existing file.
        newpath: Path to the new link.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["symlink", Int32, c_ptr[UInt8], c_ptr[UInt8]](
        oldpath, newpath
    )


def symlinkat(
    oldpath: c_ptr[UInt8], newdirfd: Int32, newpath: c_ptr[UInt8]
) -> Int32:
    """Libc POSIX `symlinkat` function.

    Reference:
        https://man7.org/linux/man-pages/man2/symlinkat.2.html

    Description:
        symlinkat() creates a symbolic link.

    Args:
        oldpath: Path to the existing file.
        newdirfd: File descriptor for the new path.
        newpath: Path to the new link.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["symlinkat", Int32, c_ptr[UInt8], Int32, c_ptr[UInt8]](
        oldpath, newdirfd, newpath
    )


# remember update
def syscall(number: Int64) -> Int64:
    """Libc POSIX `syscall` function.

    Reference:
        https://man7.org/linux/man-pages/man2/syscall.2.html

    Description:
        syscall() executes a system call.

    Args:
        number: Which system call, by the number `<sys/syscall.h>` gives
            it.

    Returns:
        What that call gives back, which is whatever it means by it and
        not 0 or -1: the number for `getpid` comes back with the process
        id. -1 is what most of them give when they fail, and `errno`
        says which.

    Notes:
        C's is `long syscall(long number, ...)` and this one takes no
        more than the number, there being no way through
        `external_call` to hand over what comes after it. Of the calls
        it can reach, then, only those wanting no arguments of their
        own; the rest need a binding of their own.
    """
    return external_call["syscall", Int64, Int64](number)


def unlink(path: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `unlink` function.

    Reference:
        https://man7.org/linux/man-pages/man2/unlink.2.html

    Description:
        unlink() removes the file specified by path.

    Args:
        path: Path to the file.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["unlink", Int32, c_ptr[UInt8]](path)


def unlinkat(dirfd: Int32, path: c_ptr[UInt8], flags: Int32) -> Int32:
    """Libc POSIX `unlinkat` function.

    Reference:
        https://man7.org/linux/man-pages/man2/unlinkat.2.html

    Description:
        unlinkat() removes the file specified by path.

    Args:
        dirfd: File descriptor.
        path: Path to the file.
        flags: Flags.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["unlinkat", Int32, Int32, c_ptr[UInt8], Int32](
        dirfd, path, flags
    )


def truncate(path: c_ptr[UInt8], length: Int64) -> Int32:
    """Libc POSIX `truncate` function.

    Reference:
        https://man7.org/linux/man-pages/man2/truncate.2.html

    Description:
        truncate() changes the size of the file specified by path.

    Args:
        path: Path to the file.
        length: Length.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["truncate", Int32, c_ptr[UInt8], Int64](path, length)


def write(fd: Int32, buf: c_ptr[UInt8], count: UInt32) -> Int:
    """Libc POSIX `write` function.

    Reference:
        https://man7.org/linux/man-pages/man2/write.2.html

    Description:
        write() writes count bytes from the buffer starting at the location pointed to by buf
        into the file associated with the file descriptor fd.

    Args:
        fd: File descriptor.
        buf: Buffer to write from.
        count: Number of bytes to write.

    Returns:
        How many bytes were written, or -1 on failure with `errno` set.
        Fewer than were handed over is allowed — a pipe whose buffer has
        filled, a signal arriving part way through, a disk with nothing
        left on it — and whatever did not go out stays the caller's to
        send again. Testing this against -1 and not against how much was
        handed over is how the tail gets quietly lost.
    """
    return external_call["write", Int, Int, c_ptr[NoneType], Int](
        Int(fd), buf.unsafe_bitcast[NoneType](), Int(count)
    )


def writev(fd: Int32, iov: c_ptr[UInt8], iovcnt: Int32) -> Int:
    """Libc POSIX `writev` function.

    Reference:
        https://man7.org/linux/man-pages/man2/writev.2.html

    Description:
        writev() writes iovcnt buffers of data described by iov to the file associated with the
        file descriptor fd.

    Args:
        fd: File descriptor.
        iov: Buffer to write from.
        iovcnt: Number of buffers to write.

    Returns:
        How many bytes went out in total across all of the buffers, or -1
        on failure with `errno` set. Fewer than they come to means it
        stopped part way, and the stopping need not have been on a
        boundary: the rest lives at some offset inside one of them rather
        than at the front of the next.
    """
    return external_call["writev", Int, Int32, c_ptr[UInt8], Int32](
        fd, iov, iovcnt
    )


def readv(fd: Int32, iov: c_ptr[UInt8], iovcnt: Int32) -> Int:
    """Libc POSIX `readv` function.

    Reference:
        https://man7.org/linux/man-pages/man2/readv.2.html

    Description:
        readv() reads into several buffers one after the other, filling the
        first before starting on the next, which is gathered reading: a
        header into one buffer and whatever follows it into another
        without asking twice or piecing anything together afterwards. It is
        `read` doing the same thing it does, spread over more than one
        destination, and it is the half of the pair `writev` was alone in.

        The buffers are described by an array of `iovec`, which is to say
        by pairs of a pointer and a length, sixteen bytes to a pair. What
        comes in here is the address of the first of them; `libc.sys.socket`
        declares `iovec`, and an array of those is what to point at.

    Args:
        fd: File descriptor.
        iov: Array of buffers to read into, in the order they are filled.
        iovcnt: Number of buffers to read into.

    Returns:
        How many bytes were read in total across all of them, or -1 on
        failure with `errno` set. As with `read`, getting fewer than were
        asked for is an answer and not an error, and it is the buffers
        taken together that get short rather than the last one in
        particular: count what came back before trusting what any one of
        them holds. Zero is the end of the file.
    """
    return external_call["readv", Int, Int32, c_ptr[UInt8], Int32](
        fd, iov, iovcnt
    )


def chown(path: c_ptr[UInt8], owner: Int32, group: Int32) -> Int32:
    """Libc POSIX `chown` function.

    Reference:
        https://man7.org/linux/man-pages/man2/chown.2.html

    Description:
        chown() changes the owner and the group of a file.

    Args:
        path: The file to change.
        owner: The user ID to set, or -1 to leave it as it is.
        group: The group ID to set, or -1 to leave it as it is.

    Returns:
        0 on success, -1 on error.

    Notes:
        Following a symbolic link is what this does and `lchown` is the one
        that does not. Only a privileged process can give a file away, or
        set its group to one it does not belong to.
    """
    return external_call["chown", Int32, c_ptr[UInt8], Int32, Int32](
        path, owner, group
    )


def fchown(fd: Int32, owner: Int32, group: Int32) -> Int32:
    """Libc POSIX `fchown` function.

    Reference:
        https://man7.org/linux/man-pages/man2/fchown.2.html

    Description:
        fchown() changes the owner and the group of an open file.

    Args:
        fd: A file descriptor for the file to change.
        owner: The user ID to set, or -1 to leave it as it is.
        group: The group ID to set, or -1 to leave it as it is.

    Returns:
        0 on success, -1 on error.

    Notes:
        Taking a descriptor rather than a path is what makes this the one to
        use when the file could be moved or replaced between looking at it
        and changing it.
    """
    return external_call["fchown", Int32, Int32, Int32, Int32](fd, owner, group)


def lchown(path: c_ptr[UInt8], owner: Int32, group: Int32) -> Int32:
    """Libc POSIX `lchown` function.

    Reference:
        https://man7.org/linux/man-pages/man2/lchown.2.html

    Description:
        lchown() changes the owner and the group of a symbolic link itself
        rather than of what it points at.

    Args:
        path: The link to change.
        owner: The user ID to set, or -1 to leave it as it is.
        group: The group ID to set, or -1 to leave it as it is.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["lchown", Int32, c_ptr[UInt8], Int32, Int32](
        path, owner, group
    )


def fchownat(
    dirfd: Int32, path: c_ptr[UInt8], owner: Int32, group: Int32, flags: Int32
) -> Int32:
    """Libc POSIX `fchownat` function.

    Reference:
        https://man7.org/linux/man-pages/man2/fchownat.2.html

    Description:
        fchownat() changes the owner and the group of a file named relative
        to a directory that is open.

    Args:
        dirfd: A descriptor for the directory `path` is relative to, or
            `AT_FDCWD` for the current one.
        path: The file to change, relative to `dirfd` when it is not
            absolute.
        owner: The user ID to set, or -1 to leave it as it is.
        group: The group ID to set, or -1 to leave it as it is.
        flags: `AT_SYMLINK_NOFOLLOW` to change the link rather than what it
            points at, or `AT_EMPTY_PATH` on Linux to change `dirfd` itself.

    Returns:
        0 on success, -1 on error.
    """
    return external_call[
        "fchownat", Int32, Int32, c_ptr[UInt8], Int32, Int32, Int32
    ](dirfd, path, owner, group, flags)


def getgid() -> Int32:
    """Libc POSIX `getgid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/getgid.2.html

    Description:
        getgid() returns the real group ID of the calling process.

    Returns:
        The real group ID.
    """
    return external_call["getgid", Int32]()


def getegid() -> Int32:
    """Libc POSIX `getegid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/getegid.2.html

    Description:
        getegid() returns the effective group ID of the calling process.

    Returns:
        The effective group ID.
    """
    return external_call["getegid", Int32]()


def setuid(uid: Int32) -> Int32:
    """Libc POSIX `setuid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/setuid.2.html

    Description:
        setuid() sets the real, effective and saved user ID of the calling
        process.

    Args:
        uid: The user ID to set.

    Returns:
        0 on success, -1 on error.

    Notes:
        For a privileged process this is one-way: once the real user ID is
        set there is no setting it back. `seteuid` is the one that leaves
        the saved ID alone and can be undone.
    """
    return external_call["setuid", Int32, Int32](uid)


def setgid(gid: Int32) -> Int32:
    """Libc POSIX `setgid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/setgid.2.html

    Description:
        setgid() sets the real, effective and saved group ID of the calling
        process.

    Args:
        gid: The group ID to set.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["setgid", Int32, Int32](gid)


def seteuid(euid: Int32) -> Int32:
    """Libc POSIX `seteuid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/seteuid.2.html

    Description:
        seteuid() sets the effective user ID of the calling process.

    Args:
        euid: The effective user ID to set.

    Returns:
        0 on success, -1 on error.

    Notes:
        The saved user ID is left alone, so a privileged process can set
        this to something else and come back, which is what `setuid` will
        not do. An unprivileged process can only set it to what its real or
        saved user ID already is.
    """
    return external_call["seteuid", Int32, Int32](euid)


def setegid(egid: Int32) -> Int32:
    """Libc POSIX `setegid` function.

    Reference:
        https://man7.org/linux/man-pages/man2/setegid.2.html

    Description:
        setegid() sets the effective group ID of the calling process.

    Args:
        egid: The effective group ID to set.

    Returns:
        0 on success, -1 on error.

    Notes:
        An unprivileged process can only set it to what its real or saved
        group ID already is.
    """
    return external_call["setegid", Int32, Int32](egid)


def alarm(seconds: Int32) -> Int32:
    """Libc POSIX `alarm` function.

    Reference:
        https://man7.org/linux/man-pages/man2/alarm.2.html

    Description:
        alarm() arranges for a `SIGALRM` to arrive in `seconds` seconds.

    Args:
        seconds: How long to wait, or 0 to cancel the one already waiting.

    Returns:
        How many seconds were left on the alarm this one replaces, or 0 if
        there was none.

    Notes:
        One alarm per process: setting a second one replaces the first. It
        does not wait for anything and returns at once.
    """
    return external_call["alarm", Int32, Int32](seconds)


def pause() -> Int32:
    """Libc POSIX `pause` function.

    Reference:
        https://man7.org/linux/man-pages/man2/pause.2.html

    Description:
        pause() waits until a signal arrives and its handler returns.

    Returns:
        -1, with `errno` set to `EINTR` when the signal's handler returns,
        which is the only way out of it.

    Notes:
        This does not come back until a signal does, so it is the one call
        here that a program cannot call and then carry on with.
    """
    return external_call["pause", Int32]()


def sleep(seconds: Int32) -> Int32:
    """Libc POSIX `sleep` function.

    Reference:
        https://man7.org/linux/man-pages/man3/sleep.3.html

    Description:
        sleep() waits for `seconds` seconds, or until a signal that is not
        ignored arrives.

    Args:
        seconds: How long to wait.

    Returns:
        0 if the whole time passed, or how many seconds were left when a
        signal cut it short.
    """
    return external_call["sleep", Int32, Int32](seconds)


def nice(inc: Int32) -> Int32:
    """Libc POSIX `nice` function.

    Reference:
        https://man7.org/linux/man-pages/man2/nice.2.html

    Description:
        nice() adds `inc` to how nice this process is, which is how willing
        it is to give up the processor: a bigger number is a politer one.

    Args:
        inc: How much to add, which can be negative, though only a
            privileged process can take away what it did not give.

    Returns:
        The new niceness, which is -1 both when that is the answer and when
        the call failed — check `errno` to tell them apart.

    Notes:
        Darwin answers 0 for success and -1 for failure and does not say
        what the niceness came to, so the two platforms do not mean the
        same thing by this result. Asking for 0 is the portable use.
    """
    return external_call["nice", Int32, Int32](inc)


def getpagesize() -> Int32:
    """Libc `getpagesize` function.

    Reference:
        https://man7.org/linux/man-pages/man2/getpagesize.2.html

    Description:
        getpagesize() returns the size of a page in bytes.

    Returns:
        The size of a page.

    Notes:
        Not in POSIX anymore, which says to ask `sysconf` for `SC_PAGESIZE`
        instead, but it is in both glibc and Darwin and it is the number a
        call like `mmap` wants.
    """
    return external_call["getpagesize", Int32]()


def sysconf(name: c_int) -> c_long:
    """Libc POSIX `sysconf` function.

    Args:
        name: Which limit to ask about, as one of the `_SC_*`.

    Returns:
        The value, or -1 when `name` names nothing the system knows.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/sysconf.3.html).
        Fn signature: `long sysconf(int name)`.

        -1 is both an answer and a failure here, and `errno` is what tells
        them apart: it is left alone when -1 is the value, and set when the
        name was not one this system has. Ask `get_errno` before deciding
        which it was.
    """
    return external_call["sysconf", c_long, c_int](name)


# Which variable `confstr` is asked about, in the same shape as the
# `_SC_*` above and for the same reason: of the twenty-five both platforms
# have, every one is numbered differently. glibc numbers them from 0 in
# POSIX order and XNU from 1 in an order of its own, so `_CS_PATH` is 0
# here and 1 there.
#
# `_CS_GNU_LIBC_VERSION`, `_CS_GNU_LIBPTHREAD_VERSION` and the `_CS_LFS_*`
# are glibc's own and XNU has nothing to answer them; `_CS_DARWIN_USER_*`
# are XNU's. A variable only one side answers is not one this package can
# claim to bind.
comptime CS_PATH: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime CS_POSIX_V6_ILP32_OFF32_CFLAGS: Int32 = (
    2 if CompilationTarget.is_macos() else 1116
)
comptime CS_POSIX_V6_ILP32_OFF32_LDFLAGS: Int32 = (
    3 if CompilationTarget.is_macos() else 1117
)
comptime CS_POSIX_V6_ILP32_OFF32_LIBS: Int32 = (
    4 if CompilationTarget.is_macos() else 1118
)
comptime CS_POSIX_V6_ILP32_OFFBIG_CFLAGS: Int32 = (
    5 if CompilationTarget.is_macos() else 1120
)
comptime CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS: Int32 = (
    6 if CompilationTarget.is_macos() else 1121
)
comptime CS_POSIX_V6_ILP32_OFFBIG_LIBS: Int32 = (
    7 if CompilationTarget.is_macos() else 1122
)
comptime CS_POSIX_V6_LP64_OFF64_CFLAGS: Int32 = (
    8 if CompilationTarget.is_macos() else 1124
)
comptime CS_POSIX_V6_LP64_OFF64_LDFLAGS: Int32 = (
    9 if CompilationTarget.is_macos() else 1125
)
comptime CS_POSIX_V6_LP64_OFF64_LIBS: Int32 = (
    10 if CompilationTarget.is_macos() else 1126
)
comptime CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS: Int32 = (
    11 if CompilationTarget.is_macos() else 1128
)
comptime CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS: Int32 = (
    12 if CompilationTarget.is_macos() else 1129
)
comptime CS_POSIX_V6_LPBIG_OFFBIG_LIBS: Int32 = (
    13 if CompilationTarget.is_macos() else 1130
)
comptime CS_XBS5_ILP32_OFF32_CFLAGS: Int32 = (
    20 if CompilationTarget.is_macos() else 1100
)
comptime CS_XBS5_ILP32_OFF32_LDFLAGS: Int32 = (
    21 if CompilationTarget.is_macos() else 1101
)
comptime CS_XBS5_ILP32_OFF32_LIBS: Int32 = (
    22 if CompilationTarget.is_macos() else 1102
)
comptime CS_XBS5_ILP32_OFFBIG_CFLAGS: Int32 = (
    24 if CompilationTarget.is_macos() else 1104
)
comptime CS_XBS5_ILP32_OFFBIG_LDFLAGS: Int32 = (
    25 if CompilationTarget.is_macos() else 1105
)
comptime CS_XBS5_ILP32_OFFBIG_LIBS: Int32 = (
    26 if CompilationTarget.is_macos() else 1106
)
comptime CS_XBS5_LP64_OFF64_CFLAGS: Int32 = (
    28 if CompilationTarget.is_macos() else 1108
)
comptime CS_XBS5_LP64_OFF64_LDFLAGS: Int32 = (
    29 if CompilationTarget.is_macos() else 1109
)
comptime CS_XBS5_LP64_OFF64_LIBS: Int32 = (
    30 if CompilationTarget.is_macos() else 1110
)
comptime CS_XBS5_LPBIG_OFFBIG_CFLAGS: Int32 = (
    32 if CompilationTarget.is_macos() else 1112
)
comptime CS_XBS5_LPBIG_OFFBIG_LDFLAGS: Int32 = (
    33 if CompilationTarget.is_macos() else 1113
)
comptime CS_XBS5_LPBIG_OFFBIG_LIBS: Int32 = (
    34 if CompilationTarget.is_macos() else 1114
)


def confstr(name: c_int, buf: c_ptr[UInt8], length: c_size_t) -> c_size_t:
    """Libc POSIX `confstr` function.

    Reference:
        https://man7.org/linux/man-pages/man3/confstr.3p.html

    Args:
        name: Which variable to ask about, as one of the `_CS_*` above.
        buf: Where the answer goes, or NULL to ask only how long it is.
        length: How many bytes `buf` holds, terminator included.

    Returns:
        How many bytes the answer needs, terminator included, which is 0
        when `name` names nothing this system has. The answer is not
        written when `buf` is NULL or `length` is 0, and is truncated
        without a terminator when `length` is too short.

    Notes:
        Fn signature: `size_t confstr(int name, char *buf, size_t len)`.

        The one variable worth asking for by name rather than by number
        is `CS_PATH`, the default search path. The rest are the compiler
        and linker flags for one of the ABIs, which is what a build
        system wants and not much else.
    """
    return external_call["confstr", c_size_t, c_int, c_ptr[UInt8], c_size_t](
        name, buf, length
    )


def usleep(usec: UInt32) -> c_int:
    """Libc POSIX `usleep` function.

    Args:
        usec: How long to sleep, in microseconds.

    Returns:
        0 on success. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/usleep.3.html).
        Fn signature: `int usleep(useconds_t usec)`.

        POSIX dropped this in 2008 in favour of `nanosleep` and put it back
        in 2024, and every platform that matters kept it throughout. The
        argument is 32 bits, so the longest sleep it can name is a little
        over 71 minutes.
    """
    return external_call["usleep", c_int, UInt32](usec)


def getpgid(pid: c_int) -> c_int:
    """Libc POSIX `getpgid` function.

    Args:
        pid: Which process to ask about, or 0 for this one.

    Returns:
        The process group id. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/getpgid.2.html).
        Fn signature: `pid_t getpgid(pid_t pid)`.
    """
    return external_call["getpgid", c_int, c_int](pid)


def setpgid(pid: c_int, pgid: c_int) -> c_int:
    """Libc POSIX `setpgid` function.

    Args:
        pid: Which process to move, or 0 for this one.
        pgid: Which process group to move it into, or 0 to make a new one
            with `pid` as its leader.

    Returns:
        0 on success. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/setpgid.2.html).
        Fn signature: `int setpgid(pid_t pid, pid_t pgid)`.

        A process may set its own group and its children's, and nothing
        else's: `EPERM` for a process that is not one of those, and
        `EACCES` for a child that has gone on to `execve`.
    """
    return external_call["setpgid", c_int, c_int, c_int](pid, pgid)


def getsid(pid: c_int) -> c_int:
    """Libc POSIX `getsid` function.

    Args:
        pid: Which process to ask about, or 0 for this one.

    Returns:
        The session id. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/getsid.2.html).
        Fn signature: `pid_t getsid(pid_t pid)`.
    """
    return external_call["getsid", c_int, c_int](pid)


def setsid() -> c_int:
    """Libc POSIX `setsid` function.

    Returns:
        The new session id, which is this process's id. Otherwise -1 and
        `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/setsid.2.html).
        Fn signature: `pid_t setsid(void)`.

        `EPERM` when the caller already leads a process group, since a
        session leader that kept its old group would have one foot in each
        session. Fork first and call this from the child.
    """
    return external_call["setsid", c_int]()
