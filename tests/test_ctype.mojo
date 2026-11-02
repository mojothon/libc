from std.testing import assert_equal, assert_true

from libc.ctype import (
    isalnum,
    isalnum_l,
    isalpha,
    isalpha_l,
    isascii,
    isascii_l,
    isblank,
    isblank_l,
    iscntrl,
    iscntrl_l,
    isdigit,
    isdigit_l,
    isgraph,
    isgraph_l,
    islower,
    islower_l,
    isprint,
    isprint_l,
    ispunct,
    ispunct_l,
    isspace,
    isspace_l,
    isupper,
    isupper_l,
    isxdigit,
    isxdigit_l,
    toascii,
    tolower,
    tolower_l,
    toupper,
    toupper_l,
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


comptime ISALNUM = (
    "00000000000000000000000000000000"
    + "00000000000000001111111111000000"
    + "01111111111111111111111111100000"
    + "01111111111111111111111111100000"
)

comptime ISXDIGIT = (
    "00000000000000000000000000000000"
    + "00000000000000001111111111000000"
    + "01111110000000000000000000000000"
    + "01111110000000000000000000000000"
)

comptime ISBLANK = (
    "00000000010000000000000000000000"
    + "10000000000000000000000000000000"
    + "00000000000000000000000000000000"
    + "00000000000000000000000000000000"
)

comptime ISCNTRL = (
    "11111111111111111111111111111111"
    + "00000000000000000000000000000000"
    + "00000000000000000000000000000000"
    + "00000000000000000000000000000001"
)

comptime ISGRAPH = (
    "00000000000000000000000000000000"
    + "01111111111111111111111111111111"
    + "11111111111111111111111111111111"
    + "11111111111111111111111111111110"
)

comptime ISPRINT = (
    "00000000000000000000000000000000"
    + "11111111111111111111111111111111"
    + "11111111111111111111111111111111"
    + "11111111111111111111111111111110"
)

comptime ISPUNCT = (
    "00000000000000000000000000000000"
    + "01111111111111110000000000111111"
    + "10000000000000000000000000011111"
    + "10000000000000000000000000011110"
)

comptime ISASCII = (
    "11111111111111111111111111111111"
    + "11111111111111111111111111111111"
    + "11111111111111111111111111111111"
    + "11111111111111111111111111111111"
)


def _bit(table: String, i: Int) -> Bool:
    """The i-th character of one of the tables above, as true or false."""
    return Int(table.as_bytes()[i]) == 49  # ord("1")


def test_classification_against_c() raises:
    """Every one of the eight, on every one of the 128 ASCII characters.

    The tables were made by asking C itself, in the C locale, and are written
    out above; a binding that calls the wrong function or hands the character
    over as the wrong thing disagrees with them somewhere in here.
    """
    var bad_isalnum = 0
    var bad_isxdigit = 0
    var bad_isblank = 0
    var bad_iscntrl = 0
    var bad_isgraph = 0
    var bad_isprint = 0
    var bad_ispunct = 0
    var bad_isascii = 0
    for c in range(128):
        var ch = Int32(c)
        if (isalnum(ch) != 0) != _bit(ISALNUM, c):
            bad_isalnum += 1
        if (isxdigit(ch) != 0) != _bit(ISXDIGIT, c):
            bad_isxdigit += 1
        if (isblank(ch) != 0) != _bit(ISBLANK, c):
            bad_isblank += 1
        if (iscntrl(ch) != 0) != _bit(ISCNTRL, c):
            bad_iscntrl += 1
        if (isgraph(ch) != 0) != _bit(ISGRAPH, c):
            bad_isgraph += 1
        if (isprint(ch) != 0) != _bit(ISPRINT, c):
            bad_isprint += 1
        if (ispunct(ch) != 0) != _bit(ISPUNCT, c):
            bad_ispunct += 1
        if (isascii(ch) != 0) != _bit(ISASCII, c):
            bad_isascii += 1
    assert_equal(bad_isalnum, 0, "isalnum agrees with C on all 128")
    assert_equal(bad_isxdigit, 0, "isxdigit agrees with C on all 128")
    assert_equal(bad_isblank, 0, "isblank agrees with C on all 128")
    assert_equal(bad_iscntrl, 0, "iscntrl agrees with C on all 128")
    assert_equal(bad_isgraph, 0, "isgraph agrees with C on all 128")
    assert_equal(bad_isprint, 0, "isprint agrees with C on all 128")
    assert_equal(bad_ispunct, 0, "ispunct agrees with C on all 128")
    assert_equal(bad_isascii, 0, "isascii agrees with C on all 128")


def test_conversion() raises:
    """`tolower` and `toupper` move the 26 letters and leave everything else
    alone; `toascii` keeps the low seven bits of anything up to 255.
    """
    var bad_lower = 0
    var bad_upper = 0
    for c in range(128):
        var want_lower = c + 32 if 65 <= c <= 90 else c
        var want_upper = c - 32 if 97 <= c <= 122 else c
        if Int(tolower(Int32(c))) != want_lower:
            bad_lower += 1
        if Int(toupper(Int32(c))) != want_upper:
            bad_upper += 1
    assert_equal(bad_lower, 0, "tolower moves A to Z and nothing else")
    assert_equal(bad_upper, 0, "toupper moves a to z and nothing else")

    var bad_ascii = 0
    for c in range(256):
        if Int(toascii(Int32(c))) != (c & 0x7F):
            bad_ascii += 1
    assert_equal(bad_ascii, 0, "toascii keeps the low seven bits")


def test_l_variants_agree_in_the_c_locale() raises:
    """The `_l` ones take a locale as their second argument, and in the C
    locale each has to say the same thing as the plain one. They were
    declared as taking a character and nothing else once, which left libc
    to read whatever came next as the locale.
    """
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "the locale object was made")

    var bad_l = 0
    for c in range(128):
        var ch = Int32(c)
        if (isalnum_l(ch, loc) != 0) != (isalnum(ch) != 0):
            bad_l += 1
        if (isalpha_l(ch, loc) != 0) != (isalpha(ch) != 0):
            bad_l += 1
        if (isspace_l(ch, loc) != 0) != (isspace(ch) != 0):
            bad_l += 1
        if (isxdigit_l(ch, loc) != 0) != (isxdigit(ch) != 0):
            bad_l += 1
        if (isblank_l(ch, loc) != 0) != (isblank(ch) != 0):
            bad_l += 1
        if (iscntrl_l(ch, loc) != 0) != (iscntrl(ch) != 0):
            bad_l += 1
        if (isgraph_l(ch, loc) != 0) != (isgraph(ch) != 0):
            bad_l += 1
        if (isprint_l(ch, loc) != 0) != (isprint(ch) != 0):
            bad_l += 1
        if (ispunct_l(ch, loc) != 0) != (ispunct(ch) != 0):
            bad_l += 1
        if Int(tolower_l(ch, loc)) != Int(tolower(ch)):
            bad_l += 1
        if Int(toupper_l(ch, loc)) != Int(toupper(ch)):
            bad_l += 1
    assert_equal(bad_l, 0, "each _l call agrees with the plain one")

    freelocale(loc)
    c_locale.unsafe_free()


def test_isdigit_l_takes_a_locale() raises:
    """`isdigit_l` is `isdigit` asked of a locale that is handed to
    it rather than of whatever one happens to be in force. The C
    locale is made here and asked which characters are digits, which
    is the ten that every locale agrees on.
    """
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "the locale object was made")

    assert_true(isdigit_l(Int32(ord("7")), loc) != 0, "'7' is a digit there")
    assert_equal(isdigit_l(Int32(ord("x")), loc), 0, "'x' is not")
    assert_equal(isdigit_l(Int32(ord(" ")), loc), 0, "nor is a space")

    freelocale(loc)
    c_locale.unsafe_free()


def main() raises:
    test_classification_against_c()
    test_conversion()
    test_l_variants_agree_in_the_c_locale()
    test_l_variants_take_a_locale()
    test_islower()
    test_isupper()
    test_isalpha()
    test_isdigit()
    test_isdigit_l_takes_a_locale()
    test_isspace()
    print("test_ctype: ok")
