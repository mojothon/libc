# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_int, c_ptr, c_size_t


@inline(.nodebug)
def strcat(s1: c_ptr[UInt8], s2: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <string.h> function `strcat`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strcat.html

    Prototype:
        char *strcat(char *s1, const char *s2)

    Description:
        Appends the string pointed to by s2 to the end of the string pointed to by s1.
    """

    return external_call["strcat", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        s1, s2
    )


@inline(.nodebug)
def strcpy(s1: c_ptr[UInt8], s2: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <string.h> function `strcpy`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strcpy.html

    Prototype:
        char *strcpy(char *s1, const char *s2)

    Description:
        Copies the string pointed to by s2 (including the terminating null character) to the array pointed to by s1.
    """

    return external_call["strcpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        s1, s2
    )


@inline(.nodebug)
def strncpy(s1: c_ptr[UInt8], s2: c_ptr[UInt8], n: UInt64) -> c_ptr[UInt8]:
    """C library <string.h> function `strncpy`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strncpy.html

    Prototype:
        char *strncpy(char *s1, const char *s2, size_t n)

    Description:
        Copies at most n characters from the string pointed to by s2 (including the terminating null character) to the array
        pointed to by s1. If the length of s2 is less than n, null characters are appended to the end of s1 to ensure that it
        is exactly n characters long.

    Return Value:
        The function returns a pointer to the resulting string s1.
    """

    return external_call[
        "strncpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8], UInt64
    ](s1, s2, n)


@inline(.nodebug)
def memcpy(
    dest: c_ptr[NoneType], src: c_ptr[NoneType], n: UInt64
) -> c_ptr[NoneType]:
    return external_call["memcpy", c_ptr[NoneType]](dest, src, n)


@inline(.nodebug)
def mempcopy(
    dest: c_ptr[NoneType], src: c_ptr[NoneType], n: UInt64
) -> c_ptr[NoneType]:
    return external_call["mempcopy", c_ptr[NoneType]](dest, src, n)


@inline(.nodebug)
def memmove(
    dest: c_ptr[NoneType], src: c_ptr[NoneType], n: UInt64
) -> c_ptr[NoneType]:
    return external_call["memmove", c_ptr[NoneType]](dest, src, n)


@inline(.nodebug)
def memset(s: c_ptr[NoneType], c: Int32, n: UInt64) -> c_ptr[NoneType]:
    return external_call["memset", c_ptr[NoneType]](s, c, n)


@inline(.nodebug)
def strcopy(dest: c_ptr[UInt8], src: c_ptr[UInt8]) -> c_ptr[UInt8]:
    return external_call["strcpy", c_ptr[UInt8]](dest, src)


@inline(.nodebug)
def strncopy(dest: c_ptr[UInt8], src: c_ptr[UInt8], n: UInt64) -> c_ptr[UInt8]:
    return external_call["strncpy", c_ptr[UInt8]](dest, src, n)


@inline(.nodebug)
def strdup(s: c_ptr[UInt8]) -> c_ptr[UInt8]:
    return external_call["strdup", c_ptr[UInt8]](s)


@inline(.nodebug)
def strndup(s: c_ptr[UInt8], n: UInt64) -> c_ptr[UInt8]:
    return external_call["strndup", c_ptr[UInt8]](s, n)


@inline(.nodebug)
def strlen(s: c_ptr[UInt8]) -> UInt64:
    return external_call["strlen", UInt64](s)


@inline(.nodebug)
def strnlen(s: c_ptr[UInt8], maxlen: UInt64) -> UInt64:
    return external_call["strnlen", UInt64](s, maxlen)


@inline(.nodebug)
def memcmp(s1: c_ptr[NoneType], s2: c_ptr[NoneType], n: c_size_t) -> c_int:
    """Libc C89 `memcmp` function.

    Args:
        s1: The first block.
        s2: The second block.
        n: How many bytes to compare.

    Returns:
        A negative, zero or positive value as `s1` sorts before, with, or
        after `s2`, compared as unsigned bytes.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/memcmp.3.html).
        Fn signature: `int memcmp(const void *s1, const void *s2, size_t n)`.
    """
    return external_call[
        "memcmp", c_int, c_ptr[NoneType], c_ptr[NoneType], c_size_t
    ](s1, s2, n)


@inline(.nodebug)
def memchr(s: c_ptr[NoneType], c: c_int, n: c_size_t) -> c_ptr[NoneType]:
    """Libc C89 `memchr` function.

    Args:
        s: The block to scan.
        c: The byte to look for, narrowed to an `unsigned char`.
        n: How many bytes to scan.

    Returns:
        A pointer to the first match, or a null pointer if `s` holds no such
        byte in its first `n` bytes.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/memchr.3.html).
        Fn signature: `void *memchr(const void *s, int c, size_t n)`.

        The result is a `void *`, so cast it before reading: `found.
        unsafe_bitcast[UInt8]()` gives you the byte back.
    """
    return external_call[
        "memchr", c_ptr[NoneType], c_ptr[NoneType], c_int, c_size_t
    ](s, c, n)


@inline(.nodebug)
def strcmp(s1: c_ptr[UInt8], s2: c_ptr[UInt8]) -> c_int:
    """Libc C89 `strcmp` function.

    Args:
        s1: The first string.
        s2: The second string.

    Returns:
        A negative, zero or positive value as `s1` sorts before, with, or
        after `s2`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcmp.3.html).
        Fn signature: `int strcmp(const char *s1, const char *s2)`.
    """
    return external_call["strcmp", c_int, c_ptr[UInt8], c_ptr[UInt8]](s1, s2)


@inline(.nodebug)
def strncmp(s1: c_ptr[UInt8], s2: c_ptr[UInt8], n: c_size_t) -> c_int:
    """Libc C89 `strncmp` function.

    Args:
        s1: The first string.
        s2: The second string.
        n: How many bytes to compare at most.

    Returns:
        A negative, zero or positive value as the first `n` bytes of `s1`
        sort before, with, or after `s2`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcmp.3.html).
        Fn signature: `int strncmp(const char *s1, const char *s2, size_t n)`.
    """
    return external_call[
        "strncmp", c_int, c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](s1, s2, n)


@inline(.nodebug)
def strcasecmp(s1: c_ptr[UInt8], s2: c_ptr[UInt8]) -> c_int:
    """Libc POSIX `strcasecmp` function.

    Args:
        s1: The first string.
        s2: The second string.

    Returns:
        A negative, zero or positive value, ignoring case.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcasecmp.3.html).
        Fn signature: `int strcasecmp(const char *s1, const char *s2)`.

        Case folding follows the current locale, so only ASCII compares the
        way you expect under the default `C` locale.
    """
    return external_call["strcasecmp", c_int, c_ptr[UInt8], c_ptr[UInt8]](
        s1, s2
    )


@inline(.nodebug)
def strncasecmp(s1: c_ptr[UInt8], s2: c_ptr[UInt8], n: c_size_t) -> c_int:
    """Libc POSIX `strncasecmp` function.

    Args:
        s1: The first string.
        s2: The second string.
        n: How many bytes to compare at most.

    Returns:
        A negative, zero or positive value, ignoring case.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcasecmp.3.html).
        Fn signature: `int strncasecmp(const char *s1, const char *s2, size_t n)`.
    """
    return external_call[
        "strncasecmp", c_int, c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](s1, s2, n)


@inline(.nodebug)
def strcoll(s1: c_ptr[UInt8], s2: c_ptr[UInt8]) -> c_int:
    """Libc C89 `strcoll` function.

    Args:
        s1: The first string.
        s2: The second string.

    Returns:
        A negative, zero or positive value under the `LC_COLLATE` ordering.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcoll.3.html).
        Fn signature: `int strcoll(const char *s1, const char *s2)`.
    """
    return external_call["strcoll", c_int, c_ptr[UInt8], c_ptr[UInt8]](s1, s2)


@inline(.nodebug)
def strxfrm(dest: c_ptr[UInt8], src: c_ptr[UInt8], n: c_size_t) -> c_size_t:
    """Libc C89 `strxfrm` function.

    Args:
        dest: Where to write the transformed string.
        src: The string to transform.
        n: The size of `dest`.

    Returns:
        The length the transformed string needs, excluding the null byte. A
        return of `n` or more means it did not fit.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strxfrm.3.html).
        Fn signature: `size_t strxfrm(char *dest, const char *src, size_t n)`.
    """
    return external_call[
        "strxfrm", c_size_t, c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](dest, src, n)


@inline(.nodebug)
def strchr(s: c_ptr[UInt8], c: c_int) -> c_ptr[UInt8]:
    """Libc C89 `strchr` function.

    Args:
        s: The string to scan.
        c: The byte to look for, narrowed to a `char`.

    Returns:
        A pointer to the first match, or a null pointer if there is none.
        Looking for 0 finds the terminating null byte.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strchr.3.html).
        Fn signature: `char *strchr(const char *s, int c)`.
    """
    return external_call["strchr", c_ptr[UInt8], c_ptr[UInt8], c_int](s, c)


@inline(.nodebug)
def strrchr(s: c_ptr[UInt8], c: c_int) -> c_ptr[UInt8]:
    """Libc C89 `strrchr` function.

    Args:
        s: The string to scan.
        c: The byte to look for, narrowed to a `char`.

    Returns:
        A pointer to the last match, or a null pointer if there is none.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strchr.3.html).
        Fn signature: `char *strrchr(const char *s, int c)`.
    """
    return external_call["strrchr", c_ptr[UInt8], c_ptr[UInt8], c_int](s, c)


@inline(.nodebug)
def strstr(haystack: c_ptr[UInt8], needle: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc C89 `strstr` function.

    Args:
        haystack: The string to search.
        needle: The substring to look for.

    Returns:
        A pointer into `haystack` where `needle` starts, or a null pointer.
        An empty `needle` returns `haystack` itself.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strstr.3.html).
        Fn signature: `char *strstr(const char *haystack, const char *needle)`.
    """
    return external_call["strstr", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        haystack, needle
    )


@inline(.nodebug)
def strspn(s: c_ptr[UInt8], accept: c_ptr[UInt8]) -> c_size_t:
    """Libc C89 `strspn` function.

    Args:
        s: The string to measure.
        accept: The bytes that count.

    Returns:
        How many leading bytes of `s` are all in `accept`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strspn.3.html).
        Fn signature: `size_t strspn(const char *s, const char *accept)`.
    """
    return external_call["strspn", c_size_t, c_ptr[UInt8], c_ptr[UInt8]](
        s, accept
    )


@inline(.nodebug)
def strcspn(s: c_ptr[UInt8], reject: c_ptr[UInt8]) -> c_size_t:
    """Libc C89 `strcspn` function.

    Args:
        s: The string to measure.
        reject: The bytes that stop the count.

    Returns:
        How many leading bytes of `s` are none of `reject`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strspn.3.html).
        Fn signature: `size_t strcspn(const char *s, const char *reject)`.
    """
    return external_call["strcspn", c_size_t, c_ptr[UInt8], c_ptr[UInt8]](
        s, reject
    )


@inline(.nodebug)
def strpbrk(s: c_ptr[UInt8], accept: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc C89 `strpbrk` function.

    Args:
        s: The string to scan.
        accept: The bytes to look for.

    Returns:
        A pointer to the first byte of `s` that is also in `accept`, or a null
        pointer if there is none.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strpbrk.3.html).
        Fn signature: `char *strpbrk(const char *s, const char *accept)`.
    """
    return external_call["strpbrk", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        s, accept
    )


