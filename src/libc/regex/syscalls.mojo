# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr, c_size_t


# What `regcomp` is asked for. `REG_EXTENDED` and `REG_ICASE` agree, and
# so do the two that gate anchors, but `REG_NOSUB` and `REG_NEWLINE` do
# not: glibc gave the bit after `REG_ICASE` to `REG_NEWLINE` and XNU gave
# it to `REG_NOSUB`. XNU writes these in octal, which is where its 4 and
# 8 come from.
comptime REG_EXTENDED: Int32 = 1
comptime REG_ICASE: Int32 = 2
comptime REG_NOSUB: Int32 = 4 if CompilationTarget.is_macos() else 8
comptime REG_NEWLINE: Int32 = 8 if CompilationTarget.is_macos() else 4
comptime REG_NOTBOL: Int32 = 1
comptime REG_NOTEOL: Int32 = 2


# What `regcomp` and `regexec` answer when it is not 0. These are the same
# numbers on both platforms, which is not what happens everywhere else in
# this package: `EAI_*` in `libc.netdb` agrees on nothing at all. POSIX
# numbered these from 1 and both implementations stuck to it.
comptime REG_NOMATCH: Int32 = 1
comptime REG_BADPAT: Int32 = 2
comptime REG_ECOLLATE: Int32 = 3
comptime REG_ECTYPE: Int32 = 4
comptime REG_EESCAPE: Int32 = 5
comptime REG_ESUBREG: Int32 = 6
comptime REG_EBRACK: Int32 = 7
comptime REG_EPAREN: Int32 = 8
comptime REG_EBRACE: Int32 = 9
comptime REG_BADBR: Int32 = 10
comptime REG_ERANGE: Int32 = 11
comptime REG_ESPACE: Int32 = 12
comptime REG_BADRPT: Int32 = 13
comptime REG_ENOSYS: Int32 = -1


struct regex_t:
    """A C `regex_t`: a pattern once it has been compiled.

    libc owns what `regcomp` writes in here, and nothing about it is
    meant to be read — it is sixty-four bytes on glibc and thirty-two on
    Darwin, opaque either way, and the two halves hold different things.
    This holds the larger and answers no questions about what is inside.

    Notes:
        `regfree` is what releases it, and is required even when the
        pattern was never used: not every implementation allocates, but
        the ones that do leak until it is called.
    """

    var _opaque: Array[UInt64, 8]

    def __init__(out self):
        """Zeroes the block, which is the state of one nothing compiled."""
        self._opaque = Array[UInt64, 8](fill=0)


struct regmatch_t:
    """A C `regmatch_t`: where one substring begins and ends.

    Both members are a `regoff_t`, and that is what the two platforms
    disagree about: it is a thirty-two-bit int on glibc and a sixty-four
    bit `__darwin_off_t` on XNU, so the whole struct is eight bytes
    here and sixteen there. It is one block either way, read out at the
    width of whoever is compiling.

    Notes:
        `regexec` fills an array of these, one for the whole match and
        one for each parenthesised subexpression after it, which is why
        `nmatch` counts the whole match too. Both members are -1 for a
        subexpression that took no part in the match.
    """

    comptime SLOTS = 2 if CompilationTarget.is_macos() else 1

    var _bytes: Array[UInt64, Self.SLOTS]

    def __init__(out self):
        """Zeroes the block, which `regexec` overwrites where it matched."""
        self._bytes = Array[UInt64, Self.SLOTS](fill=0)

    def _part(self, low: Bool) -> Int64:
        """One of the two offsets, read as whoever is compiling stores it.

        A `regoff_t` wide as a word takes a whole slot of its own on
        Darwin; the half-width one on Linux takes half a slot each, and
        since it is signed, the top bit has to be put back afterwards —
        all ones is -1, which is how an unused subexpression is marked.
        """
        comptime if CompilationTarget.is_macos():
            var held = self._bytes[0 if low else 1]
            return Int64(held) if held < 0x8000000000000000 else -1
        var raw = (
            self._bytes[0] >> 32 if not low else self._bytes[0] & 0xFFFFFFFF
        )
        return -1 if raw == 0xFFFFFFFF else Int64(raw)

    def rm_so(self) -> Int64:
        """The byte the substring starts at, or -1 when it did not match."""
        return self._part(True)

    def rm_eo(self) -> Int64:
        """The byte just past the substring, which is what rm_eo means."""
        return self._part(False)


