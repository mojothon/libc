from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import AT_FDCWD
from libc.fcntl import O_CREAT, O_RDWR, O_WRONLY, open
from libc.sys.stat import (
    Stat,
    chmod,
    fchmodat,
    fstat,
    futimens,
    futimes,
    lstat,
    lutimes,
    mkdir,
    mkdirat,
    mknod,
    mknodat,
    stat,
    timespec,
    timeval,
    utimbuf,
    utime,
    utimensat,
    utimes,
)
from libc.unistd import close, rmdir, symlink, unlink
from libc.utils import string_to_char_ptr

# POSIX keeps the file type in the top bits of `st_mode`. Nothing here
# names them, so they are written out: `S_IFMT` is the mask that selects
# the type and the three below are what it can select.
comptime S_IFMT = 0o170000
comptime S_IFREG = 0o100000
comptime S_IFLNK = 0o120000
comptime S_IFIFO = 0o010000


def test_mkdir_and_mkdirat() raises:
    """Neither had been called. `mkdirat` takes a directory descriptor
    first, and `AT_FDCWD` is how a path is said not to be relative to
    one.
    """
    var a = string_to_char_ptr("/tmp/libc_mkdir_a")
    _ = rmdir(a)
    assert_equal(mkdir(a, 0o755), 0, "mkdir makes a directory")
    _ = rmdir(a)
    a.unsafe_free()

    var b = string_to_char_ptr("/tmp/libc_mkdir_b")
    _ = rmdir(b)
    assert_equal(mkdirat(AT_FDCWD, b, 0o755), 0, "mkdirat makes one too")
    _ = rmdir(b)
    b.unsafe_free()


def test_chmod_and_fchmodat() raises:
    """Both take a path and a mode, and `fchmodat` takes a descriptor and
    a path besides. Asking for the mode afterwards is what says the call
    did anything: `chmod` on a path that is not there also answers 0 to
    nobody who checks.
    """
    var path = string_to_char_ptr("/tmp/libc_chmod_me")
    var fd = open(path, O_CREAT | O_WRONLY, 0o644)
    assert_true(fd >= 0, "the file is there to be changed")
    _ = close(fd)

    assert_equal(chmod(path, 0o600), 0, "chmod takes the mode")

    var st = unsafe_alloc[Stat](1)
    assert_equal(stat(path, st), 0, "and the file can be asked about")
    assert_equal(
        st.unsafe_offset(0)[].mode() & 0o777,
        0o600,
        "the mode is the one that was asked for",
    )

    assert_equal(
        fchmodat(AT_FDCWD, path, 0o644, 0), 0, "fchmodat takes a path as well"
    )
    assert_equal(stat(path, st), 0, "asked again")
    assert_equal(
        st.unsafe_offset(0)[].mode() & 0o777, 0o644, "and the mode moved again"
    )

    st.unsafe_free()
    _ = unlink(path)
    path.unsafe_free()


def test_lstat_does_not_follow_a_link() raises:
    """This is the whole of the difference between the two, and it is a
    difference that only shows at a link: pointed at a plain file both
    say the same thing, so a binding calling one for the other would
    have looked right for as long as nobody pointed it at a link.
    """
    var target = string_to_char_ptr("/tmp/libc_link_target")
    var fd = open(target, O_CREAT | O_WRONLY, 0o644)
    assert_true(fd >= 0, "the target is a real file")
    _ = close(fd)

    var link = string_to_char_ptr("/tmp/libc_link_to_it")
    _ = unlink(link)
    assert_equal(symlink(target, link), 0, "and the link points at it")

    var followed = unsafe_alloc[Stat](1)
    var as_link = unsafe_alloc[Stat](1)
    assert_equal(stat(link, followed), 0, "stat reads the link")
    assert_equal(lstat(link, as_link), 0, "and lstat reads it too")

    assert_equal(
        followed.unsafe_offset(0)[].mode() & S_IFMT,
        S_IFREG,
        "stat says what the link points at, an ordinary file",
    )
    assert_equal(
        as_link.unsafe_offset(0)[].mode() & S_IFMT,
        S_IFLNK,
        "lstat says it is a link",
    )

    followed.unsafe_free()
    as_link.unsafe_free()
    _ = unlink(link)
    _ = unlink(target)
    link.unsafe_free()
    target.unsafe_free()


def test_mknod_makes_a_fifo() raises:
    """A fifo is the one thing `mknod` can be asked for here without
    being root. The type goes in the top of the mode, so asking for a
    fifo and being given a file is still a call that answered 0.
    """
    var one = string_to_char_ptr("/tmp/libc_fifo_one")
    _ = unlink(one)
    assert_equal(mknod(one, S_IFIFO | 0o644, 0), 0, "mknod makes a fifo")

    var st = unsafe_alloc[Stat](1)
    assert_equal(stat(one, st), 0, "and it can be asked about")
    assert_equal(
        st.unsafe_offset(0)[].mode() & S_IFMT, S_IFIFO, "it came back a fifo"
    )

    var two = string_to_char_ptr("/tmp/libc_fifo_two")
    _ = unlink(two)
    assert_equal(
        mknodat(AT_FDCWD, two, S_IFIFO | 0o644, 0), 0, "mknodat makes one too"
    )
    assert_equal(stat(two, st), 0, "asked about as well")
    assert_equal(
        st.unsafe_offset(0)[].mode() & S_IFMT, S_IFIFO, "and that one is a fifo"
    )

    st.unsafe_free()
    _ = unlink(one)
    _ = unlink(two)
    one.unsafe_free()
    two.unsafe_free()


