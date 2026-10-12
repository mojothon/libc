from std.testing import assert_equal

from libc.constant import *


def test_int_bounds() raises:
    assert_equal(Int(INT_MIN), -2147483648)
    assert_equal(Int(INT_MAX), 2147483647)


def test_c_types() raises:
    assert_equal(Int(c_schar(-1)), -1)
    assert_equal(Int(c_uchar(255)), 255)
    assert_equal(Int(c_short(-2)), -2)
    assert_equal(Int(c_ushort(65535)), 65535)
    assert_equal(Int(c_int(-3)), -3)
    assert_equal(Int(c_uint(4294967295)), 4294967295)
    assert_equal(Int(c_long(-4)), -4)
    assert_equal(Int(c_ulong(5)), 5)


def test_stdio_constants() raises:
    assert_equal(STDIN_FILENO, 0)
    assert_equal(STDOUT_FILENO, 1)
    assert_equal(STDERR_FILENO, 2)
    assert_equal(SEEK_SET, 0)
    assert_equal(SEEK_CUR, 1)
    assert_equal(SEEK_END, 2)


def main() raises:
    test_int_bounds()
    test_c_types()
    test_stdio_constants()
    print("test_constant: ok")
