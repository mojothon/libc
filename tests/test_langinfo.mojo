"""Tests for the `libc.langinfo` bindings.

Nothing here sets a locale, so every answer is the C locale's, and the C
locale's answers are the ones POSIX fixes rather than the ones a
particular machine's language decides. That is what makes exact strings
worth asserting: `Sun`, `Sunday`, `January` and `%H:%M:%S` are the same
on both platforms.

What the tests never do is write a number down. Not one of the fifty-five
`nl_item`s is the same value on the two, so every one of them is asked
for by name.
"""
from std.testing import assert_equal, assert_true

from libc.langinfo import (
    ABDAY_1,
    ABDAY_2,
    ABMON_1,
    AM_STR,
    CODESET,
    DAY_1,
    D_FMT,
    MON_1,
    PM_STR,
    RADIXCHAR,
    T_FMT,
    THOUSEP,
    nl_langinfo,
)
from libc.utils import char_ptr_to_string


def test_the_names_of_days_and_months_are_the_locales_own() raises:
    """The first weekday is Sunday and the first month is January, and
    each has a full spelling and an abbreviated one. These are the C
    locale's and therefore both platforms'.
    """
    assert_equal(
        char_ptr_to_string(nl_langinfo(ABDAY_1)), "Sun", "Sunday abbreviated"
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(ABDAY_2)), "Mon", "and so is Monday"
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(DAY_1)), "Sunday", "and in full"
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(MON_1)), "January", "the first month"
    )
    assert_equal(char_ptr_to_string(nl_langinfo(ABMON_1)), "Jan", "abbreviated")


def test_how_the_locale_writes_a_time_and_a_date() raises:
    """The formats `strftime` would use, handed back as strings. The C
    locale's time and date formats are fixed by POSIX, so these are the
    same on both platforms; how a clock is spelled in the morning and in
    the evening goes with them.
    """
    assert_equal(
        char_ptr_to_string(nl_langinfo(T_FMT)), "%H:%M:%S", "the time format"
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(D_FMT)),
        "%m/%d/%y",
        "and the date format",
    )
    assert_equal(char_ptr_to_string(nl_langinfo(AM_STR)), "AM", "the morning")
    assert_equal(
        char_ptr_to_string(nl_langinfo(PM_STR)), "PM", "and the evening"
    )


def test_how_the_locale_writes_a_number() raises:
    """What goes between the whole part of a number and the rest of it,
    and what goes between the thousands. The C locale has a decimal
    point and no thousands separator at all, which is the empty string
    rather than nothing: this call answers the empty string for a
    question the locale has no answer to.
    """
    assert_equal(
        char_ptr_to_string(nl_langinfo(RADIXCHAR)), ".", "the decimal point"
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(THOUSEP)),
        "",
        "and no separator between thousands",
    )


def test_the_codeset_has_a_name_and_an_item_nobody_defines_does_not() raises:
    """Two answers that are not about language. The character set is
    named even in the C locale — `ANSI_X3.4-1968` on glibc, `US-ASCII` on
    Darwin — so what is checked is that it is named, not what it is
    called.

    An item no platform defines is answered with the empty string, and
    that is the whole of what the two agree on here: it is how this call
    says there is no such item, and a test that assumed a NULL would be
    wrong on both.
    """
    assert_true(
        char_ptr_to_string(nl_langinfo(CODESET)).byte_length() > 0,
        "the character set is named",
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(999999)), "", "no item is numbered that"
    )
    assert_equal(
        char_ptr_to_string(nl_langinfo(-1)), "", "and none is numbered -1"
    )


def main() raises:
    test_the_names_of_days_and_months_are_the_locales_own()
    test_how_the_locale_writes_a_time_and_a_date()
    test_how_the_locale_writes_a_number()
    test_the_codeset_has_a_name_and_an_item_nobody_defines_does_not()
    print("test_langinfo: ok")
