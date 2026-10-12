# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


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


def getcwd(buf: c_ptr[UInt8], size: Int32) -> c_ptr[UInt8]:
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
    return external_call["getcwd", c_ptr[UInt8], c_ptr[UInt8], Int32](buf, size)


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


def pread(fd: Int32, buf: c_ptr[UInt8], count: UInt32, offset: Int8) -> UInt32:
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
    return external_call["pread", UInt32, Int32, c_ptr[UInt8], UInt32, Int8](
        fd, buf, count, offset
    )


def pwrite(fd: Int32, buf: c_ptr[UInt8], count: UInt32, offset: Int8) -> UInt32:
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
    return external_call["pwrite", UInt32, Int32, c_ptr[UInt8], UInt32, Int8](
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


def readlink(path: c_ptr[UInt8], buf: c_ptr[UInt8], size: Int32) -> Int32:
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
    return external_call["readlink", Int32, c_ptr[UInt8], c_ptr[UInt8], Int32](
        path, buf, size
    )


def readlinkat(
    dirfd: Int32, path: c_ptr[UInt8], buf: c_ptr[UInt8], size: Int32
) -> Int32:
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
        "readlinkat", Int32, Int32, c_ptr[UInt8], c_ptr[UInt8], Int32
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


def swab(a: c_ptr[UInt8], b: c_ptr[UInt8], size: Int32):
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
    external_call["swab", NoneType, c_ptr[UInt8], c_ptr[UInt8], Int32](
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
def syscall(number: Int32) -> Int32:
    """Libc POSIX `syscall` function.

    Reference:
        https://man7.org/linux/man-pages/man2/syscall.2.html

    Description:
        syscall() executes a system call.

    Args:
        number: System call number.

    Returns:
        0 on success, -1 on error.
    """
    return external_call["syscall", Int32, Int32](number)


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


def writev(fd: Int32, iov: c_ptr[UInt8], iovcnt: UInt32) -> UInt32:
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
    return external_call["writev", UInt32, Int32, c_ptr[UInt8], UInt32](
        fd, iov, iovcnt
    )
