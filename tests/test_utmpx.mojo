from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import O_CREAT, O_RDWR, O_TRUNC, open
from libc.unistd import close, getpid, unlink, write
from libc.utmpx import (
    EMPTY,
    USER_PROCESS,
    UTMPX_BYTES,
    endutxent,
    getutxent,
    getutxid,
    getutxline,
    pututxline,
    setutxent,
    utmpx,
    utmpxname,
)
from libc.utils import is_null, string_to_char_ptr


comptime PATH = "/tmp/mojo-utmpx-record"


def test_a_new_record_is_the_empty_one() raises:
    """A record that has just been declared, in C and here.

    Every byte of it is zero, which is what makes it `EMPTY` and makes
    all four of its strings empty — and an empty string is the answer
    that tells apart "read nothing" from "read the wrong place", since
    the wrong place would come back as whatever is at the wrong offset.
    """
    var record = utmpx()
    assert_equal(Int(record.ut_type()), Int(EMPTY), "a new record is empty")
    assert_equal(record.ut_pid(), 0, "with no process in it")
    assert_equal(record.ut_line(), "", "and no terminal")
    assert_equal(record.ut_id(), "", "and no identifier")
    assert_equal(record.ut_user(), "", "and nobody logged in")
    assert_equal(record.ut_host(), "", "from nowhere")


def test_a_record_reads_back_what_was_put_in_it() raises:
    """The accessors against each other, on one record.

    Which is the part that cannot see a layout mistake — both ends use
    the same offsets — but does see a shift inside the record: the four
    strings are put in at different lengths and read back in a different
    order from the one they were written in, so an offset that moved by a
    byte would land in the middle of the next field.
    """
    var record = utmpx()
    record.set_ut_type(Int16(USER_PROCESS))
    record.set_ut_pid(4321)
    record.set_ut_line("ttyq7")
    record.set_ut_id("q7")
    record.set_ut_user("someone")
    record.set_ut_host("elsewhere.example")

    assert_equal(
        Int(record.ut_type()), Int(USER_PROCESS), "the type comes back"
    )
    assert_equal(record.ut_pid(), 4321, "and the process")
    assert_equal(record.ut_host(), "elsewhere.example", "and the host")
    assert_equal(record.ut_user(), "someone", "and the user")
    assert_equal(record.ut_id(), "q7", "and the identifier")
    assert_equal(record.ut_line(), "ttyq7", "and the terminal")

    # The longest name each field can hold, and one byte more, which is
    # the byte a record has to cut rather than keep.
    record.set_ut_id("abcd")
    assert_equal(record.ut_id(), "abcd", "the identifier takes its four")
    record.set_ut_id("abcde")
    assert_equal(record.ut_id(), "abcd", "and cuts the fifth rather than")
    assert_equal(record.ut_user(), "someone", "running into the user's name")


