# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# The <stdio.h> entry points that `libc.file` does not already cover.
#
# `libc.file` owns the stream lifecycle (`fopen`, `fclose`, `fread`,
# `fgets`, `fputs`, `fseek`, ...) together with the descriptor-level
# calls (`open`, `read`, `write`). This module holds the rest: output,
# buffering, temporary files and pipes.
#
# The `printf`/`scanf` families are in `libc.file`, not here, and only
# without variadic arguments.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_char, c_int, c_ptr, c_size_t, c_void
from libc.file import FILE


# How big the buffer is that `setvbuf` and `setbuf` are handed. Every C
# library on these two platforms says 8192, which is why nothing here has
# to ask which one it is on.
struct fpos_t:
    """An opaque C `fpos_t`: where a stream is, as `fgetpos` writes it
    and `fsetpos` reads it back.

    What is inside one is the library's own to say, and it is not the
    same on the two platforms: glibc keeps a position and a conversion
    state in it, and Darwin keeps no more than a position. So this one
    is a block of the larger size and never anything but a place for
    the library to write, and it is only ever handed over by pointer.

    Sixteen bytes is glibc's, which is the wider of the two, and a
    block bigger than what C writes into is safe where one smaller
    would not be. Zero it and it is the state `fgetpos` may fill.
    """

    comptime FPOS_SLOTS = 2

    var _opaque: Array[UInt64, Self.FPOS_SLOTS]

    def __init__(out self):
        """Zeroes the position, which is a state `fgetpos` may fill."""
        self._opaque = Array[UInt64, Self.FPOS_SLOTS](fill=0)


def fgetpos(stream: c_ptr[FILE], pos: c_ptr[fpos_t]) -> c_int:
    """Libc C89 `fgetpos` function.

    Description:
        Asks where a stream is and writes it down, so that `fsetpos`
        may put the stream back there.

    Args:
        stream: The stream to ask.
        pos: Where to write it down, which is written to.

    Returns:
        0 where it was written down, and not 0 where it could not be.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fgetpos.3.html).
        Fn signature: `int fgetpos(FILE *stream, fpos_t *pos)`.

        This is `ftell` writing into an opaque value rather than into a
        long, which is what makes it the one for a stream whose
        position a long will not hold. What is written down is not to
        be read: `fsetpos` is the only thing it is for.
    """
    return external_call["fgetpos", c_int, c_ptr[FILE], c_ptr[fpos_t]](
        stream, pos
    )


def fsetpos(stream: c_ptr[FILE], pos: c_ptr[fpos_t]) -> c_int:
    """Libc C89 `fsetpos` function.

    Description:
        Puts a stream back where `fgetpos` wrote down that it was.

    Args:
        stream: The stream to move.
        pos: Where to put it, as `fgetpos` wrote it down.

    Returns:
        0 where the stream was moved, and not 0 where it could not be.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fsetpos.3.html).
        Fn signature: `int fsetpos(FILE *stream, const fpos_t *pos)`.

        This is `fseek` taking an opaque value rather than a long and a
        whence, and like it, it clears whatever end-of-stream was on
        the stream and lets the next read go on from there.
    """
    return external_call["fsetpos", c_int, c_ptr[FILE], c_ptr[fpos_t]](
        stream, pos
    )


def ctermid(s: c_ptr[c_char]) -> c_ptr[c_char]:
    """Libc POSIX `ctermid` function.

    Description:
        Says the name of the terminal this process is on.

    Args:
        s: Where to write the name, or a null pointer to have it come
            back in storage the library keeps.

    Returns:
        A pointer to the name. Where `s` was given, that is `s`; where
        it was not, it is storage that is not to be freed and that the
        next call here writes over.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ctermid.3.html).
        Fn signature: `char *ctermid(char *s)`.

        On a process with no terminal this still says something, and
        what it says is not a promise that there is one: `isatty` is
        what answers that. `/dev/tty` is what glibc says, and what
        comes back is not to be held to any particular characters.
    """
    return external_call["ctermid", c_ptr[c_char], c_ptr[c_char]](s)


