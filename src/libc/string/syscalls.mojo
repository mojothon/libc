# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_char, c_int, c_long, c_longlong, c_ptr, c_size_t
from libc.locale import locale_t


@inline(.nodebug)
def strcat(s1: c_ptr[UInt8], s2: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <string.h> function `strcat`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strcat.html

    Prototype:
        char *strcat(char *s1, const char *s2)

    Description:
        Appends the string pointed to by s2 to the end of the string pointed to by s1.
        Room for what is coming is assumed rather than checked, and it writes past the
        end when it is not there; the two strings must not overlap either.

    Arguments:
        s1: The string that gets added to, which wants room for what is there already
            and for what is coming, null and all.
        s2: The string that gets added, null and all.

    Return Value:
        The function returns a pointer to the resulting string s1.
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
        Room at s1 is assumed rather than checked, and it writes past the end when the
        array is short; the two must not overlap.

    Arguments:
        s1: Where the string goes, which wants room for all of s2 and the null that
            ends it.
        s2: The string to copy, null and all.

    Return Value:
        The function returns a pointer to the resulting string s1.
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
        is exactly n characters long. When s2 runs n characters or longer no null is
        written at all, and what sits at s1 is then not a string: it wants one put at
        the end by hand before anything reads it as one.

    Arguments:
        s1: Where the characters go, which wants room for n of them.
        s2: The string to copy from.
        n: How many characters at most to copy.

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
    """C library <string.h> function `memcpy`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/memcpy.html

    Prototype:
        void *memcpy(void *restrict dest, const void *restrict src, size_t n)

    Description:
        Copies n bytes from the object pointed to by src to the one
        pointed to by dest. The two must not overlap, and what happens
        when they do is left undefined: where they might, `memmove` is
        the one that is made for it.

    Arguments:
        dest: Where the bytes go.
        src: Where they come from.
        n: How many bytes to copy.

    Return Value:
        The function returns dest.
    """
    return external_call[
        "memcpy", c_ptr[NoneType], c_ptr[NoneType], c_ptr[NoneType], UInt64
    ](dest, src, n)


@inline(.nodebug)
def mempcopy(
    dest: c_ptr[NoneType], src: c_ptr[NoneType], n: UInt64
) -> c_ptr[NoneType]:
    """C library <string.h> function `mempcpy`.

    Reference:
        https://man7.org/linux/man-pages/man3/mempcpy.3.html

    Prototype:
        void *mempcpy(void *restrict dest, const void *restrict src, size_t n)

    Description:
        Copies as `memcpy` does, overlap and all, and hands back
        something else: the byte past the last one written, `dest + n`
        rather than `dest`. Handy for filling a buffer in pieces. It is
        a GNU one, not an ISO C or a POSIX one, so it is there on Linux
        and glibc and not everywhere else.

    Arguments:
        dest: Where the bytes go.
        src: Where they come from.
        n: How many bytes to copy.

    Return Value:
        The function returns dest + n, that is, one past the last byte
        it wrote.
    """
    return external_call[
        "mempcpy", c_ptr[NoneType], c_ptr[NoneType], c_ptr[NoneType], UInt64
    ](dest, src, n)


@inline(.nodebug)
def memmove(
    dest: c_ptr[NoneType], src: c_ptr[NoneType], n: UInt64
) -> c_ptr[NoneType]:
    """C library <string.h> function `memmove`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/memmove.html

    Prototype:
        void *memmove(void *dest, const void *src, size_t n)

    Description:
        Copies n bytes from the object pointed to by src to the one
        pointed to by dest. Unlike `memcpy` it does not mind whether
        the two overlap: it copies as though it had put src aside
        first, so the bytes come out as they went in.

    Arguments:
        dest: Where the bytes go.
        src: Where they come from.
        n: How many bytes to copy.

    Return Value:
        The function returns dest.
    """
    return external_call[
        "memmove", c_ptr[NoneType], c_ptr[NoneType], c_ptr[NoneType], UInt64
    ](dest, src, n)


@inline(.nodebug)
def memset(s: c_ptr[NoneType], c: Int32, n: UInt64) -> c_ptr[NoneType]:
    """C library <string.h> function `memset`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/memset.html

    Prototype:
        void *memset(void *s, int c, size_t n)

    Description:
        Fills the first n bytes of the object pointed to by s with c.
        Only the low eight bits of c are looked at, and they are taken
        as an unsigned char, so 256 writes the same byte as 0 does and
        -1 the same as 255.

    Arguments:
        s: Where the bytes go.
        c: What to write there, of which the low eight bits are used.
        n: How many bytes to write.

    Return Value:
        The function returns s.
    """
    return external_call[
        "memset", c_ptr[NoneType], c_ptr[NoneType], Int32, UInt64
    ](s, c, n)


@inline(.nodebug)
def strcopy(dest: c_ptr[UInt8], src: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <string.h> function `strcpy` under another name.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strcpy.html

    Prototype:
        char *strcpy(char *dest, const char *src)

    Description:
        `strcpy` as it is above, the binding being the same one and
        only the names of the arguments differing: what is called is
        `strcpy` either way. It is kept so that a call can be spelled
        with dest and src.

    Arguments:
        dest: Where the string goes, which wants room for all of src
            and the null that ends it.
        src: The string to copy, null and all.

    Return Value:
        The function returns dest.
    """
    return external_call["strcpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        dest, src
    )


@inline(.nodebug)
def strncopy(dest: c_ptr[UInt8], src: c_ptr[UInt8], n: UInt64) -> c_ptr[UInt8]:
    """C library <string.h> function `strncpy` under another name.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strncpy.html

    Prototype:
        char *strncpy(char *dest, const char *src, size_t n)

    Description:
        `strncpy` as it is above, the binding being the same one and
        only the names of the arguments differing. It is kept so that
        a call can be spelled with dest and src.

    Arguments:
        dest: Where the characters go, which wants room for n of them.
        src: The string to copy from.
        n: How many characters at most to copy.

    Return Value:
        The function returns dest.
    """
    return external_call[
        "strncpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8], UInt64
    ](dest, src, n)


@inline(.nodebug)
def strdup(s: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <string.h> function `strdup`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strdup.html

    Prototype:
        char *strdup(const char *s)

    Description:
        Makes a fresh copy of s and hands back a pointer to it, the
        memory for it taken with `malloc`, which makes it memory C owns
        and this caller's to hand back: `free` from `libc.stdlib` is
        what takes it. When there is none to be had it answers with a
        null pointer, and a Mojo `Pointer` cannot be null, nor is
        there a way here to ask one whether it is — so this is for
        copies that have the memory to give.

    Arguments:
        s: The string to copy.

    Return Value:
        The function returns a pointer to the copy, or a null pointer
        when no memory was to be had.
    """
    return external_call["strdup", c_ptr[UInt8], c_ptr[UInt8]](s)


@inline(.nodebug)
def strndup(s: c_ptr[UInt8], n: UInt64) -> c_ptr[UInt8]:
    """C library <string.h> function `strndup`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strndup.html

    Prototype:
        char *strndup(const char *s, size_t n)

    Description:
        `strdup` with a bound on it: it copies the shorter of the
        string and n bytes, and it always ends what it wrote with a
        null, which `strncpy` does not, so what comes back is a string
        whatever n was. The `malloc` and the `free` are as they are
        for `strdup`, and so is the want of a way to see a null
        pointer coming back.

    Arguments:
        s: The string to copy from.
        n: How many bytes at most to copy.

    Return Value:
        The function returns a pointer to the copy, or a null pointer
        when no memory was to be had.
    """
    return external_call["strndup", c_ptr[UInt8], c_ptr[UInt8], UInt64](s, n)


@inline(.nodebug)
def strlen(s: c_ptr[UInt8]) -> UInt64:
    """C library <string.h> function `strlen`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/strlen.html

    Prototype:
        size_t strlen(const char *s)

    Description:
        Counts the bytes in s up to the null that ends it, that null
        not counted. It stops at nothing else, so a block of memory
        without one sends it reading past the end; `strnlen` below is
        the one that takes a bound.

    Arguments:
        s: The string to measure, which does want a null at its end.

    Return Value:
        The function returns how many bytes it counted.
    """
    return external_call["strlen", UInt64, c_ptr[UInt8]](s)


@inline(.nodebug)
def strnlen(s: c_ptr[UInt8], maxlen: UInt64) -> UInt64:
    """C library <string.h> function `strnlen`.

    Reference:
        https://man7.org/linux/man-pages/man3/strnlen.3.html

    Prototype:
        size_t strnlen(const char *s, size_t maxlen)

    Description:
        `strlen` with a bound on it: it counts up to maxlen bytes and
        stops there, answering with maxlen when no null turned up in
        them, which is what makes it the one to take over a buffer
        that may not be ended. GNU had it well before POSIX did, which
        took it in with the 2024 revision.

    Arguments:
        s: What to measure.
        maxlen: How many bytes to look at at most.

    Return Value:
        The function returns how many bytes it counted, which is
        maxlen when it got that far without finding a null.
    """
    return external_call["strnlen", UInt64, c_ptr[UInt8], UInt64](s, maxlen)


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


def strcasecmp_l(s1: c_ptr[UInt8], s2: c_ptr[UInt8], loc: locale_t) -> c_int:
    """Libc POSIX `strcasecmp_l` function.

    Args:
        s1: The first string.
        s2: The second string.
        loc: The locale to fold case in, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        A negative, zero or positive value as `s1` sorts before, the same as,
        or after `s2` once case is folded away in `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcasecmp.3.html).
        Fn signature: `int strcasecmp_l(const char *s1, const char *s2, locale_t loc)`.
    """
    return external_call[
        "strcasecmp_l", c_int, c_ptr[UInt8], c_ptr[UInt8], locale_t
    ](s1, s2, loc)


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


def strncasecmp_l(
    s1: c_ptr[UInt8], s2: c_ptr[UInt8], n: c_size_t, loc: locale_t
) -> c_int:
    """Libc POSIX `strncasecmp_l` function.

    Args:
        s1: The first string.
        s2: The second string.
        n: How many bytes at most to compare.
        loc: The locale to fold case in, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        A negative, zero or positive value as the first `n` bytes of `s1` sort
        before, the same as, or after those of `s2` with case folded away in
        `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strncasecmp.3.html).
        Fn signature: `int strncasecmp_l(const char *s1, const char *s2, size_t n, locale_t loc)`.
    """
    return external_call[
        "strncasecmp_l", c_int, c_ptr[UInt8], c_ptr[UInt8], c_size_t, locale_t
    ](s1, s2, n, loc)


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


def strcoll_l(s1: c_ptr[UInt8], s2: c_ptr[UInt8], loc: locale_t) -> c_int:
    """Libc POSIX `strcoll_l` function.

    Args:
        s1: The first string.
        s2: The second string.
        loc: The locale to order them by, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        A negative, zero or positive value under the `LC_COLLATE` ordering of
        `loc`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strcoll.3.html).
        Fn signature: `int strcoll_l(const char *s1, const char *s2, locale_t loc)`.
    """
    return external_call[
        "strcoll_l", c_int, c_ptr[UInt8], c_ptr[UInt8], locale_t
    ](s1, s2, loc)


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


def strxfrm_l(
    dest: c_ptr[UInt8], src: c_ptr[UInt8], n: c_size_t, loc: locale_t
) -> c_size_t:
    """Libc POSIX `strxfrm_l` function.

    Args:
        dest: Where to put the transformed string, or what `null_ptr` gives for
            a buffer wanted for its length alone: nothing is written there and
            none is read, which makes a zero `n` worth passing.
        src: The string to transform, NUL terminated.
        n: How many bytes `dest` can hold, terminator included.
        loc: The locale to transform for, rather than the one the thread is in.
            It is a `locale_t` from `newlocale`.

    Returns:
        The length of the transformed string, terminator excluded, which is
        what a buffer would have to hold to take all of it. A buffer too small
        is still told that length, which is how a caller finds out how much it
        needs before it has anywhere to put the answer.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strxfrm.3.html).
        Fn signature: `size_t strxfrm_l(char *dest, const char *src, size_t n, locale_t loc)`.
    """
    return external_call[
        "strxfrm_l", c_size_t, c_ptr[UInt8], c_ptr[UInt8], c_size_t, locale_t
    ](dest, src, n, loc)


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


@inline(.nodebug)
def strncat(s1: c_ptr[UInt8], s2: c_ptr[UInt8], n: c_size_t) -> c_ptr[UInt8]:
    """Libc C89 `strncat` function.

    Args:
        s1: The string to append to, which has to have room for the result.
        s2: The string to take from.
        n: How many bytes of `s2` to append at most.

    Returns:
        `s1`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strncat.3.html).
        Fn signature: `char *strncat(char *s1, const char *s2, size_t n)`.

        It ends the result with a null byte of its own, so the room `s1`
        needs is what it already holds plus `n` plus one.
    """
    return external_call[
        "strncat", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](s1, s2, n)


@inline(.nodebug)
def stpcpy(dst: c_ptr[UInt8], src: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc POSIX `stpcpy` function.

    Args:
        dst: The buffer to copy into, which has to have room for `src`.
        src: The string to copy.

    Returns:
        A pointer to the null byte that ends `dst`, which is what makes
        building a string out of several of these cheap: the next one takes
        up from where this one left off instead of starting over.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/stpcpy.3.html).
        Fn signature: `char *stpcpy(char *dst, const char *src)`.
    """
    return external_call["stpcpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        dst, src
    )


@inline(.nodebug)
def stpncpy(dst: c_ptr[UInt8], src: c_ptr[UInt8], n: c_size_t) -> c_ptr[UInt8]:
    """Libc POSIX `stpncpy` function.

    Args:
        dst: The buffer to copy into, which has to be `n` bytes wide at least.
        src: The string to copy.
        n: How many bytes to write at most.

    Returns:
        A pointer to the null byte that ends `dst`, or to `dst[n]` when
        `src` was `n` bytes or longer and so left no null byte behind —
        which is the thing that makes this one awkward, and why the result
        says where the string stopped rather than where it started.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/stpncpy.3.html).
        Fn signature: `char *stpncpy(char *dst, const char *src, size_t n)`.
    """
    return external_call[
        "stpncpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](dst, src, n)


@inline(.nodebug)
def strsep(stringp: c_ptr[c_ptr[UInt8]], delim: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc `strsep` function.

    Args:
        stringp: A pointer to the pointer walking the string. It is moved
            past the token handed back, and set to null once there is
            nothing left.
        delim: The bytes that separate tokens.

    Returns:
        A pointer to the token, with the separator that ended it overwritten
        by a null byte, or null when the string is finished.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strsep.3.html).
        Fn signature: `char *strsep(char **stringp, const char *delim)`.

        What `strtok` would be if it kept no state between calls: two
        separators in a row give back an empty token rather than being
        treated as one, and nothing is kept behind the caller's back.
    """
    return external_call[
        "strsep", c_ptr[UInt8], c_ptr[c_ptr[UInt8]], c_ptr[UInt8]
    ](stringp, delim)


@inline(.nodebug)
def memmem(
    haystack: c_ptr[NoneType],
    haystacklen: c_size_t,
    needle: c_ptr[NoneType],
    needlelen: c_size_t,
) -> c_ptr[NoneType]:
    """Libc `memmem` function.

    Args:
        haystack: The block to search.
        haystacklen: How many bytes of it to search.
        needle: The bytes to look for.
        needlelen: How many bytes they are.

    Returns:
        A pointer to where `needle` starts, or null if those bytes are not
        there. An empty `needle` gives `haystack` back.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/memmem.3.html).
        Fn signature: `void *memmem(const void *haystack, size_t haystacklen, const void *needle, size_t needlelen)`.

        Neither C nor POSIX has this one, but glibc and the BSDs do, and
        Darwin is a BSD here.
    """
    return external_call[
        "memmem",
        c_ptr[NoneType],
        c_ptr[NoneType],
        c_size_t,
        c_ptr[NoneType],
        c_size_t,
    ](haystack, haystacklen, needle, needlelen)


@inline(.nodebug)
def ffs(i: c_int) -> c_int:
    """Libc POSIX `ffs` function.

    Args:
        i: The word to look at.

    Returns:
        The position of the lowest bit that is set, counting from 1, or 0
        when no bit is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ffs.3.html).
        Fn signature: `int ffs(int i)`.
    """
    return external_call["ffs", c_int, c_int](i)


@inline(.nodebug)
def ffsl(i: c_long) -> c_int:
    """Libc POSIX `ffsl` function.

    Args:
        i: The word to look at.

    Returns:
        The position of the lowest bit that is set, counting from 1, or 0
        when no bit is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ffs.3.html).
        Fn signature: `int ffsl(long i)`.
    """
    return external_call["ffsl", c_int, c_long](i)


@inline(.nodebug)
def ffsll(i: c_longlong) -> c_int:
    """Libc POSIX `ffsll` function.

    Args:
        i: The word to look at.

    Returns:
        The position of the lowest bit that is set, counting from 1, or 0
        when no bit is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ffs.3.html).
        Fn signature: `int ffsll(long long i)`.
    """
    return external_call["ffsll", c_int, c_longlong](i)


def bcmp(s1: c_ptr[UInt8], s2: c_ptr[UInt8], n: c_size_t) -> c_int:
    """Libc BSD `bcmp` function.

    Description:
        Compares two blocks of bytes.

    Args:
        s1: The first block.
        s2: The second block.
        n: How many bytes to compare.

    Returns:
        0 where the blocks are the same over those bytes, and
        something else where they are not.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/bcmp.3.html).
        Fn signature: `int bcmp(const void *s1, const void *s2,
            size_t n)`.

        `memcmp` is this same comparison under a name the standard
        keeps; this one is the BSD one and is declared in
        `<strings.h>`, not `<string.h>`.
    """
    return external_call["bcmp", c_int, c_ptr[UInt8], c_ptr[UInt8], c_size_t](
        s1, s2, n
    )


def bcopy(src: c_ptr[UInt8], dest: c_ptr[UInt8], n: c_size_t):
    """Libc BSD `bcopy` function.

    Description:
        Copies `n` bytes from one block to another.

    Args:
        src: Where to copy from.
        dest: Where to copy to.
        n: How many bytes to copy.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/bcopy.3.html).
        Fn signature: `void bcopy(const void *src, void *dest,
            size_t n)`.

        The two arguments are the other way round from `memcpy`'s,
        which takes its destination first. Blocks that overlap come
        out whole, which is what `memmove` promises and `memcpy`
        does not.
    """
    external_call["bcopy", NoneType, c_ptr[UInt8], c_ptr[UInt8], c_size_t](
        src, dest, n
    )


def bzero(s: c_ptr[UInt8], n: c_size_t):
    """Libc BSD `bzero` function.

    Description:
        Sets `n` bytes of a block to zero.

    Args:
        s: The block.
        n: How many bytes of it to set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/bzero.3.html).
        Fn signature: `void bzero(void *s, size_t n)`.

        `memset` with a zero is the same thing under a name the
        standard keeps.
    """
    external_call["bzero", NoneType, c_ptr[UInt8], c_size_t](s, n)


def index(s: c_ptr[c_char], c: c_int) -> c_ptr[c_char]:
    """Libc BSD `index` function.

    Description:
        Finds the first occurrence of a byte in a string.

    Args:
        s: The string to look in.
        c: The byte to look for.

    Returns:
        A pointer to that byte, or a null pointer where the string
        has no such byte.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/index.3.html).
        Fn signature: `char *index(const char *s, int c)`.

        `strchr` is this same search under a name the standard keeps.
        Looking for the terminator finds it, as both do.
    """
    return external_call["index", c_ptr[c_char], c_ptr[c_char], c_int](s, c)


def rindex(s: c_ptr[c_char], c: c_int) -> c_ptr[c_char]:
    """Libc BSD `rindex` function.

    Description:
        Finds the last occurrence of a byte in a string.

    Args:
        s: The string to look in.
        c: The byte to look for.

    Returns:
        A pointer to that byte, or a null pointer where the string
        has no such byte.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/rindex.3.html).
        Fn signature: `char *rindex(const char *s, int c)`.

        `strrchr` is this same search under a name the standard
        keeps, and this is the one that finds the last of them and
        not the first.
    """
    return external_call["rindex", c_ptr[c_char], c_ptr[c_char], c_int](s, c)


def memccpy(
    dest: c_ptr[UInt8], src: c_ptr[UInt8], c: c_int, n: c_size_t
) -> c_ptr[UInt8]:
    """Libc POSIX `memccpy` function.

    Description:
        Copies bytes from one block to another, stopping once a
        given byte has been copied or once `n` of them have been,
        whichever comes first.

    Args:
        dest: Where to copy to.
        src: Where to copy from.
        c: The byte to stop after, as an unsigned character.
        n: The most bytes to copy.

    Returns:
        A pointer to the byte after the one that stopped it, or a
        null pointer where `n` bytes were copied without that byte
        coming up.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/memccpy.3.html).
        Fn signature: `void *memccpy(void *dest, const void *src,
            int c, size_t n)`.

        The destination is what is handed first here, the way it is
        to `memcpy`, and not the way it is to `bcopy`, which takes
        it second. That the one stopping byte is copied too, and
        that the pointer handed back points past it, is what makes
        this worth having. Blocks that overlap are not a thing this
        one says anything about.
    """
    return external_call[
        "memccpy", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8], c_int, c_size_t
    ](dest, src, c, n)
