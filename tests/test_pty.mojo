# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_char, c_int, c_ptr
from libc.pty import Winsize, forkpty, login_tty, openpty
from libc.stdlib import exit
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.termios import (
    ECHO,
    ICANON,
    ONLCR,
    TCSANOW,
    Termios,
    tcgetattr,
    tcsetattr,
)
from libc.unistd import close, fork, isatty, read, write
from libc.utils import null_ptr, string_to_char_ptr


comptime CHILD_SAYS = "the child has the terminal\n"
# What arrives at the master is not the same bytes: the child's terminal
# is at its defaults, and a default terminal turns a newline into a
# carriage return and a newline on the way out. The child writes one
# byte's worth of newline less than the parent reads, and that is the
# line discipline rather than a fault.
comptime CHILD_ARRIVES = "the child has the terminal\r\n"
comptime PING = "ping\n"
comptime PONG = "pong\n"


def collect(fd: Int32, block: c_ptr[c_char], want: Int) -> Int:
    """Reads until `want` bytes have arrived, or nothing more does.

    A pseudo-terminal is a pipe with a line discipline in it, and a read
    is free to come back with part of what was written: this file's
    forkpty test came back with twenty-five of twenty-six bytes once, on
    a machine busy compiling. So what arrives is gathered rather than
    expected in a single call, and the caller compares what was gathered.

    Args:
        fd: The descriptor to read at.
        block: Where to put the bytes.
        want: How many to wait for.

    Returns:
        How many arrived before a read answered none.
    """
    var got = 0
    while got < want:
        var more = read(fd, block.unsafe_offset(got), UInt32(want - got))
        if Int(more) <= 0:
            break
        got += Int(more)
    return got


def same(block: c_ptr[c_char], text: String) raises:
    """Asserts that the first bytes of `block` are the bytes of `text`.

    Read out of the block rather than compared as strings: a read that
    filled five bytes has not written a terminator after them, so what
    is there is five bytes and not a `String` that could be built from
    them without running past.
    """
    var bytes = text.as_bytes()
    var i = 0
    while i < len(bytes):
        assert_equal(
            Int(block.unsafe_load(i)),
            Int(bytes[i]),
            "the byte is the one that was written",
        )
        i += 1


def test_openpty_hands_back_a_working_pair() raises:
    """`openpty` answers two descriptors, and only one of them is a
    terminal: the slave is the terminal, and the master is the side a
    program reads and writes.

    The data has to cross in both directions. That is what the two local
    modes are turned off for: `ECHO` sends everything written to the
    slave back to the master, and `ICANON` holds input until a newline
    arrives, so the test would be reading its own echo and waiting for
    its own line. `ONLCR` is off for a third reason: a terminal at its
    defaults sends a newline as a carriage return and a newline, so the
    slave would read one byte more than was written and the count the
    test compares against would be the wrong one.
    """
    var master = unsafe_alloc[c_int](1)
    var slave = unsafe_alloc[c_int](1)
    master.unsafe_offset(0)[] = -1
    slave.unsafe_offset(0)[] = -1

    assert_equal(
        openpty(
            master,
            slave,
            null_ptr[c_char](),
            null_ptr[Termios](),
            null_ptr[Winsize](),
        ),
        0,
        "a pair is taken",
    )
    var m = master.unsafe_load()
    var s = slave.unsafe_load()
    assert_true(m >= 0 and s >= 0, "and both ends are descriptors")

    assert_equal(isatty(s), 1, "the slave is a terminal")
    # And so is the master, which is not what one expects of a cable: on
    # Linux the line discipline is on both ends, so `tcgetattr` answers
    # for the master too and `isatty` says yes. What the master is not is
    # the side a program under test gets -- that is the slave, and
    # `login_tty` is what puts it where a program looks.
    assert_equal(isatty(m), 1, "and the master answers for itself as well")

    var settings = unsafe_alloc[Termios](1)
    settings.unsafe_offset(0)[] = Termios()
    assert_equal(tcgetattr(s, settings), 0, "the slave's settings are read")
    settings[].set_lflag(settings[].lflag() & ~(ECHO | ICANON))
    settings[].set_oflag(settings[].oflag() & ~ONLCR)
    assert_equal(tcsetattr(s, TCSANOW, settings), 0, "and made quiet")

    var payload = string_to_char_ptr(PING)
    var sent = UInt32(PING.byte_length())
    assert_equal(
        write(m, payload, sent), Int(sent), "the bytes go in at the master"
    )

    var came = unsafe_alloc[c_char](8)
    assert_equal(
        collect(s, came, Int(sent)), Int(sent), "and come out at the slave"
    )
    same(came, PING)

    var answer = string_to_char_ptr(PONG)
    var answered = UInt32(PONG.byte_length())
    assert_equal(
        write(s, answer, answered),
        Int(answered),
        "the bytes go in at the slave",
    )
    var echoes = unsafe_alloc[c_char](8)
    assert_equal(
        collect(m, echoes, Int(answered)),
        Int(answered),
        "and come back at the master",
    )
    same(echoes, PONG)

    _ = close(s)
    _ = close(m)
    settings.unsafe_free()
    payload.unsafe_free()
    came.unsafe_free()
    answer.unsafe_free()
    echoes.unsafe_free()
    master.unsafe_free()
    slave.unsafe_free()


