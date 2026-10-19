# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


# How `fnmatch` is to treat a pattern. The surprise is the first two:
# `FNM_NOESCAPE` and `FNM_PATHNAME` trade places between glibc and XNU —
# 1 and 2 on one, 2 and 1 on the other — while the next three happen to
# agree, which is exactly the sort of near-agreement that catches a
# ported test out.
#
# `FNM_EXTMATCH` is glibc's alone (ksh-style extended patterns) and is
# not here rather than faked on XNU.
comptime FNM_NOESCAPE: Int32 = 1 if CompilationTarget.is_macos() else 2
comptime FNM_PATHNAME: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime FNM_PERIOD: Int32 = 4
comptime FNM_LEADING_DIR: Int32 = 8
comptime FNM_CASEFOLD: Int32 = 16

# What `fnmatch` answers when the name does not match: 1 on both, which
# after `EAI_*` and `GLOB_*` is its own kind of surprise.
comptime FNM_NOMATCH: Int32 = 1


def fnmatch(pattern: c_ptr[UInt8], string: c_ptr[UInt8], flags: Int32) -> Int32:
    """C library <fnmatch.h> function `fnmatch`.

    Reference:
        https://man7.org/linux/man-pages/man3/fnmatch.3.html

    Description:
        Whether one name matches one pattern, which is the question
        `glob` asks of every name it finds — `*` for any run of
        characters except `/` under `FNM_PATHNAME`, `?` for one
        character, `[abc]` for a set, and a backslash to take the magic
        out of any of them unless `FNM_NOESCAPE` says there is none.

    Args:
        pattern: The pattern, NUL terminated. Build one from a `String`
            with `string_to_char_ptr`.
        string: The name to try it against.
        flags: How to match, as the `FNM_*` above, or 0: `FNM_PATHNAME`
            keeps `*` and `?` from crossing a `/`, `FNM_PERIOD` keeps a
            leading `.` from being matched by anything but a literal
            one, and the two disagree about which of them is 1 and
            which 2, so ask for them by name.

    Returns:
        0 when the name matches, `FNM_NOMATCH` when it does not. Nothing
        else is an answer here — the header has no errno of its own.

    Notes:
        Fn signature:
        `int fnmatch(const char *pattern, const char *string, int flags)`.
    """
    return external_call["fnmatch", Int32, c_ptr[UInt8], c_ptr[UInt8], Int32](
        pattern, string, flags
    )
