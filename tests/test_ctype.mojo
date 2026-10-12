from std.testing import assert_equal

from libc.ctype import isalpha, isdigit, islower, isspace, isupper


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


def main() raises:
    test_islower()
    test_isupper()
    test_isalpha()
    test_isdigit()
    test_isspace()
    print("test_ctype: ok")
