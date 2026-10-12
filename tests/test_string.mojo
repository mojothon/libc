from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.string import (
    memchr,
    memcmp,
    strcasecmp,
    strchr,
    strcmp,
    strcoll,
    strcpy,
    strcspn,
    strerror,
    strlen,
    strncasecmp,
    strncmp,
    strnlen,
    strpbrk,
    strrchr,
    strsignal,
    strspn,
    strstr,
    strtok,
    strtok_r,
    strxfrm,
)
from libc.constant import c_ptr
from libc.utils import (
    char_ptr_to_string,
    null_ptr,
    string_to_char_ptr,
)


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


def test_memcmp_and_memchr() raises:
    var abc = string_to_char_ptr("abc")
    var abd = string_to_char_ptr("abd")

    assert_equal(
        Int(
            memcmp(
                abc.unsafe_bitcast[NoneType](),
                abd.unsafe_bitcast[NoneType](),
                3,
            )
        )
        < 0,
        True,
    )
    assert_equal(
        Int(
            memcmp(
                abd.unsafe_bitcast[NoneType](),
                abc.unsafe_bitcast[NoneType](),
                3,
            )
        )
        > 0,
        True,
    )
    assert_equal(
        Int(
            memcmp(
                abc.unsafe_bitcast[NoneType](),
                abc.unsafe_bitcast[NoneType](),
                3,
            )
        ),
        0,
    )

    var found = memchr(abc.unsafe_bitcast[NoneType](), 99, 3)
    assert_equal(Int(found) - Int(abc), 2)
    assert_equal(Int(memchr(abc.unsafe_bitcast[NoneType](), 122, 3)), 0)

    abc.unsafe_free()
    abd.unsafe_free()


def test_compare() raises:
    var abc = string_to_char_ptr("abc")
    var abd = string_to_char_ptr("abd")
    var upper = string_to_char_ptr("ABC")

    assert_equal(Int(strcmp(abc, abc)), 0)
    assert_true(Int(strcmp(abc, abd)) < 0, "abc sorts before abd")
    assert_true(Int(strcmp(abd, abc)) > 0, "abd sorts after abc")

    assert_equal(Int(strncmp(abc, abd, 2)), 0)
    assert_true(Int(strncmp(abc, abd, 3)) < 0, "the third byte decides")

    assert_equal(Int(strcasecmp(abc, upper)), 0)
    assert_equal(Int(strncasecmp(abc, upper, 3)), 0)

    assert_equal(Int(strcoll(abc, abc)), 0)

    abc.unsafe_free()
    abd.unsafe_free()
    upper.unsafe_free()


def test_strxfrm() raises:
    var src = string_to_char_ptr("abc")
    var dst = unsafe_alloc[UInt8](32)
    var n = strxfrm(dst, src, 32)
    assert_true(Int(n) >= 3, "the transform needs at least the input length")
    assert_true(strlen(dst) > 0, "the transform wrote something")
    dst.unsafe_free()
    src.unsafe_free()


def test_search() raises:
    var s = string_to_char_ptr("abcabc")

    assert_equal(char_ptr_to_string(strchr(s, 98)), "bcabc")
    assert_equal(char_ptr_to_string(strrchr(s, 98)), "bc")
    assert_equal(
        char_ptr_to_string(strstr(s, string_to_char_ptr("cab"))), "cabc"
    )
    assert_equal(
        char_ptr_to_string(strpbrk(s, string_to_char_ptr("zcb"))), "bcabc"
    )

    assert_equal(Int(strspn(s, string_to_char_ptr("abc"))), 6)
    assert_equal(Int(strspn(s, string_to_char_ptr("ab"))), 2)
    assert_equal(Int(strcspn(s, string_to_char_ptr("c"))), 2)

    # A miss comes back as a null pointer.
    assert_equal(Int(strchr(s, 122)), 0)
    assert_equal(Int(strstr(s, string_to_char_ptr("xyz"))), 0)

    s.unsafe_free()


def test_strtok_r() raises:
    var s = string_to_char_ptr("a,bb,ccc")
    var comma = string_to_char_ptr(",")
    var save = unsafe_alloc[c_ptr[UInt8]](1)

    assert_equal(char_ptr_to_string(strtok_r(s, comma, save)), "a")
    assert_equal(
        char_ptr_to_string(strtok_r(null_ptr[UInt8](), comma, save)), "bb"
    )
    assert_equal(
        char_ptr_to_string(strtok_r(null_ptr[UInt8](), comma, save)), "ccc"
    )
    assert_equal(Int(strtok_r(null_ptr[UInt8](), comma, save)), 0)

    save.unsafe_free()
    comma.unsafe_free()
    s.unsafe_free()


def test_strtok() raises:
    var s = string_to_char_ptr("x,y")
    var comma = string_to_char_ptr(",")

    assert_equal(char_ptr_to_string(strtok(s, comma)), "x")
    assert_equal(char_ptr_to_string(strtok(null_ptr[UInt8](), comma)), "y")
    assert_equal(Int(strtok(null_ptr[UInt8](), comma)), 0)

    comma.unsafe_free()
    s.unsafe_free()


def test_messages() raises:
    assert_true(strlen(strerror(0)) > 0, "every errno has a message")
    assert_true(strlen(strerror(2)) > 0, "ENOENT has a message")
    assert_true(strlen(strsignal(9)) > 0, "SIGKILL has a description")


def main() raises:
    test_strlen()
    test_strcpy()
    test_memcmp_and_memchr()
    test_compare()
    test_strxfrm()
    test_search()
    test_strtok_r()
    test_strtok()
    test_messages()
    print("test_string: ok")
