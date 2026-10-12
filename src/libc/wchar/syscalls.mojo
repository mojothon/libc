# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer

from libc.constant import c_int, c_ptr, c_size_t, c_wchar, c_wint


struct mbstate_t:
    """An opaque C `mbstate_t`: the shift state a multibyte conversion
    carries between calls.

    The real struct is 8 bytes on glibc and 16 on Darwin, so this one holds
    twice the larger and only ever travels by pointer. Zero it and it is the
    initial state, which is what `memset` gives you.
    """

    var _opaque: Array[UInt8, 32]

    def __init__(out self):
        """Zeroes the state, which is the initial state."""
        self._opaque = Array[UInt8, 32](fill=0)


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
