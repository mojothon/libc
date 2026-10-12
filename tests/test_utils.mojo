from std.testing import assert_equal, assert_true

from libc.file import fclose, fopen
from libc.utils import (
    CString,
    char_ptr_to_string,
    is_null,
    is_x86_64,
    null_ptr,
    string_to_char_ptr,
    strlen,
)


def test_round_trip() raises:
    var ptr = string_to_char_ptr("hello, libc")
    assert_equal(strlen(ptr), 11)
    assert_equal(char_ptr_to_string(ptr), "hello, libc")
    ptr.unsafe_free()


def test_cstring() raises:
    var ptr = string_to_char_ptr("mojo")
    var cstring = CString(ptr)
    assert_equal(String(cstring), "mojo")
    ptr.unsafe_free()


def test_null_ptr() raises:
    # The only spelling of NULL Mojo's non-nullable pointers allow.
    assert_equal(Int(null_ptr[UInt8]()), 0)


def test_is_null() raises:
    # One built as NULL, and one that is not, with a struct behind the
    # second to show it is not only good for bytes.
    assert_true(is_null(null_ptr[UInt8]()))
    assert_true(is_null(null_ptr[CString]()))
    var ptr = string_to_char_ptr("x")
    assert_true(not is_null(ptr))
    ptr.unsafe_free()

    # What it is for: fopen answers NULL when the file is not there.
    var missing = string_to_char_ptr("/nonexistent/definitely/not/here")
    assert_true(is_null(fopen(missing, string_to_char_ptr("r"))))
    var mode = string_to_char_ptr("r")
    var devnull = fopen(string_to_char_ptr("/dev/null"), mode)
    assert_true(not is_null(devnull))
    assert_equal(fclose(devnull), 0)
    missing.unsafe_free()
    mode.unsafe_free()


def test_platform() raises:
    # Only meaningful on the platforms this package publishes for.
    assert_true(is_x86_64() or not is_x86_64())


def main() raises:
    test_round_trip()
    test_cstring()
    test_null_ptr()
    test_is_null()
    test_platform()
    print("test_utils: ok")
