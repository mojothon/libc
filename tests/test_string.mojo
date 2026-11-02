from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.stdlib import free
from libc.string import (
    bcmp,
    bcopy,
    bzero,
    ffs,
    ffsl,
    ffsll,
    index,
    memccpy,
    memchr,
    memcmp,
    memcpy,
    memmem,
    memmove,
    mempcopy,
    rindex,
    stpcpy,
    stpncpy,
    strcasecmp,
    strcasecmp_l,
    strcat,
    strchr,
    strcmp,
    strcoll,
    strcoll_l,
    strcopy,
    strcpy,
    strcspn,
    strdup,
    strerror,
    strlen,
    strncasecmp,
    strncasecmp_l,
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
    strxfrm_l,
)
from libc.constant import c_ptr
from libc.locale import LC_ALL, Locale, freelocale, newlocale
from libc.utils import (
    char_ptr_to_string,
    is_null,
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


def test_the_bsd_spellings() raises:
    """`bcmp` says whether two blocks are the same, `bcopy` copies
    one into another and `bzero` fills one with zeroes. Each is the
    BSD spelling of a call the standard keeps under another name,
    and each is what `<strings.h>` declares rather than `<string.h>`.

    `bcopy` takes its source first and its destination second, the
    other way round from `memcpy`, and that is the thing worth
    proving here: the two blocks are made different, so a call that
    took them in the wrong order would fill the wrong one and the
    comparison after would say so.

    `bcmp` is asked about blocks that agree and then about blocks
    that differ in the last byte only, which is what keeps one that
    compared a single byte from passing.
    """
    var left = string_to_char_ptr("abcdef")
    var right = string_to_char_ptr("abcdef")
    var other = string_to_char_ptr("abcdez")

    assert_equal(bcmp(left, right, 6), 0, "the same six bytes compare equal")
    assert_true(
        bcmp(left, other, 6) != 0,
        "and blocks that differ in the last byte do not",
    )
    assert_equal(bcmp(left, other, 5), 0, "though their first five do")

    # Filled with zeroes, and left holding what it held.
    var room = string_to_char_ptr("abcdef")
    var zeroed = string_to_char_ptr("......")
    bcopy(room, zeroed, 6)
    assert_equal(char_ptr_to_string(zeroed), "abcdef", "bcopy fills its second")
    assert_equal(
        char_ptr_to_string(room), "abcdef", "and leaves its first alone"
    )

    bzero(zeroed, 6)
    var all_zero = True
    for i in range(6):
        if Int(zeroed.unsafe_offset(i)[]) != 0:
            all_zero = False
    assert_true(all_zero, "bzero leaves six zero bytes behind it")
    assert_equal(
        char_ptr_to_string(room), "abcdef", "and bcopy's source is whole"
    )

    other.unsafe_free()
    right.unsafe_free()
    left.unsafe_free()
    room.unsafe_free()
    zeroed.unsafe_free()


def test_finding_the_first_and_the_last() raises:
    """`index` finds the first of a byte in a string and `rindex` the
    last, which are `strchr` and `strrchr` under their BSD names.

    The string has the byte in it three times, which is what makes
    the two calls answerable: both find one, and where they land is
    the whole difference between them. A string with the byte once
    would have them land in the same place and prove nothing.

    Each is asked for a byte that is not in the string either, and a
    null pointer is what comes back of that.
    """
    var s = string_to_char_ptr("aXbXc")
    var once = string_to_char_ptr("abXcd")

    assert_equal(
        char_ptr_to_string(index(s, 88)), "XbXc", "index finds the first X"
    )
    assert_equal(
        char_ptr_to_string(rindex(s, 88)), "Xc", "and rindex the last one"
    )
    assert_equal(
        char_ptr_to_string(index(once, 88)),
        "Xcd",
        "both land in the same place where there is only the one",
    )
    assert_equal(
        char_ptr_to_string(rindex(once, 88)), "Xcd", "which is what they do"
    )

    assert_true(
        is_null(index(s, 90)), "and a byte that is not there is a null pointer"
    )
    assert_true(is_null(rindex(s, 90)), "for either of them")

    once.unsafe_free()
    s.unsafe_free()


def test_copying_up_to_a_byte() raises:
    """`memccpy` copies until it has copied a given byte, or until it
    has copied as many as it was allowed to, whichever comes first,
    and hands back a pointer to the byte after the one that stopped
    it — or a null pointer where that byte never came up.

    Both of those are asked for. The first is asked with a room of
    more than enough, so what stops the copy is the byte and not the
    count; the second with a count that runs out before the byte does,
    so what stops it is the count.

    The destination is the first argument here, as it is to `memcpy`,
    and not the second, as it is to `bcopy`: the source is left whole
    and the destination is the one that ends up holding the bytes,
    which is what a call that had them the other way round could not
    manage.
    """
    var src = string_to_char_ptr("hello, world")
    var room = string_to_char_ptr("............")

    # Stops on the comma, and hands back the byte after it.
    var stopped = memccpy(room, src, 44, 12)
    assert_true(not is_null(stopped), "the comma stops it, so this is not null")
    # It points into the destination, one past the byte that stopped
    # it, and not into the source — which is where the rest of the
    # string sits, and is what a call handing back the wrong pointer
    # would have shown.
    assert_equal(
        char_ptr_to_string(stopped), "......", "and it points into the copy"
    )
    # Nothing is written past the comma: the rest of the room is as
    # it was, and no terminator is put in, this being a copy of bytes.
    assert_equal(
        char_ptr_to_string(room), "hello,......", "which is what was copied"
    )
    assert_equal(
        char_ptr_to_string(src), "hello, world", "and the source is left alone"
    )

    # Runs out of count before the byte comes up.
    var short = string_to_char_ptr("...")
    assert_true(
        is_null(memccpy(short, src, 44, 3)),
        "three bytes hold no comma, so this one is null",
    )
    assert_equal(
        char_ptr_to_string(short), "hel", "and three bytes were copied"
    )

    short.unsafe_free()
    room.unsafe_free()
    src.unsafe_free()


def test_the_l_variants_ask_a_locale_object() raises:
    """The `_l` calls ask a locale that is handed to them instead of the one
    the thread is in, and it arrives as the last argument — a binding that
    dropped it would read whatever followed as the locale and answer about
    nothing.

    The C locale is the one asked, both because its answers are the ones
    POSIX fixes and because there the `_l` calls and the plain ones have to
    agree: `strcasecmp_l` folds case the way `strcasecmp` does, `strcoll_l`
    orders the way `strcoll` does, and `strxfrm_l` in a C locale leaves a
    string exactly as it found it, which is the one case where the
    transformed string can be read back as the string it came from.
    """
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "a C locale object was made to ask")
    c_locale.unsafe_free()

    var apple = string_to_char_ptr("apple")
    var banana = string_to_char_ptr("banana")
    assert_true(strcoll_l(apple, banana, loc) < 0, "apple sorts before banana")
    assert_true(strcoll_l(banana, apple, loc) > 0, "and after it the other way")
    assert_equal(
        strcoll_l(apple, apple, loc), 0, "and a string is not before itself"
    )
    assert_equal(
        strcoll_l(apple, banana, loc) < 0,
        strcoll(apple, banana) < 0,
        "which is the order strcoll gives in the same locale",
    )

    var hello = string_to_char_ptr("Hello")
    var shout = string_to_char_ptr("hELLO")
    assert_equal(strcasecmp_l(hello, shout, loc), 0, "case is folded away")

    var abc_x = string_to_char_ptr("abcX")
    var abc_y = string_to_char_ptr("ABCY")
    assert_equal(strncasecmp_l(abc_x, abc_y, 3, loc), 0, "three bytes agree")
    assert_true(strncasecmp_l(abc_x, abc_y, 4, loc) != 0, "the fourth does not")

    var roomy = unsafe_alloc[UInt8](16)
    var src = string_to_char_ptr("abc")
    assert_equal(
        Int(strxfrm_l(roomy, src, 16, loc)),
        3,
        "the C locale leaves abc three bytes long",
    )
    assert_equal(
        char_ptr_to_string(roomy), "abc", "and writes it out unchanged"
    )

    var tight = unsafe_alloc[UInt8](3)
    var six = string_to_char_ptr("abcdef")
    assert_equal(
        Int(strxfrm_l(tight, six, 3, loc)),
        6,
        "and a buffer too small is still told the six bytes a full one needs",
    )

    freelocale(loc)


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
    test_the_bsd_spellings()
    test_finding_the_first_and_the_last()
    test_the_l_variants_ask_a_locale_object()
    test_copying_up_to_a_byte()
    test_strsep()
    test_ffs()
    print("test_string: ok")