def tempnam(dir: c_ptr[c_char], pfx: c_ptr[c_char]) -> c_ptr[c_char]:
    """Libc POSIX `tempnam` function.

    Description:
        Makes up the name of a file that no file has yet, in a
        directory chosen for the purpose.

    Args:
        dir: A directory to make it up in, or a null pointer to let
            the library choose.
        pfx: The first characters of the file's own name, or a null
            pointer to go without.

    Returns:
        A pointer to the name, in fresh memory, or a null pointer
        where one could not be made up.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/tempnam.3.html).
        Fn signature: `char *tempnam(const char *dir, const char *pfx)`.

        Fresh memory of its own asking for, which is to say the
        caller's to hand to `free`.

        The name is made up and handed back, and the file is not made:
        what there is between the two, another process may take. That
        is what `mkstemp` is for, and why this one is not to be
        reached for where the making of the file matters.
    """
    return external_call[
        "tempnam", c_ptr[c_char], c_ptr[c_char], c_ptr[c_char]
    ](dir, pfx)


def open_memstream(
    bufloc: c_ptr[c_ptr[c_char]], sizeloc: c_ptr[c_size_t]
) -> c_ptr[FILE]:
    """Libc POSIX `open_memstream` function.

    Description:
        Opens a stream that writes into memory rather than to a file,
        growing the room as it goes.

    Args:
        bufloc: Where to put the address of what was written, which is
            written to.
        sizeloc: Where to put how many bytes were written, which is
            written to.

    Returns:
        The stream, or a null pointer where one could not be had.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open_memstream.3.html).
        Fn signature: `FILE *open_memstream(char **bufloc,
            size_t *sizeloc)`.

        Both are written to as the stream is used, and neither is to
        be read until the stream has been flushed or closed — which is
        what makes the writing come out. The room is the library's own
        asking for and the caller's to hand to `free` once it is shut.

        A terminator goes on the end of what was written, and it is
        not counted in the size.
    """
    return external_call[
        "open_memstream", c_ptr[FILE], c_ptr[c_ptr[c_char]], c_ptr[c_size_t]
    ](bufloc, sizeloc)


comptime BUFSIZ = 8192


def fwrite(
    ptr: c_ptr[c_void], size: c_size_t, nmemb: c_size_t, stream: c_ptr[FILE]
) -> c_size_t:
    """C library <stdio.h> function `fwrite`.

    Reference:
        https://man7.org/linux/man-pages/man3/fread.3.html

    Prototype:
        size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream)

    Description:
        Writes `nmemb` items of `size` bytes each from `ptr` to `stream`.

    Args:
        ptr: The bytes to write.
        size: Size of one item, in bytes.
        nmemb: Number of items.
        stream: The output stream.

    Returns:
        The number of items written, which is less than `nmemb` on error.
    """

    return external_call[
        "fwrite", c_size_t, c_ptr[c_void], c_size_t, c_size_t, c_ptr[FILE]
    ](ptr, size, nmemb, stream)


