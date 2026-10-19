# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


# What `glob` is asked for. These are the twelve both platforms name, and
# almost none of them is the same number on the two: glibc counts them 1,
# 2, 4, 8 upward in the order it wrote them and XNU counts them 1, 2, 4,
# 8 upward too, but in a different order — its `GLOB_NOESCAPE` is 8192
# against glibc's 64. `GLOB_NOCHECK` and `GLOB_MAGCHAR` agree, and that
# is the whole agreement.
#
# `GLOB_PERIOD` and `GLOB_ONLYDIR` are glibc's alone and `GLOB_QUOTE` and
# `GLOB_LIMIT` are XNU's, and none of the four is here: a name either
# side does not answer is not something to give the other one.
comptime GLOB_APPEND: Int32 = 1 if CompilationTarget.is_macos() else 32
comptime GLOB_DOOFFS: Int32 = 2 if CompilationTarget.is_macos() else 8
comptime GLOB_ERR: Int32 = 4 if CompilationTarget.is_macos() else 1
comptime GLOB_MARK: Int32 = 8 if CompilationTarget.is_macos() else 2
comptime GLOB_NOCHECK: Int32 = 16
comptime GLOB_NOSORT: Int32 = 32 if CompilationTarget.is_macos() else 4
comptime GLOB_NOESCAPE: Int32 = 8192 if CompilationTarget.is_macos() else 64
comptime GLOB_ALTDIRFUNC: Int32 = 64 if CompilationTarget.is_macos() else 512
comptime GLOB_BRACE: Int32 = 128 if CompilationTarget.is_macos() else 1024
comptime GLOB_MAGCHAR: Int32 = 256
comptime GLOB_NOMAGIC: Int32 = 512 if CompilationTarget.is_macos() else 2048
comptime GLOB_TILDE: Int32 = 2048 if CompilationTarget.is_macos() else 4096


# What `glob` answers when it is not 0. Here glibc says positive and XNU
# says negative: `GLOB_NOMATCH` is 3 here and -3 there, which is the same
# disagreement `EAI_*` in `libc.netdb` has, so these are named rather
# than written down too.
comptime GLOB_NOSPACE: Int32 = -1 if CompilationTarget.is_macos() else 1
comptime GLOB_ABORTED: Int32 = -2 if CompilationTarget.is_macos() else 2
comptime GLOB_NOMATCH: Int32 = -3 if CompilationTarget.is_macos() else 3


