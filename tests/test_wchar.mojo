from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr, c_wchar
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr
from libc.wchar import (
    btowc,
    iswalnum,
    iswalpha,
    iswdigit,
    iswlower,
    iswspace,
    iswupper,
    mbrlen,
    mbrtowc,
    mbstowcs,
    mbstate_t,
    towlower,
    towupper,
    wcscat,
    wcschr,
    wcscmp,
    wcscpy,
    wcscspn,
    wcslen,
    wcsncmp,
    wcsncpy,
    wcsrchr,
    wcsspn,
    wcsstr,
    wcstombs,
    wcrtomb,
    wctob,
)


def wide(s: String) raises -> c_ptr[c_wchar]:
    """Copies an ASCII string into a null terminated wide buffer."""
    var buf = unsafe_alloc[c_wchar](s.byte_length() + 1)
    var i = 0
    for byte in s.bytes():
        buf.unsafe_store(i, Int32(byte))
        i += 1
    buf.unsafe_store(s.byte_length(), 0)
    return buf


def wide_to_string(s: c_ptr[c_wchar]) raises -> String:
    """Reads a null terminated wide buffer back, ASCII only."""
    var n = 0
    while s.unsafe_load(n) != 0:
        n += 1
    var bytes = unsafe_alloc[UInt8](n + 1)
    for i in range(n):
        bytes.unsafe_store(i, UInt8(s.unsafe_load(i)))
    bytes.unsafe_store(n, 0)
    var out = char_ptr_to_string(bytes)
    bytes.unsafe_free()
    return out


def test_length_and_compare() raises:
    var hi = wide("hi")
    var ho = wide("ho")

    assert_equal(Int(wcslen(hi)), 2)
    assert_equal(Int(wcslen(wide(""))), 0)

    assert_equal(Int(wcscmp(hi, hi)), 0)
    assert_true(Int(wcscmp(hi, ho)) < 0, "hi sorts before ho")
    assert_equal(Int(wcsncmp(hi, ho, 1)), 0)

    hi.unsafe_free()
    ho.unsafe_free()


def test_search() raises:
    var s = wide("hello")

    assert_equal(wide_to_string(wcschr(s, 108)), "llo")
    assert_equal(wide_to_string(wcsrchr(s, 108)), "lo")
    assert_equal(wide_to_string(wcsstr(s, wide("ll"))), "llo")

    assert_equal(Int(wcsspn(s, wide("hel"))), 4)
    assert_equal(Int(wcscspn(s, wide("o"))), 4)

    # A miss comes back as a null pointer.
    assert_equal(Int(wcschr(s, 122)), 0)
    assert_equal(Int(wcsstr(s, wide("zz"))), 0)

    s.unsafe_free()


def test_copy() raises:
    var src = wide("abc")
    var dest = unsafe_alloc[c_wchar](16)
    dest.unsafe_store(0, 0)

    _ = wcscpy(dest, src)
    assert_equal(wide_to_string(dest), "abc")

    # wcsncpy only writes a terminator when it does not fill the buffer.
    # Here it fills two of three slots and leaves the third one alone.
    var tight = unsafe_alloc[c_wchar](3)
    tight.unsafe_store(0, 122)
    tight.unsafe_store(1, 122)
    tight.unsafe_store(2, 122)
    _ = wcsncpy(tight, src, 2)
    assert_equal(Int(tight.unsafe_load(0)), 97)
    assert_equal(Int(tight.unsafe_load(1)), 98)
    assert_equal(Int(tight.unsafe_load(2)), 122)

    var roomy = unsafe_alloc[c_wchar](16)
    roomy.unsafe_store(0, 0)
    _ = wcsncpy(roomy, src, 16)
    assert_equal(wide_to_string(roomy), "abc")

    dest.unsafe_store(0, 120)
    dest.unsafe_store(1, 0)
    _ = wcscat(dest, wide("yz"))
    assert_equal(wide_to_string(dest), "xyz")

    roomy.unsafe_free()
    tight.unsafe_free()
    dest.unsafe_free()
    src.unsafe_free()


def test_multibyte() raises:
    # Under the default C locale, ASCII converts one byte to one character.
    var ascii = string_to_char_ptr("hi")
    var out = unsafe_alloc[c_wchar](8)
    assert_equal(Int(mbstowcs(out, ascii, 8)), 2)
    assert_equal(wide_to_string(out), "hi")

    var back = unsafe_alloc[UInt8](8)
    assert_equal(Int(wcstombs(back, out, 8)), 2)
    assert_equal(char_ptr_to_string(back), "hi")

    # One character at a time, letting libc keep the shift state.
    var one = unsafe_alloc[c_wchar](1)
    one.unsafe_store(0, 0)
    assert_equal(Int(mbrtowc(one, ascii, 2, null_ptr[mbstate_t]())), 1)
    assert_equal(Int(one.unsafe_load()), 104)

    var byte = unsafe_alloc[UInt8](8)
    assert_equal(Int(wcrtomb(byte, 104, null_ptr[mbstate_t]())), 1)
    assert_equal(char_ptr_to_string(byte), "h")

    assert_equal(Int(mbrlen(ascii, 2, null_ptr[mbstate_t]())), 1)

    one.unsafe_free()
    byte.unsafe_free()
    back.unsafe_free()
    out.unsafe_free()
    ascii.unsafe_free()


def test_classify() raises:
    assert_true(Int(iswalpha(65)) != 0, "A is a letter")
    assert_true(Int(iswalpha(48)) == 0, "0 is not")
    assert_true(Int(iswalnum(48)) != 0, "0 is alphanumeric")
    assert_true(Int(iswdigit(48)) != 0, "0 is a digit")
    assert_true(Int(iswdigit(65)) == 0, "A is not")
    assert_true(Int(iswspace(32)) != 0, "space is space")
    assert_true(Int(iswspace(65)) == 0, "A is not")
    assert_true(Int(iswupper(65)) != 0, "A is upper")
    assert_true(Int(iswupper(97)) == 0, "a is not")
    assert_true(Int(iswlower(97)) != 0, "a is lower")
    assert_true(Int(iswlower(65)) == 0, "A is not")

    assert_equal(Int(towupper(97)), 65)
    assert_equal(Int(towlower(65)), 97)
    assert_equal(Int(towupper(48)), 48)


def test_single_byte() raises:
    assert_equal(Int(btowc(65)), 65)
    assert_equal(Int(wctob(65)), 65)


def main() raises:
    test_length_and_compare()
    test_search()
    test_copy()
    test_multibyte()
    test_classify()
    test_single_byte()
    print("test_wchar: ok")
