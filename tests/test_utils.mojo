from std.testing import assert_equal, assert_true

from libc.utils import (
    CString,
    char_ptr_to_string,
    is_x86_64,
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


def test_platform() raises:
    # Only meaningful on the platforms this package publishes for.
    assert_true(is_x86_64() or not is_x86_64())


def main() raises:
    test_round_trip()
    test_cstring()
    test_platform()
    print("test_utils: ok")
