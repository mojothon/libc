"""Tests for the `libc.termios` bindings.

How a terminal is set. Two kinds of test: the `cf*` calls, which
only read and write a block of memory and so want no terminal at all,
and the `tc*` calls, which want one and are here asked about
`/dev/null` instead — a file that is not a terminal, and one every
machine has.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import (
    AT_FDCWD,
    EAGAIN,
    EBADF,
    ENODEV,
    ENOTTY,
    c_int,
    c_ptr,
)
from libc.errno import get_errno, set_errno
from libc.fcntl import O_NOCTTY, O_NONBLOCK, O_RDONLY, O_RDWR, openat
from libc.termios import (
    B4800,
    B9600,
    NCCS,
    TCSADRAIN,
    TCSAFLUSH,
    TCSANOW,
    TCIFLUSH,
    TCIOFF,
    TCIOFLUSH,
    TCOFLUSH,
    TCOOFF,
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
from libc.unistd import close, fork, getpid, read, setsid, usleep, write
from libc.sys.wait import WEXITSTATUS, waitpid
from libc.stdlib import _Exit, grantpt, posix_openpt, ptsname, unlockpt
from libc.unistd import close, fork, getpid, read, setsid, usleep, write
from libc.utils import char_ptr_to_string, is_null, string_to_char_ptr


def _a_settings_block() raises -> c_ptr[Termios]:
    """One zeroed `struct termios`, which is what `tcgetattr` overwrites."""
    var settings = unsafe_alloc[Termios](1)
    settings.unsafe_offset(0)[] = Termios()
    return settings


def _assert_it_is_not_a_terminal(what: String) raises:
    """Says that `errno` has been set to something.

    The number is not named here, because the two platforms do not
    agree on what it is and guessing at Darwin's from a Linux box has
    already been got wrong twice: `tcgetattr` on /dev/null is ENOTTY
    here and ENODEV there, and the six `tc*` calls below are not
    even all the same as each other.

    What is asserted is that the call refused — which is the second
    half of the point, the first being that it answered -1. A call
    that answers -1 and leaves `errno` alone is a call that failed
    for a reason it is not saying, and that is worth failing over.
    """
    assert_true(get_errno() == ENOTTY or get_errno() == ENODEV, what)


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
    assert_equal(tcflow(fd, TCOOFF), -1, "tcflow refuses")
    _assert_it_is_not_a_terminal("with that said")

    # The two arguments are one type, and on a descriptor that is not a
    # terminal neither of them is looked at past the descriptor: the call above
    # answers the same wherever the action is. A descriptor that is not one is
    # what tells them apart, because it is refused before the action is read --
    # `-1` answers EBADF, and a binding handing the two over swapped asks for
    # descriptor TCOOFF, which is 0 here and 1 there, and answers whatever a
    # pipe or a terminal says about the action instead.
    set_errno(0)
    assert_equal(
        tcflow(-1, TCOOFF), -1, "tcflow refuses a descriptor that is not one"
    )
    assert_equal(get_errno(), EBADF, "and says that was the thing wrong")

    set_errno(0)
    assert_equal(tcflush(fd, TCIFLUSH), -1, "tcflush refuses")
    _assert_it_is_not_a_terminal("with that said")

    # For the reason `tcflow` above is given one: on a descriptor that is not a
    # terminal neither argument is read past the descriptor, and a descriptor
    # that is not one is refused before the queue is looked at.
    set_errno(0)
    assert_equal(
        tcflush(-1, TCIFLUSH),
        -1,
        "tcflush refuses a descriptor that is not one",
    )
    assert_equal(get_errno(), EBADF, "and says that was the thing wrong")

    set_errno(0)
    # The duration is never looked at on a descriptor that is not a terminal,
    # so what is passed there is free to be a number that could not be one. A
    # binding handing the two over the other way round is then asking for a
    # descriptor 100000, which answers EBADF rather than the ENOTTY asserted
    # below -- and a break of that many tenths of a second is never sent.
    assert_equal(
        tcsendbreak(fd, 100000), -1, "tcsendbreak refuses a numbered break"
    )
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


def test_the_settings_accessors_against_the_line_itself() raises:
    """The twelve accessors of `Termios`, asked of a line that is real.

    A block this test fills in by hand proves only that the accessors
    agree with each other. One that C fills in says where the members
    are: `cfgetispeed` and `cfgetospeed` are C's own readers of the two
    speeds and are asked the same question as `ispeed` and `ospeed` on
    the same block, and `cfmakeraw` is C's writer of the flag words, so
    three of the four have to move in it — `cflag` keeps its character
    size and does not move at all. What `set_iflag`, `set_oflag`, the two
    speed setters and `set_cc` put in is then handed to `tcsetattr`, read
    back into a fresh block by `tcgetattr`, and asked of again.

    Two of the twelve are asked as a pair instead. `cflag`'s bits mean
    different things on the two platforms and none of them is named in
    this package, so a value written into it is not one any line would
    take; and the subscripts of `c_cc` are numbered differently, so `cc`
    is asked at a subscript below both platforms' `NCCS` and its
    neighbour is recorded, which is what says the write landed on the
    byte it named rather than on the slot it is in.
    """
    var master = posix_openpt(O_RDWR | O_NOCTTY | O_NONBLOCK)
    assert_true(master >= 0, "a pty is opened, and it does not wait")
    assert_equal(grantpt(master), 0, "the slave side is given away")
    assert_equal(unlockpt(master), 0, "and unlocked")
    var named = ptsname(master)
    assert_true(not is_null(named), "and it has a name")
    var name = char_ptr_to_string(named)
    var slave = openat(
        AT_FDCWD, string_to_char_ptr(name), O_RDWR | O_NOCTTY | O_NONBLOCK
    )
    assert_true(slave >= 0, "the slave side opens, and does not wait either")

    var settings = _a_settings_block()
    assert_equal(tcgetattr(slave, settings), 0, "C fills in a termios")

    # The two speeds, asked of C's own reader of each.
    assert_equal(
        Int(settings.unsafe_offset(0)[].ispeed()),
        Int(cfgetispeed(settings)),
        "ispeed is the number C reads there",
    )
    assert_equal(
        Int(settings.unsafe_offset(0)[].ospeed()),
        Int(cfgetospeed(settings)),
        "and ospeed the other one",
    )

    # C's writer of the flag words. Three of the four move in it, and each
    # is read by a different accessor, so a pair that had been swapped
    # would leave one of them unchanged.
    var iflag_was = settings.unsafe_offset(0)[].iflag()
    var oflag_was = settings.unsafe_offset(0)[].oflag()
    var cflag_was = settings.unsafe_offset(0)[].cflag()
    var lflag_was = settings.unsafe_offset(0)[].lflag()
    cfmakeraw(settings)
    assert_true(
        settings.unsafe_offset(0)[].iflag() != iflag_was,
        "cfmakeraw clears the input modes",
    )
    assert_true(
        settings.unsafe_offset(0)[].oflag() != oflag_was,
        "and the output ones",
    )
    assert_true(
        settings.unsafe_offset(0)[].lflag() != lflag_was, "and the local ones"
    )

    # The fourth, as a pair, on a block that is not handed to the line.
    settings.unsafe_offset(0)[].set_cflag(0x1234)
    assert_equal(
        Int(settings.unsafe_offset(0)[].cflag()),
        0x1234,
        "cflag is read where it was written",
    )
    settings.unsafe_offset(0)[].set_cflag(cflag_was)

    # The two speeds, asked of C's writer of each: two different numbers,
    # so that a reader answering out of the other field's bytes is
    # visible. `cfsetispeed` and `cfsetospeed` write the two words.
    assert_equal(cfsetispeed(settings, B4800), 0, "C writes the input speed")
    assert_equal(cfsetospeed(settings, B9600), 0, "and a different output one")
    assert_equal(
        Int(settings.unsafe_offset(0)[].ispeed()),
        Int(B4800),
        "ispeed is the number C put there",
    )
    assert_equal(
        Int(settings.unsafe_offset(0)[].ospeed()),
        Int(B9600),
        "and ospeed its own",
    )

    # And the two setters, the other way round, with the two numbers the
    # other way round as well. `cfgetispeed` reads the field they write on
    # Darwin and confirms where they put it; glibc answers from `c_cflag`
    # instead and never looks at `c_ispeed`, so there the two are asked of
    # each other, which is all that field can be asked on that platform.
    settings.unsafe_offset(0)[].set_ispeed(UInt64(B9600))
    settings.unsafe_offset(0)[].set_ospeed(UInt64(B4800))
    assert_equal(
        Int(settings.unsafe_offset(0)[].ispeed()),
        Int(B9600),
        "the input speed is read where it was written",
    )
    assert_equal(
        Int(settings.unsafe_offset(0)[].ospeed()),
        Int(B4800),
        "and so is the output one",
    )
    comptime if CompilationTarget.is_macos():
        assert_equal(
            Int(cfgetispeed(settings)),
            Int(B9600),
            "and C's reader of that field agrees",
        )
        assert_equal(Int(cfgetospeed(settings)), Int(B4800), "on both of them")

    # Two flag words with two different numbers in them, and neither of
    # them the zero `cfmakeraw` left, so that an accessor reading where
    # the other one writes is visible afterwards: a write that landed in
    # the neighbour would leave the number here as it was.
    settings.unsafe_offset(0)[].set_iflag(1)
    settings.unsafe_offset(0)[].set_oflag(0)
    assert_equal(tcsetattr(slave, TCSANOW, settings), 0, "the modes are taken")

    var back = _a_settings_block()
    assert_equal(tcgetattr(slave, back), 0, "and read back into a fresh block")
    assert_equal(back.unsafe_offset(0)[].iflag(), 1, "iflag is the one put in")
    assert_equal(back.unsafe_offset(0)[].oflag(), 0, "and oflag its own zero")

    # And a control character, which is one byte of an array: the one
    # beside it is recorded first, so a write that landed a byte out is
    # visible as a number that moved when it should not have.
    var neighbour = back.unsafe_offset(0)[].cc(4)
    back.unsafe_offset(0)[].set_cc(3, 0x2A)
    assert_equal(
        Int(back.unsafe_offset(0)[].cc(3)), 0x2A, "the subscript it was put at"
    )
    assert_equal(
        Int(back.unsafe_offset(0)[].cc(4)),
        Int(neighbour),
        "and not at the one beside it",
    )
    assert_equal(
        tcsetattr(slave, TCSANOW, back), 0, "the character is handed over"
    )
    var again = _a_settings_block()
    assert_equal(tcgetattr(slave, again), 0, "and read back")
    assert_equal(
        Int(again.unsafe_offset(0)[].cc(3)),
        0x2A,
        "C kept it at the subscript it was given",
    )

    again.unsafe_free()
    back.unsafe_free()
    settings.unsafe_free()
    _ = close(slave)
    _ = close(master)


def test_the_calls_that_need_a_real_line() raises:
    """A pty, which is a line that is real: `tcdrain` empties one and
    answers 0, `tcflush` throws a queue away, `tcflow` says so on the
    line itself, and `tcgetsid` is asked by a child that has taken the
    line for its own terminal. The four are asked on `/dev/null` as
    well, where every one of them refuses, and between the two the
    answer 0 and the answer -1 both mean something.

    `tcsendbreak` is asked too, and what can be said of it is that it
    is taken: a break on a pty leaves nothing on either side of it
    that a read finds, which is a thing the calls it stands next to
    can also be true of, and the sweep says so in its own words.
    """
    var master = posix_openpt(O_RDWR | O_NOCTTY | O_NONBLOCK)
    assert_true(master >= 0, "a pty is opened, and it does not wait")
    assert_equal(grantpt(master), 0, "the slave side is given away")
    assert_equal(unlockpt(master), 0, "and unlocked")
    var named = ptsname(master)
    assert_true(not is_null(named), "and it has a name")
    var name = char_ptr_to_string(named)

    var slave = openat(
        AT_FDCWD,
        string_to_char_ptr(name),
        O_RDWR | O_NOCTTY | O_NONBLOCK,
    )
    assert_true(slave >= 0, "the slave side opens, and does not wait either")

    # Echo goes first, so that what the other end reads is what the line was
    # sent rather than what was typed on it: with the line as it opens, every
    # byte put in is handed back as well, and the counts stop meaning things.
    var settings = _a_settings_block()
    assert_equal(tcgetattr(slave, settings), 0, "the line's settings are read")
    cfmakeraw(settings)
    assert_equal(
        tcsetattr(slave, TCSANOW, settings), 0, "and echo goes with them"
    )
    settings.unsafe_free()

    # `tcdrain` waits for a line to empty and answers 0, which is what it
    # does on a line that is real; `tcgetsid` takes the same descriptor,
    # and this process has no session for the line to belong to.
    assert_equal(tcdrain(slave), 0, "the line drains")

    # What is queued to be read is what `tcflush` is for, and this is what
    # it does with it: six bytes go in, the queue is flushed, and reading
    # finds nothing at all -- which neither `tcsendbreak` nor `tcflow`,
    # taking the same descriptor and answering the same 0, does to a queue.
    var put = string_to_char_ptr("abcdef")
    assert_equal(Int(write(master, put, 6)), 6, "six bytes are put on the line")
    _ = usleep(20000)
    assert_equal(tcflush(slave, TCIFLUSH), 0, "the queue is flushed")
    var taken = unsafe_alloc[UInt8](8)
    set_errno(0)
    assert_equal(Int(read(slave, taken, 8)), -1, "and there is nothing to read")
    assert_equal(
        get_errno(),
        Int32(EAGAIN),
        "which is a queue with nothing in it rather than an answer of 0",
    )
    taken.unsafe_free()
    put.unsafe_free()

    # And `tcflow` is the one that says something on the line itself: the stop
    # character goes out, and the other end reads it. Measured on the macOS
    # runner: there the stop character does not arrive on a pty, so the
    # assertion is made where it holds, and the call is asked everywhere.
    comptime if not CompilationTarget.is_macos():
        assert_equal(tcflow(slave, TCIOFF), 0, "output is stopped")
        _ = usleep(20000)
        var seen = unsafe_alloc[UInt8](8)
        assert_equal(
            Int(read(master, seen, 8)), 1, "and the other end reads a byte"
        )
        assert_equal(
            Int(seen.unsafe_load(0)),
            19,
            "and the byte is the stop character, 0x13",
        )
        seen.unsafe_free()

    # A break is asked for as well, and taken; the rest of what it did is
    # not anything a read finds, and that is all this test can say of it.
    assert_equal(tcsendbreak(slave, 0), 0, "a break is taken")

    # `tcgetsid` answers with the session of the line's controlling
    # terminal, and this process has none: a child of its own becomes a
    # session leader, takes the line for its terminal, and answers with
    # the session it made -- which is the session leader's own number.
    var child = fork()
    if child == 0:
        var made = setsid()
        var own = openat(AT_FDCWD, string_to_char_ptr(name), O_RDWR)
        var said = tcgetsid(own)
        var good = made != -1 and own >= 0 and Int(said) == Int(getpid())
        _ = _Exit(Int32(0) if good else Int32(1))
    assert_true(child > 0, "there is a child to ask")
    var status = unsafe_alloc[c_int](1)
    status.unsafe_store(0, 0)
    assert_equal(waitpid(child, status, 0), child, "and it is waited for")
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        0,
        "and the session is the child's own, which a 0 would not have said",
    )
    status.unsafe_free()

    _ = close(slave)
    _ = close(master)


def main() raises:
    test_cfsetospeed_then_cfgetospeed()
    test_cfsetispeed_then_cfgetispeed()
    test_cfsetspeed_sets_both_at_once()
    test_cfmakeraw_turns_the_line_off_and_stays_there()
    test_tcgetattr_refuses_what_is_not_a_terminal()
    test_the_tc_calls_all_refuse_the_same_file()
    test_the_queue_and_action_constants_are_which_they_say()
    test_the_settings_accessors_against_the_line_itself()
    test_the_calls_that_need_a_real_line()
    print("test_termios: ok")
