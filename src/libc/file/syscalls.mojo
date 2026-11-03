# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from libc.constant import *
from std.ffi import external_call
from libc.sys.socket import iovec

# The descriptor-level calls this module is asked for are not bound here:
# `read`, `write`, `lseek`, `pread`, `pwrite` and `close` are `libc.unistd`'s,
# `openat`, `creat` and `fcntl` are `libc.fcntl`'s, and they are imported so
# that there is one signature for each rather than two that look alike. A
# caller reaching for `libc.file` gets the same call as one reaching for
# `libc.unistd`, and the two cannot drift apart because there is only one.
from libc.fcntl import creat, fcntl, openat
from libc.unistd import close, lseek, pread, pwrite, read, write


# Two of `<stdio.h>`'s calls are not in this file, and it is not for want of a
# signature: the Mojo standard library declares `fflush` and `fdopen` itself,
# with a `FILE *` of its own inside `std.io`, and `external_call` refuses a
# second declaration of a name that is already declared — `error: existing
# function with conflicting signature`, at compile time, in the module where
# the call is made. Every other call here that takes a `FILE *` is fine,
# `fopen` and `fclose` and the rest of them, so this is about the two names
# and not about streams.
#
# Both were bound, and the bindings compiled, because `external_call` is only
# lowered where it is used. What a caller would have met is that error,
# pointing into `std/ffi` and not into this file. They are gone; a test that
# asks them something is what found it, and `scripts/check-symbols.py` keeps
# them from coming back.


struct FILE(TrivialRegisterPassable):
    """An opaque C `FILE`, the stream `fopen` and friends hand back.

    Empty on purpose: libc owns these and gives out a pointer to one, and
    nothing here allocates a `FILE` or looks inside it. Every call in this
    package takes `c_ptr[FILE]`.
    """

    pass


def open(path: c_ptr[c_char], oflag: c_int) -> c_int:
    """Libc POSIX `open` function.

    Args:
        path: A path to a file.
        oflag: A flag to open the file with.

    Returns:
        A File Descriptor or -1 in case of failure

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int open(const char *path, int oflag, ...)`.
    Notes:
        C's is a variadic call and Mojo cannot pass a variadic
        argument, so the ones after the listed ones are not handed
        over; what libc reads instead is whatever is next to them.

    """

    return external_call["open", c_int, c_ptr[c_char], c_int](path, oflag)


def fopen(pathname: c_ptr[c_char], mode: c_ptr[c_char]) -> c_ptr[FILE]:
    """Libc POSIX `fopen` function.

    Args:
        pathname: A path to a file.
        mode: A mode to open the file with.

    Returns:
    The stream, or a null pointer on failure with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fopen.3p.html).
        Fn signature: `FILE *fopen(const char *restrict pathname,
        const char *restrict mode)`.
    """
    return external_call[
        "fopen",
        c_ptr[FILE],
        c_ptr[c_char],
        c_ptr[c_char],
    ](pathname, mode)


def freopen(
    pathname: c_ptr[c_char],
    mode: c_ptr[c_char],
    stream: c_ptr[FILE],
) -> c_ptr[FILE]:
    """Libc POSIX `freopen` function.

    Args:
        pathname: A path to a file.
        mode: A mode to open the file with.
        stream: A pointer to a stream.

    Returns:
    The stream, or a null pointer on failure with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/freopen.3p.html).
        Fn signature: `FILE *freopen(const char *restrict pathname,
        const char *restrict mode, FILE *restrict stream)`.
    """
    return external_call[
        "freopen",
        c_ptr[FILE],
        c_ptr[c_char],
        c_ptr[c_char],
        c_ptr[FILE],
    ](pathname, mode, stream)


def fmemopen(
    buf: c_ptr[c_void], size: c_size_t, mode: c_ptr[c_char]
) -> c_ptr[FILE]:
    """Libc POSIX `fmemopen` function.

    Args:
        buf: A pointer to a buffer.
        size: The size of the buffer.
        mode: A mode to open the file with.

    Returns:
    The stream, or a null pointer on failure with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fmemopen.3p.html).
        Fn signature: `FILE *fmemopen(void *restrict buf, size_t size,
        const char *restrict mode)`.
    """
    return external_call[
        "fmemopen",
        c_ptr[FILE],
        c_ptr[c_void],
        c_size_t,
        c_ptr[c_char],
    ](buf, size, mode)


