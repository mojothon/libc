# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# Linux only: glibc has <uchar.h> and Darwin has no such header at all, so
# importing this package there will not link. The four calls are the C11
# conversions between the multibyte encoding of the current locale and
# UTF-16 or UTF-32, and the encoding they read is the one the calling
# thread's locale says — under the default `C` locale that is ASCII, and
# everything above it fails with EILSEQ. A caller has to set a UTF-8 locale
# first, by `setlocale` or by `uselocale` on an object from `newlocale`.
from std.ffi import external_call

from libc.constant import c_ptr, c_size_t
from libc.wchar import mbstate_t

# Three of the answers these calls give are not byte counts: C writes them
# `(size_t) -1`, `-2` and `-3`, and as a `size_t` each is a number no string
# could be long enough to earn, so they are read back as `Int(n)` against the
# negative one. `-1` is `EILSEQ` set in `errno`, `-2` is "these bytes are the
# start of a character and not all of it", and `-3` is the second half of a
# surrogate pair, which is the one thing here that only `mbrtoc16` says.


def mbrtoc16(
    pc16: c_ptr[UInt16], s: c_ptr[UInt8], n: c_size_t, ps: c_ptr[mbstate_t]
) -> c_size_t:
    """Libc C11 `mbrtoc16` function.

    Args:
        pc16: Where the UTF-16 code unit goes. Nothing is written when the
            call answers `-2` or `-1`.
        s: The multibyte string to read, in the encoding of the calling
            thread's locale.
        n: How many bytes of `s` are there to read.
        ps: The conversion state to carry, or a null pointer to use the
            library's own.

    Returns:
        How many bytes of `s` the character took — 1 to 4 in UTF-8 — or 0 if
        it was the null character. `(size_t) -3` when the unit written is the
        low half of a pair whose high half an earlier call wrote, in which
        case no input was read; `(size_t) -2` when the bytes are the start of
        a character and `n` ran out before its end, in which case the state
        holds them for the next call; `(size_t) -1` with `EILSEQ` when they
        are not a character at all.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbrtoc16.3.html).
        Fn signature:
        `size_t mbrtoc16(char16_t *pc16, const char *s, size_t n, mbstate_t *ps)`.

        The `-3` is what a UTF-16 string costs and a UTF-8 one does not: a
        character above U+FFFF is two code units and four bytes, so one call
        consumes the four bytes and writes the high half, and the next call
        writes the low half without consuming anything. A loop that treats
        every answer as a byte count either loses that second unit or reads
        four bytes twice; the answer to compare is `-3`, and a caller that
        handles only the counts leaves a hole where the character was. It
        comes once: the call after it answers `-2`, since there is nothing
        left in the state and nothing in `s`.

        Passing the same `ps` in each time is what joins the two halves. A
        null `ps` uses the library's own state for the thread, which works
        the same way until something else in the thread uses it too.
    """
    return external_call[
        "mbrtoc16",
        c_size_t,
        c_ptr[UInt16],
        c_ptr[UInt8],
        c_size_t,
        c_ptr[mbstate_t],
    ](pc16, s, n, ps)


def mbrtoc32(
    pc32: c_ptr[UInt32], s: c_ptr[UInt8], n: c_size_t, ps: c_ptr[mbstate_t]
) -> c_size_t:
    """Libc C11 `mbrtoc32` function.

    Args:
        pc32: Where the UTF-32 character goes. Nothing is written when the
            call answers `-2` or `-1`.
        s: The multibyte string to read, in the encoding of the calling
            thread's locale.
        n: How many bytes of `s` are there to read.
        ps: The conversion state to carry, or a null pointer to use the
            library's own.

    Returns:
        How many bytes of `s` the character took — 1 to 4 in UTF-8 — or 0 if
        it was the null character, `(size_t) -2` when `n` ran out inside a
        character, or `(size_t) -1` with `EILSEQ` when the bytes are not one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbrtoc16.3.html).
        Fn signature:
        `size_t mbrtoc32(char32_t *pc32, const char *s, size_t n, mbstate_t *ps)`.

        There is no `-3` here: a UTF-32 character is whole, so every answer
        is either a byte count or one of the two reasons there is not one.
        The state is still worth passing in, because the bytes of a character
        split across two calls are what it is holding — the second call gets
        the rest of them and answers the count only of what it read.
    """
    return external_call[
        "mbrtoc32",
        c_size_t,
        c_ptr[UInt32],
        c_ptr[UInt8],
        c_size_t,
        c_ptr[mbstate_t],
    ](pc32, s, n, ps)


def c16rtomb(s: c_ptr[UInt8], c16: UInt16, ps: c_ptr[mbstate_t]) -> c_size_t:
    """Libc C11 `c16rtomb` function.

    Args:
        s: Where the multibyte bytes go, room for four of them.
        c16: The UTF-16 code unit to write out.
        ps: The conversion state to carry, or a null pointer to use the
            library's own.

    Returns:
        How many bytes were written — 1 to 4 in UTF-8 — or 0 when `c16` is a
        high surrogate, which writes nothing until its low half arrives, or
        `(size_t) -1` with `EILSEQ` when it is a low surrogate with no high
        one before it in the state.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/c16rtomb.3.html).
        Fn signature: `size_t c16rtomb(char *s, char16_t c16, mbstate_t *ps)`.

        The pair has to be given one unit at a time and with the same `ps`:
        the high half answers 0 and is remembered, and the low half answers
        the four bytes both of them make. Freeing or re-zeroing the state
        between the two leaves a high surrogate that can never be finished,
        and the low half on its own is `EILSEQ`.

        A null `s` is not the way to ask how many bytes there would be. C11
        says that is what it is for; glibc reads it as `wcrtomb` does, and
        answers 1 for every character while clearing the state — which is
        also how a half-finished pair is thrown away.

        The null character flushes whatever the state is holding and writes
        the shift sequence back to the initial one, which in UTF-8 is
        nothing: `c16rtomb` of 0 writes one byte, the terminator.
    """
    return external_call[
        "c16rtomb", c_size_t, c_ptr[UInt8], UInt16, c_ptr[mbstate_t]
    ](s, c16, ps)


def c32rtomb(s: c_ptr[UInt8], c32: UInt32, ps: c_ptr[mbstate_t]) -> c_size_t:
    """Libc C11 `c32rtomb` function.

    Args:
        s: Where the multibyte bytes go, room for four of them.
        c32: The UTF-32 character to write out.
        ps: The conversion state to carry, or a null pointer to use the
            library's own, which for this call is only ever the initial one.

    Returns:
        How many bytes were written — 1 to 4 in UTF-8 — or `(size_t) -1` with
        `EILSEQ` when `c32` is a surrogate.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/c16rtomb.3.html).
        Fn signature: `size_t c32rtomb(char *s, char32_t c32, mbstate_t *ps)`.

        A value above U+10FFFF is not refused by glibc, though UTF-8 has no
        encoding for one: U+110000 comes back as the four bytes `F4 90 80
        80`, and U+7FFFFFFF as six, which is the old five and six byte form
        and not something a UTF-8 decoder will read back. A caller with a
        number from somewhere untrusted has to range check it, because the
        call will not.

        A null `s` answers 1 for every character rather than the length, as
        in `c16rtomb`, and clears the state on the way.
    """
    return external_call[
        "c32rtomb", c_size_t, c_ptr[UInt8], UInt32, c_ptr[mbstate_t]
    ](s, c32, ps)