def test_the_walk_reads_a_file_of_our_own() raises:
    """Records written here and read back by C.

    This is the test that knows the layout: the bytes are put in the file
    at this package's offsets, and libc's own reader is what finds the
    terminal names in them. If `ut_line` were at glibc's 8 on a machine
    where C keeps it elsewhere, the walk would find a record whose
    terminal name is a part of a pid, and every assertion below would
    say so.
    """
    var path = string_to_char_ptr(PATH)
    _ = unlink(path)
    var fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o600)
    assert_true(fd >= 0, "a file of our own to be the database")

    var first = unsafe_alloc[utmpx](1)
    first[] = utmpx()
    first[].set_ut_type(Int16(USER_PROCESS))
    first[].set_ut_pid(4242)
    first[].set_ut_line("mojo-tty0")
    first[].set_ut_id("mj00")
    first[].set_ut_user("mojo")
    assert_equal(
        write(fd, first.unsafe_bitcast[UInt8](), UInt32(UTMPX_BYTES)),
        UTMPX_BYTES,
        "the first record is exactly one record long",
    )

    var second = unsafe_alloc[utmpx](1)
    second[] = utmpx()
    second[].set_ut_type(Int16(USER_PROCESS))
    second[].set_ut_pid(4243)
    second[].set_ut_line("mojo-tty1")
    second[].set_ut_id("mj11")
    second[].set_ut_user("other")
    assert_equal(
        write(fd, second.unsafe_bitcast[UInt8](), UInt32(UTMPX_BYTES)),
        UTMPX_BYTES,
        "and so is the second",
    )

    assert_equal(utmpxname(path), 0, "the walk is pointed at that file")
    setutxent()

    var got = getutxent()
    assert_true(not is_null(got), "the first record is read back")
    assert_equal(
        got[].ut_line(), "mojo-tty0", "with the terminal that was put in"
    )
    assert_equal(got[].ut_id(), "mj00", "and the identifier")
    assert_equal(got[].ut_user(), "mojo", "and the user")
    assert_equal(got[].ut_pid(), 4242, "and the process")
    assert_equal(Int(got[].ut_type()), Int(USER_PROCESS), "and the type")

    got = getutxent()
    assert_true(not is_null(got), "and then the second")
    assert_equal(got[].ut_line(), "mojo-tty1", "which is the other terminal")
    assert_equal(got[].ut_user(), "other", "and the other user")

    assert_true(is_null(getutxent()), "and then there are no more records")

    # A search starts where the walk is, and the walk has just ended, so
    # this one finds nothing: the file is not searched again from the top.
    var probe = unsafe_alloc[utmpx](1)
    probe[] = utmpx()
    probe[].set_ut_type(Int16(USER_PROCESS))
    probe[].set_ut_line("mojo-tty0")
    assert_true(
        is_null(getutxline(probe)),
        "a search from the end of the file finds nothing, until",
    )

    # Asking for one by name, from a record that holds nothing else: the
    # comparison is C's, at C's offset for the terminal.
    setutxent()
    probe[].set_ut_line("mojo-tty1")
    var found = getutxline(probe)
    assert_true(not is_null(found), "a terminal that is in the file is found")
    assert_equal(
        found[].ut_pid(), 4243, "and it is the record for that terminal"
    )
    assert_equal(found[].ut_user(), "other", "with the user on it")

    probe[].set_ut_line("mojo-tty9")
    assert_true(is_null(getutxline(probe)), "and one that is not is not found")

    # By identifier, which pairs it with the type — and which, like the
    # search by name, starts from where the last one left off.
    setutxent()
    probe[].set_ut_line("")
    probe[].set_ut_id("mj00")
    var by_id = getutxid(probe)
    assert_true(not is_null(by_id), "an identifier that is filed is found")
    assert_equal(by_id[].ut_line(), "mojo-tty0", "and it is the first record")
    assert_equal(by_id[].ut_pid(), 4242, "of the two that were written")

    probe[].set_ut_id("zz99")
    assert_true(is_null(getutxid(probe)), "and one that is not filed is not")

    # Written back through libc, then found again by libc, which is the
    # only way to tell that a record this package filled in was one C
    # could read out of the block.
    var third = unsafe_alloc[utmpx](1)
    third[] = utmpx()
    third[].set_ut_type(Int16(USER_PROCESS))
    third[].set_ut_pid(getpid())
    third[].set_ut_line("mojo-put")
    third[].set_ut_id("mj22")
    third[].set_ut_user("writer")
    var written = pututxline(third)
    assert_true(not is_null(written), "a record can be written back")
    assert_equal(written[].ut_line(), "mojo-put", "and it is the one given")
    assert_equal(written[].ut_user(), "writer", "whole, and not another one")

    # A record with next to nothing in it is written as it stands: glibc
    # adds neither the pid of the caller nor an identifier taken from the
    # end of the terminal, and hands back the zeroes it was given. XNU is
    # not asserted here — it is the one thing in this file the two could
    # answer differently — so the write is asked for on both and the two
    # zeroes only on glibc.
    var bare = unsafe_alloc[utmpx](1)
    bare[] = utmpx()
    bare[].set_ut_type(Int16(USER_PROCESS))
    bare[].set_ut_line("mojo-bare")
    var as_written = pututxline(bare)
    assert_true(not is_null(as_written), "a record with next to nothing in it")
    assert_equal(as_written[].ut_line(), "mojo-bare", "is written as it stands")
    if not CompilationTarget.is_macos():
        assert_equal(as_written[].ut_pid(), 0, "with nothing added to its pid")
        assert_equal(as_written[].ut_id(), "", "and nothing filing it")

    setutxent()
    probe[].set_ut_id("")
    probe[].set_ut_line("mojo-put")
    var after = getutxline(probe)
    assert_true(not is_null(after), "and the walk finds it afterwards")
    assert_equal(after[].ut_pid(), getpid(), "belonging to this process")

    endutxent()

    first.unsafe_free()
    second.unsafe_free()
    third.unsafe_free()
    bare.unsafe_free()
    probe.unsafe_free()
    assert_equal(close(fd), 0, "the file is closed")
    assert_equal(unlink(path), 0, "and taken away")
    path.unsafe_free()


def test_endutxent_ends_the_walk_and_setutxent_starts_it_again() raises:
    """Winding the walk back and forth on a file that is not there.

    A file that is not there is an empty database rather than an error:
    the walk opens it at `setutxent` and finds nothing to hand back. What
    that costs is one call whose answer is null — and what it buys is a
    `setutxent` after an `endutxent` that does not walk off the end of a
    closed file.
    """
    var path = string_to_char_ptr("/tmp/mojo-utmpx-does-not-exist")
    _ = unlink(path)
    assert_equal(
        utmpxname(path), 0, "a name is remembered whether or not it is"
    )

    setutxent()
    assert_true(
        is_null(getutxent()), "there is a file there, so nothing is read"
    )

    endutxent()
    setutxent()
    assert_true(is_null(getutxent()), "and starting again reads nothing again")
    endutxent()

    path.unsafe_free()


def main() raises:
    test_a_new_record_is_the_empty_one()
    test_a_record_reads_back_what_was_put_in_it()
    test_the_walk_reads_a_file_of_our_own()
    test_endutxent_ends_the_walk_and_setutxent_starts_it_again()
    print("test_utmpx: ok")
