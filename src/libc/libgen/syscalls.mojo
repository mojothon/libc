# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


# glibc's `<libgen.h>` does not declare `basename` at all: it declares
# `__xpg_basename` and `#define basename __xpg_basename`, because the
# symbol `basename` in its libc.so is the GNU one from `<string.h>`, and
# the two differ on `/usr/lib/` — the GNU one answers the empty string,
# the POSIX one answers `lib`. The macro means a C caller never sees it,
# and an `external_call` has no macros, so the POSIX one is asked for by
# the name the header actually exports. XNU has no such second basename;
# its `basename` is the POSIX one.
comptime _BASENAME = "basename" if CompilationTarget.is_macos() else "__xpg_basename"


def basename(path: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <libgen.h> function `basename`.

    Reference:
        https://man7.org/linux/man-pages/man3/basename.3.html

    Description:
        The last part of a path: what is left of `/usr/bin/ls` once the
        directory is taken off. Trailing slashes do not count, so
        `/usr/lib/` still answers `lib`, and a path that is nothing but
        slashes answers `/`. A path with no slash in it is its own last
        part, and an empty path answers `.`.

    Args:
        path: The path, NUL terminated, from `string_to_char_ptr`.

            POSIX lets the answer be written back over the argument, and
            XNU takes it up on that, so do not count on the string being
            readable as it was afterwards — `char_ptr_to_string` the
            answer first.

    Returns:
        The last part, as a pointer into the argument or into storage
        libc owns; either way it is NUL terminated and nothing here owns
        it.

    Notes:
        Fn signature:
        `char *basename(char *path)`.

        glibc keeps a second `basename` in `<string.h>` that answers `""`
        for `/usr/lib/`; this is the POSIX one from `<libgen.h>`, which
        glibc exports under the name `__xpg_basename` and its header
        renames with a macro. That is the name this call asks for on
        glibc, and `basename` on XNU, where the one symbol is POSIX's.
    """
    return external_call[_BASENAME, c_ptr[UInt8], c_ptr[UInt8]](path)


def dirname(path: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <libgen.h> function `dirname`.

    Reference:
        https://man7.org/linux/man-pages/man3/basename.3.html

    Description:
        The directory part of a path: everything of `/usr/bin/ls` before
        the last slash, so `/usr/bin`. A path with no slash in it has
        `.` for a directory, trailing slashes are trimmed before any of
        that is decided, and `/` is its own directory.

    Args:
        path: The path, NUL terminated, from `string_to_char_ptr`.

            The answer is written back over the argument — both
            platforms take POSIX up on that here — so the string is
            shorter afterwards than it was, and anything still pointing
            past the cut is stale.

    Returns:
        The directory part, as a pointer into the argument or into
        storage libc owns; NUL terminated either way.

    Notes:
        Fn signature:
        `char *dirname(char *path)`.
    """
    return external_call["dirname", c_ptr[UInt8], c_ptr[UInt8]](path)
