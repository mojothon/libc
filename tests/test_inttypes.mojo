from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr, c_wchar
from libc.inttypes import (
    imaxabs,
    imaxdiv,
    strtoimax,
    strtoumax,
    wcstoimax,
    wcstoumax,
)
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def wide(s: String) raises -> c_ptr[c_wchar]:
    """Copies an ASCII string into a null terminated wide buffer."""
    var buf = unsafe_alloc[c_wchar](s.byte_length() + 1)
    var i = 0
    for byte in s.bytes():
        buf.unsafe_store(i, Int32(byte))
        i += 1
    buf.unsafe_store(s.byte_length(), 0)
    return buf


def test_imax() raises:
    assert_equal(imaxabs(-7), 7)
    assert_equal(imaxabs(7), 7)


def test_imaxdiv_truncates_toward_zero() raises:
    """`imaxdiv` returns both the quotient and the remainder as
    one value. The quotient is truncated toward zero: -10 / 3
    comes out as -3 with a remainder of -1, the way C99 says
    it should, not -4 with a remainder of 2, the way floor
    division would have it.
    """
    var r = imaxdiv(10, 3)
    assert_equal(r.quot, 3, "ten divided by three is three")
    assert_equal(r.rem, 1, "with one left over")

    r = imaxdiv(-10, 3)
    assert_equal(
        r.quot, -3, "minus ten divided by three is minus three, not four"
    )
    assert_equal(
        r.rem, -1, "with a remainder that keeps the sign of the dividend"
    )

    r = imaxdiv(10, -3)
    assert_equal(
        r.quot, -3, "and ten divided by minus three is also minus three"
    )
    assert_equal(r.rem, 1, "with a remainder of one")

    r = imaxdiv(7, 1)
    assert_equal(r.quot, 7, "and seven divided by one is seven")
    assert_equal(r.rem, 0, "with nothing left over")

    r = imaxdiv(0, 5)
    assert_equal(r.quot, 0, "and zero divided by five is zero")
    assert_equal(r.rem, 0, "with nothing left over")

    var divided = imaxdiv(17, 5)
    assert_equal(divided.quot, 3)
    assert_equal(divided.rem, 2)

    var negative = imaxdiv(-17, 5)
    assert_equal(negative.quot, -3)
    assert_equal(negative.rem, -2)


def test_strto() raises:
    var s = string_to_char_ptr("  42abc")
    var end = unsafe_alloc[c_ptr[UInt8]](1)

    assert_equal(strtoimax(s, end, 10), 42)
    # endptr lands on the first character that did not convert.
    assert_equal(char_ptr_to_string(end[]), "abc")

    var hex = string_to_char_ptr("ff")
    assert_equal(strtoimax(hex, null_ptr[c_ptr[UInt8]](), 16), 255)
    assert_equal(strtoumax(hex, null_ptr[c_ptr[UInt8]](), 16), 255)

    # Unsigned parsing of a negative string wraps, which is what C does.
    var negative = string_to_char_ptr("-1")
    assert_equal(strtoimax(negative, null_ptr[c_ptr[UInt8]](), 10), -1)
    assert_equal(
        strtoumax(negative, null_ptr[c_ptr[UInt8]](), 10),
        18446744073709551615,
    )

    end.unsafe_free()
    negative.unsafe_free()
    hex.unsafe_free()
    s.unsafe_free()


def test_wcsto() raises:
    var s = wide("42")
    assert_equal(wcstoimax(s, null_ptr[c_ptr[c_wchar]](), 10), 42)
    assert_equal(wcstoumax(s, null_ptr[c_ptr[c_wchar]](), 10), 42)

    var wide_end = wide("7zz")
    var end = unsafe_alloc[c_ptr[c_wchar]](1)
    assert_equal(wcstoimax(wide_end, end, 10), 7)
    assert_true(Int(end[]) != 0, "endptr points at the rest")

    end.unsafe_free()
    wide_end.unsafe_free()
    s.unsafe_free()


def main() raises:
    test_imax()
    test_imaxdiv_truncates_toward_zero()
    test_strto()
    test_wcsto()
    print("test_inttypes: ok")
