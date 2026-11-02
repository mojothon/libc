# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from std.sys import CompilationTarget

from libc.constant import (
    c_int,
    c_longlong,
    c_ptr,
    c_size_t,
    c_ulonglong,
    c_wchar,
    c_wint,
)
from libc.file import FILE
from libc.locale import locale_t
from libc.time import tm


struct mbstate_t:
    """An opaque C `mbstate_t`: the shift state a multibyte conversion
    carries between calls.

    The real struct is 8 bytes on glibc and 128 on Darwin, so this one
    holds the platform's own size and only ever travels by pointer. Zero
    it and it is the initial state, which is what `memset` gives you.

    The size is the platform's rather than the larger of the two because
    the conversion calls write the state through the pointer they are
    handed: `mbrtowc`, `wcrtomb` and `mbrlen` all take one, and handing
    C a block shorter than the one it writes runs off the end of it.
    """

    comptime MBSTATE_SLOTS = 16 if CompilationTarget.is_macos() else 4

    var _opaque: Array[UInt64, Self.MBSTATE_SLOTS]

    def __init__(out self):
        """Zeroes the state, which is the initial state."""
        self._opaque = Array[UInt64, Self.MBSTATE_SLOTS](fill=0)


def wcslen(s: c_ptr[c_wchar]) -> c_size_t:
    """Libc C95 `wcslen` function.

    Args:
        s: A wide string.

    Returns:
        How many wide characters precede the terminating null.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcslen.3.html).
        Fn signature: `size_t wcslen(const wchar_t *s)`.
    """
    return external_call["wcslen", c_size_t, c_ptr[c_wchar]](s)


def wcscmp(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar]) -> c_int:
    """Libc C95 `wcscmp` function.

    Args:
        s1: The first wide string.
        s2: The second wide string.

    Returns:
        A negative, zero or positive value as `s1` sorts before, with, or
        after `s2`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscmp.3.html).
        Fn signature: `int wcscmp(const wchar_t *s1, const wchar_t *s2)`.
    """
    return external_call["wcscmp", c_int, c_ptr[c_wchar], c_ptr[c_wchar]](
        s1, s2
    )


def wcsncmp(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar], n: c_size_t) -> c_int:
    """Libc C95 `wcsncmp` function.

    Args:
        s1: The first wide string.
        s2: The second wide string.
        n: How many wide characters to compare at most.

    Returns:
        A negative, zero or positive value, as with `wcscmp`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscmp.3.html).
        Fn signature: `int wcsncmp(const wchar_t *s1, const wchar_t *s2, size_t n)`.
    """
    return external_call[
        "wcsncmp", c_int, c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](s1, s2, n)


def wcscpy(dest: c_ptr[c_wchar], src: c_ptr[c_wchar]) -> c_ptr[c_wchar]:
    """Libc C95 `wcscpy` function.

    Args:
        dest: Where to copy, with room for the source plus its null.
        src: The wide string to copy.

    Returns:
        `dest`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscpy.3.html).
        Fn signature: `wchar_t *wcscpy(wchar_t *dest, const wchar_t *src)`.

        `dest` must be large enough; there is no length limit here.
    """
    return external_call[
        "wcscpy", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar]
    ](dest, src)


def wcsncpy(
    dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t
) -> c_ptr[c_wchar]:
    """Libc C95 `wcsncpy` function.

    Args:
        dest: Where to copy.
        src: The wide string to copy.
        n: How many wide characters `dest` holds.

    Returns:
        `dest`. Shorter than `src` means no null terminator gets written.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscpy.3.html).
        Fn signature: `wchar_t *wcsncpy(wchar_t *dest, const wchar_t *src, size_t n)`.
    """
    return external_call[
        "wcsncpy", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def wcscat(dest: c_ptr[c_wchar], src: c_ptr[c_wchar]) -> c_ptr[c_wchar]:
    """Libc C95 `wcscat` function.

    Args:
        dest: A wide string with room for `src` appended.
        src: The wide string to append.

    Returns:
        `dest`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscat.3.html).
        Fn signature: `wchar_t *wcscat(wchar_t *dest, const wchar_t *src)`.
    """
    return external_call[
        "wcscat", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar]
    ](dest, src)


def wcschr(s: c_ptr[c_wchar], wc: c_wchar) -> c_ptr[c_wchar]:
    """Libc C95 `wcschr` function.

    Args:
        s: The wide string to scan.
        wc: The wide character to look for.

    Returns:
        A pointer to the first match, or a null pointer if there is none.
        Looking for 0 finds the terminating null.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcschr.3.html).
        Fn signature: `wchar_t *wcschr(const wchar_t *s, wchar_t wc)`.
    """
    return external_call["wcschr", c_ptr[c_wchar], c_ptr[c_wchar], c_wchar](
        s, wc
    )


def wcsrchr(s: c_ptr[c_wchar], wc: c_wchar) -> c_ptr[c_wchar]:
    """Libc C95 `wcsrchr` function.

    Args:
        s: The wide string to scan.
        wc: The wide character to look for.

    Returns:
        A pointer to the last match, or a null pointer if there is none.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcschr.3.html).
        Fn signature: `wchar_t *wcsrchr(const wchar_t *s, wchar_t wc)`.
    """
    return external_call["wcsrchr", c_ptr[c_wchar], c_ptr[c_wchar], c_wchar](
        s, wc
    )


def wcsstr(haystack: c_ptr[c_wchar], needle: c_ptr[c_wchar]) -> c_ptr[c_wchar]:
    """Libc C99 `wcsstr` function.

    Args:
        haystack: The wide string to search.
        needle: The wide substring to look for.

    Returns:
        A pointer into `haystack` where `needle` starts, or a null pointer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsstr.3.html).
        Fn signature: `wchar_t *wcsstr(const wchar_t *haystack, const wchar_t *needle)`.
    """
    return external_call[
        "wcsstr", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar]
    ](haystack, needle)


def wcsspn(s: c_ptr[c_wchar], accept: c_ptr[c_wchar]) -> c_size_t:
    """Libc C95 `wcsspn` function.

    Args:
        s: The wide string to measure.
        accept: The wide characters that count.

    Returns:
        How many leading wide characters of `s` are all in `accept`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsspn.3.html).
        Fn signature: `size_t wcsspn(const wchar_t *s, const wchar_t *accept)`.
    """
    return external_call["wcsspn", c_size_t, c_ptr[c_wchar], c_ptr[c_wchar]](
        s, accept
    )


