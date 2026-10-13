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
    """Libc POSIX `opendir` function.

    Reference:
        https://man7.org/linux/man-pages/man3/opendir.3.html

    Description:
        Opens a directory stream for the directory at `arg`, sitting at
        the first entry. The stream is what `readdir` walks and
        `closedir` ends, and it has a descriptor of its own, so one
        opened here wants closing here.

    Args:
        arg: The path of the directory to open.

    Returns:
        The stream, or null with `errno` set when it could not be opened:
        a path that is not a directory gives `ENOTDIR`, one that is not
        there `ENOENT`, and one that may not be read `EACCES`. `is_null`
        from `libc.utils` is how to ask.
    """
    return external_call["opendir", c_ptr[DIR], c_ptr[c_char]](arg)


def readdir(arg: c_ptr[DIR]) -> c_ptr[dirent]:
    """Libc POSIX `readdir` function.

    Reference:
        https://man7.org/linux/man-pages/man3/readdir.3.html

    Description:
        Reads the next entry from the stream and moves it along one. The
        entries come back in the order the filesystem holds them, which
        is not sorted and is not promised to be the same on the way
        through a second time.

    Args:
        arg: The stream to read from, as `opendir` or `fdopendir` gave
            it.

    Returns:
        The next entry, or null when there is none left, which is one
        answer for two questions: it is how the stream says it is at the
        end, and it is how it says it went wrong. `errno` is not cleared
        on the way out, so the two cannot be told apart unless it is
        cleared first. `is_null` from `libc.utils` is how to ask.

        What it points at is a buffer the stream owns, so it is not the
        caller's to free, and the next call overwrites it: take what is
        wanted out of it before asking again.
    """
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


def fdopendir(fd: Int32) -> c_ptr[DIR]:
    """Libc POSIX `fdopendir` function.

    Reference:
        https://man7.org/linux/man-pages/man3/fdopendir.3.html

    Description:
        fdopendir() opens a directory stream for a directory that is
        already open, and takes the descriptor over.

    Args:
        fd: A descriptor for the directory, opened for reading.

    Returns:
        A directory stream, or null with `errno` set if the descriptor is
        not for a directory.

    Notes:
        The stream owns the descriptor once this succeeds, and `closedir`
        closes it. If this fails the descriptor is still yours.
    """
    return external_call["fdopendir", c_ptr[DIR], Int32](fd)


def rewinddir(dirp: c_ptr[DIR]):
    """Libc POSIX `rewinddir` function.

    Reference:
        https://man7.org/linux/man-pages/man3/rewinddir.3.html

    Description:
        rewinddir() puts a directory stream back to where it was when it
        was opened.

    Args:
        dirp: The stream to rewind.

    Notes:
        There is no result: C declares this one `void`. Unlike seeking back
        to a position from `telldir`, this also forgets about entries added
        to the directory since, so a later `readdir` can show them.

        POSIX promises the stream is at the beginning again and says
        nothing about the number `telldir` then gives, and the two do not
        agree: on Darwin it is not the number it gave before the rewind.
    """
    external_call["rewinddir", NoneType, c_ptr[DIR]](dirp)


def seekdir(dirp: c_ptr[DIR], loc: Int64):
    """Libc POSIX `seekdir` function.

    Reference:
        https://man7.org/linux/man-pages/man3/seekdir.3.html

    Description:
        seekdir() sets where in the directory the next `readdir` reads from.

    Args:
        dirp: The stream to move.
        loc: A position that `telldir` gave for this same stream.

    Notes:
        There is no result: C declares this one `void`. The position is
        only good for the stream it came from, and only until something is
        added to or taken out of the directory.
    """
    external_call["seekdir", NoneType, c_ptr[DIR], Int64](dirp, loc)


def telldir(dirp: c_ptr[DIR]) -> Int64:
    """Libc POSIX `telldir` function.

    Reference:
        https://man7.org/linux/man-pages/man3/telldir.3.html

    Description:
        telldir() returns where in the directory the stream has got to.

    Args:
        dirp: The stream to ask.

    Returns:
        The position, which `seekdir` can come back to, or -1 on failure
        with `errno` set.

    Notes:
        This is a position within the directory and not a number of bytes,
        so it means nothing to `lseek`, and it is only good for the stream
        it came from.
    """
    return external_call["telldir", Int64, c_ptr[DIR]](dirp)
