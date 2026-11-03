from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import (
    AT_FDCWD,
    EAGAIN,
    ENOENT,
    EPERM,
    O_NONBLOCK,
    O_RDONLY,
    O_WRONLY,
)
from libc.errno import (
    check,
    check_ptr,
    errno_message,
    errno_name,
    get_errno,
    set_errno,
)
from libc.fcntl import openat
from libc.sys.stat import Stat, mkfifo, stat
from libc.unistd import close, getcwd, read, unlink
from libc.utils import string_to_char_ptr


def test_errno() raises:
    """The numbers a failure leaves behind, asked of failures that happen.

    The last of them is the one worth the trouble: `EAGAIN` is 11 here and
    35 on Darwin, so a test that hard-coded either would pass on one
    platform and mean something else on the other.

    Getting an `EAGAIN` used to be done by opening a pipe and setting
    `O_NONBLOCK` on the read end with `fcntl`, and on macOS the read then
    blocked forever -- the whole run hung -- which is why this test was
    skipped on that side. The flag was the reason: `F_SETFL` takes it in
    C's variadic argument, and that argument does not arrive on arm64, so
    the descriptor was never made non-blocking. A fifo opened with
    `O_NONBLOCK` says the same thing in an argument `openat` has been
    given a name for, and both platforms read it as empty rather than
    waiting for something to fall into it.
    """
    set_errno(0)
    assert_equal(get_errno(), 0, "errno starts out clear")

    # A path that cannot exist leaves ENOENT behind, which is what set_errno
    # exists to clear.
    var missing = string_to_char_ptr("/nonexistent-path-for-libc-tests")
    var buf = unsafe_alloc[Stat](1)
    buf[] = Stat()
    assert_equal(stat(missing, buf), -1, "stat failed")
    assert_equal(get_errno(), 2, "the failure left ENOENT in errno")

    set_errno(0)
    assert_equal(get_errno(), 0, "set_errno cleared it")

    # The errno whose number differs between the platforms that is easy to
    # provoke: a read of an empty fifo that was opened non-blocking. Linux
    # says 11 and Darwin says 35, so this is what keeps `EAGAIN` honest on
    # both, and a value that is not the platform's own fails here rather
    # than in a caller's error handling.
    var fifo = string_to_char_ptr("/tmp/libc-errno-fifo")
    _ = unlink(fifo)  # a run that was cut short may have left it
    assert_equal(mkfifo(fifo, 0o600), 0, "a fifo to read nothing out of")
    var reading = openat(Int32(AT_FDCWD), fifo, O_RDONLY | O_NONBLOCK)
    assert_true(
        reading >= 0,
        "opened non-blocking, which is a flag on the open and not one set"
        + " afterwards, and",
    )
    # A writer on the other end, because a fifo with nobody writing to it
    # is at its end: that read answers 0 rather than waiting, which is EOF
    # and not the failure this is about.
    var writing = openat(Int32(AT_FDCWD), fifo, O_WRONLY)
    assert_true(writing >= 0, "a writer on the other end of it")
    var one = unsafe_alloc[UInt8](1)
    set_errno(0)
    assert_equal(
        read(reading, one, 1), -1, "reading it with nothing in it fails"
    )
    assert_equal(
        Int(get_errno()), Int(EAGAIN), "and says EAGAIN, this platform's number"
    )
    assert_equal(close(writing), 0, "the fifo closes, and")
    assert_equal(close(reading), 0, "both ends of it do, and")
    assert_equal(unlink(fifo), 0, "it goes")

    one.unsafe_free()
    fifo.unsafe_free()
    missing.unsafe_free()
    buf.unsafe_free()


def test_errno_name() raises:
    """The name for a number, which is the question C cannot be asked.

    `EAGAIN` is the one worth saying: 11 here and 35 on Darwin, and the
    name is the same on both, so it is the number that is asked about and
    the name that comes back.
    """
    assert_equal(errno_name(0), "no error", "0 has no name")
    assert_equal(errno_name(Int32(EPERM)), "EPERM", "1 is EPERM")
    assert_equal(errno_name(Int32(ENOENT)), "ENOENT", "2 is ENOENT")
    assert_equal(
        errno_name(Int32(EAGAIN)), "EAGAIN", "and EAGAIN is EAGAIN either way"
    )
    assert_equal(
        errno_name(9999), "errno 9999", "a number with no name says the number"
    )


def test_errno_message() raises:
    """The name and the message, which is what `perror` prints."""
    var m = errno_message(Int32(ENOENT))
    assert_true(m.startswith("ENOENT: "), "it is the name and then the message")
    assert_true(
        m.byte_length() > "ENOENT: ".byte_length(),
        "and there is a message after the colon",
    )


def test_check() raises:
    """A failure that raises, which C has nothing to answer with."""
    assert_equal(check(0), 0, "0 passes through")
    assert_equal(check(7), 7, "and so does a descriptor")

    set_errno(Int32(ENOENT))
    var raised = False
    try:
        _ = check(-1)
    except e:
        raised = True
        assert_true(
            "ENOENT" in String(e), "and the error says which errno it was"
        )
    assert_true(raised, "a negative result raises")


def test_check_ptr() raises:
    """The other half of libc, which answers NULL rather than -1.

    `getcwd` with a buffer that cannot hold the directory is what asks
    for NULL here: POSIX says ERANGE for that, on both platforms, and it
    is the errno `getcwd` itself set rather than one put there for it.
    """
    # Room for any path: PATH_MAX is 4096 here and 1024 on Darwin.
    var room = unsafe_alloc[UInt8](4096)
    var back = check_ptr(getcwd(room, 4096))
    assert_true(Int(back) != 0, "a pointer that is real passes through")
    room.unsafe_free()

    var too_small = unsafe_alloc[UInt8](1)
    var raised = False
    try:
        _ = check_ptr(getcwd(too_small, 1))
    except e:
        raised = True
        assert_true(
            "ERANGE" in String(e), "and the error says which errno it was"
        )
    assert_true(raised, "a NULL answer raises")
    too_small.unsafe_free()


def main() raises:
    test_errno()
    test_errno_name()
    test_errno_message()
    test_check()
    test_check_ptr()
    print("test_errno: ok")
