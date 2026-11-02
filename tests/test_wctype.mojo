"""Tests for the `libc.wctype` bindings.

Four functions in two pairs. `wctrans` and `towctrans` ask for a change
of case by name and carry it out; `wctype` and `iswctype` do the same for
a character class. Neither handle is ever looked at: one platform's is
a pointer into a table and the other's is a number or a mask of bits,
and nothing that can be said about one is true of the other.

What can be said is that the two halves agree. The second test asks a
class for a name and then, for every one of the 128 ASCII characters,
whether `iswctype` puts that character in it. The answer has to be the
one the twelve named classifiers in `libc.wchar` already give. Nothing
about the handle's value is written down, and neither is a table of
which characters belong where: those twelve bindings are the table.
"""
from std.testing import assert_equal

from libc.constant import c_int
from libc.utils import string_to_char_ptr
from libc.wchar import (
    iswalnum,
    iswalpha,
    iswblank,
    iswcntrl,
    iswdigit,
    iswgraph,
    iswlower,
    iswprint,
    iswpunct,
    iswspace,
    iswupper,
    iswxdigit,
)
from libc.wctype import iswctype, towctrans, wctrans, wctype


def test_the_two_changes_of_case() raises:
    """The two names POSIX promises, asked for and then carried out.

    A goes down to a and a goes up to A, and those two are the whole
    of what is asked for. They are asked in the C locale, which is
    the one a process starts in, and the letters are two that the C
    locale has no other idea about.

    What is asked beyond those is what the same handle does to a
    character with no case at all: a digit and a space come back as
    they went in. A handle that had been mixed up with the other one
    would still answer these right, so they pin less down than the
    letters do, but they are the difference between a binding that
    changes case and one that returns whatever it likes.
    """
    var lower_name = string_to_char_ptr("tolower")
    var down = wctrans(lower_name)
    lower_name.unsafe_free()

    var upper_name = string_to_char_ptr("toupper")
    var up = wctrans(upper_name)
    upper_name.unsafe_free()

    assert_equal(Int(towctrans(c_int(65), down)), 97, "A goes down to a")
    assert_equal(Int(towctrans(c_int(97), up)), 65, "and a goes up to A")

    assert_equal(Int(towctrans(c_int(49), down)), 49, "a digit has no case")
    assert_equal(Int(towctrans(c_int(32), up)), 32, "and nor does a space")

    assert_equal(
        Int(towctrans(c_int(97), down)), 97, "a letter already down stays put"
    )
    assert_equal(
        Int(towctrans(c_int(65), up)), 65, "and one already up likewise"
    )


def class_handle(name: String) -> UInt64:
    """Ask for one class by name, then give the bytes back."""
    var bytes = string_to_char_ptr(name)
    var desc = wctype(bytes)
    bytes.unsafe_free()
    return desc


def test_a_class_asked_for_by_name() raises:
    """A handle from `wctype` has to classify exactly what the named
    classifiers say, across all of ASCII.

    A wrong symbol, a descriptor of the wrong width, or an argument
    order reversed would not survive one of these; 128 characters
    times twelve names makes 1536 of them. The nonzero answer is
    compared as a boolean because one platform answers 1 and the
    other answers a mask of bits, so only "is it zero" travels.

    Nothing here says what a handle looks like. What is written down
    is that an unknown name, and a name that means a change of case,
    are not character classes, and that a zero handle classifies
    nothing at all.
    """
    var alnum = class_handle("alnum")
    var alpha = class_handle("alpha")
    var blank = class_handle("blank")
    var cntrl = class_handle("cntrl")
    var digit = class_handle("digit")
    var graph = class_handle("graph")
    var lower = class_handle("lower")
    var print = class_handle("print")
    var punct = class_handle("punct")
    var space = class_handle("space")
    var upper = class_handle("upper")
    var xdigit = class_handle("xdigit")

    for i in range(128):
        var c = Int32(i)
        assert_equal(iswctype(c, alnum) != 0, iswalnum(c) != 0, "alnum")
        assert_equal(iswctype(c, alpha) != 0, iswalpha(c) != 0, "alpha")
        assert_equal(iswctype(c, blank) != 0, iswblank(c) != 0, "blank")
        assert_equal(iswctype(c, cntrl) != 0, iswcntrl(c) != 0, "cntrl")
        assert_equal(iswctype(c, digit) != 0, iswdigit(c) != 0, "digit")
        assert_equal(iswctype(c, graph) != 0, iswgraph(c) != 0, "graph")
        assert_equal(iswctype(c, lower) != 0, iswlower(c) != 0, "lower")
        assert_equal(iswctype(c, print) != 0, iswprint(c) != 0, "print")
        assert_equal(iswctype(c, punct) != 0, iswpunct(c) != 0, "punct")
        assert_equal(iswctype(c, space) != 0, iswspace(c) != 0, "space")
        assert_equal(iswctype(c, upper) != 0, iswupper(c) != 0, "upper")
        assert_equal(iswctype(c, xdigit) != 0, iswxdigit(c) != 0, "xdigit")

    var unknown = string_to_char_ptr("no-such-class")
    assert_equal(wctype(unknown), 0, "a name nobody knows buys nothing")
    unknown.unsafe_free()

    var for_change = string_to_char_ptr("toupper")
    assert_equal(
        wctype(for_change), 0, "nor does a change of case name a class"
    )
    for_change.unsafe_free()

    assert_equal(
        iswctype(Int32(65), 0), 0, "and a zero handle classifies nothing"
    )


def main() raises:
    test_the_two_changes_of_case()
    test_a_class_asked_for_by_name()
    print("test_wctype: ok")
