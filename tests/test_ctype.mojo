from std.testing import assert_equal, assert_true

from libc.ctype import (
    isalpha,
    isdigit,
    islower,
    islower_l,
    isspace,
    isupper,
    isupper_l,
)
from libc.locale import LC_ALL, Locale, freelocale, newlocale
from libc.utils import null_ptr, string_to_char_ptr


def test_islower() raises:
    assert_equal(islower(Int32(ord("a"))) != 0, True)
    assert_equal(islower(Int32(ord("A"))), 0)


def test_isupper() raises:
    assert_equal(isupper(Int32(ord("A"))) != 0, True)
    assert_equal(isupper(Int32(ord("a"))), 0)


def test_isalpha() raises:
    assert_equal(isalpha(Int32(ord("z"))) != 0, True)
    assert_equal(isalpha(Int32(ord("7"))), 0)


def test_isdigit() raises:
    assert_equal(isdigit(Int32(ord("7"))) != 0, True)
    assert_equal(isdigit(Int32(ord("z"))), 0)


def test_isspace() raises:
    assert_equal(isspace(Int32(ord(" "))) != 0, True)
    assert_equal(isspace(Int32(ord("x"))), 0)


def test_l_variants_take_a_locale() raises:
    # They were declared as taking a character and nothing else, so libc read
    # whatever was next to it as the locale.
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "the locale object was made")

    assert_true(islower_l(Int32(ord("a")), loc) != 0, "'a' is lowercase there")
    assert_equal(islower_l(Int32(ord("A")), loc), 0, "'A' is not")
    assert_true(isupper_l(Int32(ord("A")), loc) != 0, "'A' is uppercase there")
    assert_equal(isupper_l(Int32(ord("a")), loc), 0, "'a' is not")

    freelocale(loc)
    c_locale.unsafe_free()


def main() raises:
    test_l_variants_take_a_locale()
    test_islower()
    test_isupper()
    test_isalpha()
    test_isdigit()
    test_isspace()
    print("test_ctype: ok")
