# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr, c_size_t, c_wchar, c_wint
from libc.file import FILE


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