def wcscspn(s: c_ptr[c_wchar], reject: c_ptr[c_wchar]) -> c_size_t:
    """Libc C95 `wcscspn` function.

    Args:
        s: The wide string to measure.
        reject: The wide characters that stop the count.

    Returns:
        How many leading wide characters of `s` are none of `reject`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsspn.3.html).
        Fn signature: `size_t wcscspn(const wchar_t *s, const wchar_t *reject)`.
    """
    return external_call["wcscspn", c_size_t, c_ptr[c_wchar], c_ptr[c_wchar]](
        s, reject
    )


def mbstowcs(dest: c_ptr[c_wchar], src: c_ptr[UInt8], n: c_size_t) -> c_size_t:
    """Libc C89 `mbstowcs` function.

    Args:
        dest: Where to write the wide string, or a null pointer to only
            measure.
        src: The multibyte string to convert.
        n: How many wide characters `dest` holds.

    Returns:
        The number of wide characters written, excluding the null, or
        `(size_t) -1` if `src` is not valid multibyte in the current locale.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbstowcs.3.html).
        Fn signature: `size_t mbstowcs(wchar_t *dest, const char *src, size_t n)`.

        The result depends on `LC_CTYPE`; under the default `C` locale this
        is a byte for byte copy of ASCII.
    """
    return external_call[
        "mbstowcs", c_size_t, c_ptr[c_wchar], c_ptr[UInt8], c_size_t
    ](dest, src, n)


