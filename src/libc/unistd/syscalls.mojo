# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_int, c_long, c_ptr


# Which knob `sysconf` is asked about: 30 here and 29 on Darwin. C spells
# it `_SC_PAGESIZE`, and a leading underscore makes a name private to a Mojo
# module, so it is `SC_PAGESIZE` here.
comptime SC_PAGESIZE: Int32 = 29 if CompilationTarget.is_macos() else 30


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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
    """
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
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
        0 on success, -1 on error.
    """
    return external_call["writev", Int, Int32, c_ptr[UInt8], Int32](
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