def fseek(stream: c_ptr[FILE], offset: c_long, whence: c_int) -> c_int:
    """Libc POSIX `fseek` function.

    Args:
        stream: A pointer to a stream.
        offset: An offset to seek to.
        whence: A pointer to a buffer to store the length of the address of the
            accepted socket.

    Returns:
    0 on success, or -1 with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fseek.3p.html).
        Fn signature: `int fseek(FILE *stream, long offset, int whence)`.
    """
    return external_call["fseek", c_int, c_ptr[FILE], c_long, c_int](
        stream, offset, whence
    )


def fseeko(stream: c_ptr[FILE], offset: off_t, whence: c_int) -> c_int:
    """Libc POSIX `fseeko` function.

    Args:
        stream: A pointer to a stream.
        offset: An offset to seek to.
        whence: A pointer to a buffer to store the length of the address of the
            accepted socket.

    Returns:
    0 on success, or -1 with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fseek.3p.html).
        Fn signature: `int fseeko(FILE *stream, off_t offset, int whence)`.
    """
    return external_call["fseeko", c_int, c_ptr[FILE], off_t, c_int](
        stream, offset, whence
    )


def fputc(c: c_int, stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `fputc` function.

    Args:
        c: A character to write.
        stream: A pointer to a stream.

    Returns:
    The character it wrote, as an `int`, or `EOF` on failure.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fputc_3p.html).
        Fn signature: `int fputc(int c, FILE *stream)`.
    """
    return external_call["fputc", c_int, c_int, c_ptr[FILE]](c, stream)


def fputs(s: c_ptr[c_char], stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `fputs` function.

    [Reference](https://man7.org/linux/man-pages/man3/fputs.3p.html).
    Fn signature: `int fputs(const char *restrict s, FILE *restrict stream)`.

    Args:
        s: A string to write.
        stream: A pointer to a stream.

    Returns:
        A number that is not negative, or `EOF` on failure.
    """
    return external_call[
        "fputs",
        c_int,
        c_ptr[c_char],
        c_ptr[FILE],
    ](s, stream)


def fgetc(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `fgetc` function.

    Args:
        stream: A pointer to a stream.

    Returns:
    The character it read as an `int`, or `EOF` at the end of the
        file or on failure.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fgetc_3p.html).
        Fn signature: `int fgetc(FILE *stream)`.
    """
    return external_call["fgetc", c_int, c_ptr[FILE]](stream)


def fgets(s: c_ptr[c_char], n: c_int, stream: c_ptr[FILE]) -> c_ptr[c_char]:
    """Libc POSIX `fgets` function.

    Args:
        s: A pointer to a buffer to store the read string.
        n: The maximum number of characters to read.
        stream: A pointer to a stream.

    Returns:
    `s`, or a null pointer at the end of the file or on failure.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fgets.3p.html).
        Fn signature: `char *fgets(char *restrict s, int n,
        FILE *restrict stream)`.
    """
    return external_call[
        "fgets",
        c_ptr[c_char],
        c_ptr[c_char],
        c_int,
        c_ptr[FILE],
    ](s, n, stream)


def fprintf(stream: c_ptr[FILE], format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `fprintf` function.

    Args:
        stream: A pointer to a stream to write to.
        format: What to write, which goes to the stream exactly as it
            stands.

    Returns:
        How many bytes it wrote, or a negative number on failure.

    Notes:
        C's takes `...` after the format and this takes none of it: there is
        no way through `external_call` to hand over what comes after it. A
        conversion, `%d` and the rest, is therefore not something it can
        write, and neither is a bare `%`, which C reads as the start of one.
        What goes through is the format as it stands -- which is enough for
        a line with nothing to fill in, and is why `sprintf` and `snprintf`
        are here for the ones that have something.

        [Reference](https://man7.org/linux/man-pages/man3/fprintf.3p.html).
        Fn signature: `int fprintf(FILE *restrict stream,
        const char *restrict format, ...)`.
    """
    return external_call["fprintf", c_int, c_ptr[FILE], c_ptr[c_char]](
        stream, format
    )


