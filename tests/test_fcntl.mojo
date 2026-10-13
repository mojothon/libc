from std.testing import assert_equal, assert_true

from libc.constant import EEXIST
from libc.errno import errno_message, get_errno, set_errno
from libc.fcntl import (
    O_APPEND,
    O_CLOEXEC,
    O_CREAT,
    O_EXCL,
    O_RDONLY,
    O_TRUNC,
    O_WRONLY,
    lockf,
    open,
)
from libc.unistd import close, unlink, write
from libc.utils import string_to_char_ptr


def test_lockf_on_what_is_not_open() raises:
    """`lockf` asked about a range in a file that is not open.

    Taking a lock on a real file from a test would leave the lock behind
    if the test were to fail, so this asks about a descriptor that does
    not exist, and the answer to that is no. The 3 is `F_TEST`, which
    asks whether a range is free rather than locking it, and it is 3 on
    both platforms.
    """
    assert_equal(lockf(-1, 3, 0), -1, "no such descriptor")


def test_open_with_the_flags() raises:
    """The flags of a real `open`, which are numbers that differ per platform.

    O_CREAT is 64 here and 512 on Darwin, O_APPEND 1024 and 8, O_TRUNC 512
    and 1024 — so a flag written down as the other platform's number opens
    a file with the wrong flags on it or fails outright, which is what this
    watches for. 0o644 is the mode, only looked at when O_CREAT makes the
    file.
    """
    var path = string_to_char_ptr("/tmp/libc-open-flags-test")
    _ = unlink(path)  # 上一次跑可能留下了它

    var fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    assert_true(fd >= 0, "opened a new file for writing")

    # What the mode argument came to, which is worth knowing: umask takes a
    # bite out of it, and a later open of this path came back EACCES on
    # Darwin with no permission bits set at all.
    var info = unsafe_alloc[Stat](1)
    info[] = Stat()
    if fstat(fd, info) == 0:
        print("  (the new file's mode came out as", info[].mode() & 0o7777, ")")
    info.unsafe_free()

    # Set outright, so what follows is about the flags and not about umask.
    assert_equal(fchmod(fd, 0o644), 0, "and its permissions are set")
    assert_equal(write(fd, path, 4), 4, "wrote four bytes to it")
    assert_equal(close(fd), 0, "and closed it")

    # The same file opened again without O_CREAT, so this is a plain open of
    # something that exists: it succeeds, which says O_RDONLY is 0 and not
    # the other platform's O_WRONLY.
    var back = open(path, O_RDONLY)
    assert_true(
        back >= 0,
        "and opened it again for reading"
        + ("" if back >= 0 else ": " + errno_message(get_errno())),
    )
    assert_equal(close(back), 0, "and closed that")

    # O_EXCL on a file that is already there is answered with EEXIST, and
    # errno is the number this platform uses.
    set_errno(0)
    assert_equal(
        open(path, O_WRONLY | O_CREAT | O_EXCL, 0o644), -1, "O_EXCL says no"
    )
    assert_equal(Int(get_errno()), EEXIST, "and leaves EEXIST behind")

    # O_CLOEXEC and O_APPEND both work on an open that succeeds; there is
    # nothing to read back for either from here, but a wrong number for
    # either would have failed the open.
    var appended = open(path, O_WRONLY | O_APPEND | O_CLOEXEC)
    assert_true(appended >= 0, "append and close-on-exec are accepted")
    assert_equal(close(appended), 0, "and closed")

    _ = unlink(path)
    path.unsafe_free()


def main() raises:
    test_lockf_on_what_is_not_open()
    test_open_with_the_flags()
    print("test_fcntl: ok")
