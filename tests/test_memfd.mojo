# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import F_GETFD, FD_CLOEXEC, fcntl
from libc.sys.memfd import MFD_CLOEXEC, memfd_create
from libc.unistd import close, lseek, read, write
from libc.utils import string_to_char_ptr


def test_an_anonymous_file_reads_and_writes() raises:
    """`memfd_create` and the ordinary calls an ordinary file answers
    to: the bytes that went in come back out, though no path
    anywhere names the file they went into.
    """

    comptime if not CompilationTarget.is_macos():
        var name = string_to_char_ptr("libc-memfd")
        var fd = memfd_create(name, 0)
        assert_true(fd >= 0, "an anonymous file is made")

        var one = string_to_char_ptr("hello, anonymous")
        assert_equal(
            Int(write(fd, one, 16)), 16, "the anonymous file is written"
        )
        one.unsafe_free()

        assert_equal(
            Int(lseek(fd, 0, 0)), 0, "the position goes back to the start"
        )
        var buf = unsafe_alloc[UInt8](64)
        assert_equal(Int(read(fd, buf, 64)), 16, "the bytes come back")
        assert_true(
            buf.unsafe_offset(0)[] == 104 and buf.unsafe_offset(7)[] == 97,
            "and they are the ones that went in",
        )
        buf.unsafe_free()

        assert_equal(Int(close(fd)), 0, "the anonymous file is closed")


def test_two_files_may_carry_the_same_name() raises:
    """`memfd_create` and the name it is given: the name is a label
    for `/proc/self/fd` and nothing is looked up by it, so two files
    made with the same label are two files, and the bytes one holds
    are not the bytes the other does.
    """
    comptime if not CompilationTarget.is_macos():
        var name = string_to_char_ptr("libc-memfd-twice")
        var first = memfd_create(name, 0)
        var second = memfd_create(name, 0)
        assert_true(first >= 0, "the first file of the name is made")
        assert_true(second >= 0, "and a second of the very same name too")

        var one = string_to_char_ptr("aaa")
        assert_equal(Int(write(first, one, 3)), 3, "the first is written to")
        var two = string_to_char_ptr("bbb")
        assert_equal(
            Int(write(second, two, 3)), 3, "and the second, another word"
        )

        var buf = unsafe_alloc[UInt8](8)
        assert_equal(
            Int(lseek(first, 0, 0)), 0, "the first's position goes back"
        )
        assert_equal(
            Int(read(first, buf, 8)), 3, "the first's own bytes come back"
        )
        assert_true(
            buf.unsafe_offset(0)[] == 97 and buf.unsafe_offset(2)[] == 97,
            "and they are the first's",
        )
        assert_equal(
            Int(lseek(second, 0, 0)), 0, "the second's position goes back"
        )
        assert_equal(
            Int(read(second, buf, 8)), 3, "the second's own bytes come back"
        )
        assert_true(
            buf.unsafe_offset(0)[] == 98 and buf.unsafe_offset(2)[] == 98,
            "and they are the second's",
        )
        buf.unsafe_free()

        one.unsafe_free()
        two.unsafe_free()
        assert_equal(Int(close(first)), 0, "the first is closed")
        assert_equal(Int(close(second)), 0, "and the second is closed")


def test_an_empty_name_makes_a_file_all_the_same() raises:
    """`memfd_create` and the name's having no rules to break: an
    empty label makes a file, and the file reads and writes like
    any other the call makes.
    """
    comptime if not CompilationTarget.is_macos():
        var name = string_to_char_ptr("")
        var fd = memfd_create(name, 0)
        assert_true(fd >= 0, "an empty label makes the file")

        var one = string_to_char_ptr("x")
        assert_equal(Int(write(fd, one, 1)), 1, "the file takes bytes")
        one.unsafe_free()

        assert_equal(Int(lseek(fd, 0, 0)), 0, "the position goes back")
        var buf = unsafe_alloc[UInt8](8)
        assert_equal(Int(read(fd, buf, 8)), 1, "and gives them back")
        assert_true(
            buf.unsafe_offset(0)[] == 120, "and they are the ones that went in"
        )
        buf.unsafe_free()

        assert_equal(Int(close(fd)), 0, "the file is closed")


def test_cloexec_is_the_open_flag_by_another_name() raises:
    """`memfd_create` and the flag that is `open`'s by another name:
    a file made with `MFD_CLOEXEC` carries the close-on-exec mark,
    and `fcntl` sees it just as it sees it on a file `open` made.
    """
    comptime if not CompilationTarget.is_macos():
        var plain = string_to_char_ptr("libc-memfd-plain")
        var fd = memfd_create(plain, 0)
        assert_true(fd >= 0, "a file without the flag is made")
        assert_true(
            Int(fcntl(fd, F_GETFD, 0)) & Int(FD_CLOEXEC) == 0,
            "the mark is not on it",
        )
        assert_equal(Int(close(fd)), 0, "and it is closed")

        var marked = string_to_char_ptr("libc-memfd-marked")
        fd = memfd_create(marked, UInt32(MFD_CLOEXEC))
        assert_true(fd >= 0, "a file with the flag is made")
        assert_true(
            Int(fcntl(fd, F_GETFD, 0)) & Int(FD_CLOEXEC) != 0,
            "the mark is on it",
        )
        assert_equal(Int(close(fd)), 0, "and it is closed too")


def main() raises:
    test_an_anonymous_file_reads_and_writes()
    test_two_files_may_carry_the_same_name()
    test_an_empty_name_makes_a_file_all_the_same()
    test_cloexec_is_the_open_flag_by_another_name()
    print("test_memfd: ok")
