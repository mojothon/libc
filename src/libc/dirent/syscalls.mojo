# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import *


struct DIR(TrivialRegisterPassable):
    pass


# Layout must match glibc's `struct dirent`: `d_name` is an inline `char[256]`,
# not a pointer, so modelling it as a pointer both reads garbage and shifts the
# field to the wrong offset.
struct dirent:
    var d_ino: c_ulong
    var d_off: c_ulong
    var d_reclen: c_ushort
    var d_type: c_char
    var d_name: Array[UInt8, 256]

    def name(self) -> String:
        """The NUL terminated entry name as a Mojo `String`."""
        var bytes = List[UInt8](capacity=256)
        var i = 0
        while i < 256 and self.d_name[i] != 0:
            bytes.append(self.d_name[i])
            i += 1
        return String(unsafe_from_utf8=Span[UInt8](bytes))


def closedir(arg: c_ptr[DIR]) -> Int32:
    """Libc POSIX `closedir` function.

    Args:
        arg: An accessible object of the type DIR.  If a file descriptor is used to implement type DIR, that file descriptor shall be closed.

    Returns:
        Upon successful completion, closedir() shall return 0; otherwise,
       -1 shall be returned and errno set to indicate the error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/closedir.3p.html).
        Fn signature: `  int closedir(DIR *dirp)`.
    """
    return external_call["closedir", Int32, c_ptr[DIR]](arg)


def opendir(arg: c_ptr[c_char]) -> c_ptr[DIR]:
    return external_call["opendir", c_ptr[DIR], c_ptr[c_char]](arg)


def readdir(arg: c_ptr[DIR]) -> c_ptr[dirent]:
    return external_call["readdir", c_ptr[dirent], c_ptr[DIR]](arg)


def dirfd(arg: c_ptr[DIR]) -> Int32:
    """Libc POSIX `dirfd` function.

    Args:
        arg: A file descriptor referring to the same directory.

    Returns:
        Upon successful completion, the dirfd() function shall return an
        integer which contains a file descriptor for the stream pointed
        to by dirp.  Otherwise, it shall return -1 and shall set errno to
        indicate the error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/dirfd.3p.html).
        Fn signature: `  int dirfd(DIR *dirp)`.
    """
    return external_call["dirfd", Int32, c_ptr[DIR]](arg)
