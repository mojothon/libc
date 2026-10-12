# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


def chmod(path: c_ptr[Int8], mode: Int32) -> Int32:
    """Libc POSIX `chmod` function.

    Args:
        path: A path to a file.
        mode: A mode to open the file with.

    Returns: A pointer to a socket.
    """
    return external_call[
        "chmod", Int32, c_ptr[Int8], Int32  # FnName, RetType  # Args
    ](
        path, mode
    )  # Args


def fchmod(fd: Int32, mode: Int32) -> Int32:
    """Libc POSIX `fchmod` function.

    Args:
        fd: A file descriptor.
        mode: A mode to open the file with.

    Returns: A pointer to a socket.
    """
    return external_call["fchmod", Int32, Int32, Int32](fd, mode)


def fchmodat(fd: Int32, path: c_ptr[Int8], mode: Int32) -> Int32:
    """Libc POSIX `fchmodat` function.

    Args:
        fd: A file descriptor.
        path: A path to a file.
        mode: A mode to open the file with.

    Returns: A pointer to a socket.
    """
    return external_call["fchmodat", Int32, Int32, c_ptr[Int8], Int32](
        fd, path, mode
    )


def fstat(fd: Int32, stat: c_ptr[Stat]) -> Int32:
    """Libc POSIX `fstat` function.

    Args:
        fd: A file descriptor.
        stat: A pointer to a `stat` struct.

    Returns: A pointer to a socket.
    """
    return external_call["fstat", Int32, Int32, c_ptr[Stat]](fd, stat)


def lstat(path: c_ptr[Int8], stat: c_ptr[Stat]) -> Int32:
    """Libc POSIX `lstat` function.

    Args:
        path: A path to a file.
        stat: A pointer to a `stat` struct.

    Returns: A pointer to a socket.
    """
    return external_call["lstat", Int32, c_ptr[Int8], c_ptr[Stat]](path, stat)


def mkdir(path: c_ptr[Int8], mode: Int32) -> Int32:
    """Libc POSIX `mkdir` function.

    Args:
        path: A path to a directory.
        mode: A mode to create the directory with.

    Returns: A pointer to a socket.
    """
    return external_call["mkdir", Int32, c_ptr[Int8], Int32](path, mode)


def mkdirat(fd: Int32, path: c_ptr[Int8], mode: Int32) -> Int32:
    """Libc POSIX `mkdirat` function.

    Args:
        fd: A file descriptor.
        path: A path to a directory.
        mode: A mode to create the directory with.

    Returns: A pointer to a socket.
    """
    return external_call["mkdirat", Int32, Int32, c_ptr[Int8], Int32](
        fd, path, mode
    )


def mknod(path: c_ptr[Int8], mode: Int32, dev: Int32) -> Int32:
    """Libc POSIX `mknod` function.

    Args:
        path: A path to a file.
        mode: A mode to create the file with.
        dev: A device number.

    Returns: A pointer to a socket.
    """
    return external_call["mknod", Int32, c_ptr[Int8], Int32, Int32](
        path, mode, dev
    )


def mknodat(fd: Int32, path: c_ptr[Int8], mode: Int32, dev: Int32) -> Int32:
    """Libc POSIX `mknodat` function.

    Args:
        fd: A file descriptor.
        path: A path to a file.
        mode: A mode to create the file with.
        dev: A device number.

    Returns: A pointer to a socket.
    """
    return external_call["mknodat", Int32, Int32, c_ptr[Int8], Int32, Int32](
        fd, path, mode, dev
    )


struct Stat(TrivialRegisterPassable):
    var st_dev: Int32
    var st_ino: Int32
    var st_mode: Int32
    var st_nlink: Int32
    var st_uid: Int32
    var st_gid: Int32
    var st_rdev: Int32
    var st_size: Int32
    var st_atime: Int32
    var st_mtime: Int32
    var st_ctime: Int32


def stat(pathname: c_ptr[Int8], statbuf: c_ptr[Stat]) -> Int32:
    """Libc POSIX `stat` function.

    Args:
        pathname: A pathname to a file.
        statbuf: A pointer to a `stat` struct.

    Returns: A pointer to a socket.
    """
    return external_call["stat", Int32, c_ptr[Int8], c_ptr[Stat]](
        pathname, statbuf
    )


def umask(mask: Int32) -> Int32:
    """Libc POSIX `umask` function.

    Args:
        mask: A mask to apply to file creation modes.

    Returns: The previous umask.
    """
    return external_call["umask", Int32, Int32](mask)


def utime(path: c_ptr[Int8], times: c_ptr[timeval]) -> Int32:
    """Libc POSIX `utime` function.

    Args:
        path: A path to a file.
        times: A pointer to a `timeval` struct.

    Returns: A pointer to a socket.
    """
    return external_call["utime", Int32, c_ptr[Int8], c_ptr[timeval]](
        path, times
    )


struct timespec(TrivialRegisterPassable):
    var tv_sec: Int32
    var tv_nsec: Int64


struct timeval(TrivialRegisterPassable):
    var tv_sec: Int32
    var tv_usec: Int32


def utimensat(
    fd: Int32, path: c_ptr[Int8], times: c_ptr[timespec], flag: Int32
) -> Int32:
    """Libc POSIX `utimensat` function.

    Args:
        fd: A file descriptor.
        path: A path to a file.
        times: A pointer to a `timespec` struct.
        flag: A flag to modify the behavior of the function.

    Returns: A pointer to a socket.
    """
    return external_call[
        "utimensat", Int32, Int32, c_ptr[Int8], c_ptr[timespec], Int32
    ](fd, path, times, flag)


def futimens(fd: Int32, times: c_ptr[timespec]) -> Int32:
    """Libc POSIX `futimens` function.

    Args:
        fd: A file descriptor.
        times: A pointer to a `timespec` struct.

    Returns: A pointer to a socket.
    """
    return external_call["futimens", Int32, Int32, c_ptr[timespec]](fd, times)