def wcstombs(dest: c_ptr[UInt8], src: c_ptr[c_wchar], n: c_size_t) -> c_size_t:
    """Libc C89 `wcstombs` function.

    Args:
        dest: Where to write the multibyte string, or a null pointer to only
            measure.
        src: The wide string to convert.
        n: How many bytes `dest` holds.

    Returns:
        The number of bytes written, excluding the null, or `(size_t) -1` if
        a wide character has no multibyte form in the current locale.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstombs.3.html).
        Fn signature: `size_t wcstombs(char *dest, const wchar_t *src, size_t n)`.
    """
    return external_call[
        "wcstombs", c_size_t, c_ptr[UInt8], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def mbrtowc(
    pwc: c_ptr[c_wchar], s: c_ptr[UInt8], n: c_size_t, ps: c_ptr[mbstate_t]
) -> c_size_t:
    """Libc C95 `mbrtowc` function.

    Args:
        pwc: Where to write the wide character, or a null pointer to only
            measure.
        s: The multibyte string to read.
        n: How many bytes of `s` are available.
        ps: The shift state to carry, or a null pointer to use the library's
            own.

    Returns:
        The number of bytes consumed, 0 if the character was the null one, or
        `(size_t) -1` with `EILSEQ` if the bytes are invalid.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbrtowc.3.html).
        Fn signature: `size_t mbrtowc(wchar_t *pwc, const char *s, size_t n, mbstate_t *ps)`.
    """
    return external_call[
        "mbrtowc",
        c_size_t,
        c_ptr[c_wchar],
        c_ptr[UInt8],
        c_size_t,
        c_ptr[mbstate_t],
    ](pwc, s, n, ps)


def wcrtomb(s: c_ptr[UInt8], wc: c_wchar, ps: c_ptr[mbstate_t]) -> c_size_t:
    """Libc C95 `wcrtomb` function.

    Args:
        s: Where to write the multibyte form, or a null pointer to reset the
            state.
        wc: The wide character to convert.
        ps: The shift state to carry, or a null pointer to use the library's
            own.

    Returns:
        The number of bytes written, or `(size_t) -1` with `EILSEQ` if `wc`
        has no multibyte form.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcrtomb.3.html).
        Fn signature: `size_t wcrtomb(char *s, wchar_t wc, mbstate_t *ps)`.
    """
    return external_call[
        "wcrtomb", c_size_t, c_ptr[UInt8], c_wchar, c_ptr[mbstate_t]
    ](s, wc, ps)


def mbrlen(s: c_ptr[UInt8], n: c_size_t, ps: c_ptr[mbstate_t]) -> c_size_t:
    """Libc C95 `mbrlen` function.

    Args:
        s: The multibyte string to read.
        n: How many bytes of `s` are available.
        ps: The shift state to carry, or a null pointer to use the library's
            own.

    Returns:
        The number of bytes in the next multibyte character, 0 if it is the
        null one, or `(size_t) -1` with `EILSEQ` if the bytes are invalid.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbrlen.3.html).
        Fn signature: `size_t mbrlen(const char *s, size_t n, mbstate_t *ps)`.
    """
    return external_call[
        "mbrlen", c_size_t, c_ptr[UInt8], c_size_t, c_ptr[mbstate_t]
    ](s, n, ps)


def iswalpha(wc: c_wint) -> c_int:
    """Libc C95 `iswalpha` function.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if `wc` is a letter under `LC_CTYPE`, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswalpha.3.html).
        Fn signature: `int iswalpha(wint_t wc)`.
    """
    return external_call["iswalpha", c_int, c_wint](wc)


def iswalnum(wc: c_wint) -> c_int:
    """Libc C95 `iswalnum` function.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if `wc` is a letter or a digit under `LC_CTYPE`, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswalnum.3.html).
        Fn signature: `int iswalnum(wint_t wc)`.
    """
    return external_call["iswalnum", c_int, c_wint](wc)


def iswdigit(wc: c_wint) -> c_int:
    """Libc C95 `iswdigit` function.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if `wc` is a decimal digit, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswdigit.3.html).
        Fn signature: `int iswdigit(wint_t wc)`.
    """
    return external_call["iswdigit", c_int, c_wint](wc)


def iswspace(wc: c_wint) -> c_int:
    """Libc C95 `iswspace` function.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if `wc` is whitespace under `LC_CTYPE`, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswspace.3.html).
        Fn signature: `int iswspace(wint_t wc)`.
    """
    return external_call["iswspace", c_int, c_wint](wc)


def iswupper(wc: c_wint) -> c_int:
    """Libc C95 `iswupper` function.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if `wc` is an upper case letter, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswupper.3.html).
        Fn signature: `int iswupper(wint_t wc)`.
    """
    return external_call["iswupper", c_int, c_wint](wc)


def iswlower(wc: c_wint) -> c_int:
    """Libc C95 `iswlower` function.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if `wc` is a lower case letter, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswlower.3.html).
        Fn signature: `int iswlower(wint_t wc)`.
    """
    return external_call["iswlower", c_int, c_wint](wc)


def towupper(wc: c_wint) -> c_wint:
    """Libc C95 `towupper` function.

    Args:
        wc: A wide character.

    Returns:
        The upper case form of `wc`, or `wc` itself if it has none.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/towupper.3.html).
        Fn signature: `wint_t towupper(wint_t wc)`.
    """
    return external_call["towupper", c_wint, c_wint](wc)


def towlower(wc: c_wint) -> c_wint:
    """Libc C95 `towlower` function.

    Args:
        wc: A wide character.

    Returns:
        The lower case form of `wc`, or `wc` itself if it has none.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/towlower.3.html).
        Fn signature: `wint_t towlower(wint_t wc)`.
    """
    return external_call["towlower", c_wint, c_wint](wc)


def btowc(c: Int32) -> Int32:
    """C library <wchar.h> function `btowc`.

    Reference:
        https://man7.org/linux/man-pages/man3/btowc.3.html

    Description:
        btowc() converts a single byte character to a wide character.

    Args:
        c: An integer representing a single byte character.

    Returns:
        A wide character.
    """
    return external_call["btowc", Int32, Int32](c)


def wctob(wc: Int32) -> Int32:
    """C library <wchar.h> function `wctob`.

    Reference:
        https://man7.org/linux/man-pages/man3/wctob.3.html

    Description:
        wctob() converts a wide character to a single byte character.

    Args:
        wc: A wide character.

    Returns:
        An integer representing a single byte character.
    """
    return external_call["wctob", Int32, Int32](wc)


def iswblank(wc: c_wint) -> c_int:
    """Libc C99 `iswblank` function.

    Description:
        Says whether `wc` is a blank — a space or a tab, the two that
        separate words within a line.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if it is one, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswblank.3.html).
        Fn signature: `int iswblank(wint_t wc)`.

        Blank is not the same as space: a newline and a form feed are
        space and are not blank, which is the pair this one is for.
        It is C99, and the older `iswspace` is the one to ask about
        any of the lot.
    """
    return external_call["iswblank", c_int, c_wint](wc)


def iswcntrl(wc: c_wint) -> c_int:
    """Libc C95 `iswcntrl` function.

    Description:
        Says whether `wc` is a control character, which is to say one
        that is not printed but does something to the output.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if it is one, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswcntrl.3.html).
        Fn signature: `int iswcntrl(wint_t wc)`.

        A tab and a newline are control characters. A space is not,
        being printable; it is `iswblank` and `iswspace` that say so
        of it.
    """
    return external_call["iswcntrl", c_int, c_wint](wc)


def iswgraph(wc: c_wint) -> c_int:
    """Libc C95 `iswgraph` function.

    Description:
        Says whether `wc` has a glyph, a space being the one printable
        character that does not.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if it has one, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswgraph.3.html).
        Fn signature: `int iswgraph(wint_t wc)`.

        Graph and print differ in this one character: every printable
        character but the space is a graph, and asking the two about
        a space is how the pair is told apart.
    """
    return external_call["iswgraph", c_int, c_wint](wc)


def iswprint(wc: c_wint) -> c_int:
    """Libc C95 `iswprint` function.

    Description:
        Says whether `wc` is printable, the space included.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if it is, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswprint.3.html).
        Fn signature: `int iswprint(wint_t wc)`.

        Printable here is the opposite of control, and the two do not
        quite divide everything between them on every locale.
    """
    return external_call["iswprint", c_int, c_wint](wc)


def iswpunct(wc: c_wint) -> c_int:
    """Libc C95 `iswpunct` function.

    Description:
        Says whether `wc` is punctuation: printable, and neither a
        letter, a digit nor a space.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if it is, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswpunct.3.html).
        Fn signature: `int iswpunct(wint_t wc)`.
    """
    return external_call["iswpunct", c_int, c_wint](wc)


def iswxdigit(wc: c_wint) -> c_int:
    """Libc C95 `iswxdigit` function.

    Description:
        Says whether `wc` is a hexadecimal digit.

    Args:
        wc: A wide character.

    Returns:
        Non-zero if it is one, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/iswxdigit.3.html).
        Fn signature: `int iswxdigit(wint_t wc)`.

        A hexadecimal digit is wider than a decimal one by six
        letters, `a` through `f` and `A` through `F`, so asking about
        `g` is what tells this one from `iswdigit`.
    """
    return external_call["iswxdigit", c_int, c_wint](wc)


# `WEOF` is the wide character that is not one: what a read hands back
# when there is nothing left to read. It is `(wint_t)-1` on both
# platforms, which is the one thing about it that is not left to them.
comptime WEOF: Int32 = -1


def fgetwc(stream: c_ptr[FILE]) -> c_wint:
    """Libc C95 `fgetwc` function.

    Description:
        Reads one wide character from a stream.

    Args:
        stream: The stream to read from.

    Returns:
        The character, or `WEOF` at the end of it or on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fgetwc.3.html).
        Fn signature: `wint_t fgetwc(FILE *stream)`.

        Which of the two it was — the end or a mistake — is what
        `ferror` and `feof` are for asking about.
    """
    return external_call["fgetwc", c_wint, c_ptr[FILE]](stream)


def getwc(stream: c_ptr[FILE]) -> c_wint:
    """Libc C95 `getwc` function.

    Description:
        Reads one wide character from a stream.

    Args:
        stream: The stream to read from.

    Returns:
        The character, or `WEOF` at the end of it or on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getwc.3.html).
        Fn signature: `wint_t getwc(FILE *stream)`.

        The same call as `fgetwc`, kept because C has it as a macro
        that may take its argument more than once, where this one
        does not. A stream with something to say about it either way.
    """
    return external_call["getwc", c_wint, c_ptr[FILE]](stream)


def getwchar() -> c_wint:
    """Libc C95 `getwchar` function.

    Description:
        Reads one wide character from standard input.

    Returns:
        The character, or `WEOF` at the end of it or on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getwchar.3.html).
        Fn signature: `wint_t getwchar(void)`.

        Bound and not called: what comes in on standard input is not
        a test's to say, and a test that asked would wait.
    """
    return external_call["getwchar", c_wint]()


def fputwc(wc: c_wchar, stream: c_ptr[FILE]) -> c_wint:
    """Libc C95 `fputwc` function.

    Description:
        Writes one wide character to a stream.

    Args:
        wc: The character to write.
        stream: The stream to write it to.

    Returns:
        The character written, or `WEOF` on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fputwc.3.html).
        Fn signature: `wint_t fputwc(wchar_t wc, FILE *stream)`.
    """
    return external_call["fputwc", c_wint, c_wchar, c_ptr[FILE]](wc, stream)


def putwc(wc: c_wchar, stream: c_ptr[FILE]) -> c_wint:
    """Libc C95 `putwc` function.

    Description:
        Writes one wide character to a stream.

    Args:
        wc: The character to write.
        stream: The stream to write it to.

    Returns:
        The character written, or `WEOF` on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/putwc.3.html).
        Fn signature: `wint_t putwc(wchar_t wc, FILE *stream)`.

        The same call as `fputwc`, and kept for the same reason
        `getwc` is.
    """
    return external_call["putwc", c_wint, c_wchar, c_ptr[FILE]](wc, stream)


def putwchar(wc: c_wchar) -> c_wint:
    """Libc C95 `putwchar` function.

    Description:
        Writes one wide character to standard output.

    Args:
        wc: The character to write.

    Returns:
        The character written, or `WEOF` on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/putwchar.3.html).
        Fn signature: `wint_t putwchar(wchar_t wc)`.

        Bound and not called: a test that wrote to the terminal would
        be writing to the terminal, and what comes back from it is
        not a thing a test can hold to.
    """
    return external_call["putwchar", c_wint, c_wchar](wc)


def ungetwc(wc: c_wint, stream: c_ptr[FILE]) -> c_wint:
    """Libc C95 `ungetwc` function.

    Description:
        Hands one wide character back to a stream, so that the next
        thing read from it is that character again.

    Args:
        wc: The character to hand back.
        stream: The stream to hand it back to.

    Returns:
        The character handed back, or `WEOF` on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ungetwc.3.html).
        Fn signature: `wint_t ungetwc(wint_t wc, FILE *stream)`.

        One character is what a stream is asked to take back. Asking
        for a second without reading in between is not a thing C
        promises anything about.
    """
    return external_call["ungetwc", c_wint, c_wint, c_ptr[FILE]](wc, stream)


def fgetws(ws: c_ptr[c_wchar], n: Int32, stream: c_ptr[FILE]) -> c_ptr[c_wchar]:
    """Libc C95 `fgetws` function.

    Description:
        Reads wide characters from a stream into a buffer, stopping
        at a newline, at the end of the stream, or when the buffer
        is one short of full.

    Args:
        ws: Where to put them.
        n: How many it will hold, the terminator included.
        stream: The stream to read from.

    Returns:
        `ws` on success, or a null pointer at the end or on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fgetws.3.html).
        Fn signature: `wchar_t *fgetws(wchar_t *ws, int n,
            FILE *stream)`.

        The newline is kept, which is how this one differs from
        `fgets`' narrow cousin in nothing and from `getline` in
        everything. A terminator is written, and it is one of the
        `n`.
    """
    return external_call[
        "fgetws", c_ptr[c_wchar], c_ptr[c_wchar], Int32, c_ptr[FILE]
    ](ws, n, stream)


def fputws(ws: c_ptr[c_wchar], stream: c_ptr[FILE]) -> c_int:
    """Libc C95 `fputws` function.

    Description:
        Writes a null terminated wide string to a stream. No newline
        is added, and the terminator is not written.

    Args:
        ws: The string to write.
        stream: The stream to write it to.

    Returns:
        A non-negative number on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fputws.3.html).
        Fn signature: `int fputws(const wchar_t *ws, FILE *stream)`.
    """
    return external_call["fputws", c_int, c_ptr[c_wchar], c_ptr[FILE]](
        ws, stream
    )


def fwide(stream: c_ptr[FILE], mode: Int32) -> Int32:
    """Libc C95 `fwide` function.

    Description:
        Says which way a stream is turned: toward wide characters,
        toward bytes, or not yet either way. With `mode` at zero it
        only asks; with `mode` other than zero it asks the stream to
        turn that way, if it has not been turned already.

    Args:
        stream: The stream to ask about.
        mode: 0 to ask, positive for wide, negative for bytes.

    Returns:
        Positive if the stream is turned wide, negative if it is
        turned to bytes, and 0 if it is not turned either way.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fwide.3.html).
        Fn signature: `int fwide(FILE *stream, int mode)`.

        A stream turns once and stays turned: asking it to turn the
        other way after it has does nothing, and this is what would
        say so.
    """
    return external_call["fwide", Int32, c_ptr[FILE], Int32](stream, mode)


def wcstol(
    nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]], base: Int32
) -> Int:
    """Libc C95 `wcstol` function.

    Description:
        Reads a long integer off the front of a wide string.

    Args:
        nptr: The string to read from.
        endptr: Where to put a pointer to the first character that
            was not part of the number, or a null pointer where that
            is not wanted.
        base: The base to read it in, or 0 to let the string say —
            a leading `0x` for sixteen, a leading `0` for eight, and
            ten otherwise.

    Returns:
        The number, which is 0 where there was none to read.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstol.3.html).
        Fn signature: `long wcstol(const wchar_t *nptr,
            wchar_t **endptr, int base)`.

        Reading a number too big for a long is not a failure this
        call reports as one: it hands back the largest long there is
        and leaves `errno` to say the rest.
    """
    return external_call[
        "wcstol", Int, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]], Int32
    ](nptr, endptr, base)


