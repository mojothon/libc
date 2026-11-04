from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_int
from libc.fcntl import O_CREAT, O_RDWR, O_TRUNC, open
from libc.sys.stat import fchmod
from libc.unistd import close, getpid, unlink, write
from libc.utmpx import (
    EMPTY,
    USER_PROCESS,
    UTMPX_BYTES,
    UT_USER_ROOM,
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


# XNU will only take a name for its login database that ends in `x` — its
# own are `/var/run/utmpx` and `/var/log/wtmpx` — so the files here are
# named to suit both, and the suffix is the one thing about the test that
# is there for one platform's benefit.
comptime PATH = "/tmp/mojo-utmpx-record.utmpx"

# And what the two answer when a name is taken: glibc 0, XNU 1. The
# binding hands back whichever it got; this is what says the test knows
# which one it is asking for rather than accepting either.
comptime NAME_TAKEN: c_int = 1 if CompilationTarget.is_macos() else 0


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


def test_a_name_too_long_for_its_field_stops_at_the_field() raises:
    """The room is the field's width, and the field beside it is next.

    `ut_user` is thirty-two bytes of a Linux record and two hundred and
    fifty-six of a Darwin one, and whichever it is the next field starts
    at the byte after it — `ut_host` on Linux, `ut_id` on Darwin. A name
    written past the room would land in that field, so the name is
    longer than either room and the answer asked for is the room
    itself: the one length both platforms agree the field has.
    """
    var record = utmpx()
    var name = String()
    for _ in range(UT_USER_ROOM + 8):
        name = name + "n"
    record.set_ut_user(name)

    assert_equal(
        record.ut_user().byte_length(),
        UT_USER_ROOM,
        "the name is cut to the room the field has",
    )
    assert_equal(
        record.ut_user(),
        name[byte=0:UT_USER_ROOM],
        "and is its first bytes",
    )
    assert_equal(record.ut_id(), "", "with nothing written past the field")
    assert_equal(record.ut_host(), "", "on either side of it")


def test_a_record_written_back_comes_out_again() raises:
    """A file of our own, filled and walked through the binding itself.

    Every value goes in through a setter, is copied out of the record by
    libc, written down, read back by libc and copied in again, and is
    read out through an accessor — so a member this package puts
    somewhere C does not would be lost on the way and come back empty or
    as whatever its neighbour is. XNU converts to a narrower record on
    the way to the file and back, which is why that holds there and not
    only here.
    """
    var path = string_to_char_ptr(PATH)
    _ = unlink(path)
    var fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o600)
    assert_true(fd >= 0, "a file of our own to be the database")

    # Set outright rather than taken from the mode above: that mode is a
    # variadic argument, and on arm64 Darwin variadic arguments do not
    # arrive, so the file is made with whatever was on the stack — here,
    # no permission bits at all, which the next thing to open it for
    # writing reads as EACCES. The first run of this test failed three
    # steps later for exactly that, with pututxline answering EPERM.
    assert_equal(fchmod(fd, 0o600), 0, "and writable outright")
    assert_equal(close(fd), 0, "empty, and left for libc to fill")

    # The name is remembered rather than opened, so this cannot fail on
    # the file being empty — and what it answers when it takes one is
    # asked below, after a record has landed in it.
    var named = utmpxname(path)

    var first = unsafe_alloc[utmpx](1)
    first[] = utmpx()
    first[].set_ut_type(Int16(USER_PROCESS))
    first[].set_ut_pid(4242)
    first[].set_ut_line("mojo-tty0")
    first[].set_ut_id("mj00")
    first[].set_ut_user("mojo")
    var written = pututxline(first)
    assert_true(not is_null(written), "the first record is written")
    assert_equal(
        written[].ut_line(), "mojo-tty0", "and comes back as it went in"
    )
    assert_equal(written[].ut_id(), "mj00", "with its identifier")
    assert_equal(written[].ut_user(), "mojo", "and its user")
    assert_equal(written[].ut_pid(), 4242, "and its process")
    assert_equal(Int(written[].ut_type()), Int(USER_PROCESS), "and its type")

    # Nothing was written anywhere until the name was taken, and it went
    # into a file this process can write, so the answer is the platform's
    # one for success.
    assert_equal(named, NAME_TAKEN, "a name ending in x is taken, and answered")

    var second = unsafe_alloc[utmpx](1)
    second[] = utmpx()
    second[].set_ut_type(Int16(USER_PROCESS))
    second[].set_ut_pid(4243)
    second[].set_ut_line("mojo-tty1")
    second[].set_ut_id("mj11")
    second[].set_ut_user("other")
    assert_true(not is_null(pututxline(second)), "and so is the second")

    setutxent()
    var got = getutxent()
    assert_true(not is_null(got), "the walk reads the first one back")
    assert_equal(
        got[].ut_line(), "mojo-tty0", "with the terminal that was put in"
    )
    assert_equal(got[].ut_id(), "mj00", "and the identifier")
    assert_equal(got[].ut_user(), "mojo", "and the user")
    assert_equal(got[].ut_pid(), 4242, "and the process")

    got = getutxent()
    assert_true(not is_null(got), "the walk reads the second one")
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

    setutxent()
    # The probe says whose terminal it wants and, to keep the two searches
    # apart, names the *other* record's identifier as well: the search by
    # line has to come back with the record for mojo-tty1, and the search by
    # identifier -- the same probe, the other call -- has to come back with
    # the one the identifier names.
    probe[].set_ut_line("mojo-tty1")
    probe[].set_ut_id("mj00")
    var found = getutxline(probe)
    assert_true(not is_null(found), "a terminal that is in the file is found")
    assert_equal(
        found[].ut_pid(), 4243, "and it is the record for that terminal"
    )
    assert_equal(found[].ut_user(), "other", "with the user on it")

    setutxent()
    var found_by_id = getutxid(probe)
    assert_true(not is_null(found_by_id), "the identifier finds its record too")
    assert_equal(
        found_by_id[].ut_pid(),
        4242,
        "which is the other one, the one the identifier names",
    )

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

    endutxent()

    first.unsafe_free()
    second.unsafe_free()
    bare.unsafe_free()
    probe.unsafe_free()
    assert_equal(unlink(path), 0, "the file is taken away")
    path.unsafe_free()


