from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.stdlib import free
from libc.string import (
    ffs,
    ffsl,
    ffsll,
    memchr,
    memcmp,
    memcpy,
    memmem,
    memmove,
    mempcopy,
    stpcpy,
    stpncpy,
    strcasecmp,
    strcat,
    strchr,
    strcmp,
    strcoll,
    strcopy,
    strcpy,
    strcspn,
    strdup,
    strerror,
    strlen,
    strncasecmp,
    strncat,
    strncmp,
    strncopy,
    strncpy,
    strndup,
    strnlen,
    strpbrk,
    strrchr,
    strsep,
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


def test_strncat_and_stpcpy() raises:
    var src = string_to_char_ptr("cdef")
    var dst = unsafe_alloc[UInt8](16)
    dst.unsafe_offset(0)[] = 97  # a
    dst.unsafe_offset(1)[] = 98  # b
    dst.unsafe_offset(2)[] = 0

    _ = strncat(dst, src, 2)
    assert_equal(char_ptr_to_string(dst), "abcd", "only two bytes of `src`")

    # `stpcpy` hands back the end of what it wrote rather than the start.
    var xy = string_to_char_ptr("xy")
    var end = stpcpy(dst, xy)
    assert_equal(Int(end) - Int(dst), 2, "the pointer is to the null byte")
    assert_equal(char_ptr_to_string(dst), "xy")

    dst.unsafe_free()
    src.unsafe_free()
    xy.unsafe_free()


def test_memmem() raises:
    var haystack = string_to_char_ptr("hello, world")
    var needle = string_to_char_ptr("world")
    var absent = string_to_char_ptr("nowhere")

    var found = memmem(
        haystack.unsafe_bitcast[NoneType](),
        12,
        needle.unsafe_bitcast[NoneType](),
        5,
    )
    assert_equal(Int(found) - Int(haystack), 7, "world starts at byte 7")

    var nothing = memmem(
        haystack.unsafe_bitcast[NoneType](),
        12,
        absent.unsafe_bitcast[NoneType](),
        7,
    )
    assert_equal(Int(nothing), 0, "and `nowhere` is not in it")

    haystack.unsafe_free()
    needle.unsafe_free()
    absent.unsafe_free()


def test_strsep() raises:
    var line = string_to_char_ptr("a,b,c")
    var delim = string_to_char_ptr(",")
    # `strsep` moves the caller's pointer along, so it needs somewhere for
    # that pointer to live.
    var walker = unsafe_alloc[c_ptr[UInt8]](1)
    walker.unsafe_offset(0)[] = line

    assert_equal(char_ptr_to_string(strsep(walker, delim)), "a")
    assert_equal(char_ptr_to_string(strsep(walker, delim)), "b")
    assert_equal(char_ptr_to_string(strsep(walker, delim)), "c")
    assert_equal(Int(strsep(walker, delim)), 0, "and then it is finished")

    walker.unsafe_free()
    delim.unsafe_free()
    line.unsafe_free()


def test_ffs() raises:
    assert_equal(ffs(0), 0, "no bits set is 0")
    assert_equal(ffs(1), 1, "the first bit is at 1")
    assert_equal(ffs(8), 4, "and 8 is the fourth")
    assert_equal(ffsl(1 << 40), 41, "which `ffs` cannot see past 32 of")
    assert_equal(ffsll(1 << 62), 63)


def test_copying() raises:
    """The ten copying calls here had never been made. Each takes its
    destination first and its source second, and both are pointers, so
    handing them over the other way round is a call the compiler is happy
    with and that nothing here would have caught.
    """
    var src = string_to_char_ptr("abcdef")

    var dst = unsafe_alloc[UInt8](16)
    for i in range(16):
        dst.unsafe_store(i, 0)
    _ = memcpy(
        dst.unsafe_bitcast[NoneType](), src.unsafe_bitcast[NoneType](), 7
    )
    assert_equal(
        char_ptr_to_string(dst), "abcdef", "memcpy fills the first one"
    )

    # Overlapping is what `memmove` is for and what `memcpy` does not
    # promise, so this is the one that says which of the two it is.
    var overlap = unsafe_alloc[UInt8](8)
    for i in range(6):
        overlap.unsafe_store(i, UInt8(ord("a") + i))
    overlap.unsafe_store(6, 0)
    _ = memmove(
        overlap.unsafe_offset(2).unsafe_bitcast[NoneType](),
        overlap.unsafe_bitcast[NoneType](),
        4,
    )
    assert_equal(
        char_ptr_to_string(overlap), "ababcd", "memmove survives overlap"
    )

    var moved = unsafe_alloc[UInt8](8)
    for i in range(8):
        moved.unsafe_store(i, 0)
    var end = mempcopy(
        moved.unsafe_bitcast[NoneType](), src.unsafe_bitcast[NoneType](), 4
    )
    assert_equal(char_ptr_to_string(moved), "abcd", "mempcopy copies too")
    assert_equal(
        Int(UInt(end.unsafe_bitcast[UInt8]())) - Int(UInt(moved)),
        4,
        "and hands back one past what it wrote",
    )

    var dup = strdup(src)
    assert_equal(char_ptr_to_string(dup), "abcdef", "strdup copies the string")
    assert_true(
        Int(UInt(dup)) != Int(UInt(src)), "and it is a copy, not the same one"
    )
    _ = free(dup)

    var part = strndup(src, 3)
    assert_equal(char_ptr_to_string(part), "abc", "strndup stops at three")
    _ = free(part)

    var cat = unsafe_alloc[UInt8](16)
    for i in range(16):
        cat.unsafe_store(i, 0)
    _ = strcopy(cat, string_to_char_ptr("hello, "))
    _ = strcat(cat, string_to_char_ptr("libc"))
    assert_equal(
        char_ptr_to_string(cat), "hello, libc", "strcat joins onto the end"
    )

    # What `strncpy` is known for: with a source longer than the count it
    # writes no NUL, so what it leaves is not a string.
    var cut = unsafe_alloc[UInt8](9)
    for i in range(8):
        cut.unsafe_store(i, UInt8(ord("X")))
    cut.unsafe_store(8, 0)
    _ = strncpy(cut, src, 3)
    assert_equal(
        char_ptr_to_string(cut),
        "abcXXXXX",
        "strncpy writes three and leaves no NUL behind",
    )

    var pad = unsafe_alloc[UInt8](8)
    for i in range(8):
        pad.unsafe_store(i, 0)
    var stop = stpncpy(pad, string_to_char_ptr("ab"), 6)
    assert_equal(
        Int(UInt(stop)) - Int(UInt(pad)),
        2,
        "stpncpy stops where the NULs begin",
    )

    var again = unsafe_alloc[UInt8](8)
    for i in range(8):
        again.unsafe_store(i, 0)
    _ = strncopy(again, src, 7)
    assert_equal(
        char_ptr_to_string(again),
        "abcdef",
        "strncopy is strncpy under another name",
    )

    dst.unsafe_free()
    overlap.unsafe_free()
    moved.unsafe_free()
    cat.unsafe_free()
    cut.unsafe_free()
    pad.unsafe_free()
    again.unsafe_free()
    src.unsafe_free()


def main() raises:
    test_strlen()
    test_copying()
    test_strcpy()
    test_memcmp_and_memchr()
    test_compare()
    test_strxfrm()
    test_search()
    test_strtok_r()
    test_strtok()
    test_messages()
    test_strncat_and_stpcpy()
    test_memmem()
    test_strsep()
    test_ffs()
    print("test_string: ok")