@inline(.nodebug)
def strtok(s: c_ptr[UInt8], delim: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc C89 `strtok` function.

    Args:
        s: The string to split, or a null pointer to keep scanning the string
            an earlier call started on.
        delim: The bytes that separate tokens.

    Returns:
        A pointer to the next token, or a null pointer when there are none
        left.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strtok.3.html).
        Fn signature: `char *strtok(char *s, const char *delim)`.

        This rewrites `s` in place and keeps its place in a static variable,
        so it is neither reentrant nor thread safe. Prefer `strtok_r`.
    """
    return external_call["strtok", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        s, delim
    )


@inline(.nodebug)
def strtok_r(
    s: c_ptr[UInt8], delim: c_ptr[UInt8], saveptr: c_ptr[c_ptr[UInt8]]
) -> c_ptr[UInt8]:
    """Libc POSIX `strtok_r` function.

    Args:
        s: The string to split, or a null pointer to keep scanning.
        delim: The bytes that separate tokens.
        saveptr: Where the scan resumes from; the caller owns it and must not
            touch it between calls.

    Returns:
        A pointer to the next token, or a null pointer when there are none
        left.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strtok.3.html).
        Fn signature: `char *strtok_r(char *s, const char *delim, char **saveptr)`.
    """
    return external_call[
        "strtok_r",
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[c_ptr[UInt8]],
    ](s, delim, saveptr)


@inline(.nodebug)
def strerror(errnum: c_int) -> c_ptr[UInt8]:
    """Libc C89 `strerror` function.

    Args:
        errnum: An `errno` value.

    Returns:
        A pointer to the message for `errnum`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strerror.3.html).
        Fn signature: `char *strerror(int errnum)`.

        The message lives in static storage that a later call may overwrite,
        and it is not thread safe.
    """
    return external_call["strerror", c_ptr[UInt8], c_int](errnum)


@inline(.nodebug)
def strsignal(sig: c_int) -> c_ptr[UInt8]:
    """Libc POSIX `strsignal` function.

    Args:
        sig: A signal number.

    Returns:
        A pointer to the description of `sig`, or to a message of its own for
        a number out of range.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strsignal.3.html).
        Fn signature: `char *strsignal(int sig)`.
    """
    return external_call["strsignal", c_ptr[UInt8], c_int](sig)
