"""Tests for the `libc.termios` bindings.

How a terminal is set. Two kinds of test: the `cf*` calls, which
only read and write a block of memory and so want no terminal at all,
and the `tc*` calls, which want one and are here asked about
`/dev/null` instead — a file that is not a terminal, and one every
machine has.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AT_FDCWD, ENODEV, ENOTTY, O_RDONLY, c_ptr
from libc.errno import get_errno, set_errno
from libc.fcntl import openat
from libc.termios import (
    B9600,
    NCCS,
    TCSADRAIN,
    TCSAFLUSH,
    TCSANOW,
    TCIFLUSH,
    TCIOFLUSH,
    TCOFLUSH,
    Termios,
    cfgetispeed,
    cfgetospeed,
    cfmakeraw,
    cfsetspeed,
    cfsetispeed,
    cfsetospeed,
    tcflow,
    tcflush,
    tcgetattr,
    tcgetsid,
    tcsendbreak,
    tcsetattr,
    tcdrain,
)
from libc.unistd import close
from libc.utils import string_to_char_ptr


def _a_settings_block() raises -> c_ptr[Termios]:
    """One zeroed `struct termios`, which is what `tcgetattr` overwrites."""
    var settings = unsafe_alloc[Termios](1)
    settings.unsafe_offset(0)[] = Termios()
    return settings


def _assert_it_is_not_a_terminal(what: String) raises:
    """Says that `errno` is whatever this platform means by that.

    glibc answers ENOTTY for a terminal call on something that is not
    a terminal; Darwin's /dev/null answers ENODEV. Both are refusals.
    That they differ is worth knowing rather than hiding, so the two
    are named here side by side instead of one of them being picked.
    """
    var why = get_errno()
    assert_true(why == ENOTTY or why == ENODEV, what)


def test_cfsetospeed_then_cfgetospeed() raises:
    """Output speed in, the same speed out.

    This is the one that would say something were the block the wrong
    shape: `cfsetospeed` writes where C thinks `c_ospeed` is and
    `cfgetospeed` reads it back, so a struct laid out for the other
    platform would put the number somewhere else and read nothing.
    """
    var settings = _a_settings_block()

    assert_equal(cfsetospeed(settings, B9600), 0, "setting the speed works")
    assert_equal(Int(cfgetospeed(settings)), Int(B9600), "and it comes back")

    settings.unsafe_free()


def test_cfsetispeed_then_cfgetispeed() raises:
    """Input speed in, the same speed out — the other half of the pair."""
    var settings = _a_settings_block()

    assert_equal(cfsetispeed(settings, B9600), 0, "setting the speed works")
    assert_equal(Int(cfgetispeed(settings)), Int(B9600), "and it comes back")

    settings.unsafe_free()


def test_cfsetspeed_sets_both_at_once() raises:
    """`cfsetspeed` is the two above in one call, so both come back the
    same.
    """
    var settings = _a_settings_block()

    assert_equal(cfsetspeed(settings, B9600), 0, "setting the speed works")
    assert_equal(Int(cfgetispeed(settings)), Int(B9600), "the input speed took")
    assert_equal(
        Int(cfgetospeed(settings)), Int(B9600), "and so did the output"
    )

    settings.unsafe_free()


def test_cfmakeraw_turns_the_line_off_and_stays_there() raises:
    """`cfmakeraw` clears the flags it is about, and asking twice is
    the same as asking once.

    The flags themselves are numbered differently on the two
    platforms, so this asks only what is true of both: that the modes
    change, and that they change to the same thing every time.
    """
    var settings = _a_settings_block()
    # Every bit set, so that clearing one of them has to show.
    settings[].set_lflag(0xFFFFFFFF)
    var before = settings[].lflag()
    assert_equal(Int(before), Int(0xFFFFFFFF), "and a set bit reads back set")

    cfmakeraw(settings)
    var after = settings[].lflag()
    assert_true(after != before, "raw mode clears some of them")

    cfmakeraw(settings)
    assert_equal(
        Int(settings[].lflag()), Int(after), "and asking again clears no more"
    )

    settings.unsafe_free()


def test_tcgetattr_refuses_what_is_not_a_terminal() raises:
    """`tcgetattr` on `/dev/null`, which is a file and not a
    terminal. The answer is -1 and `errno` is set, which is not the
    same as an empty struct that looks plausible.
    """
    var fd = openat(Int32(AT_FDCWD), string_to_char_ptr("/dev/null"), O_RDONLY)
    assert_true(fd >= 0, "/dev/null opens")

    var settings = _a_settings_block()
    set_errno(0)
    assert_equal(tcgetattr(fd, settings), -1, "it refuses")
    _assert_it_is_not_a_terminal("and says why")

    settings.unsafe_free()
    _ = close(fd)


def test_the_tc_calls_all_refuse_the_same_file() raises:
    """`tcsetattr`, `tcdrain`, `tcflow`, `tcflush`, `tcsendbreak` and
    `tcgetsid` on the same `/dev/null`. None of them reaches a
    driver, so all six answer the same way.
    """
    var fd = openat(Int32(AT_FDCWD), string_to_char_ptr("/dev/null"), O_RDONLY)
    assert_true(fd >= 0, "/dev/null opens")
    var settings = _a_settings_block()

    set_errno(0)
    assert_equal(tcsetattr(fd, TCSANOW, settings), -1, "tcsetattr refuses")
    _assert_it_is_not_a_terminal("with that said")

    set_errno(0)
    assert_equal(tcdrain(fd), -1, "tcdrain refuses")
    _assert_it_is_not_a_terminal("with that said")

    set_errno(0)
    assert_equal(tcflow(fd, 0), -1, "tcflow refuses")
    _assert_it_is_not_a_terminal("with that said")

    set_errno(0)
    assert_equal(tcflush(fd, TCIFLUSH), -1, "tcflush refuses")
    _assert_it_is_not_a_terminal("with that said")

    set_errno(0)
    assert_equal(tcsendbreak(fd, 0), -1, "tcsendbreak refuses")
    _assert_it_is_not_a_terminal("with that said")

    set_errno(0)
    assert_equal(tcgetsid(fd), -1, "tcgetsid refuses")
    _assert_it_is_not_a_terminal("with that said")

    settings.unsafe_free()
    _ = close(fd)


def test_the_queue_and_action_constants_are_which_they_say() raises:
    """The three `TC*FLUSH` are in order and the four `TCO*`/`TCI*`
    are in order. They are one apart between the platforms, which is
    the sort of thing a caller passing a bare integer gets wrong
    without a word from anybody.
    """
    assert_true(TCIFLUSH < TCOFLUSH, "input flushes before output")
    assert_true(TCOFLUSH < TCIOFLUSH, "and both flush after either one")
    assert_true(TCSANOW < TCSADRAIN, "now is before waiting to drain")
    assert_true(TCSADRAIN < TCSAFLUSH, "and draining is before flushing")
    assert_true(
        NCCS == 20 or NCCS == 32, "and there are 20 or 32 control characters"
    )


def main() raises:
    test_cfsetospeed_then_cfgetospeed()
    test_cfsetispeed_then_cfgetispeed()
    test_cfsetspeed_sets_both_at_once()
    test_cfmakeraw_turns_the_line_off_and_stays_there()
    test_tcgetattr_refuses_what_is_not_a_terminal()
    test_the_tc_calls_all_refuse_the_same_file()
    test_the_queue_and_action_constants_are_which_they_say()
    print("test_termios: ok")