def test_the_times() raises:
    """`utime` counts microseconds and `utimensat` nanoseconds, and both
    are handed an array of two, the access time and then the modified
    one; `futimens` takes a descriptor in place of a path. None of the
    three says what it did, so each is asked back through `mtime`.

    The descriptor `futimens` is handed is the one the file was created
    with, held open for the length of the test. It used to be closed and
    a second one opened, which fails on Darwin: `open`'s mode argument
    is variadic and does not arrive on arm64, so a file created with
    `O_CREAT` there carries no read permission — and the macOS runner is
    not root, so reopening it answers EACCES.
    """
    var path = string_to_char_ptr("/tmp/libc_time_me")
    var fd = open(path, O_CREAT | O_RDWR, 0o644)
    assert_true(fd >= 0, "the file is there to be dated")

    var st = unsafe_alloc[Stat](1)

    var tv = unsafe_alloc[utimbuf](1)
    tv.unsafe_offset(0)[].actime = 1000000
    tv.unsafe_offset(0)[].modtime = 1000000
    assert_equal(utime(path, tv), 0, "utime takes the two times, in seconds")
    assert_equal(stat(path, st), 0, "and the file can be asked")
    assert_equal(
        st.unsafe_offset(0)[].mtime(), 1000000, "mtime is the one that was set"
    )
    tv.unsafe_free()

    var ts = unsafe_alloc[timespec](2)
    ts.unsafe_offset(0)[].tv_sec = 2000000
    ts.unsafe_offset(0)[].tv_nsec = 0
    ts.unsafe_offset(1)[].tv_sec = 2000000
    ts.unsafe_offset(1)[].tv_nsec = 0
    assert_equal(
        utimensat(AT_FDCWD, path, ts, 0), 0, "utimensat counts nanoseconds"
    )
    assert_equal(stat(path, st), 0, "asked again")
    assert_equal(st.unsafe_offset(0)[].mtime(), 2000000, "and mtime moved")
    ts.unsafe_free()

    var ts2 = unsafe_alloc[timespec](2)
    ts2.unsafe_offset(0)[].tv_sec = 3000000
    ts2.unsafe_offset(0)[].tv_nsec = 0
    ts2.unsafe_offset(1)[].tv_sec = 3000000
    ts2.unsafe_offset(1)[].tv_nsec = 0
    assert_equal(futimens(fd, ts2), 0, "futimens takes a descriptor")
    assert_equal(fstat(fd, st), 0, "and it can be asked through it")
    assert_equal(st.unsafe_offset(0)[].mtime(), 3000000, "mtime moved again")
    ts2.unsafe_free()
    _ = close(fd)

    st.unsafe_free()
    _ = unlink(path)
    path.unsafe_free()


def test_setting_times_in_microseconds() raises:
    """`utimes`, `lutimes` and `futimes` set the two times on a file,
    counting microseconds where `utime` counts only seconds.

    Each is asked to set a time, and each is asked back through
    `mtime`, which is what says the time was set and not merely that
    the call came back 0. The two times are handed as an array of two,
    the access one first, so the second slot is the one `mtime` reads
    — a call that read only the first would set nothing that `mtime`
    can see.

    `lutimes` is `utimes` that does not follow a link, and `futimes` is
    it taking a descriptor rather than a path. Neither difference
    shows on a plain file, so what is asked of them is that they set
    the time too, and the docstrings say what each is for.

    The descriptor `futimes` is handed is the one the file was made
    with, held open for the length of the test: reopening one on
    Darwin answers EACCES, `open`'s mode being variadic and not
    arriving there.
    """
    var path = string_to_char_ptr("/tmp/libc_times_us")
    var fd = open(path, O_CREAT | O_RDWR, 0o644)
    assert_true(fd >= 0, "the file is there to be dated")

    var st = unsafe_alloc[Stat](1)

    # Two of them: the access time, and then the modified one.
    var tv = unsafe_alloc[timeval](2)
    tv.unsafe_offset(0)[].tv_sec = 3000000
    tv.unsafe_offset(0)[].tv_usec = 0
    tv.unsafe_offset(1)[].tv_sec = 3000000
    tv.unsafe_offset(1)[].tv_usec = 0

    assert_equal(utimes(path, tv), 0, "utimes takes the two times")
    assert_equal(stat(path, st), 0, "and the file can be asked")
    assert_equal(
        st.unsafe_offset(0)[].mtime(), 3000000, "mtime is the one that was set"
    )

    # The same two, given without a path.
    tv.unsafe_offset(0)[].tv_sec = 4000000
    tv.unsafe_offset(1)[].tv_sec = 4000000
    assert_equal(lutimes(path, tv), 0, "lutimes sets them too")
    assert_equal(stat(path, st), 0, "asked again")
    assert_equal(
        st.unsafe_offset(0)[].mtime(), 4000000, "and mtime moved again"
    )

    # And again, by descriptor.
    tv.unsafe_offset(0)[].tv_sec = 5000000
    tv.unsafe_offset(1)[].tv_sec = 5000000
    assert_equal(futimes(fd, tv), 0, "futimes takes a descriptor")
    assert_equal(stat(path, st), 0, "asked a third time")
    assert_equal(
        st.unsafe_offset(0)[].mtime(), 5000000, "and mtime moved a third time"
    )

    tv.unsafe_free()
    st.unsafe_free()
    _ = close(fd)
    _ = unlink(path)
    path.unsafe_free()


def main() raises:
    test_mkdir_and_mkdirat()
    test_chmod_and_fchmodat()
    test_lstat_does_not_follow_a_link()
    test_mknod_makes_a_fifo()
    test_the_times()
    test_setting_times_in_microseconds()
    print("test_stat: ok")
