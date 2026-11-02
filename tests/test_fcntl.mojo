from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AT_FDCWD, EEXIST
from libc.errno import errno_message, get_errno, set_errno
from libc.sys.stat import Stat, fchmod, fstat
from libc.fcntl import (
    LOCK_EX,
    LOCK_NB,
    LOCK_UN,
    O_APPEND,
    O_CLOEXEC,
    O_CREAT,
    O_EXCL,
    O_RDONLY,
    O_RDWR,
    O_TRUNC,
    O_WRONLY,
    flock,
    lockf,
    open,
    openat,
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


def test_openat_opens_by_way_of_a_directory() raises:
    """`openat` is `open` with the path taken as relative to a
    directory rather than to wherever the process happens to be.
    `AT_FDCWD` means wherever that is, which makes it `open` by
    another name, and is what is given here, a directory to open
    relative to being one more thing that could go wrong.

    The one with a mode is the one that can make a file that is not
    there yet, and is the one asked to make one.
    """
    var here = openat(Int32(AT_FDCWD), string_to_char_ptr("/tmp"), O_RDONLY)
    assert_true(here >= 0, "openat opens what is there")
    _ = close(here)

    var path = string_to_char_ptr("/tmp/mojo_libc_openat")
    var made = openat(Int32(AT_FDCWD), path, O_CREAT | O_WRONLY, 0o644)
    assert_true(made >= 0, "and the one with a mode makes what is not")
    _ = close(made)
    _ = unlink(path)
    path.unsafe_free()


def test_flock_is_taken_on_the_open_file() raises:
    """The lock `flock` takes belongs to the open file and not to the
    process, which is the one part of this that a test can show: two
    descriptors opened separately on the same path are two open files,
    so the second one is refused by the first while `LOCK_NB` keeps it
    from waiting.

    Asking the same descriptor for the same lock twice is the other
    half. It answers 0 and it is not a second lock — it is the one that
    is already there — so a binding that took a new lock every time
    would still answer 0 here and would be caught by the refusal, not by
    this.

    The file is in `/tmp` and removed at the end, and the path is not
    used by anything else, so a run that is cut short cannot leave a
    lock that another run would trip over: the lock goes when the
    descriptor is closed.
    """
    var path = string_to_char_ptr("/tmp/libc-flock-test")
    _ = unlink(path)

    var first = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o644)
    assert_true(first >= 0, "a file to lock, opened")
    var second = open(path, O_RDWR)
    assert_true(second >= 0, "and opened a second time, as a second open of it")

    assert_equal(flock(first, LOCK_EX), 0, "the first open takes the lock")
    assert_equal(
        flock(first, LOCK_EX),
        0,
        "and asking it again is the same lock, not a new one",
    )
    assert_equal(
        flock(second, LOCK_EX | LOCK_NB),
        -1,
        "which the second open cannot take, because it is a different open",
    )
    assert_equal(flock(first, LOCK_UN), 0, "the first gives it up")
    assert_equal(
        flock(second, LOCK_EX | LOCK_NB), 0, "and then the second one takes it"
    )

    assert_equal(close(second), 0, "closed, which is the other way to let go")
    assert_equal(close(first), 0, "both of them")
    assert_equal(unlink(path), 0, "and the file goes with them")

    path.unsafe_free()


def main() raises:
    test_lockf_on_what_is_not_open()
    test_open_with_the_flags()
    test_openat_opens_by_way_of_a_directory()
    test_flock_is_taken_on_the_open_file()
    print("test_fcntl: ok")