def wcstoul(
    nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]], base: Int32
) -> UInt:
    """Libc C95 `wcstoul` function.

    Description:
        Reads an unsigned long integer off the front of a wide
        string.

    Args:
        nptr: The string to read from.
        endptr: Where to put a pointer to the first character that
            was not part of the number, or a null pointer where that
            is not wanted.
        base: The base to read it in, or 0 to let the string say.

    Returns:
        The number, which is 0 where there was none to read.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstoul.3.html).
        Fn signature: `unsigned long wcstoul(const wchar_t *nptr,
            wchar_t **endptr, int base)`.

        A minus sign in front is not a mistake to this one, being
        negated into an unsigned long rather than refused.
    """
    return external_call[
        "wcstoul", UInt, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]], Int32
    ](nptr, endptr, base)


def wcstod(nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]]) -> Float64:
    """Libc C95 `wcstod` function.

    Description:
        Reads a double off the front of a wide string.

    Args:
        nptr: The string to read from.
        endptr: Where to put a pointer to the first character that
            was not part of the number, or a null pointer where that
            is not wanted.

    Returns:
        The number, which is 0 where there was none to read.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstod.3.html).
        Fn signature: `double wcstod(const wchar_t *nptr,
            wchar_t **endptr)`.

        Whatever the locale says a decimal point is, that is what
        this one reads, which under the C locale is a full stop.
    """
    return external_call[
        "wcstod", Float64, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]]
    ](nptr, endptr)