struct glob_t:
    """A C `glob_t`: where `glob` put what it found.

    The first four members — how many paths there are, where the vector
    of them is, how much room was left at its head, and which flags were
    asked for — sit at the same offsets on both platforms, which is not
    the same as being laid out the same way: glibc has

        gl_pathc, gl_pathv, gl_offs, gl_flags
          gl_pathc  size_t  0     gl_pathv  char **  8
          gl_offs   size_t  16    gl_flags  int      24

    and XNU has

        gl_pathc, gl_matchc, gl_offs, gl_flags, gl_pathv
          gl_pathc  size_t  0     gl_matchc int      8
          gl_offs   size_t  16    gl_flags  int      24
          gl_pathv  char ** 32

    so the vector is at 8 on one and 32 on the other. Everything after
    that is function pointers libc owns. One block of the larger size
    either way, with the four things a caller wants read out by method at
    the offset of whoever is compiling.

    Notes:
        `globfree` is what releases it, and it is the only thing that
        may: the vector and the strings in it come from libc's allocator,
        not from this package's.
    """

    comptime SLOTS = 11 if CompilationTarget.is_macos() else 9

    var _bytes: Array[UInt64, Self.SLOTS]

    def __init__(out self):
        """Zeroes the block, which is what `glob` expects to be given."""
        self._bytes = Array[UInt64, Self.SLOTS](fill=0)

    def _slot(self, offset: Int) -> UInt64:
        """The eight bytes at byte `offset`."""
        return self._bytes[offset // 8]

    def gl_pathc(self) -> Int:
        """How many paths there are, which is 0 when nothing matched
        unless `GLOB_NOCHECK` said otherwise."""
        return Int(self._slot(0))

    def gl_pathv(self) -> c_ptr[c_ptr[UInt8]]:
        """The paths themselves: that many NUL-terminated strings one
        after another, read each with `char_ptr_to_string`.

        Notes:
            Twenty-four bytes of difference between the platforms, and
            the only member of these four that moves. It is NULL with no
            paths in it, so check `gl_pathc` before walking it.
        """
        return c_ptr[c_ptr[UInt8]](
            unsafe_from_address=Int(
                self._slot(32 if CompilationTarget.is_macos() else 8)
            )
        )

    def gl_offs(self) -> Int:
        """How many entries were asked to be left empty at the head of
        `gl_pathv`, by `GLOB_DOOFFS`."""
        return Int(self._slot(16))

    def gl_flags(self) -> Int32:
        """Which flags the pattern was expanded with, as `glob` kept
        them, including `GLOB_MAGCHAR` when the pattern had metacharacters
        in it."""
        return Int32(self._slot(24) >> 32)


def glob(
    pattern: c_ptr[UInt8],
    flags: Int32,
    errfunc: c_ptr[UInt8],
    pglob: c_ptr[glob_t],
) -> Int32:
    """C library <glob.h> function `glob`.

    Reference:
        https://man7.org/linux/man-pages/man3/glob.3.html

    Description:
        Expands a pattern against the names in a directory, which is what
        a shell does when you write `*.txt`: `*` for any run of
        characters, `?` for one, `[abc]` for a set of them, and a
        backslash to take the magic out of any of those. What it finds is
        written into `pglob` as a vector of paths, sorted unless
        `GLOB_NOSORT` was asked for.

    Args:
        pattern: The pattern, possibly absolute, NUL terminated. Build
            one from a `String` with `string_to_char_ptr`.
        flags: What to expand for, as the `GLOB_*` above, or 0 for the
            defaults, which is sorted and silent.
        errfunc: Called on a directory it cannot open or read, when it is
            not NULL; ignored when it is. Give it `null_ptr[UInt8]()`,
            which is the only value this package can offer: a Mojo
            closure cannot be made into the C function pointer this slot
            wants.
        pglob: Where the answer is written. Zeroed before the call, and
            given to `globfree` afterwards whatever the call answered.

    Returns:
        0 however many or few paths turned up, `GLOB_NOMATCH` when none
        did and `GLOB_NOCHECK` was not set, `GLOB_NOSPACE` when the list
        could not be allocated, or `GLOB_ABORTED` when a directory could
        not be read and `GLOB_ERR` was set.

    Notes:
        Fn signature:
        `int glob(const char *restrict pattern, int flags, int (*errfunc)(const char *epath, int eerrno), glob_t *restrict pglob)`.

        The three non-zero answers are positive on glibc and negative on
        XNU — `GLOB_NOMATCH` being 3 here and -3 there — so compare
        against the names above rather than against a number.

        A pattern with no magic in it is still expanded, which is how a
        plain path turns into one entry; without `GLOB_NOCHECK`, nothing
        matching is a number rather than an empty list.
    """
    return external_call[
        "glob",
        Int32,
        c_ptr[UInt8],
        Int32,
        c_ptr[UInt8],
        c_ptr[glob_t],
    ](pattern, flags, errfunc, pglob)


def globfree(pglob: c_ptr[glob_t]) -> None:
    """C library <glob.h> function `globfree`.

    Reference:
        https://man7.org/linux/man-pages/man3/glob.3.html

    Args:
        pglob: What `glob` filled in. The vector and every string in it
            go with this call, so nothing read out of `gl_pathv` is good
            afterwards — `char_ptr_to_string` while it still is.
    """
    external_call["globfree", NoneType, c_ptr[glob_t]](pglob)
