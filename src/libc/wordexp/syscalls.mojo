# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr
from libc.utils import null_ptr


# `WRDE_NOCMD` is 4 on both platforms. The other two are 1 and 2 in
# opposite orders: glibc has `WRDE_DOOFFS` 1 and `WRDE_APPEND` 2, XNU has
# `WRDE_APPEND` 1 and `WRDE_DOOFFS` 2. So the swap is a swap and not a
# renumbering.
comptime WRDE_NOCMD: Int32 = 4
comptime WRDE_DOOFFS: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime WRDE_APPEND: Int32 = 1 if CompilationTarget.is_macos() else 2


struct wordexp_t:
    """A C `wordexp_t`: where `wordexp` put the words it found.

    The one struct of this family the two platforms agree on to the byte
    — 24 of them, `size_t`, `char **`, `size_t`, in that order on both,
    with nothing in between. XNU calls the third one `we_offs` and glibc
    calls it `we_we_offs`, which is a difference in a name and not in a
    place.

    The vector is NULL-terminated as well as counted, so either number
    will do to walk it; the count is the cheaper of the two.
    """

    # How many words there are, not counting the NULL that ends them.
    var we_wordc: UInt64
    # The words themselves, read each one with `char_ptr_to_string`.
    var we_wordv: c_ptr[c_ptr[UInt8]]
    # How many entries were asked to be left empty at the head of the
    # vector, by `WRDE_DOOFFS`. Zero unless that flag was given.
    var we_offs: UInt64

    def __init__(out self):
        """Zeroes the block, which is what `wordexp` expects to be given."""
        self.we_wordc = 0
        self.we_wordv = null_ptr[c_ptr[UInt8]]()
        self.we_offs = 0


def wordexp(
    words: c_ptr[UInt8], result: c_ptr[wordexp_t], flags: c_int
) -> Int32:
    """C library <wordexp.h> function `wordexp`.

    Reference:
        https://man7.org/linux/man-pages/man3/wordexp.3.html

    Args:
        words: The line to expand, as a NUL-terminated string.
        result: The `wordexp_t` to fill in. It is the caller's storage,
            but the vector and the strings in it belong to libc once this
            has returned.
        flags: `WRDE_NOCMD` to refuse command substitution rather than
            run it, `WRDE_DOOFFS` to leave room at the head of the
            vector, `WRDE_APPEND` to add to what is already there rather
            than start again.

    Returns:
        0 with the words in `result`, or one of the `WRDE_*` error
        numbers — 1 for a character that cannot appear, 3 for a command
        substitution where `WRDE_NOCMD` forbade one, 6 for a line that
        does not parse.

    Notes:
        Splits a line the way a shell would: on whitespace, with quotes
        and backslashes taking the meaning out of what they cover. Two
        spaces in a row are one gap, which is the difference between this
        and cutting a string on every space.

        Everything it allocates is libc's, so what releases it is
        `wordfree` and not `free` — the pointer came from somewhere this
        package does not know about, and handing it to the other
        allocator is the sort of mistake that reads as working until it
        does not.

        Nothing is expanded that a shell would not expand, which is the
        point of it and also the reason for `WRDE_NOCMD`: without that
        flag a line that came from somewhere untrusted can run a command.
    """
    return external_call[
        "wordexp", Int32, c_ptr[UInt8], c_ptr[wordexp_t], c_int
    ](words, result, flags)


def wordfree(result: c_ptr[wordexp_t]) -> None:
    """C library <wordexp.h> function `wordfree`.

    Reference:
        https://man7.org/linux/man-pages/man3/wordexp.3.html

    Args:
        result: What `wordexp` filled in. The vector and every string in
            it go with this call, so nothing read out of `we_wordv` is
            good afterwards — `char_ptr_to_string` while it still is.
    """
    external_call["wordfree", NoneType, c_ptr[wordexp_t]](result)
