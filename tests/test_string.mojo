from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal

from libc.string import strcpy, strlen, strnlen
from libc.utils import char_ptr_to_string, string_to_char_ptr


def test_strlen() raises:
    var s = string_to_char_ptr("libc")
    assert_equal(Int(strlen(s)), 4)
    assert_equal(Int(strnlen(s, 32)), 4)
    s.unsafe_free()


def test_strcpy() raises:
    var src = string_to_char_ptr("hello, libc")
    var dst = unsafe_alloc[UInt8](32)
    _ = strcpy(dst, src)
    assert_equal(char_ptr_to_string(dst), "hello, libc")
    dst.unsafe_free()
    src.unsafe_free()


def main() raises:
    test_strlen()
    test_strcpy()
    print("test_string: ok")
