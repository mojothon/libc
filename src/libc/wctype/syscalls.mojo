# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr

# glibc hands back a pointer into a table it keeps; Darwin hands back a small
# number. That is the one type in this header the two platforms have to be
# told apart over. The other kind of handle, the one `wctype` gives, is a
# number on both, so it needs no name of its own.
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

        `wctype` and `iswctype` are the other half of this header:
        one asks for a character class by name and the other asks
        whether a character belongs to it. Those two are bound here
        as well, so both kinds of handle have somewhere to go.
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


def wctype(property: c_ptr[UInt8]) -> UInt64:
    """Asks C for the character class a name stands for.

    What comes back is not a letter and not a rule that can be read:
    it is a handle, and the only thing it is good for is being handed
    back to `iswctype`. The twelve names POSIX promises -- "alnum",
    "alpha", "blank" and so on -- each buy a handle; a name C does
    not know buys one worth nothing, and that one is zero.

    Args:
        property: The name of the class, as bytes with a nil on the end.

    Returns:
        A handle for `iswctype`, or zero where the name is not known.

    Notes:
        This is not the kind of handle `wctrans` gives. A name that
        means a change of case, "toupper", is not a character class,
        so asking for it here answers zero even though `wctrans`
        knows it; the same is true the other way round.

        Both platforms answer with a number here, where the handle
        `wctrans` gives is a pointer on Linux and a number on Darwin.
        On Linux this one is an unsigned long, wide enough to hold an
        address; on Darwin it is a mask of bits. Both are unsigned
        64-bit integers as far as a call is concerned, so this one
        needs no name of its own the way `wctrans_t` does.
    """
    return external_call["wctype", UInt64, c_ptr[UInt8]](property)


def iswctype(c: c_int, desc: UInt64) -> c_int:
    """Asks whether one wide character belongs to a class asked for
    by name.

    The class comes in as the handle `wctype` gave, not as a name:
    asking by name is what `wctype` is for, and this is what the
    handle is for. A character in the class answers a nonzero number
    and one outside answers zero. The number itself is not worth
    reading -- one platform answers one and another answers a mask of
    bits -- so the question a caller asks is whether it is zero.

    Args:
        c: The wide character, as a number.
        desc: The handle `wctype` gave.

    Returns:
        Nonzero where the character is in the class, and zero where
        it is not or where the handle is worth nothing.

    Notes:
        This is answered in the C locale, which is the one a process
        starts in. A locale that classifies a character differently
        would have to be set first, and this package does not set one.
    """
    return external_call["iswctype", c_int, c_int, UInt64](c, desc)
