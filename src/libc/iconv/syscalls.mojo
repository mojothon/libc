# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr


# A C `iconv_t`: an open conversion, which is a `void *` on both
# platforms. Note the one that is *not* how it fails: an encoding
# `iconv_open` does not know is `(iconv_t) -1`, not NULL, so
# `is_null` is the wrong question to ask of it.
comptime iconv_t = c_ptr[UInt8]


def iconv_open(tocode: c_ptr[UInt8], fromcode: c_ptr[UInt8]) -> iconv_t:
    """C library <iconv.h> function `iconv_open`.

    Reference:
        https://man7.org/linux/man-pages/man3/iconv_open.3.html

    Description:
        Opens a conversion from one character encoding to another: UTF-8
        to ASCII, ISO-8859-1 to UTF-8, and so on for every encoding the
        implementation knows the name of. The conversion is asked for by
        name both ways round, and a name either platform understands is
        `UTF-8`, `ASCII`, `ISO-8859-1` and `UTF-16`.

    Args:
        tocode: The encoding to convert to, NUL terminated, from
            `string_to_char_ptr`.
        fromcode: The encoding to convert from, likewise. The order is
            destination first, which is the way round `iconv` writes it
            and the opposite of the way most people say it.

    Returns:
        The conversion, or `(iconv_t) -1` with `errno` set to `EINVAL`
        when one of the names is not one libc knows. Note the failure is
        -1 and not NULL, so `is_null` is not how to ask; compare the
        address against -1.

    Notes:
        Fn signature:
        `iconv_t iconv_open(const char *tocode, const char *fromcode)`.

        The same encoding both ways round is a conversion that copies,
        which is what a test that wants a known answer uses.

        glibc's `iconv` is in libc itself and XNU's is GNU libiconv
        wearing the same names, so the two agree on the calls and differ
        only in which encodings they have.
    """
    return external_call["iconv_open", iconv_t, c_ptr[UInt8], c_ptr[UInt8]](
        tocode, fromcode
    )


def iconv(
    cd: iconv_t,
    inbuf: c_ptr[c_ptr[UInt8]],
    inbytesleft: c_ptr[UInt64],
    outbuf: c_ptr[c_ptr[UInt8]],
    outbytesleft: c_ptr[UInt64],
) -> UInt64:
    """C library <iconv.h> function `iconv`.

    Reference:
        https://man7.org/linux/man-pages/man3/iconv.3.html

    Description:
        Converts as much of the input as will fit in the output, and
        says how much it could not. Every argument but the conversion is
        a pointer to something of the caller's, and all four are moved
        along by the call: the two pointers and the two counts come back
        describing what is left, so a conversion too big for one call is
        done in as many as it takes.

    Args:
        cd: The conversion, as `iconv_open` gave it.
        inbuf: Where the input pointer lives. It is the address of the
            caller's `char *`, and it is advanced by however much was
            converted — not the bytes themselves.
        inbytesleft: Where the count of bytes not yet converted lives.
        outbuf: Where the output pointer lives, likewise advanced.
        outbytesleft: Where the count of bytes still free in the output
            lives, likewise reduced.

    Returns:
        How many characters were converted irreversibly, which is 0 for
        any conversion that is one-to-one, or `(size_t) -1` with `errno`
        set when it stopped short: `E2BIG` for an output too small,
        `EILSEQ` for a byte that means nothing in the encoding it is
        being read as, `EINVAL` for an incomplete sequence at the end of
        the input.

    Notes:
        Fn signature:
        `size_t iconv(iconv_t cd, char **restrict inbuf, size_t *restrict inbytesleft, char **restrict outbuf, size_t *restrict outbytesleft)`.

        What it writes is not NUL terminated: the output is `outbytesleft`
        shorter than it was, so put the terminator in yourself, or keep
        the count.

        The conversion keeps state between calls, so one that ends with
        `EINVAL` on a truncated multibyte character wants the rest of it
        next time rather than a fresh start; `iconv_open` again is how to
        go back to the beginning.
    """
    return external_call[
        "iconv",
        UInt64,
        iconv_t,
        c_ptr[c_ptr[UInt8]],
        c_ptr[UInt64],
        c_ptr[c_ptr[UInt8]],
        c_ptr[UInt64],
    ](cd, inbuf, inbytesleft, outbuf, outbytesleft)


def iconv_close(cd: iconv_t) -> Int32:
    """C library <iconv.h> function `iconv_close`.

    Reference:
        https://man7.org/linux/man-pages/man3/iconv_open.3.html

    Args:
        cd: The conversion to release. Nothing of it is good afterwards,
            and the bytes it converted already are untouched by this.

    Returns:
        0, or -1 with `errno` set if the release failed.
    """
    return external_call["iconv_close", Int32, iconv_t](cd)
