# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from libc.constant import *
from libc.locale import locale_t


@inline(.nodebug)
def islower(c: Int32) -> Int32:
    """Libc POSIX `islower` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a lower-case letter in the locale this thread is using,
            and 0 when it is not. It is 1 on some systems and other numbers on
            others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/islower.3.html).
        Fn signature: `int islower(int c)`.
    """
    return external_call["islower", Int32](c)


@inline(.nodebug)
def islower_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `islower_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a lower-case letter in `loc`, and 0 when it is not. It
            is 1 on some systems and other numbers on others, so ask whether it
            is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/islower_l.3.html).
        Fn signature: `int islower_l(int c, locale_t loc)`.
    """
    return external_call["islower_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isupper(c: Int32) -> Int32:
    """Libc POSIX `isupper` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is an upper-case letter in the locale this thread is
            using, and 0 when it is not. It is 1 on some systems and other
            numbers on others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isupper.3.html).
        Fn signature: `int isupper(int c)`.
    """
    return external_call["isupper", Int32](c)


@inline(.nodebug)
def isupper_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isupper_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is an upper-case letter in `loc`, and 0 when it is not. It
            is 1 on some systems and other numbers on others, so ask whether it
            is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isupper_l.3.html).
        Fn signature: `int isupper_l(int c, locale_t loc)`.
    """
    return external_call["isupper_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isalpha(c: Int32) -> Int32:
    """Libc POSIX `isalpha` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a letter in the locale this thread is using, and 0 when
            it is not. It is 1 on some systems and other numbers on others, so
            ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isalpha.3.html).
        Fn signature: `int isalpha(int c)`.
    """
    return external_call["isalpha", Int32](c)


@inline(.nodebug)
def isdigit(c: Int32) -> Int32:
    """Libc POSIX `isdigit` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a decimal digit, which is to say one of 0 to 9 and not
            the other digits other locales write in the locale this thread is
            using, and 0 when it is not. It is 1 on some systems and other
            numbers on others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isdigit.3.html).
        Fn signature: `int isdigit(int c)`.
    """
    return external_call["isdigit", Int32](c)


@inline(.nodebug)
def isdigit_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isdigit_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a decimal digit, which is to say one of 0 to 9 and not
            the other digits other locales write in `loc`, and 0 when it is not.
            It is 1 on some systems and other numbers on others, so ask whether
            it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isdigit_l.3.html).
        Fn signature: `int isdigit_l(int c, locale_t loc)`.
    """
    return external_call["isdigit_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isalnum(c: Int32) -> Int32:
    """Libc POSIX `isalnum` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a letter or a digit in the locale this thread is using,
            and 0 when it is not. It is 1 on some systems and other numbers on
            others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isalnum.3.html).
        Fn signature: `int isalnum(int c)`.
    """
    return external_call["isalnum", Int32](c)


@inline(.nodebug)
def isalnum_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isalnum_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a letter or a digit in `loc`, and 0 when it is not. It
            is 1 on some systems and other numbers on others, so ask whether it
            is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isalnum_l.3.html).
        Fn signature: `int isalnum_l(int c, locale_t loc)`.
    """
    return external_call["isalnum_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isxdigit(c: Int32) -> Int32:
    """Libc POSIX `isxdigit` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a digit of hexadecimal, so 0 to 9, a to f or A to F in
            the locale this thread is using, and 0 when it is not. It is 1 on
            some systems and other numbers on others, so ask whether it is 0 and
            not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isxdigit.3.html).
        Fn signature: `int isxdigit(int c)`.
    """
    return external_call["isxdigit", Int32](c)


@inline(.nodebug)
def isxdigit_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isxdigit_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a digit of hexadecimal, so 0 to 9, a to f or A to F in
            `loc`, and 0 when it is not. It is 1 on some systems and other
            numbers on others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isxdigit_l.3.html).
        Fn signature: `int isxdigit_l(int c, locale_t loc)`.
    """
    return external_call["isxdigit_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isspace(c: Int32) -> Int32:
    """Libc POSIX `isspace` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is white space: a space, a tab, a newline, a carriage
            return, a form feed or a vertical tab in the locale this thread is
            using, and 0 when it is not. It is 1 on some systems and other
            numbers on others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isspace.3.html).
        Fn signature: `int isspace(int c)`.
    """
    return external_call["isspace", Int32](c)


@inline(.nodebug)
def isblank(c: Int32) -> Int32:
    """Libc POSIX `isblank` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a blank, which is a space or a tab and nothing else in
            the locale this thread is using, and 0 when it is not. It is 1 on
            some systems and other numbers on others, so ask whether it is 0 and
            not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isblank.3.html).
        Fn signature: `int isblank(int c)`.
    """
    return external_call["isblank", Int32](c)


@inline(.nodebug)
def isblank_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isblank_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a blank, which is a space or a tab and nothing else in
            `loc`, and 0 when it is not. It is 1 on some systems and other
            numbers on others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isblank_l.3.html).
        Fn signature: `int isblank_l(int c, locale_t loc)`.
    """
    return external_call["isblank_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def iscntrl(c: Int32) -> Int32:
    """Libc POSIX `iscntrl` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a control character in the locale this thread is using,
            and 0 when it is not. It is 1 on some systems and other numbers on
            others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iscntrl.3.html).
        Fn signature: `int iscntrl(int c)`.
    """
    return external_call["iscntrl", Int32](c)


@inline(.nodebug)
def iscntrl_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `iscntrl_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a control character in `loc`, and 0 when it is not. It
            is 1 on some systems and other numbers on others, so ask whether it
            is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iscntrl_l.3.html).
        Fn signature: `int iscntrl_l(int c, locale_t loc)`.
    """
    return external_call["iscntrl_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isgraph(c: Int32) -> Int32:
    """Libc POSIX `isgraph` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a character that prints and is not a space in the
            locale this thread is using, and 0 when it is not. It is 1 on some
            systems and other numbers on others, so ask whether it is 0 and not
            whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isgraph.3.html).
        Fn signature: `int isgraph(int c)`.
    """
    return external_call["isgraph", Int32](c)


@inline(.nodebug)
def isgraph_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isgraph_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a character that prints and is not a space in `loc`,
            and 0 when it is not. It is 1 on some systems and other numbers on
            others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isgraph_l.3.html).
        Fn signature: `int isgraph_l(int c, locale_t loc)`.
    """
    return external_call["isgraph_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isascii(c: Int32) -> Int32:
    """Libc POSIX `isascii` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is an ASCII character, which is one below 128 in the
            locale this thread is using, and 0 when it is not. It is 1 on some
            systems and other numbers on others, so ask whether it is 0 and not
            whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isascii.3.html).
        Fn signature: `int isascii(int c)`.
    """
    return external_call["isascii", Int32](c)


@inline(.nodebug)
def isascii_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isascii_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is an ASCII character, which is one below 128 in `loc`,
            and 0 when it is not. It is 1 on some systems and other numbers on
            others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isascii_l.3.html).
        Fn signature: `int isascii_l(int c, locale_t loc)`.
    """
    return external_call["isascii_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isprint(c: Int32) -> Int32:
    """Libc POSIX `isprint` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is a character that prints, the space included in the
            locale this thread is using, and 0 when it is not. It is 1 on some
            systems and other numbers on others, so ask whether it is 0 and not
            whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isprint.3.html).
        Fn signature: `int isprint(int c)`.
    """
    return external_call["isprint", Int32](c)


@inline(.nodebug)
def isprint_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `isprint_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is a character that prints, the space included in `loc`,
            and 0 when it is not. It is 1 on some systems and other numbers on
            others, so ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/isprint_l.3.html).
        Fn signature: `int isprint_l(int c, locale_t loc)`.
    """
    return external_call["isprint_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def ispunct(c: Int32) -> Int32:
    """Libc POSIX `ispunct` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.

    Returns:
        Not 0 when it is punctuation: it prints, is not a space, and is neither
            a letter nor a digit in the locale this thread is using, and 0 when
            it is not. It is 1 on some systems and other numbers on others, so
            ask whether it is 0 and not whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ispunct.3.html).
        Fn signature: `int ispunct(int c)`.
    """
    return external_call["ispunct", Int32](c)


@inline(.nodebug)
def ispunct_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `ispunct_l` function.

    Args:
        c: The character to ask about. It has to be either what an `unsigned
            char` holds or `EOF`: anything else, a negative number in
            particular, is not something C promises to answer for.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        Not 0 when it is punctuation: it prints, is not a space, and is neither
            a letter nor a digit in `loc`, and 0 when it is not. It is 1 on some
            systems and other numbers on others, so ask whether it is 0 and not
            whether it is 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ispunct_l.3.html).
        Fn signature: `int ispunct_l(int c, locale_t loc)`.
    """
    return external_call["ispunct_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def tolower(c: Int32) -> Int32:
    """Libc POSIX `tolower` function.

    Args:
        c: The character to convert, which has to be either what an `unsigned
            char` holds or `EOF`, for the reason the ones that only ask have.

    Returns:
        The lower case of it, or the same character back when there is no lower
            case of it, which is anything that is not an upper-case letter, in
            the locale this thread is using.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/tolower.3.html).
        Fn signature: `int tolower(int c)`.
    """
    return external_call["tolower", Int32](c)


@inline(.nodebug)
def tolower_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `tolower_l` function.

    Args:
        c: The character to convert, which has to be either what an `unsigned
            char` holds or `EOF`, for the reason the ones that only ask have.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        The lower case of it, or the same character back when there is no lower
            case of it, which is anything that is not an upper-case letter, in
            `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/tolower_l.3.html).
        Fn signature: `int tolower_l(int c, locale_t loc)`.
    """
    return external_call["tolower_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def toupper(c: Int32) -> Int32:
    """Libc POSIX `toupper` function.

    Args:
        c: The character to convert, which has to be either what an `unsigned
            char` holds or `EOF`, for the reason the ones that only ask have.

    Returns:
        The upper case of it, or the same character back when there is no upper
            case of it, which is anything that is not a lower-case letter, in
            the locale this thread is using.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/toupper.3.html).
        Fn signature: `int toupper(int c)`.
    """
    return external_call["toupper", Int32](c)


@inline(.nodebug)
def toupper_l(c: Int32, loc: locale_t) -> Int32:
    """Libc POSIX `toupper_l` function.

    Args:
        c: The character to convert, which has to be either what an `unsigned
            char` holds or `EOF`, for the reason the ones that only ask have.
        loc: The locale to answer for, rather than the one the thread is in. It
            is a `locale_t` from `newlocale`; `uselocale` is how the thread's
            own is changed.

    Returns:
        The upper case of it, or the same character back when there is no upper
            case of it, which is anything that is not a lower-case letter, in
            `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/toupper_l.3.html).
        Fn signature: `int toupper_l(int c, locale_t loc)`.
    """
    return external_call["toupper_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def toascii(c: Int32) -> Int32:
    return external_call["toascii", Int32](c)