def wcstof(nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]]) -> Float32:
    """Libc C99 `wcstof` function.

    Description:
        Reads a float off the front of a wide string.

    Args:
        nptr: The string to read from.
        endptr: Where to put a pointer to the first character that
            was not part of the number, or a null pointer where that
            is not wanted.

    Returns:
        The number, which is 0 where there was none to read.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstod.3.html).
        Fn signature: `float wcstof(const wchar_t *nptr,
            wchar_t **endptr)`.

        This is `wcstod` for the narrower of the two, which is what
        the `f` at the end of the name is for. A float holds fewer
        digits than a double does, so a number long enough to read
        comes out different from the two: what they agree on is the
        short ones.

        Whatever the locale says a decimal point is, that is what
        this one reads, which under the C locale is a full stop.
    """
    return external_call[
        "wcstof", Float32, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]]
    ](nptr, endptr)


def wcsnlen(s: c_ptr[c_wchar], maxlen: c_size_t) -> c_size_t:
    """Libc POSIX `wcsnlen` function.

    Description:
        Says how many wide characters there are in a string, looking
        at no more than a given number of them.

    Args:
        s: The string to measure.
        maxlen: The most characters to look at.

    Returns:
        How many there are before the end of the string, or `maxlen`
        where there was no end within that many.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsnlen.3.html).
        Fn signature: `size_t wcsnlen(const wchar_t *s,
            size_t maxlen)`.

        This is `wcslen` with a stopping place, which is what makes
        it the one to reach for where the string may not have been
        ended: `wcslen` would walk off the end of one that has not.
    """
    return external_call["wcsnlen", c_size_t, c_ptr[c_wchar], c_size_t](
        s, maxlen
    )


def wcspbrk(s: c_ptr[c_wchar], accept: c_ptr[c_wchar]) -> c_ptr[c_wchar]:
    """Libc C95 `wcspbrk` function.

    Description:
        Finds the first character of a string that is one of a given
        set.

    Args:
        s: The string to look in.
        accept: The characters to look for.

    Returns:
        A pointer to that character, or a null pointer where none of
        them is in the string.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcspbrk.3.html).
        Fn signature: `wchar_t *wcspbrk(const wchar_t *s,
            const wchar_t *accept)`.

        `wcscspn` says the same thing as a count rather than as a
        pointer, and `wcsspn` counts the run before it instead.
    """
    return external_call[
        "wcspbrk", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar]
    ](s, accept)


def wcscasecmp(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar]) -> c_int:
    """Libc POSIX `wcscasecmp` function.

    Description:
        Compares two wide strings, taking no account of the case of
        the letters in them.

    Args:
        s1: The first string.
        s2: The second string.

    Returns:
        0 where they are the same letters apart from case, and
        something else where they are not, laid out the way `wcscmp`
        lays it out.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscasecmp.3.html).
        Fn signature: `int wcscasecmp(const wchar_t *s1,
            const wchar_t *s2)`.

        Which letters count as the same is the locale's to say, and
        under the C locale it is the ASCII letters and no others.
        `wcsncasecmp` is this over no more than so many characters.
    """
    return external_call["wcscasecmp", c_int, c_ptr[c_wchar], c_ptr[c_wchar]](
        s1, s2
    )


def wcscasecmp_l(
    s1: c_ptr[c_wchar], s2: c_ptr[c_wchar], loc: locale_t
) -> c_int:
    """Libc POSIX `wcscasecmp_l` function.

    Args:
        s1: The first wide string.
        s2: The second wide string.
        loc: The locale to fold case in, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        A negative, zero or positive value as `s1` sorts before, the same as,
        or after `s2` once case is folded away in `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscasecmp.3.html).
        Fn signature: `int wcscasecmp_l(const wchar_t *s1, const wchar_t *s2, locale_t loc)`.
    """
    return external_call[
        "wcscasecmp_l", c_int, c_ptr[c_wchar], c_ptr[c_wchar], locale_t
    ](s1, s2, loc)


def wcsncasecmp(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar], n: c_size_t) -> c_int:
    """Libc POSIX `wcsncasecmp` function.

    Description:
        Compares no more than a given number of characters of two
        wide strings, taking no account of the case of the letters
        in them.

    Args:
        s1: The first string.
        s2: The second string.
        n: The most characters to compare.

    Returns:
        0 where the first that many are the same apart from case, and
        something else where they are not.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscasecmp.3.html).
        Fn signature: `int wcsncasecmp(const wchar_t *s1,
            const wchar_t *s2, size_t n)`.

        This is `wcscasecmp` with a stopping place, and like it, what
        counts as the same letter is the locale's to say.
    """
    return external_call[
        "wcsncasecmp", c_int, c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](s1, s2, n)


def wcsncasecmp_l(
    s1: c_ptr[c_wchar], s2: c_ptr[c_wchar], n: c_size_t, loc: locale_t
) -> c_int:
    """Libc POSIX `wcsncasecmp_l` function.

    Args:
        s1: The first wide string.
        s2: The second wide string.
        n: How many wide characters at most to compare.
        loc: The locale to fold case in, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        A negative, zero or positive value as the first `n` wide characters of
        `s1` sort before, the same as, or after those of `s2` with case folded
        away in `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsncasecmp.3.html).
        Fn signature: `int wcsncasecmp_l(const wchar_t *s1, const wchar_t *s2, size_t n, locale_t loc)`.
    """
    return external_call[
        "wcsncasecmp_l",
        c_int,
        c_ptr[c_wchar],
        c_ptr[c_wchar],
        c_size_t,
        locale_t,
    ](s1, s2, n, loc)


def wcscoll(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar]) -> c_int:
    """Libc C95 `wcscoll` function.

    Description:
        Compares two wide strings in the order the locale puts
        things in.

    Args:
        s1: The first string.
        s2: The second string.

    Returns:
        0 where the two come to the same place in that order, below 0
        where the first comes before the second and above 0 where it
        comes after.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscoll.3.html).
        Fn signature: `int wcscoll(const wchar_t *s1,
            const wchar_t *s2)`.

        This is not `wcscmp`, which puts characters in the order
        their numbers come: under the C locale the two agree, and
        under another they need not. `strcoll` is this for narrow
        strings, and `wcsxfrm` is what makes it cheaper where one
        string is to be compared against many.
    """
    return external_call["wcscoll", c_int, c_ptr[c_wchar], c_ptr[c_wchar]](
        s1, s2
    )


def wcscoll_l(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar], loc: locale_t) -> c_int:
    """Libc POSIX `wcscoll_l` function.

    Args:
        s1: The first wide string.
        s2: The second wide string.
        loc: The locale to order them by, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        A negative, zero or positive value under the `LC_COLLATE` ordering of
        `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcscoll.3.html).
        Fn signature: `int wcscoll_l(const wchar_t *s1, const wchar_t *s2, locale_t loc)`.
    """
    return external_call[
        "wcscoll_l", c_int, c_ptr[c_wchar], c_ptr[c_wchar], locale_t
    ](s1, s2, loc)