def dprintf(fildes: c_int, format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `dprintf` function.

    Args:
        fildes: A File Descriptor to open the file with.
        format: A format string.

    Returns:
    How many bytes it wrote, or a negative number on failure.

    Notes:
        C's takes `...` after this one and this takes none of it: there
            is no way through `external_call` to hand over what comes
            after the format. A conversion, `%d` and the rest, is
            therefore not something it can write, and nor is a bare `%`,
            which C reads as the start of one. What goes through is the
            format exactly as it stands.

        [Reference](https://man7.org/linux/man-pages/man3/fprintf.3p.html).
        Fn signature: `int dprintf(int fildes,
        const char *restrict format, ...)`.
    Notes:
        C's is a variadic call, and Mojo cannot pass a variadic
        argument, so only what is listed here is handed over. A format
        asking for more — anything with a `%` in it — is answered by
        libc reading whatever sits next to the arguments, which is not
        a value anybody put there.

    """
    return external_call["dprintf", c_int, c_int, c_ptr[c_char]](fildes, format)


def printf(format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `printf` function.

    Args:
        format: What to write, which goes to `printf` exactly as it
            stands.

    Returns:
        How many bytes it wrote, or a negative number on failure.

    Notes:
        C's is `int printf(const char *restrict format, ...)` and this
        one takes no more than the format: there is no way through
        `external_call` to hand over what comes after it. That rules
        out every conversion — `%d` and the rest — and a bare `%` as
        well, which C reads as the start of one. For text with numbers
        in it, build it in Mojo and write it out, or take `snprintf`,
        which is limited the same way.

        What it was before, a binding taking `*args` and passing them
        along, did not compile: `external_call` wants the types of the
        arguments written out, and a pack of them has none to give.

        [Reference](https://man7.org/linux/man-pages/man3/fprintf.3p.html).
    Notes:
        C's is a variadic call, and Mojo cannot pass a variadic
        argument, so only what is listed here is handed over. A format
        asking for more — anything with a `%` in it — is answered by
        libc reading whatever sits next to the arguments, which is not
        a value anybody put there.

    """
    return external_call["printf", c_int, c_ptr[c_char]](format)


def snprintf(
    s: c_ptr[c_char],
    n: c_size_t,
    format: c_ptr[c_char],
) -> c_int:
    """Libc POSIX `snprintf` function.

    Args:
        s: A pointer to a buffer to store the read string.
        n: The maximum number of characters to read.
        format: A format string.

    Returns:
    How many bytes it would have written had `n` been big enough,
        not counting the one that ends the string, or a negative number
        on failure.

    Notes:
        C's takes `...` after this one and this takes none of it: there
            is no way through `external_call` to hand over what comes
            after the format. A conversion, `%d` and the rest, is
            therefore not something it can write, and nor is a bare `%`,
            which C reads as the start of one. What goes through is the
            format exactly as it stands.

        [Reference](https://man7.org/linux/man-pages/man3/fprintf.3p.html).
        Fn signature: ``int snprintf(char *restrict s, size_t n,`.
        const char *restrict format, ...)`.
    Notes:
        C's is a variadic call, and Mojo cannot pass a variadic
        argument, so only what is listed here is handed over. A format
        asking for more — anything with a `%` in it — is answered by
        libc reading whatever sits next to the arguments, which is not
        a value anybody put there.

    """
    return external_call[
        "snprintf",
        c_int,
        c_ptr[c_char],
        c_size_t,
        c_ptr[c_char],
    ](s, n, format)


def sprintf(s: c_ptr[c_char], format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `sprintf` function.

    Args:
        s: A pointer to a buffer to store the read string.
        format: A format string.

    Returns:
    How many bytes it wrote, not counting the one that ends the
        string, or a negative number on failure.

    Notes:
        C's takes `...` after this one and this takes none of it: there
            is no way through `external_call` to hand over what comes
            after the format. A conversion, `%d` and the rest, is
            therefore not something it can write, and nor is a bare `%`,
            which C reads as the start of one. What goes through is the
            format exactly as it stands.

        [Reference](https://man7.org/linux/man-pages/man3/fprintf.3p.html).
        Fn signature: ``int sprintf(char *restrict s,`.
        const char *restrict format, ...)`.
    Notes:
        C's is a variadic call, and Mojo cannot pass a variadic
        argument, so only what is listed here is handed over. A format
        asking for more — anything with a `%` in it — is answered by
        libc reading whatever sits next to the arguments, which is not
        a value anybody put there.

    """
    return external_call["sprintf", c_int, c_ptr[c_char], c_ptr[c_char]](
        s, format
    )


def fscanf(stream: c_ptr[FILE], format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `fscanf` function.

    Args:
        stream: A pointer to a stream.
        format: A format string.

    Returns:
        How many fields it filled in, which is none: there is nowhere
            for a conversion to put what it reads, so 0 is all this one
            can answer, or `EOF` when the input was at its end before
            the first one.

    Notes:
        C's takes `...` after this one and this takes none of it: there
            is no way through `external_call` to hand over what comes
            after the format. Every conversion, `%d` and the rest, needs
            somewhere to put what it reads, and there is nowhere to give
            it. What is left is a format with no conversions in it,
            which reads nothing at all.

        [Reference](https://man7.org/linux/man-pages/man3/fscanf.3p.html).
        Fn signature: ``int fscanf(FILE *restrict stream,`.
        const char *restrict format, ...)`.
    Notes:
        C's is a variadic call, and the pointers it writes through are
        the variadic part of it, so Mojo cannot pass them: only the
        stream and the format are handed over. A format with a `%` in
        it is then answered by writing through whatever address libc
        finds next to the arguments. Nothing can be read back from
        this call.

    """
    return external_call["fscanf", c_int, c_ptr[FILE], c_ptr[c_char]](
        stream, format
    )


def scanf(format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `scanf` function.

    Args:
        format: A format string.

    Returns:
        How many fields it filled in, which is none: there is nowhere
            for a conversion to put what it reads, so 0 is all this one
            can answer, or `EOF` when the input was at its end before
            the first one.

    Notes:
        C's takes `...` after this one and this takes none of it: there
            is no way through `external_call` to hand over what comes
            after the format. Every conversion, `%d` and the rest, needs
            somewhere to put what it reads, and there is nowhere to give
            it. What is left is a format with no conversions in it,
            which reads nothing at all.

        [Reference](https://man7.org/linux/man-pages/man3/fscanf.3p.html).
        Fn signature: ``int scanf(const char *restrict format, ...)`.`.
    Notes:
        C's is a variadic call, and the pointers it writes through are
        the variadic part of it, so Mojo cannot pass them: only the
        stream and the format are handed over. A format with a `%` in
        it is then answered by writing through whatever address libc
        finds next to the arguments. Nothing can be read back from
        this call.

    """
    return external_call["scanf", c_int, c_ptr[c_char]](format)


def sscanf(s: c_ptr[c_char], format: c_ptr[c_char]) -> c_int:
    """Libc POSIX `sscanf` function.

    Args:
        s: A pointer to a buffer to store the read string.
        format: A format string.

    Returns:
        How many fields it filled in, which is none: there is nowhere
            for a conversion to put what it reads, so 0 is all this one
            can answer, or `EOF` when the input was at its end before
            the first one.

    Notes:
        C's takes `...` after this one and this takes none of it: there
            is no way through `external_call` to hand over what comes
            after the format. Every conversion, `%d` and the rest, needs
            somewhere to put what it reads, and there is nowhere to give
            it. What is left is a format with no conversions in it,
            which reads nothing at all.

        [Reference](https://man7.org/linux/man-pages/man3/fscanf.3p.html).
        Fn signature: ``int sscanf(const char *restrict s,`.
        const char *restrict format, ...)`.
    Notes:
        C's is a variadic call, and the pointers it writes through are
        the variadic part of it, so Mojo cannot pass them: only the
        string and the format are handed over. A format with a `%` in
        it is then answered by writing through whatever address libc
        finds next to the arguments. Nothing can be read back from
        this call.

    """
    return external_call["sscanf", c_int, c_ptr[c_char], c_ptr[c_char]](
        s, format
    )


def fread(
    ptr: c_ptr[c_void],
    size: c_size_t,
    nitems: c_size_t,
    stream: c_ptr[FILE],
) -> c_size_t:
    """Libc POSIX `fread` function.

    Args:
        ptr: A pointer to a buffer to store the read string.
        size: The size of the buffer.
        nitems: The number of items to read.
        stream: A pointer to a stream.

    Returns:
    How many whole items it read, which is fewer than were asked for
        at the end of the file or on failure. It counts items and not
        bytes, so it is not a number of bytes unless the size is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fread.3p.html).
        Fn signature: `size_t fread(void *restrict ptr, size_t size,
        size_t nitems, FILE *restrict stream)`.
    """
    return external_call[
        "fread",
        c_size_t,
        c_ptr[c_void],
        c_size_t,
        c_size_t,
        c_ptr[FILE],
    ](ptr, size, nitems, stream)


def rewind(stream: c_ptr[FILE]) -> c_void:
    """Libc POSIX `rewind` function.

    Args:
        stream: A pointer to a stream.

    Returns:
        Nothing: C declares this one `void`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/rewind.3p.html).
        Fn signature: `void rewind(FILE *stream)`.
    """
    return external_call["rewind", c_void, c_ptr[FILE]](stream)


def getline(
    lineptr: c_ptr[c_ptr[c_char]], n: c_ptr[c_size_t], stream: c_ptr[FILE]
) -> c_ssize_t:
    """Libc POSIX `getline` function.

    Args:
        lineptr: A pointer to a pointer to a buffer to store the read
            string, which is grown as needed and has to be given to `free`.
        n: A pointer to how big that buffer is, which is kept up to date.
        stream: A pointer to a stream.

    Returns:
        How many bytes were read, or -1 at the end or on failure.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getline.3p.html).
        Fn signature: `ssize_t getline(char **restrict lineptr,
            size_t *restrict n, FILE *restrict stream);`.
    """
    return external_call[
        "getline", c_ssize_t, c_ptr[c_ptr[c_char]], c_ptr[c_size_t], c_ptr[FILE]
    ](lineptr, n, stream)


def getdelim(
    lineptr: c_ptr[c_ptr[c_char]],
    n: c_ptr[c_size_t],
    delimiter: c_int,
    stream: c_ptr[FILE],
) -> c_ssize_t:
    """Libc POSIX `getdelim` function.

    Args:
        lineptr: A pointer to a pointer to a buffer to store the read
            string, which is grown as needed and has to be given to `free`.
        n: A pointer to how big that buffer is, which is kept up to date.
        delimiter: The byte to read up to, which does not have to be a
            newline.
        stream: A pointer to a stream.

    Returns:
        How many bytes were read, or -1 at the end or on failure.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getdelim.3p.html).
        Fn signature: `ssize_t getdelim(char **restrict lineptr,
            size_t *restrict n, int delimiter, FILE *restrict stream);`.

        `getline` is this one with the delimiter set to a newline. The
        delimiter is kept in the string that comes back, so reading up to a
        comma hands back a string that ends in one.
    """
    return external_call[
        "getdelim",
        c_ssize_t,
        c_ptr[c_ptr[c_char]],
        c_ptr[c_size_t],
        c_int,
        c_ptr[FILE],
    ](lineptr, n, delimiter, stream)


def preadv(
    fildes: c_int, iov: c_ptr[iovec], iovcnt: c_int, offset: off_t
) -> c_ssize_t:
    """Libc POSIX `preadv` function.

    Args:
        fildes: A File Descriptor to open the file with.
        iov: The pieces to fill, `iovcnt` of them, each one a buffer and
            how much of it to read into.
        iovcnt: How many pieces there are, which is at most 1024.
        offset: Where in the file to read from, counted in bytes from the
            start. Where the stream was is left alone, as with `pread`.

    Returns:
        How many bytes were read in total across the pieces, which is
        fewer than were asked for at the end of the file, or -1 on
        failure with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/readv.3p.html).
        Fn signature: `ssize_t preadv(int fd, const struct iovec *iov,
            int iovcnt, off_t offset)`.

        `pread` across several buffers at once: the pieces are filled in
        the order they are given, and the total is one number rather than
        one per piece, so a caller adds up the lengths and compares.

        It is the newer half of the header and `readv` is the older one;
        Darwin has had it only since 11.0, which is late enough that a
        header of its own from before then does not declare it at all.
    """
    return external_call[
        "preadv", c_ssize_t, c_int, c_ptr[iovec], c_int, off_t
    ](fildes, iov, iovcnt, offset)


def pwritev(
    fildes: c_int, iov: c_ptr[iovec], iovcnt: c_int, offset: off_t
) -> c_ssize_t:
    """Libc POSIX `pwritev` function.

    Args:
        fildes: A File Descriptor to open the file with.
        iov: The pieces to write, `iovcnt` of them, each one a buffer and
            how much of it to write.
        iovcnt: How many pieces there are, which is at most 1024.
        offset: Where in the file to write, counted in bytes from the
            start. Where the stream was is left alone, as with `pwrite`.

    Returns:
        How many bytes were written in total across the pieces, or -1 on
        failure with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/writev.3p.html).
        Fn signature: `ssize_t pwritev(int fd, const struct iovec *iov,
            int iovcnt, off_t offset)`.

        Writing past the end of the file leaves a hole, and the hole
        reads back as zeroes — nothing here fills it in, and nothing
        reports that it was made.
    """
    return external_call[
        "pwritev", c_ssize_t, c_int, c_ptr[iovec], c_int, off_t
    ](fildes, iov, iovcnt, offset)


def fclose(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `fclose` function.

    Args:
        stream: A pointer to a stream.

    Returns:
    0, or `EOF` on failure with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fclose.3p.html).
        Fn signature: `int fclose(FILE *stream)`.

        `std.io` emits its own `fclose` declaration, and a second
        `external_call` for the same symbol that takes a `Pointer` fails
        to lower with "existing function with conflicting signature".
        Passing the address as an `Int` keeps one declaration; an address
        and an `Int` are both 8 bytes in an integer register on every ABI
        this package targets, so the call is still ABI-compatible.
    """
    return external_call["fclose", c_int, Int](Int(stream))


def ftell(stream: c_ptr[FILE]) -> c_long:
    """Libc POSIX `ftell` function.

    Args:
        stream: A pointer to a stream.

    Returns:
        The current file position of the given stream.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ftell.3p.html).
        Fn signature: `long ftell(FILE *stream)`.
    """
    return external_call["ftell", c_long, c_ptr[FILE]](stream)


def ftello(stream: c_ptr[FILE]) -> off_t:
    """Libc POSIX `ftello` function.

    Args:
        stream: A pointer to a stream.

    Returns:
        The current file position of the given stream.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ftell.3p.html).
        Fn signature: `off_t ftello(FILE *stream)`.
    """
    return external_call["ftello", off_t, c_ptr[FILE]](stream)


def clearerr(stream: c_ptr[FILE]) -> c_void:
    """Libc POSIX `clearerr` function.

    Args:
        stream: A pointer to a stream.

    Returns:
        Nothing: C declares this one `void`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/clearerr.3p.html).
        Fn signature: `void clearerr(FILE *stream)`.
    """
    return external_call["clearerr", c_void, c_ptr[FILE]](stream)


def feof(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `feof` function.

    Args:
        stream: A pointer to a stream.

    Returns:
        1 if the end-of-file indicator associated with the stream is set,
            else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feof.3p.html).
        Fn signature: `int feof(FILE *stream)`.
    """
    return external_call["feof", c_int, c_ptr[FILE]](stream)


def ferror(stream: c_ptr[FILE]) -> c_int:
    """Libc POSIX `ferror` function.

    Args:
        stream: A pointer to a stream.

    Returns:
        1 if the error indicator associated with the stream is set, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ferror.3p.html).
        Fn signature: `int ferror(FILE *stream)`.
    """
    return external_call["ferror", c_int, c_ptr[FILE]](stream)


def ioctl(fildes: c_int, request: c_ulong) -> c_int:
    """Libc POSIX `ioctl` function, bound without the argument it asks about.

    Args:
        fildes: A File Descriptor to ask something of.
        request: What to ask. Each thing that answers to `ioctl` has its
            own set of these, and they are numbers written down in
            `<sys/ioctl.h>`: there is no saying what one means without
            knowing what it is being asked of.

    Returns:
        0, or -1 with `errno` set, for the requests that answer with
        whether they worked. What comes back is up to the request, and
        some hand back a value of their own.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ioctl.3p.html).
        Fn signature: `int ioctl(int fildes, unsigned long request, ...)`.

        C's third parameter is the variadic one, it is a `void *`, and it
        is where nearly every request puts its answer. It cannot be passed
        from here: `external_call` emits a call whose arguments are all in
        registers, and Apple's arm64 ABI hands a variadic function its
        anonymous arguments on the stack instead, so the callee reads a
        slot nobody wrote. That is the same wall `open` is bound around by
        being `openat` here. `FIONREAD` through this form answers 0 on
        Apple silicon and leaves the integer it was asked about untouched,
        which is why the calls that carry an address are not bound at all.

        What is left is the requests that take no argument of their own --
        `TIOCNOTTY` is one -- where there is no third thing to be lost.
    """
    return external_call["ioctl", c_int, c_int, c_ulong](fildes, request)
