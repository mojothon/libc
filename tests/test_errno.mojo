from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import EAGAIN, ENOENT, EPERM
from libc.errno import check, errno_message, errno_name, get_errno, set_errno
from libc.fcntl import F_SETFL, O_NONBLOCK, fcntl
from libc.sys.stat import Stat, stat
from libc.unistd import pipe, read
from libc.utils import string_to_char_ptr


def test_errno() raises:
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
    # provoke: a non-blocking read of an empty pipe. Linux says 11 and Darwin
    # says 35, so this is what keeps `EAGAIN` honest on both, and a value
    # that is not the platform's own fails here rather than in a caller's
    # error handling.
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "pipe succeeded")
    assert_equal(
        fcntl(fds.unsafe_offset(0)[], F_SETFL, O_NONBLOCK),
        0,
        "the read end is non-blocking",
    )
    var one = unsafe_alloc[UInt8](1)
    set_errno(0)
    assert_equal(
        read(fds.unsafe_offset(0)[], one, 1),
        -1,
        "reading an empty non-blocking pipe fails",
    )
    assert_equal(
        Int(get_errno()), Int(EAGAIN), "and says EAGAIN, this platform's number"
    )
    fds.unsafe_free()
    one.unsafe_free()

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


def main() raises:
    test_errno()
    test_errno_name()
    test_errno_message()
    test_check()
    print("test_errno: ok")
