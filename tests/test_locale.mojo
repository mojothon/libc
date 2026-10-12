from std.testing import assert_equal, assert_true

from libc.locale import (
    LC_ALL,
    Locale,
    duplocale,
    freelocale,
    localeconv,
    newlocale,
    setlocale,
    uselocale,
)
from libc.string import strcmp, strlen
from libc.utils import null_ptr, string_to_char_ptr


def test_setlocale() raises:
    # The categories are numbered differently on Darwin, so a wrong one makes
    # this return a null pointer rather than a locale name.
    var c_locale = string_to_char_ptr("C")
    var name = setlocale(LC_ALL, c_locale)
    assert_true(Int(name) != 0, "the C locale was set")
    assert_equal(
        strcmp(name, c_locale), 0, "and that is the name that comes back"
    )
    c_locale.unsafe_free()


def test_localeconv() raises:
    var conv = localeconv()
    assert_true(Int(conv) != 0, "localeconv gave an object")

    var dot = string_to_char_ptr(".")
    var empty = string_to_char_ptr("")
    assert_equal(
        strcmp(conv[].decimal_point, dot), 0, "the decimal point is a dot"
    )
    assert_equal(
        strlen(conv[].thousands_sep),
        0,
        "the C locale has no thousands separator",
    )
    # CHAR_MAX, which is how the C locale says it has nothing to report.
    assert_equal(
        Int(conv[].int_frac_digits), 127, "no fraction digits to report"
    )
    assert_equal(Int(conv[].frac_digits), 127, "no fraction digits to report")

    dot.unsafe_free()
    empty.unsafe_free()


def test_locale_objects() raises:
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "the object was made")

    var copy = duplocale(loc)
    assert_true(Int(copy) != 0, "and it was copied")
    freelocale(copy)

    var previous = uselocale(loc)
    _ = uselocale(previous)
    freelocale(loc)

    c_locale.unsafe_free()
    # Leaving the thread without a locale of its own, so nothing after this
    # sees one that is about to be freed.
    _ = uselocale(null_ptr[Locale]())


def main() raises:
    test_setlocale()
    test_localeconv()
    test_locale_objects()
    print("test_locale: ok")