def wcsxfrm(dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t) -> c_size_t:
    """Libc C95 `wcsxfrm` function.

    Description:
        Writes a string out again in a form that `wcscmp` may compare
        with the result the locale's own order would give.

    Args:
        dest: Where to write it, which may be a null pointer where
            only the length is wanted.
        src: The string to write out.
        n: The most characters to write.

    Returns:
        How many characters the whole of it would take, which may be
        more than were written.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsxfrm.3.html).
        Fn signature: `size_t wcsxfrm(wchar_t *dest,
            const wchar_t *src, size_t n)`.

        Where one string is to be compared against a great many, this
        is the cheaper way to do it: the writing out is done once and
        `wcscmp` is plain comparison after it, where `wcscoll` asks
        the locale about every pair. What is written out is not meant
        to be read, only compared.
    """
    return external_call[
        "wcsxfrm", c_size_t, c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def wcsxfrm_l(
    dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t, loc: locale_t
) -> c_size_t:
    """Libc POSIX `wcsxfrm_l` function.

    Args:
        dest: Where to put the transformed wide string.
        src: The wide string to transform, NUL terminated.
        n: How many wide characters `dest` can hold, terminator included.
        loc: The locale to transform for, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        The length of the transformed wide string, terminator excluded, which
        is what a buffer would have to hold to take all of it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsxfrm.3.html).
        Fn signature: `size_t wcsxfrm_l(wchar_t *dest, const wchar_t *src, size_t n, locale_t loc)`.
    """
    return external_call[
        "wcsxfrm_l",
        c_size_t,
        c_ptr[c_wchar],
        c_ptr[c_wchar],
        c_size_t,
        locale_t,
    ](dest, src, n, loc)


def wcsdup(s: c_ptr[c_wchar]) -> c_ptr[c_wchar]:
    """Libc POSIX `wcsdup` function.

    Description:
        Makes a copy of a wide string in fresh memory.

    Args:
        s: The string to copy.

    Returns:
        A pointer to the copy, or a null pointer where none could be
        had.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsdup.3.html).
        Fn signature: `wchar_t *wcsdup(const wchar_t *s)`.

        Fresh memory of its own asking for, which is to say the
        caller's to hand to `free` — and not to hand to `free` twice,
        nor after some other call has freed what was copied.
    """
    return external_call["wcsdup", c_ptr[c_wchar], c_ptr[c_wchar]](s)


def wcsncat(
    dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t
) -> c_ptr[c_wchar]:
    """Libc C95 `wcsncat` function.

    Description:
        Puts no more than a given number of characters from one wide
        string onto the end of another.

    Args:
        dest: The string to add to, which is written to.
        src: What to add to it.
        n: The most characters to add.

    Returns:
        The first string.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsncat.3.html).
        Fn signature: `wchar_t *wcsncat(wchar_t *dest,
            const wchar_t *src, size_t n)`.

        A terminator is put on the end whatever `n` is, so the room
        has to be one wider than the two strings come to. This is
        `wcscat` with a stopping place, and where the destination is
        not known to have room for the whole of the source, this is
        the one and not that.
    """
    return external_call[
        "wcsncat", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def wcpcpy(dest: c_ptr[c_wchar], src: c_ptr[c_wchar]) -> c_ptr[c_wchar]:
    """Libc GNU `wcpcpy` function.

    Description:
        Copies one wide string over another and hands back a pointer
        to the end of what was written.

    Args:
        dest: Where to copy to, which is written to.
        src: What to copy there.

    Returns:
        A pointer to the terminator at the end of the copy.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcpcpy.3.html).
        Fn signature: `wchar_t *wcpcpy(wchar_t *dest,
            const wchar_t *src)`.

        This is `wcscpy` that says where it got to, which is what
        makes it the one for putting several strings one after
        another: there is no walking the string again to find the end
        between one copy and the next. `stpcpy` is this for narrow
        strings. The room has to be one wider than the source is
        long, the terminator being copied too.
    """
    return external_call[
        "wcpcpy", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar]
    ](dest, src)


def wcpncpy(
    dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t
) -> c_ptr[c_wchar]:
    """Libc GNU `wcpncpy` function.

    Description:
        Copies no more than a given number of characters from one
        wide string to another, and hands back a pointer to where it
        got to.

    Args:
        dest: Where to copy to, which is written to.
        src: What to copy there.
        n: The most characters to write.

    Returns:
        A pointer to the terminator at the end of the copy, or to
        one past the last character written where the source was
        longer than that.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcpncpy.3.html).
        Fn signature: `wchar_t *wcpncpy(wchar_t *dest,
            const wchar_t *src, size_t n)`.

        Where the source runs out first, the rest of the room is
        filled with terminators — which is what makes this unlike
        `wcsncpy`, and why what comes back points to a terminator
        rather than to nothing in particular. Where it does not run
        out, nothing is terminated at all, and what comes back is one
        past the last character written.
    """
    return external_call[
        "wcpncpy", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def wmemchr(s: c_ptr[c_wchar], c: c_wchar, n: c_size_t) -> c_ptr[c_wchar]:
    """Libc C95 `wmemchr` function.

    Description:
        Looks for a wide character in the first so many of them.

    Args:
        s: Where to look.
        c: The character to look for.
        n: How many characters to look at.

    Returns:
        A pointer to the one found, or a null pointer where the first
        that many do not hold it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wmemchr.3.html).
        Fn signature: `wchar_t *wmemchr(const wchar_t *s, wchar_t c,
            size_t n)`.

        This is `wcschr` with a stopping place, and unlike it, this
        one keeps looking past a terminator: what it is given is a
        number of characters and not a string.
    """
    return external_call[
        "wmemchr", c_ptr[c_wchar], c_ptr[c_wchar], c_wchar, c_size_t
    ](s, c, n)


def wmemcmp(s1: c_ptr[c_wchar], s2: c_ptr[c_wchar], n: c_size_t) -> c_int:
    """Libc C95 `wmemcmp` function.

    Description:
        Compares the first so many wide characters of two places.

    Args:
        s1: The first.
        s2: The second.
        n: How many characters to compare.

    Returns:
        0 where they are the same, and something else where they are
        not, laid out the way `wcscmp` lays it out.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wmemcmp.3.html).
        Fn signature: `int wmemcmp(const wchar_t *s1,
            const wchar_t *s2, size_t n)`.

        Plain comparison of the characters' numbers, and no regard for
        the locale: that is `wcscoll`'s work and not this one's.
    """
    return external_call[
        "wmemcmp", c_int, c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](s1, s2, n)


def wmemcpy(
    dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t
) -> c_ptr[c_wchar]:
    """Libc C95 `wmemcpy` function.

    Description:
        Copies so many wide characters from one place to another.

    Args:
        dest: Where to copy to, which is written to.
        src: Where to copy from.
        n: How many characters to copy.

    Returns:
        The first place.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wmemcpy.3.html).
        Fn signature: `wchar_t *wmemcpy(wchar_t *dest,
            const wchar_t *src, size_t n)`.

        The two must not overlap. Where they may, `wmemmove` is the
        one and not this. No terminator is put on: what is moved is a
        number of characters and not a string.
    """
    return external_call[
        "wmemcpy", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def wmemmove(
    dest: c_ptr[c_wchar], src: c_ptr[c_wchar], n: c_size_t
) -> c_ptr[c_wchar]:
    """Libc C95 `wmemmove` function.

    Description:
        Copies so many wide characters from one place to another,
        which may be the same place.

    Args:
        dest: Where to copy to, which is written to.
        src: Where to copy from.
        n: How many characters to copy.

    Returns:
        The first place.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wmemmove.3.html).
        Fn signature: `wchar_t *wmemmove(wchar_t *dest,
            const wchar_t *src, size_t n)`.

        What makes it not `wmemcpy` is that the two may overlap: the
        characters come out whole whichever way round they lie.
    """
    return external_call[
        "wmemmove", c_ptr[c_wchar], c_ptr[c_wchar], c_ptr[c_wchar], c_size_t
    ](dest, src, n)


def wmemset(s: c_ptr[c_wchar], c: c_wchar, n: c_size_t) -> c_ptr[c_wchar]:
    """Libc C95 `wmemset` function.

    Description:
        Sets so many wide characters to one value.

    Args:
        s: Where to set them, which is written to.
        c: The character to set them to.
        n: How many to set.

    Returns:
        The place.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wmemset.3.html).
        Fn signature: `wchar_t *wmemset(wchar_t *s, wchar_t c,
            size_t n)`.

        Setting them to 0 puts an end on the string, which is the one
        thing a terminator is.
    """
    return external_call[
        "wmemset", c_ptr[c_wchar], c_ptr[c_wchar], c_wchar, c_size_t
    ](s, c, n)


def wcstoll(
    nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]], base: c_int
) -> c_longlong:
    """Libc C99 `wcstoll` function.

    Description:
        Reads a long long off the front of a wide string.

    Args:
        nptr: The string to read from.
        endptr: Where to put a pointer to the first character that
            was not part of the number, or a null pointer where that
            is not wanted.
        base: Which base to read it in, from 2 to 36, or 0 to let
            the string say.

    Returns:
        The number, which is 0 where there was none to read. A number
        too big for a long long comes back as its widest or
        narrowest, with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstol.3.html).
        Fn signature: `long long wcstoll(const wchar_t *nptr,
            wchar_t **endptr, int base)`.

        Under a base of 0 the string says which: a leading `0x` is
        sixteen, a leading `0` is eight, and neither is ten. Under a
        base of 16 the `0x` is read as part of the number rather than
        as a say-so, which this package's `wcstol` notes too.

        Take `LONG_LONG_MAX` and `LONG_LONG_MIN` from `libc.constant`
        rather than writing the numbers out.
    """
    return external_call[
        "wcstoll", c_longlong, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]], c_int
    ](nptr, endptr, base)