def test_forkpty_gives_the_child_all_three_descriptors() raises:
    """`forkpty` is `fork`, `openpty` and `login_tty` in one call: the
    child has the slave on 0, 1 and 2, and the parent has the master.

    What the child writes to its standard output is what the parent
    reads at the master, which is the whole of the arrangement: the
    child thinks it is talking to a terminal, and the program behind the
    master is the terminal. What arrives is a byte longer than what was
    written, because the terminal is at its defaults and they translate
    the newline.
    """
    var master = unsafe_alloc[c_int](1)
    master.unsafe_offset(0)[] = -1

    var child = forkpty(
        master, null_ptr[c_char](), null_ptr[Termios](), null_ptr[Winsize]()
    )
    if child == 0:
        var all_three = isatty(0) + isatty(1) + isatty(2)
        if all_three != 3:
            _ = exit(1)
        var said = string_to_char_ptr(CHILD_SAYS)
        _ = write(1, said, UInt32(CHILD_SAYS.byte_length()))
        _ = exit(0)

    var m = master.unsafe_load()
    assert_true(child > 0, "there is a child, and a master to read")
    assert_true(m >= 0, "and the master is a descriptor")

    var heard = unsafe_alloc[c_char](64)
    var got = collect(m, heard, CHILD_ARRIVES.byte_length())
    assert_equal(
        got,
        CHILD_ARRIVES.byte_length(),
        "the child's writing is what arrives, with the newline the terminal "
        + "made of it",
    )
    same(heard, CHILD_ARRIVES)

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is taken back")
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it left of its own accord"
    )
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())), 0, "with nothing wrong"
    )

    _ = close(m)
    heard.unsafe_free()
    status.unsafe_free()
    master.unsafe_free()


def test_login_tty_makes_the_descriptor_the_terminal() raises:
    """`login_tty` puts a descriptor on 0, 1 and 2 and makes it the
    controlling terminal of a new session.

    It is the half of `forkpty` a caller does by hand when the fork has
    to happen first -- and the half that is easy to leave out, which is
    a child that finds its terminal on a descriptor it does not think is
    a terminal.
    """
    var master = unsafe_alloc[c_int](1)
    var slave = unsafe_alloc[c_int](1)
    master.unsafe_offset(0)[] = -1
    slave.unsafe_offset(0)[] = -1

    assert_equal(
        openpty(
            master,
            slave,
            null_ptr[c_char](),
            null_ptr[Termios](),
            null_ptr[Winsize](),
        ),
        0,
        "a pair is taken",
    )
    var m = master.unsafe_load()
    var s = slave.unsafe_load()

    var child = fork()
    if child == 0:
        _ = close(m)
        if login_tty(s) != 0:
            _ = exit(1)
        var all_three = isatty(0) + isatty(1) + isatty(2)
        if all_three != 3:
            _ = exit(2)
        var said = string_to_char_ptr("ok")
        _ = write(1, said, 2)
        _ = exit(0)

    assert_true(child > 0, "there is a child to log in")
    _ = close(s)

    var heard = unsafe_alloc[c_char](8)
    assert_equal(collect(m, heard, 2), 2, "and what it wrote crosses the pair")
    same(heard, "ok")

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is taken back")
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        0,
        "and it found a terminal on all three",
    )

    _ = close(m)
    heard.unsafe_free()
    status.unsafe_free()
    master.unsafe_free()
    slave.unsafe_free()


def main() raises:
    test_openpty_hands_back_a_working_pair()
    test_forkpty_gives_the_child_all_three_descriptors()
    test_login_tty_makes_the_descriptor_the_terminal()
    print("pty ok")
