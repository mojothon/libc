# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr

# glibc hands back a pointer into a table it keeps; Darwin hands back a small
# number. Nothing else in the header is bound, so this is the one type the two
# of them have to be told apart over.
comptime wctrans_t = Int32 if CompilationTarget.is_macos() else c_ptr[Int32]


def wctrans(property: c_ptr[UInt8]) -> wctrans_t:
    """Asks C for the change of case that a name stands for.

    What comes back is not a letter and not a rule that can be read: it
    is a handle, and the only thing it is good for is being handed back
    to `towctrans`. `wctrans("tolower")` is the one that takes a letter
    down and `wctrans("toupper")` the one that takes it up. Those two
    names are all POSIX promises, and a name C does not know buys a
    handle worth nothing.

    Args:
        property: The name of the change, "tolower" or "toupper", as
            bytes with a nil on the end.

    Returns:
        A handle for `towctrans`.

    Notes:
        The two platforms do not agree on what a handle is, which is
        why this package gives the type a name: `wctrans_t` is the one
        this platform uses, and `towctrans` takes whichever it is
        handed.

        `wctype` and `iswctype` are the other half of this header.
        Darwin has no `iswctype`, and the number `wctype` gives has
        nothing to be given to without it, so neither is bound.
    """
    return external_call["wctrans", wctrans_t, c_ptr[UInt8]](property)


def towctrans(c: c_int, desc: wctrans_t) -> c_int:
    """Carries out the change of case `desc` stands for, on one wide
    character.

    A character with a case has it changed. Anything else -- a digit, a
    space, a character with no upper and no lower -- comes back as it
    went in. The change is the one `wctrans` was asked for by name,
    and it is the same change whatever is put under it.

    Args:
        c: The wide character, as a number.
        desc: The handle `wctrans` gave.

    Returns:
        The character changed, or the same one back where there is
        nothing to change.

    Notes:
        This is answered in the C locale, which is the one a process
        starts in. A locale that maps a letter somewhere else would
        have to be set first, and this package does not set one.
    """
    return external_call["towctrans", c_int, c_int, wctrans_t](c, desc)