def test_bytes_written_at_these_offsets_are_bytes_libc_reads() raises:
    """The one test that would catch an offset that is not C's.

    Everything else here goes through libc in both directions, so a
    member read at the wrong offset on the way in is written at that same
    wrong offset on the way out and comes back looking right. Here the
    bytes are put in the file at this package's offsets and libc is the
    only reader: an offset that moved by a byte turns a terminal name
    into a part of a pid and every assertion below says so.

    glibc only, and not for want of trying. XNU's database file is not an
    array of these records: it opens with a signature record in the
    narrower 32-bit shape and every record after it is in that shape too,
    converted on the way in and out — so bytes written at a 64-bit
    record's offsets are not bytes XNU can read at all, which is why the
    test above is the one that covers XNU.
    """
    if CompilationTarget.is_macos():
        return

    var path = string_to_char_ptr("/tmp/mojo-utmpx-raw.utmpx")
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
        "one record, exactly as long as C's",
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
        "and a second one after it",
    )

    assert_equal(
        utmpxname(path), NAME_TAKEN, "the walk is pointed at that file"
    )
    setutxent()

    var got = getutxent()
    assert_true(not is_null(got), "the first record is read back")
    assert_equal(
        got[].ut_line(), "mojo-tty0", "with the terminal that was put there"
    )
    assert_equal(got[].ut_id(), "mj00", "and the identifier")
    assert_equal(got[].ut_user(), "mojo", "and the user")
    assert_equal(got[].ut_pid(), 4242, "and the process")

    got = getutxent()
    assert_true(not is_null(got), "and then the second")
    assert_equal(got[].ut_line(), "mojo-tty1", "which is the other terminal")
    assert_equal(got[].ut_user(), "other", "and the other user")
    assert_true(is_null(getutxent()), "and then there are no more records")

    # Worth saying twice: the walk is at the end of the file now, so the
    # search has to be wound back before it can find the record that is
    # behind it.
    setutxent()
    var probe = unsafe_alloc[utmpx](1)
    probe[] = utmpx()
    probe[].set_ut_type(Int16(USER_PROCESS))
    probe[].set_ut_line("mojo-tty1")
    var found = getutxline(probe)
    assert_true(
        not is_null(found), "and libc finds one of them by its own field"
    )
    assert_equal(
        found[].ut_pid(), 4243, "which is the record for that terminal"
    )

    endutxent()

    first.unsafe_free()
    second.unsafe_free()
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
    var path = string_to_char_ptr("/tmp/mojo-utmpx-absent.utmpx")
    _ = unlink(path)
    assert_equal(utmpxname(path), NAME_TAKEN, "a name is remembered whether")

    setutxent()
    assert_true(is_null(getutxent()), "or not the file is there to be read")

    endutxent()
    setutxent()
    assert_true(is_null(getutxent()), "and starting again reads nothing again")
    endutxent()

    # XNU's reader makes the file it was pointed at before finding nothing
    # in it; glibc's does not. Neither is asked about afterwards except
    # for being gone.
    _ = unlink(path)
    path.unsafe_free()


def main() raises:
    test_a_new_record_is_the_empty_one()
    test_a_record_reads_back_what_was_put_in_it()
    test_a_name_too_long_for_its_field_stops_at_the_field()
    test_a_record_written_back_comes_out_again()
    test_bytes_written_at_these_offsets_are_bytes_libc_reads()
    test_endutxent_ends_the_walk_and_setutxent_starts_it_again()
    print("test_utmpx: ok")