def regcomp(
    preg: c_ptr[regex_t], pattern: c_ptr[UInt8], cflags: Int32
) -> Int32:
    """C library <regex.h> function `regcomp`.

    Reference:
        https://man7.org/linux/man-pages/man3/regcomp.3.html

    Description:
        Compiles a regular expression into the form `regexec` matches
        against, which is what makes this cheaper than matching the text
        of the pattern every time: compile once, then match as often as
        you like. `REG_EXTENDED` asks for the modern syntax — the one
        with `+`, `?` and `|` in it — without which the pattern is taken
        as a POSIX basic expression, where those have to be written with
        backslashes.

    Args:
        preg: Where the compiled pattern is written, which must stay put
            until `regfree` takes it.
        pattern: The pattern itself, NUL terminated. Build one from a
            `String` with `string_to_char_ptr`.
        cflags: What to compile for, as the `REG_EXTENDED`, `REG_ICASE`,
            `REG_NOSUB` and `REG_NEWLINE` above, or 0 for the defaults.

    Returns:
        0 on success, or the error `regerror` turns into a sentence —
        `REG_BADPAT` for a pattern that will not parse, `REG_EPAREN` for
        a parenthesis left open, and so on through the `REG_*` above.

    Notes:
        Fn signature:
        `int regcomp(regex_t *restrict preg, const char *restrict pattern, int cflags)`.

        `REG_NOSUB` and `REG_NEWLINE` are not the same number on both
        platforms, so pass the names rather than a value read off one of
        them: see the list above.
    """
    return external_call["regcomp", Int32, c_ptr[regex_t], c_ptr[UInt8], Int32](
        preg, pattern, cflags
    )


def regexec(
    preg: c_ptr[regex_t],
    string: c_ptr[UInt8],
    nmatch: c_size_t,
    pmatch: c_ptr[regmatch_t],
    eflags: Int32,
) -> Int32:
    """C library <regex.h> function `regexec`.

    Reference:
        https://man7.org/linux/man-pages/man3/regexec.3.html

    Description:
        Matches a compiled pattern against a string, and says where each
        part of it landed. The answer 0 means it matched; where it
        matched is written into `pmatch`, one entry for the whole match
        and one for each parenthesised subexpression after it, each
        holding the offset it starts at and the offset just past it.

    Args:
        preg: The pattern, as `regcomp` compiled it.
        string: The text to match against, NUL terminated.
        nmatch: How many entries `pmatch` has room for. Give it the
            number of subexpressions plus one for the whole match; zero
            is allowed and asks for nothing but the answer.
        pmatch: Where the offsets are written, `nmatch` entries of
            `regmatch_t`, or ignored when `nmatch` is 0. An entry whose
            subexpression took no part reads back -1 in both members.
        eflags: How to match, as `REG_NOTBOL` and `REG_NOTEOL` above, or
            0 for neither.

    Returns:
        0 when it matched, or `REG_NOMATCH` when it did not, which is
        the expected answer for text the pattern is not in rather than a
        failure of any kind.

    Notes:
        Fn signature:
        `int regexec(const regex_t *restrict preg, const char *restrict string, size_t nmatch, regmatch_t pmatch[restrict nmatch], int eflags)`.

        `^` and `$` match the ends of the string, not the ends of its
        lines, unless `REG_NEWLINE` was asked for at compile time.
    """
    return external_call[
        "regexec",
        Int32,
        c_ptr[regex_t],
        c_ptr[UInt8],
        c_size_t,
        c_ptr[regmatch_t],
        Int32,
    ](preg, string, nmatch, pmatch, eflags)


def regerror(
    errcode: Int32,
    preg: c_ptr[regex_t],
    errbuf: c_ptr[UInt8],
    errbuf_size: c_size_t,
) -> c_size_t:
    """C library <regex.h> function `regerror`.

    Reference:
        https://man7.org/linux/man-pages/man3/regerror.3.html

    Description:
        Turns one of the `REG_*` error numbers into the sentence that
        goes with it, which is the only way to find out why a pattern
        would not compile: `regcomp` answers with a number and expects
        this to be asked about it.

    Args:
        errcode: What `regcomp` or `regexec` answered.
        preg: The pattern the answer came from, which is how the message
            knows anything about it.
        errbuf: Where the message is written, as a NUL-terminated C
            string.
        errbuf_size: How many bytes `errbuf` has.

    Returns:
        How many bytes the whole message takes, `\0` and all, however
        much of it fitted in `errbuf`: a return larger than
        `errbuf_size` means it was cut short. Read the buffer with
        `char_ptr_to_string`.

    Notes:
        Fn signature:
        `size_t regerror(int errcode, const regex_t *restrict preg, char *restrict errbuf, size_t errbuf_size)`.

        The pattern has to be given even though the number alone looks
        like enough: some implementations keep the detail of what went
        wrong inside it.
    """
    return external_call[
        "regerror",
        c_size_t,
        Int32,
        c_ptr[regex_t],
        c_ptr[UInt8],
        c_size_t,
    ](errcode, preg, errbuf, errbuf_size)


def regfree(preg: c_ptr[regex_t]) -> None:
    """C library <regex.h> function `regfree`.

    Reference:
        https://man7.org/linux/man-pages/man3/regcomp.3.html

    Args:
        preg: The pattern `regcomp` filled in, whether or not anything
            was ever matched against it. It cannot be used afterwards
            without being compiled again.
    """
    external_call["regfree", NoneType, c_ptr[regex_t]](preg)