def wcstoull(
    nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]], base: c_int
) -> c_ulonglong:
    """Libc C99 `wcstoull` function.

    Description:
        Reads an unsigned long long off the front of a wide string.

    Args:
        nptr: The string to read from.
        endptr: Where to put a pointer to the first character that
            was not part of the number, or a null pointer where that
            is not wanted.
        base: Which base to read it in, from 2 to 36, or 0 to let
            the string say.

    Returns:
        The number, which is 0 where there was none to read. A number
        too big for an unsigned long long comes back as its widest,
        with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstoul.3.html).
        Fn signature: `unsigned long long wcstoull(const wchar_t *nptr,
            wchar_t **endptr, int base)`.

        A minus sign in front is read as part of the number, and what
        comes out is the number taken away from nothing — which is to
        say that this one does not refuse a negative the way `strtoul`
        is sometimes thought to.
    """
    return external_call[
        "wcstoull", c_ulonglong, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]], c_int
    ](nptr, endptr, base)


def wcstok(
    s: c_ptr[c_wchar], delim: c_ptr[c_wchar], ptr: c_ptr[c_ptr[c_wchar]]
) -> c_ptr[c_wchar]:
    """Libc C95 `wcstok` function.

    Description:
        Splits a wide string into pieces, one call to a piece.

    Args:
        s: The string to split on the first call, and a null pointer
            on every one after it.
        delim: The characters to split on.
        ptr: Where the call keeps its place between one call and the
            next. The same one has to be handed to every call of a
            run, and it is written to.

    Returns:
        A pointer to the piece, or a null pointer where there are no
        more of them.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstok.3.html).
        Fn signature: `wchar_t *wcstok(wchar_t *s, const wchar_t *delim,
            wchar_t **ptr)`.

        The string is written to: a terminator goes in where a
        delimiter was, so what is handed in is not what it was. Two
        runs cannot be in hand at once on the same string, and this is
        the one that may be — `strtok_r` is the narrow one that takes
        its place from the caller and not from a static.
    """
    return external_call[
        "wcstok",
        c_ptr[c_wchar],
        c_ptr[c_wchar],
        c_ptr[c_wchar],
        c_ptr[c_ptr[c_wchar]],
    ](s, delim, ptr)


def mbsinit(ps: c_ptr[mbstate_t]) -> c_int:
    """Libc C95 `mbsinit` function.

    Description:
        Says whether a conversion state is at its beginning.

    Args:
        ps: The state to ask about, or a null pointer, which is taken
            as the state the library keeps for its own.

    Returns:
        Something other than 0 where it is at its beginning, and 0
        where it is part-way through a character.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbsinit.3.html).
        Fn signature: `int mbsinit(const mbstate_t *ps)`.

        `mbstate_t` is bound in this module and is opaque: make one
        and hand it, and it is the same state the calls that read a
        character at a time share.
    """
    return external_call["mbsinit", c_int, c_ptr[mbstate_t]](ps)


