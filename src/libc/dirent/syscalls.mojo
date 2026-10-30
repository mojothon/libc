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
# A `struct dirent` is 280 bytes on glibc and 1048 on Darwin, and the two
# disagree about where things sit: `d_name` starts at 19 on one and 21 on
# the other, and `d_type` is at 18 and 20. `d_reclen` is at 16 on both.
# So the record is held as bytes and every member is read at the offset
# that fits the platform, the way `Stat` does it.
#
# The size is the platform's own, not the smaller of the two: `readdir`
# hands back a pointer into a record libc owns, and holding less of it
# than C writes means a copy made of one runs off the end. Darwin's
# `d_name` is 1024 long where glibc's is 256, which is the whole of the
# difference.
comptime DIRENT_BYTES = 1048 if CompilationTarget.is_macos() else 280
comptime DIRENT_SLOTS = DIRENT_BYTES // 8
comptime DIRENT_NAME_OFFSET = 21 if CompilationTarget.is_macos() else 19
comptime DIRENT_TYPE_OFFSET = 20 if CompilationTarget.is_macos() else 18
comptime DIRENT_RECLEN_OFFSET = 16


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
    """A C `struct dirent`, the record `readdir` hands back.

    glibc's is `d_ino`, `d_off`, `d_reclen`, `d_type` and then `d_name` at
    19. Darwin's keeps a `d_seekoff` where glibc has `d_off` and carries a
    `d_namlen` besides, so its `d_type` is at 20 and `d_name` at 21. Only
    `d_reclen` is at the same place on both, 16. Neither is a prefix of
    the other, so the bytes are held as they come and each member is read
    at the offset that fits, which is what the constants above say.
    """

    # Eight-byte slots rather than bytes: C says this record is 8-aligned,
    # and an `Array[UInt8]` would take the struct's alignment down to 1.
    var _slots: Array[UInt64, DIRENT_SLOTS]

    def __init__(out self):
        """Zeroes the whole record."""
        self._slots = Array[UInt64, DIRENT_SLOTS](fill=0)

    def _byte(self, off: Int) -> UInt8:
        """The single byte at `off`, whichever slot holds it."""
        return UInt8((self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFF)

    def _u16(self, off: Int) -> UInt16:
        """Two little-endian bytes at `off`."""
        return UInt16(self._byte(off)) | (UInt16(self._byte(off + 1)) << 8)

    def _u64(self, off: Int) -> UInt64:
        """Eight little-endian bytes at `off`."""
        var acc: UInt64 = 0
        for i in range(8):
            acc |= UInt64(self._byte(off + i)) << UInt64(i * 8)
        return acc

    def ino(self) -> UInt64:
        """The inode number of the entry."""
        return self._u64(0)

    def reclen(self) -> UInt16:
        """The length of this record, which is how `readdir` steps to the next.
        """
        return self._u16(DIRENT_RECLEN_OFFSET)

    def type(self) -> UInt8:
        """The `d_type` file-type byte, on glibc and Darwin alike."""
        return self._byte(DIRENT_TYPE_OFFSET)

    def name(self) -> String:
        """The NUL terminated entry name as a Mojo `String`."""
        var bytes = List[UInt8]()
        var i = DIRENT_NAME_OFFSET
        while i < DIRENT_BYTES and self._byte(i) != 0:
            bytes.append(self._byte(i))
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


def scandir(
    dirp: c_ptr[c_char],
    namelist: c_ptr[c_ptr[c_ptr[dirent]]],
    selector: c_ptr[UInt8],
    compar: c_ptr[UInt8],
) -> Int32:
    """C library <dirent.h> function `scandir`.

    Reference:
        https://man7.org/linux/man-pages/man3/scandir.3.html

    Description:
        Reads a whole directory in one call and hands back a vector of
        every entry in it: what `opendir` plus a loop of `readdir` would
        give, already collected. Each entry is a `dirent` of its own,
        allocated for the caller rather than reused between entries, so
        all of them are readable at once — which is the whole reason to
        want a sort over them.

    Args:
        dirp: The directory to read, NUL terminated.
        namelist: Where the vector is written: room for one pointer, which
            this call fills with the address of an array of `dirent`
            pointers that many long. Zeroed before the call, untouched if
            the answer is -1.
        selector: Which entries to keep, called once for each, a non-zero
            answer meaning keep. Give it `null_ptr[UInt8]()` to keep them
            all, which is the only value this package can offer: a Mojo
            closure cannot be made into the C function pointer this slot
            wants.
        compar: What order to put them in, called the way `qsort` would
            call it. Give it `null_ptr[UInt8]()` for the order the
            filesystem holds them, which is no order; `alphasort` below
            cannot be passed here either, because there is no way to take
            the address of a C function from Mojo. Sort the vector
            yourself, or call `alphasort` on two of its entries.

    Returns:
        How many entries are in the vector, or -1 with `errno` set when
        the directory could not be read: `ENOENT`, `ENOTDIR`, `EACCES`
        and `ENOMEM` are the ones to expect. Zero is a directory with
        nothing in it, which is not an error.

    Notes:
        Fn signature:
        `int scandir(const char *restrict dirp, struct dirent ***restrict namelist, int (*selector)(const struct dirent *), int (*compar)(const struct dirent **, const struct dirent **))`.

        What it allocates is the caller's to release and nothing else
        will: `free` from `libc.stdlib` on each entry in the vector and
        then on the vector itself. glibc's is documented that way and
        XNU's behaves the same.

        glibc redirects this to `scandir64` when the 64-bit file offsets
        are in play, and the two are the same call on any 64-bit machine.
    """
    return external_call[
        "scandir",
        Int32,
        c_ptr[c_char],
        c_ptr[c_ptr[c_ptr[dirent]]],
        c_ptr[UInt8],
        c_ptr[UInt8],
    ](dirp, namelist, selector, compar)


def alphasort(a: c_ptr[c_ptr[dirent]], b: c_ptr[c_ptr[dirent]]) -> Int32:
    """C library <dirent.h> function `alphasort`.

    Reference:
        https://man7.org/linux/man-pages/man3/scandir.3.html

    Description:
        How `scandir` would have sorted its entries had it been given a
        comparator: the two names compared as strings, `strcmp`'s answer
        on a name against a name.

    Args:
        a: Where one entry's pointer lives — `namelist` plus an index,
            not the entry itself.
        b: Where the other one's does.

    Returns:
        Below 0 when the first name sorts before the second, above 0 when
        it sorts after, and 0 when they are the same name.

    Notes:
        Fn signature:
        `int alphasort(const struct dirent **a, const struct dirent **b)`.

        It asks the name out of the record the way `readdir` wrote it,
        which is why these are pointers to pointers: the argument is
        where in the vector the entry sits, because that is what a
        comparator for `scandir` is handed.

        `alphasort` cannot be handed to `scandir` from Mojo, there being
        no way to take the address of a C function here; it is bound for
        sorting a vector that `scandir` already gave back, one pair at a
        time.
    """
    return external_call[
        "alphasort", Int32, c_ptr[c_ptr[dirent]], c_ptr[c_ptr[dirent]]
    ](a, b)


def readdir_r(
    arg: c_ptr[DIR], entry: c_ptr[dirent], result: c_ptr[c_ptr[dirent]]
) -> Int32:
    """Libc POSIX `readdir_r` function.

    Description:
        Reads the next entry of a directory, putting it in room the
        caller gives rather than in one of its own.

    Args:
        arg: The open directory, which `opendir` handed back.
        entry: The `dirent` to fill in, which is written to.
        result: Where to put a pointer to `entry` where there was an
            entry to read and nothing at the end of the directory,
            which is written to.

    Returns:
        0 where the reading was done, whether or not there was an
        entry: what is in `result` is what says which. Anything else
        is a number that says what went wrong, and is not in `errno`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/readdir_r.3.html).
        Fn signature: `int readdir_r(DIR *restrict dirp,
            struct dirent *restrict entry,
            struct dirent **restrict result)`.

        This is `readdir` that puts what it finds in the caller's room
        rather than in one of its own, which is what makes it the one
        to call where a thread other than the first is reading.
        `readdir` is the one that hands back the same object every
        caller, and is the one to call now: this one cannot say how
        much room a name needs before it is asked, and a name longer
        than the room given is a name that does not fit.

        The room has to be big enough for either platform's `dirent`,
        which is not the same size on the two of them and is why
        `DIRENT_BYTES` is what it is.

        It is deprecated in POSIX as of its 2018 edition, `readdir`
        being what is left.
    """
    return external_call[
        "readdir_r", Int32, c_ptr[DIR], c_ptr[dirent], c_ptr[c_ptr[dirent]]
    ](arg, entry, result)
