"""Tests for the `libc.wctype` bindings.

Two functions, and one of them is only there to feed the other.
`wctrans` takes a name and hands back a handle; `towctrans` takes a
wide character and a handle and changes the case of one. The handle
is never looked at, which is just as well: one platform's is a
pointer into a table and the other's is a small number, and nothing
that can be said about one is true of the other.
"""
from std.testing import assert_equal

from libc.constant import c_int
from libc.utils import string_to_char_ptr
from libc.wctype import towctrans, wctrans


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


def main() raises:
    test_the_two_changes_of_case()
    print("test_wctype: ok")
