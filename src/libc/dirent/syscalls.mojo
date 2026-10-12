# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from std.sys import CompilationTarget

from libc.constant import *

# `struct dirent` is not laid out the same way everywhere:
#
#   glibc   ino(8) off(8) reclen(2) type(1)      name[256]   -> name at 19
#   Darwin  ino(8) seekoff(8) reclen(2) namlen(2) type(1)
#           name[1024]                                       -> name at 21
#
# The fields above `d_name` line up, so one struct serves both: keep the array
# big enough for Darwin and start reading it two bytes later there. The struct
# then has the same size as the C one on each platform (280 on glibc, 1048 on
# Darwin), which is what makes `readdir`'s pointer safe to dereference.
comptime DIRENT_NAME_SIZE = 1026 if CompilationTarget.is_macos() else 256
comptime DIRENT_NAME_OFFSET = 2 if CompilationTarget.is_macos() else 0


struct DIR(TrivialRegisterPassable):
    """An opaque C `DIR`, the directory stream `opendir` hands back.

    Empty on purpose: libc owns these and gives out a pointer to one, and
    nothing here allocates a `DIR` or looks inside it. `opendir` returns
    `c_ptr[DIR]` and every other call here takes one.
    """

    pass


# Layout must match the platform's `struct dirent`: `d_name` is an inline
# character array, not a pointer, so modelling it as a pointer both reads
# garbage and shifts the field to the wrong offset.
struct dirent:
    var d_ino: c_ulong
    var d_off: c_ulong
    var d_reclen: c_ushort
    # glibc only. On Darwin this byte is the low half of `d_namlen`; use
    # `type()` to read the file type on either platform.
    var d_type: c_char
    var d_name: Array[UInt8, DIRENT_NAME_SIZE]

    def name(self) -> String:
        """The NUL terminated entry name as a Mojo `String`."""
        var bytes = List[UInt8](capacity=DIRENT_NAME_SIZE)
        var i = DIRENT_NAME_OFFSET
        while i < DIRENT_NAME_SIZE and self.d_name[i] != 0:
            bytes.append(self.d_name[i])
            i += 1
        return String(unsafe_from_utf8=Span[UInt8](bytes))

    def type(self) -> UInt8:
        """The `d_type` file-type byte, on glibc and Darwin alike."""
        comptime if CompilationTarget.is_macos():
            # Offset 20, which is `d_name[1]` given the array starts at 19.
            return self.d_name[1]
        else:
            return self.d_type


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
