from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.limits import CHAR_MAX
from libc.signal import SIGSEGV, signal
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.stdlib import exit
from libc.unistd import fork
from libc.locale import (
    LC_ALL,
    LC_ALL_MASK,
    Locale,
    lconv,
    duplocale,
    freelocale,
    localeconv,
    newlocale,
    setlocale,
    uselocale,
)
from libc.string import memset, strcmp, strlen
from libc.utils import null_ptr, string_to_char_ptr


def test_setlocale() raises:
    # The categories are numbered differently on Darwin, so a wrong one makes
    # this return a null pointer rather than a locale name.
    var c_locale = string_to_char_ptr("C")
    var name = setlocale(LC_ALL, c_locale)
    assert_true(Int(name) != 0, "the C locale was set")
    assert_equal(
        strcmp(name, c_locale), 0, "and that is the name that comes back"
    )
    c_locale.unsafe_free()


def test_localeconv() raises:
    var conv = localeconv()
    assert_true(Int(conv) != 0, "localeconv gave an object")

    var dot = string_to_char_ptr(".")
    var empty = string_to_char_ptr("")
    assert_equal(
        strcmp(conv[].decimal_point, dot), 0, "the decimal point is a dot"
    )
    assert_equal(
        strlen(conv[].thousands_sep),
        0,
        "the C locale has no thousands separator",
    )
    # CHAR_MAX, which is how the C locale says it has nothing to report --
    # 127 where `char` is signed, 255 on the ARM ABI where it is not, and
    # the field reads as the byte the C locale put there.
    assert_equal(
        Int(conv[].int_frac_digits),
        Int(CHAR_MAX),
        "no fraction digits to report",
    )
    assert_equal(
        Int(conv[].frac_digits),
        Int(CHAR_MAX),
        "no fraction digits to report",
    )

    dot.unsafe_free()
    empty.unsafe_free()


def test_locale_objects() raises:
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL_MASK, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "the object was made")

    var copy = duplocale(loc)
    assert_true(Int(copy) != 0, "and it was copied")
    # Whether the copy holds a life of its own is asked from a child: the
    # only thing that tells a real copy from a handle some other call
    # answered with is that it can be freed on its own, and a copy that is
    # not a copy ends the child rather than the suite.
    var child = fork()
    if child == 0:
        _ = signal(SIGSEGV, null_ptr[UInt8]())
        freelocale(copy)
        _ = exit(0)
    assert_true(child > 0, "there is a child to free the copy in")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_store(0, 0)
    assert_equal(waitpid(child, status, 0), child, "and it is waited for")
    assert_true(
        WIFEXITED(status.unsafe_load()),
        "the copy was freed in its own right, which is what a copy is",
    )
    assert_equal(
        WEXITSTATUS(status.unsafe_load()),
        0,
        "and it went out quietly, the freeing having succeeded",
    )
    status.unsafe_free()

    var previous = uselocale(loc)
    _ = uselocale(previous)
    freelocale(loc)

    c_locale.unsafe_free()
    # Leaving the thread without a locale of its own, so nothing after this
    # sees one that is about to be freed.
    _ = uselocale(null_ptr[Locale]())


def test_lconv_tail_offsets() raises:
    # Which of the last six `char`s is which cannot be settled by reading
    # them: in the C locale every one of them is CHAR_MAX, so all six come
    # back 127 whatever order they are declared in. So this writes a
    # different byte at each of 88 to 93 and asks for them by name, and the
    # number that comes back says which offset the name reads.
    var buf = unsafe_alloc[lconv](1)
    var raw = buf.unsafe_bitcast[UInt8]()
    _ = memset(buf.unsafe_bitcast[NoneType](), 0, 96)
    for i in range(6):
        raw.unsafe_store(88 + i, UInt8(i + 1))

    assert_equal(
        Int(buf[].int_p_cs_precedes()), 1, "int_p_cs_precedes is at 88"
    )
    assert_equal(
        Int(buf[].int_p_sep_by_space()),
        3 if CompilationTarget.is_macos() else 2,
        "int_p_sep_by_space is at 90 on Darwin and 89 on Linux",
    )
    assert_equal(
        Int(buf[].int_n_cs_precedes()),
        2 if CompilationTarget.is_macos() else 3,
        "int_n_cs_precedes is at 89 on Darwin and 90 on Linux",
    )
    assert_equal(
        Int(buf[].int_n_sep_by_space()), 4, "int_n_sep_by_space is at 91"
    )
    assert_equal(Int(buf[].int_p_sign_posn()), 5, "int_p_sign_posn is at 92")
    assert_equal(Int(buf[].int_n_sign_posn()), 6, "int_n_sign_posn is at 93")

    # The eight before them sit at 80 to 87 on both and are still plain
    # fields, so those had nothing to be wrong about.
    assert_equal(Int(buf[].p_sign_posn), 0, "the eight before the six")

    buf.unsafe_free()


def main() raises:
    test_setlocale()
    test_localeconv()
    test_lconv_tail_offsets()
    test_locale_objects()
    print("test_locale: ok")
