"""Tests for the `libc.unistd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.unistd import (
    alarm,
    chown,
    fchown,
    fchownat,
    getcwd,
    getegid,
    geteuid,
    getgid,
    getpagesize,
    getpid,
    getuid,
    lchown,
    nice,
    setegid,
    seteuid,
    sleep,
    swab,
)
from libc.utils import string_to_char_ptr


def test_getcwd() raises:
    """`getcwd` hands back the buffer it filled, not 0 or -1."""
    var buf = unsafe_alloc[UInt8](256)
    var got = getcwd(buf, 256)

    # An absolute path starts with `/`, and what comes back is the pointer
    # that was passed in, so it has to be readable as bytes.
    assert_equal(got.unsafe_offset(0)[], UInt8(0x2F))

    var length = 0
    while got.unsafe_offset(length)[] != 0:
        length += 1
    assert_true(length > 1)


def test_swab() raises:
    """`swab` copies and swaps each pair of bytes."""
    var src = unsafe_alloc[UInt8](4)
    var dst = unsafe_alloc[UInt8](4)
    src.unsafe_offset(0)[] = 0x01
    src.unsafe_offset(1)[] = 0x02
    src.unsafe_offset(2)[] = 0x03
    src.unsafe_offset(3)[] = 0x04

    swab(src, dst, 4)

    assert_equal(dst.unsafe_offset(0)[], UInt8(0x02))
    assert_equal(dst.unsafe_offset(1)[], UInt8(0x01))
    assert_equal(dst.unsafe_offset(2)[], UInt8(0x04))
    assert_equal(dst.unsafe_offset(3)[], UInt8(0x03))


def test_getpid() raises:
    """This process has an id, and it is not zero."""
    assert_true(getpid() > 0)


def test_ids() raises:
    """`getgid` and `getegid`, and setting an id to what it already is."""
    assert_true(getgid() >= 0, "the real group id is not negative")
    assert_true(getegid() >= 0, "and neither is the effective one")

    # Handing an effective id the value it already has is the only way to
    # call these from a test without changing what the process may do.
    assert_equal(seteuid(geteuid()), 0, "seteuid to the current euid")
    assert_equal(setegid(getegid()), 0, "setegid to the current egid")


def test_alarm_and_sleep() raises:
    """Both can be asked for nothing, and neither one waits."""
    assert_equal(alarm(0), 0, "no alarm was set, so none was replaced")
    assert_equal(sleep(0), 0, "and there was nothing to sleep through")


def test_nice_and_pagesize() raises:
    # What `nice` answers with is not the same on the two platforms: Linux
    # gives back the niceness it came to and Darwin gives 0 or -1, so all
    # that can be asked of it here is that asking twice says the same thing.
    assert_equal(nice(0), nice(0), "the answer does not depend on the asking")
    assert_true(getpagesize() > 0, "a page is some number of bytes")


def test_chown_on_what_is_not_there() raises:
    """All four say -1 for a file that does not exist.

    Giving a real file to somebody else is not a thing a test should do,
    so this is the part of them a test can safely ask about.
    """
    var nowhere = string_to_char_ptr("/nonexistent/libc-test")

    assert_equal(chown(nowhere, getuid(), getgid()), -1)
    assert_equal(lchown(nowhere, getuid(), getgid()), -1)
    assert_equal(fchown(-1, getuid(), getgid()), -1, "no such descriptor")
    assert_equal(fchownat(-1, nowhere, getuid(), getgid(), 0), -1)

    nowhere.unsafe_free()


def main() raises:
    test_getcwd()
    test_swab()
    test_getpid()
    test_ids()
    test_alarm_and_sleep()
    test_nice_and_pagesize()
    test_chown_on_what_is_not_there()
    print("test_unistd: ok")