def mbsrtowcs(
    dest: c_ptr[c_wchar],
    src: c_ptr[c_ptr[UInt8]],
    length: c_size_t,
    ps: c_ptr[mbstate_t],
) -> c_size_t:
    """Libc C95 `mbsrtowcs` function.

    Description:
        Reads a multibyte string out into wide characters, one whole
        character at a time.

    Args:
        dest: Where to write them, or a null pointer where only how
            many there are is wanted.
        src: Where the string is. This is written to: it is moved on
            past what was read, and set to a null pointer once the end
            of the string has been read.
        length: The most wide characters to write.
        ps: The conversion state, or a null pointer for the one the
            library keeps for its own.

    Returns:
        How many wide characters were written, or how many there would
        have been where `dest` was a null pointer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbsrtowcs.3.html).
        Fn signature: `size_t mbsrtowcs(wchar_t *dest, const char **src,
            size_t len, mbstate_t *ps)`.

        This is `mbstowcs` that keeps a state between calls, which is
        what a character taking more than one byte needs: it can be
        handed the string a piece at a time. `mbsnrtowcs` is this with
        a limit on how many bytes it will read as well as on how many
        characters it will write.
    """
    return external_call[
        "mbsrtowcs",
        c_size_t,
        c_ptr[c_wchar],
        c_ptr[c_ptr[UInt8]],
        c_size_t,
        c_ptr[mbstate_t],
    ](dest, src, length, ps)


def wcsrtombs(
    dest: c_ptr[UInt8],
    src: c_ptr[c_ptr[c_wchar]],
    length: c_size_t,
    ps: c_ptr[mbstate_t],
) -> c_size_t:
    """Libc C95 `wcsrtombs` function.

    Description:
        Writes wide characters out as a multibyte string, one whole
        character at a time.

    Args:
        dest: Where to write it, or a null pointer where only how many
            bytes it would take is wanted.
        src: Where the characters are. This is written to: it is moved
            on past what was read, and set to a null pointer once the
            end of them has been read.
        length: The most bytes to write.
        ps: The conversion state, or a null pointer for the one the
            library keeps for its own.

    Returns:
        How many bytes were written, or how many it would have taken
        where `dest` was a null pointer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsrtombs.3.html).
        Fn signature: `size_t wcsrtombs(char *dest, const wchar_t **src,
            size_t len, mbstate_t *ps)`.

        This is `wcstombs` that keeps a state between calls. No
        terminator is written where the characters run out before the
        room does, so a byte of 0 goes in first where one is wanted.
        `wcsnrtombs` is this with a limit on how many characters it
        will read as well as on how many bytes it will write.
    """
    return external_call[
        "wcsrtombs",
        c_size_t,
        c_ptr[UInt8],
        c_ptr[c_ptr[c_wchar]],
        c_size_t,
        c_ptr[mbstate_t],
    ](dest, src, length, ps)


def mbsnrtowcs(
    dest: c_ptr[c_wchar],
    src: c_ptr[c_ptr[UInt8]],
    nmc: c_size_t,
    length: c_size_t,
    ps: c_ptr[mbstate_t],
) -> c_size_t:
    """Libc GNU `mbsnrtowcs` function.

    Description:
        Reads no more than a given number of bytes of a multibyte
        string out into wide characters.

    Args:
        dest: Where to write them, or a null pointer where only how
            many there are is wanted.
        src: Where the string is. This is written to: it is moved on
            past what was read.
        nmc: The most bytes of the string to read.
        length: The most wide characters to write.
        ps: The conversion state, or a null pointer for the one the
            library keeps for its own.

    Returns:
        How many wide characters were written, or how many there would
        have been where `dest` was a null pointer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbsnrtowcs.3.html).
        Fn signature: `size_t mbsnrtowcs(wchar_t *dest, const char **src,
            size_t nmc, size_t len, mbstate_t *ps)`.

        This is `mbsrtowcs` with a stopping place in the source as
        well as in the destination, which is what makes it the one for
        a string that has not been ended or that is being read in
        pieces. Reading stops at a terminator, and at a character that
        would take more bytes than are left to read.
    """
    return external_call[
        "mbsnrtowcs",
        c_size_t,
        c_ptr[c_wchar],
        c_ptr[c_ptr[UInt8]],
        c_size_t,
        c_size_t,
        c_ptr[mbstate_t],
    ](dest, src, nmc, length, ps)


def wcsnrtombs(
    dest: c_ptr[UInt8],
    src: c_ptr[c_ptr[c_wchar]],
    nwc: c_size_t,
    length: c_size_t,
    ps: c_ptr[mbstate_t],
) -> c_size_t:
    """Libc GNU `wcsnrtombs` function.

    Description:
        Writes no more than a given number of wide characters out as a
        multibyte string.

    Args:
        dest: Where to write it, or a null pointer where only how many
            bytes it would take is wanted.
        src: Where the characters are. This is written to: it is moved
            on past what was read.
        nwc: The most characters to read.
        length: The most bytes to write.
        ps: The conversion state, or a null pointer for the one the
            library keeps for its own.

    Returns:
        How many bytes were written, or how many it would have taken
        where `dest` was a null pointer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsnrtombs.3.html).
        Fn signature: `size_t wcsnrtombs(char *dest, const wchar_t **src,
            size_t nwc, size_t len, mbstate_t *ps)`.

        This is `wcsrtombs` with a stopping place in the source as
        well as in the destination, so the source need not be ended.
        No terminator is written, as with `wcsrtombs`.
    """
    return external_call[
        "wcsnrtombs",
        c_size_t,
        c_ptr[UInt8],
        c_ptr[c_ptr[c_wchar]],
        c_size_t,
        c_size_t,
        c_ptr[mbstate_t],
    ](dest, src, nwc, length, ps)


def wcsftime(
    s: c_ptr[c_wchar], max: c_size_t, format: c_ptr[c_wchar], timeptr: c_ptr[tm]
) -> c_size_t:
    """Libc C95 `wcsftime` function.

    Description:
        Writes a wide string from a broken-down time, in the shape a
        format asks for.

    Args:
        s: Where to write it, which is written to.
        max: The most characters to write, terminator and all.
        format: The format, which is the same one `strftime` takes:
            `%Y` for the year, `%m` for the month and so on.
        timeptr: The time to write out.

    Returns:
        How many characters were written, terminator not counted, or 0
        where they would not fit in `max`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcsftime.3.html).
        Fn signature: `size_t wcsftime(wchar_t *s, size_t max,
            const wchar_t *format, const struct tm *timeptr)`.

        This is `strftime` writing wide characters. Which words come
        out for `%a` and `%B` is the locale's to say, so a format of
        digits is what a test wants: `%Y` is the year in every locale
        that has one.
    """
    return external_call[
        "wcsftime",
        c_size_t,
        c_ptr[c_wchar],
        c_size_t,
        c_ptr[c_wchar],
        c_ptr[tm],
    ](s, max, format, timeptr)
