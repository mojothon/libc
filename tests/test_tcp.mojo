# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, IPPROTO_TCP, SOCK_STREAM
from libc.sys.socket import getsockopt, setsockopt, socket
from libc.tcp import TCP_KEEPCNT, TCP_KEEPINTVL, TCP_MAXSEG, TCP_NODELAY
from libc.unistd import close


def opened() raises -> Int32:
    """A TCP socket, unconnected: every option here is settable on one."""
    var sock = socket(AF_INET, SOCK_STREAM, 0)
    assert_true(sock >= 0, "a TCP socket was made")
    return sock


def reading(sock: Int32, name: Int32) raises -> Int32:
    """Reads an option as an `int`, which is what all four of these are.

    The width is handed over as 4 and read back, so a call that answered
    with a different width is not passed over: the four options in this
    header are all `int`s, and one that came back as something else would
    mean the number asked for is not the option it was thought to be.
    """
    var value = unsafe_alloc[Int32](1)
    value[] = -1
    var width = unsafe_alloc[UInt32](1)
    width[] = 4
    assert_equal(
        Int(
            getsockopt(
                sock,
                IPPROTO_TCP,
                name,
                value.unsafe_bitcast[NoneType](),
                width,
            )
        ),
        0,
        "the option was read",
    )
    assert_equal(Int(width[]), 4, "and it is four bytes wide")
    var answer = value[]
    value.unsafe_free()
    width.unsafe_free()
    return answer


def setting(sock: Int32, name: Int32, value: Int32) -> Int32:
    """Sets an option to an `int`, and answers what C said about it."""
    var given = unsafe_alloc[Int32](1)
    given[] = value
    var code = setsockopt(
        sock,
        IPPROTO_TCP,
        name,
        given.unsafe_bitcast[NoneType](),
        UInt32(4),
    )
    given.unsafe_free()
    return code


def test_nodelay_starts_off_and_the_number_turns_it_on() raises:
    """`TCP_NODELAY` is off on a fresh connection, and the number the
    binding gives is the one that turns it on.

    This is what the number is checked by: a wrong one asks for an option
    that does not exist, which the call refuses, and an option that
    happens to exist under that number is not `TCP_NODELAY` and does not
    come back as what was written. Neither can pass by being self
    consistent.
    """
    var sock = opened()
    assert_equal(reading(sock, TCP_NODELAY), 0, "nodelay starts off")
    assert_equal(setting(sock, TCP_NODELAY, 1), 0, "and the call sets it")
    # What comes back is not 1 on both platforms. glibc answers the option
    # as the caller wrote it; Darwin answers the flag the kernel set, and
    # its `TF_NODELAY` is 0x4, which is what the macOS runner read back.
    # Both mean on, and neither is a value this package chooses -- so both
    # are written down as the measured answer rather than compared for
    # being nonzero, which would pass on a wrong option number too.
    comptime ON: Int32 = 4 if CompilationTarget.is_macos() else 1
    assert_equal(
        reading(sock, TCP_NODELAY), ON, "to what that platform answers"
    )
    assert_equal(setting(sock, TCP_NODELAY, 0), 0, "and it can be put back")
    assert_equal(reading(sock, TCP_NODELAY), 0, "which reads back as off")
    _ = close(sock)


def test_the_keepalive_pair_answers_what_was_written() raises:
    """`TCP_KEEPINTVL` and `TCP_KEEPCNT` are asked with a number and
    answer it back, on a socket that is not connected yet.

    Two different numbers, so an option that answers the other one's
    storage is caught: 42 seconds and then 7 probes are not one value
    read twice.
    """
    var sock = opened()
    assert_equal(setting(sock, TCP_KEEPINTVL, 42), 0, "the interval is set")
    assert_equal(reading(sock, TCP_KEEPINTVL), 42, "and answers 42")
    assert_equal(setting(sock, TCP_KEEPCNT, 7), 0, "the count is set")
    assert_equal(reading(sock, TCP_KEEPCNT), 7, "and answers 7")
    assert_equal(
        reading(sock, TCP_KEEPINTVL),
        42,
        "and setting one did not move the other",
    )
    _ = close(sock)


def test_maxseg_is_there_to_be_read() raises:
    """`TCP_MAXSEG` is read rather than written: what a socket answers
    before it has a path is the default segment size, and what it answers
    after is the one the path negotiated.

    The number is checked by the read succeeding: the wrong one is
    refused, and the right one answers a size a segment could be.
    """
    var sock = opened()
    var mss = reading(sock, TCP_MAXSEG)
    assert_true(mss > 0, "a segment size is there")
    assert_true(mss <= 65535, "and it is one a segment could be")
    _ = close(sock)


def main() raises:
    test_nodelay_starts_off_and_the_number_turns_it_on()
    test_the_keepalive_pair_answers_what_was_written()
    test_maxseg_is_there_to_be_read()
    print("tcp ok")
