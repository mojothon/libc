"""Tests for `libc.logging`, none of which had been called.

These four are how a program writes to the system log: `openlog`
says who is writing, `setlogmask` says what is worth sending,
`syslog` sends it, and `closelog` says it is finished.
"""
from std.testing import assert_equal

from libc.constant import LOG_INFO, LOG_PID, LOG_USER
from libc.logging import LOG_MASK, closelog, openlog, setlogmask, syslog
from libc.utils import string_to_char_ptr


def test_openlog_and_syslog_and_closelog() raises:
    """The three that write. `openlog` keeps the pointer it is given
    and not a copy of what it points at, so the name has to stay
    where it is for as long as messages are being sent, which
    `string_to_char_ptr` sees to.

    `syslog` is a variadic call, so it is given a message with no `%`
    in it: the rest of what a format string would make it read is
    not on the stack to be read.

    Where the messages go is not asked about. There may be nothing
    listening, and there is nothing here that would say either way.
    """
    var who = string_to_char_ptr("mojo-libc-test")
    _ = openlog(who, LOG_PID, LOG_USER)
    _ = syslog(LOG_INFO, string_to_char_ptr("a message from the tests"))
    closelog()


def test_setlogmask_hands_back_the_one_before() raises:
    """`setlogmask` hands back the mask that was there before it, so
    it can be asked twice: the second time it is given what it gave,
    and answers with what it was given the first time.

    The mask is put back before the test ends, so what is worth
    sending afterwards is whatever it was before.
    """
    var wanted = LOG_MASK(LOG_INFO)
    var was = setlogmask(wanted)
    assert_equal(
        Int(setlogmask(was)),
        Int(wanted),
        "setlogmask hands back the mask it was given before",
    )
    _ = setlogmask(was)


def main() raises:
    test_openlog_and_syslog_and_closelog()
    test_setlogmask_hands_back_the_one_before()
    print("test_logging: ok")
