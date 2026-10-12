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
