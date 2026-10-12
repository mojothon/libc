from std.testing import assert_equal

from libc.fcntl import lockf


def test_lockf_on_what_is_not_open() raises:
    """`lockf` asked about a range in a file that is not open.

    Taking a lock on a real file from a test would leave the lock behind
    if the test were to fail, so this asks about a descriptor that does
    not exist, and the answer to that is no. The 3 is `F_TEST`, which
    asks whether a range is free rather than locking it, and it is 3 on
    both platforms.
    """
    assert_equal(lockf(-1, 3, 0), -1, "no such descriptor")


def main() raises:
    test_lockf_on_what_is_not_open()
    print("test_fcntl: ok")