def fputc(c: c_int, stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `fputc`.

    Reference:
        https://man7.org/linux/man-pages/man3/fputc.3.html

    Prototype:
        int fputc(int c, FILE *stream)

    Description:
        Writes one byte to `stream`.

    Args:
        c: The byte, converted to an `unsigned char`.
        stream: The output stream.

    Returns:
        The byte written, or `EOF` on error.
    """

    return external_call["fputc", c_int, c_int, c_ptr[FILE]](c, stream)


def putc(c: c_int, stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `putc`.

    Reference:
        https://man7.org/linux/man-pages/man3/fputc.3.html

    Prototype:
        int putc(int c, FILE *stream)

    Description:
        Equivalent to `fputc`; kept because C code uses both names.

    Args:
        c: The byte to write.
        stream: The output stream.

    Returns:
        The byte written, or `EOF` on error.
    """

    return external_call["putc", c_int, c_int, c_ptr[FILE]](c, stream)


def putchar(c: c_int) -> c_int:
    """C library <stdio.h> function `putchar`.

    Reference:
        https://man7.org/linux/man-pages/man3/fputc.3.html

    Prototype:
        int putchar(int c)

    Description:
        Writes one byte to `stdout`.

    Args:
        c: The byte to write.

    Returns:
        The byte written, or `EOF` on error.
    """

    return external_call["putchar", c_int, c_int](c)


def puts(s: c_ptr[c_char]) -> c_int:
    """C library <stdio.h> function `puts`.

    Reference:
        https://man7.org/linux/man-pages/man3/puts.3.html

    Prototype:
        int puts(const char *s)

    Description:
        Writes `s` to `stdout`, followed by a newline.

    Args:
        s: The string to write.

    Returns:
        A non-negative number on success, or `EOF` on error.
    """

    return external_call["puts", c_int, c_ptr[c_char]](s)


def getc(stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `getc`.

    Reference:
        https://man7.org/linux/man-pages/man3/fgetc.3.html

    Prototype:
        int getc(FILE *stream)

    Description:
        Reads one byte from `stream`.

    Args:
        stream: The input stream.

    Returns:
        The byte read as an `unsigned char`, or `EOF` at end of file.
    """

    return external_call["getc", c_int, c_ptr[FILE]](stream)


def getchar() -> c_int:
    """C library <stdio.h> function `getchar`.

    Reference:
        https://man7.org/linux/man-pages/man3/fgetc.3.html

    Prototype:
        int getchar(void)

    Description:
        Reads one byte from `stdin`.

    Returns:
        The byte read as an `unsigned char`, or `EOF` at end of file.
    """

    return external_call["getchar", c_int]()


def ungetc(c: c_int, stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `ungetc`.

    Reference:
        https://man7.org/linux/man-pages/man3/ungetc.3.html

    Prototype:
        int ungetc(int c, FILE *stream)

    Description:
        Pushes one byte back onto `stream` so the next read returns it.

    Args:
        c: The byte to push back.
        stream: The input stream.

    Returns:
        The pushed byte, or `EOF` on error. Only one push-back is
        guaranteed between reads.
    """

    return external_call["ungetc", c_int, c_int, c_ptr[FILE]](c, stream)


# -------------------------------------------------------
#  buffering
# -------------------------------------------------------
def setbuf(stream: c_ptr[FILE], buf: c_ptr[c_char]) -> c_void:
    """C library <stdio.h> function `setbuf`.

    Reference:
        https://man7.org/linux/man-pages/man3/setbuf.3.html

    Prototype:
        void setbuf(FILE *stream, char *buf)

    Description:
        Sets the buffer of `stream` to `buf`, or disables buffering when
        `buf` is null. Must be called before any I/O on the stream.

    Args:
        stream: The stream to configure.
        buf: A `BUFSIZ`-sized buffer owned by the caller, or null.
    """

    return external_call["setbuf", c_void, c_ptr[FILE], c_ptr[c_char]](
        stream, buf
    )


def setvbuf(
    stream: c_ptr[FILE], buf: c_ptr[c_char], mode: c_int, size: c_size_t
) -> c_int:
    """C library <stdio.h> function `setvbuf`.

    Reference:
        https://man7.org/linux/man-pages/man3/setbuf.3.html

    Prototype:
        int setvbuf(FILE *stream, char *buf, int mode, size_t size)

    Description:
        Sets both the buffering mode and the buffer of `stream`.

    Args:
        stream: The stream to configure.
        buf: The buffer, or null to let libc allocate one.
        mode: `_IOFBF` for full buffering, `_IOLBF` for line buffering or
            `_IONBF` for none.
        size: The buffer size in bytes.

    Returns:
        0 on success, non-zero on failure.
    """

    return external_call[
        "setvbuf", c_int, c_ptr[FILE], c_ptr[c_char], c_int, c_size_t
    ](stream, buf, mode, size)


# C spells these `_IOFBF`, `_IOLBF` and `_IONBF`, but a leading underscore
# makes a name private in Mojo, which would keep it out of
# `from libc.stdio import *`. The values are glibc's.
comptime IOFBF: c_int = 0
"""Fully buffered I/O, for `setvbuf` (C `_IOFBF`)."""

comptime IOLBF: c_int = 1
"""Line-buffered I/O, for `setvbuf` (C `_IOLBF`)."""

comptime IONBF: c_int = 2
"""Unbuffered I/O, for `setvbuf` (C `_IONBF`)."""


# -------------------------------------------------------
#  files and pipes
# -------------------------------------------------------
def rename(oldpath: c_ptr[c_char], newpath: c_ptr[c_char]) -> c_int:
    """C library <stdio.h> function `rename`.

    Reference:
        https://man7.org/linux/man-pages/man3/rename.3.html

    Prototype:
        int rename(const char *oldpath, const char *newpath)

    Description:
        Renames a file or directory, moving it between directories when
        both paths are on the same filesystem.

    Args:
        oldpath: The existing path.
        newpath: The new path; an existing file there is replaced.

    Returns:
        0 on success, -1 on failure with `errno` set.
    """

    return external_call["rename", c_int, c_ptr[c_char], c_ptr[c_char]](
        oldpath, newpath
    )


def remove(pathname: c_ptr[c_char]) -> c_int:
    """C library <stdio.h> function `remove`.

    Reference:
        https://man7.org/linux/man-pages/man3/remove.3.html

    Prototype:
        int remove(const char *pathname)

    Description:
        Deletes a file (via `unlink`) or an empty directory (via
        `rmdir`).

    Args:
        pathname: The path to delete.

    Returns:
        0 on success, -1 on failure with `errno` set.
    """

    return external_call["remove", c_int, c_ptr[c_char]](pathname)


def tmpfile() -> c_ptr[FILE]:
    """C library <stdio.h> function `tmpfile`.

    Reference:
        https://man7.org/linux/man-pages/man3/tmpfile.3.html

    Prototype:
        FILE *tmpfile(void)

    Description:
        Creates and opens a unique temporary file in `w+b` mode, which
        libc removes when the stream is closed.

    Returns:
        The stream, or null on failure with `errno` set.
    """

    return external_call["tmpfile", c_ptr[FILE]]()


def tmpnam(s: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdio.h> function `tmpnam`.

    Reference:
        https://man7.org/linux/man-pages/man3/tmpnam.3.html

    Prototype:
        char *tmpnam(char *s)

    Description:
        Produces a file name that did not exist at the time of the call.

    Args:
        s: A buffer of at least `L_tmpnam` bytes, or null to use a static
            internal buffer.

    Returns:
        The generated name. This is racy: the name can be taken by
        another process before you open it. Prefer `tmpfile` or
        `mkstemp`.
    """

    return external_call["tmpnam", c_ptr[c_char], c_ptr[c_char]](s)


def fileno(stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `fileno`.

    Reference:
        https://man7.org/linux/man-pages/man3/fileno.3.html

    Prototype:
        int fileno(FILE *stream)

    Description:
        Returns the file descriptor behind a stream.

    Args:
        stream: The stream.

    Returns:
        The descriptor, or -1 on failure with `errno` set. Do not close
        it while the stream is still in use.
    """

    return external_call["fileno", c_int, c_ptr[FILE]](stream)


def popen(command: c_ptr[c_char], mode: c_ptr[c_char]) -> c_ptr[FILE]:
    """C library <stdio.h> function `popen`.

    Reference:
        https://man7.org/linux/man-pages/man3/popen.3.html

    Prototype:
        FILE *popen(const char *command, const char *mode)

    Description:
        Runs `command` with `/bin/sh -c` and connects a pipe to it.

    Args:
        command: The shell command line.
        mode: `r` to read the command's output, or `w` to write to its
            input.

    Returns:
        The stream, or null on failure with `errno` set. Close it with
        `pclose`, not `fclose`.
    """

    return external_call["popen", c_ptr[FILE], c_ptr[c_char], c_ptr[c_char]](
        command, mode
    )


def pclose(stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `pclose`.

    Reference:
        https://man7.org/linux/man-pages/man3/popen.3.html

    Prototype:
        int pclose(FILE *stream)

    Description:
        Closes a stream opened by `popen` and waits for the child.

    Args:
        stream: The stream from `popen`.

    Returns:
        The wait status of the child, or -1 on failure with `errno` set.
    """

    return external_call["pclose", c_int, c_ptr[FILE]](stream)


def perror(s: c_ptr[c_char]) -> c_void:
    """C library <stdio.h> function `perror`.

    Reference:
        https://man7.org/linux/man-pages/man3/perror.3.html

    Prototype:
        void perror(const char *s)

    Description:
        Writes `s`, followed by `: ` and the message for the current
        value of `errno`, to `stderr`.

    Args:
        s: A prefix describing the failure.
    """

    return external_call["perror", c_void, c_ptr[c_char]](s)


def flockfile(stream: c_ptr[FILE]) -> c_void:
    """C library <stdio.h> function `flockfile`.

    Reference:
        https://man7.org/linux/man-pages/man3/flockfile.3.html

    Prototype:
        void flockfile(FILE *stream)

    Description:
        Takes the lock on a stream, waiting for it.

    Args:
        stream: The stream to lock.

    Notes:
        There is no result: C declares this one `void`. Every call that
        reads or writes a stream takes this lock for itself, so what it is
        for is holding it across several of them to keep them together,
        and `funlockfile` gives it up.

        The lock is on the stream and not on the file, and it is one you
        can take twice, so taking it twice means giving it up twice.
    """
    return external_call["flockfile", c_void, c_ptr[FILE]](stream)


def ftrylockfile(stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `ftrylockfile`.

    Reference:
        https://man7.org/linux/man-pages/man3/flockfile.3.html

    Prototype:
        int ftrylockfile(FILE *stream)

    Description:
        Takes the lock on a stream if it is free, without waiting.

    Args:
        stream: The stream to lock.

    Returns:
        0 with the lock held, or something else when somebody else has it.

    Notes:
        `flockfile` is this one waiting. What this is for is a stream that
        is looked at from time to time rather than one that has to be
        locked: nothing is lost by not getting the lock, so nothing waits
        for it.
    """
    return external_call["ftrylockfile", c_int, c_ptr[FILE]](stream)


def funlockfile(stream: c_ptr[FILE]) -> c_void:
    """C library <stdio.h> function `funlockfile`.

    Reference:
        https://man7.org/linux/man-pages/man3/flockfile.3.html

    Prototype:
        void funlockfile(FILE *stream)

    Description:
        Gives up the lock on a stream that `flockfile` or `ftrylockfile`
        took.

    Args:
        stream: The stream to unlock.

    Notes:
        There is no result: C declares this one `void`. It has to be given
        up from the thread that took it, and once for each time it was
        taken.
    """
    return external_call["funlockfile", c_void, c_ptr[FILE]](stream)


def getw(stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `getw`.

    Reference:
        https://man7.org/linux/man-pages/man3/getw.3.html

    Prototype:
        int getw(FILE *stream)

    Description:
        Reads one `int` from a stream.

    Args:
        stream: The stream to read from.

    Returns:
        The value, or `EOF` at the end or on failure.

    Notes:
        What is read is the bytes of an `int` laid out the way this machine
        lays them out, so a file written this way is only good for the
        machine that wrote it. `fread` reads the same bytes without
        guessing at the width or the order, which is why it is the one to
        reach for in new code.

        `EOF` is a value an `int` can hold, so a file of `int`s that could
        hold -1 cannot be told apart from the end of it.
    """
    return external_call["getw", c_int, c_ptr[FILE]](stream)


def putw(w: c_int, stream: c_ptr[FILE]) -> c_int:
    """C library <stdio.h> function `putw`.

    Reference:
        https://man7.org/linux/man-pages/man3/putw.3.html

    Prototype:
        int putw(int w, FILE *stream)

    Description:
        Writes one `int` to a stream.

    Args:
        w: The value to write.
        stream: The stream to write to.

    Returns:
        0 on success, or `EOF` on failure.

    Notes:
        What is written is the bytes of an `int` laid out the way this
        machine lays them out, so the file is only good for the machine
        that wrote it. See `getw`, which is the other half of this and
        carries the same warning.
    """
    return external_call["putw", c_int, c_int, c_ptr[FILE]](w, stream)


def renameat(
    olddirfd: c_int,
    oldpath: c_ptr[c_char],
    newdirfd: c_int,
    newpath: c_ptr[c_char],
) -> c_int:
    """C library <stdio.h> function `renameat`.

    Reference:
        https://man7.org/linux/man-pages/man2/renameat.2.html

    Prototype:
        int renameat(int olddirfd, const char *oldpath, int newdirfd,
            const char *newpath)

    Description:
        Renames a file, taking each path as relative to a directory rather
        than to the current one.

    Args:
        olddirfd: A descriptor for the directory `oldpath` is relative to,
            which can be a directory opened with `open`, or `AT_FDCWD` for
            the current one.
        oldpath: The existing path.
        newdirfd: The same for `newpath`.
        newpath: The new path; an existing file there is replaced.

    Returns:
        0 on success, -1 on failure with `errno` set.

    Notes:
        `rename` is this with `AT_FDCWD` for both directories. What this one
        is for is a directory that has been opened and checked first: the
        name cannot be swapped for another between the check and the rename,
        because it is the descriptor and not the name that says where.

        Take `AT_FDCWD` from `libc.constant` and not from a number written
        out: it is -100 on Linux and -2 on Darwin, so the number means
        different things on the two.

        A directory cannot be renamed over a directory that has anything in
        it, and nothing can be renamed onto itself.
    """
    return external_call[
        "renameat", c_int, c_int, c_ptr[c_char], c_int, c_ptr[c_char]
    ](olddirfd, oldpath, newdirfd, newpath)


def getc_unlocked(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `getc_unlocked` function.

    Description:
        Reads one byte from a stream without taking its lock.

    Args:
        stream: The stream to read from.

    Returns:
        The byte, or `EOF` at the end of it or on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getc_unlocked.3.html).
        Fn signature: `int getc_unlocked(FILE *stream)`.

        The lock is not taken, which is the point of it and also the
        whole of what is asked of the caller: nothing else may be
        using the stream at the time. `flockfile` and `funlockfile`
        are what hold it around a run of these.
    """
    return external_call["getc_unlocked", c_int, c_ptr[FILE]](stream)


def putc_unlocked(c: c_int, stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `putc_unlocked` function.

    Description:
        Writes one byte to a stream without taking its lock.

    Args:
        c: The byte to write.
        stream: The stream to write it to.

    Returns:
        The byte written, or `EOF` on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/putc_unlocked.3.html).
        Fn signature: `int putc_unlocked(int c, FILE *stream)`.

        The lock is not taken, so it is on the caller that nothing
        else is using the stream.
    """
    return external_call["putc_unlocked", c_int, c_int, c_ptr[FILE]](c, stream)


def getchar_unlocked() -> c_int:
    """Libc POSIX `getchar_unlocked` function.

    Description:
        Reads one byte from standard input without taking its lock.

    Returns:
        The byte, or `EOF` at the end of it or on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getchar_unlocked.3.html).
        Fn signature: `int getchar_unlocked(void)`.

        Bound and not called: what comes in on standard input is not
        a test's to say, and a test that asked would wait.
    """
    return external_call["getchar_unlocked", c_int]()


def putchar_unlocked(c: c_int) -> c_int:
    """Libc POSIX `putchar_unlocked` function.

    Description:
        Writes one byte to standard output without taking its lock.

    Args:
        c: The byte to write.

    Returns:
        The byte written, or `EOF` on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/putchar_unlocked.3.html).
        Fn signature: `int putchar_unlocked(int c)`.

        Bound and not called: a test that wrote to the terminal would
        be writing to the terminal.
    """
    return external_call["putchar_unlocked", c_int, c_int](c)


def clearerr_unlocked(stream: c_ptr[FILE]):
    """Libc POSIX `clearerr_unlocked` function.

    Description:
        Clears the end-of-file and error marks on a stream, without
        taking its lock.

    Args:
        stream: The stream to clear them on.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/clearerr_unlocked.3.html).
        Fn signature: `void clearerr_unlocked(FILE *stream)`.
    """
    external_call["clearerr_unlocked", NoneType, c_ptr[FILE]](stream)


def feof_unlocked(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `feof_unlocked` function.

    Description:
        Says whether the end of a stream has been read, without
        taking its lock.

    Args:
        stream: The stream to ask about.

    Returns:
        Something other than 0 where the end has been read, and 0
        where it has not.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feof_unlocked.3.html).
        Fn signature: `int feof_unlocked(FILE *stream)`.

        The mark is set by a read that found nothing left, so this
        says something about the read before it and nothing about
        what is to come.
    """
    return external_call["feof_unlocked", c_int, c_ptr[FILE]](stream)


def ferror_unlocked(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `ferror_unlocked` function.

    Description:
        Says whether a stream has been marked as having failed,
        without taking its lock.

    Args:
        stream: The stream to ask about.

    Returns:
        Something other than 0 where it has, and 0 where it has not.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ferror_unlocked.3.html).
        Fn signature: `int ferror_unlocked(FILE *stream)`.

        `clearerr_unlocked` is what takes the mark off again.
    """
    return external_call["ferror_unlocked", c_int, c_ptr[FILE]](stream)


def fileno_unlocked(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `fileno_unlocked` function.

    Description:
        Says which descriptor a stream is reading from or writing to,
        without taking its lock.

    Args:
        stream: The stream to ask about.

    Returns:
        The descriptor, or -1 on error, with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fileno_unlocked.3.html).
        Fn signature: `int fileno_unlocked(FILE *stream)`.

        The descriptor is the stream's own, and closing it out from
        under the stream is not a thing to do: `fclose` closes both.
    """
    return external_call["fileno_unlocked", c_int, c_ptr[FILE]](stream)
