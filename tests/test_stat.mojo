from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import (
    AT_EMPTY_PATH,
    AT_FDCWD,
    AT_SYMLINK_NOFOLLOW,
    c_int,
    c_uint,
)
from libc.fcntl import O_CREAT, O_RDONLY, O_RDWR, O_TRUNC, O_WRONLY, open
from libc.sys.stat import (
    Stat,
    Statx,
    chmod,
    fchmodat,
    fstat,
    fstatat,
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
    statx,
    STATX_ALL,
    STATX_MODE,
    STATX_NLINK,
    STATX_BTIME,
    STATX_MTIME,
    STATX_SIZE,
    umask,
    utimbuf,
    utime,
    utimensat,
    utimes,
    STATX_SLOTS,
    STATX_MASK_OFFSET,
    STATX_BLKSIZE_OFFSET,
    STATX_ATTRIBUTES_OFFSET,
    STATX_NLINK_OFFSET,
    STATX_UID_OFFSET,
    STATX_GID_OFFSET,
    STATX_MODE_OFFSET,
    STATX_INO_OFFSET,
    STATX_SIZE_OFFSET,
    STATX_BLOCKS_OFFSET,
    STATX_ATTRIBUTES_MASK_OFFSET,
    STATX_ATIME_OFFSET,
    STATX_BTIME_OFFSET,
    STATX_CTIME_OFFSET,
    STATX_MTIME_OFFSET,
    STATX_RDEV_MAJOR_OFFSET,
    STATX_RDEV_MINOR_OFFSET,
    STATX_DEV_MAJOR_OFFSET,
    STATX_DEV_MINOR_OFFSET,
    STATX_BYTES,
)
from libc.unistd import (
    access,
    link,
    chown,
    close,
    getegid,
    geteuid,
    getuid,
    getgroups,
    rmdir,
    symlink,
    unlink,
    write,
)
from libc.utils import null_ptr, string_to_char_ptr

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
    # And what it took is gone -- asked with mode 0, which is `F_OK`, the
    # question of whether the thing is there at all. `chdir` takes the same
    # path, answers the same 0, and leaves the directory standing.
    assert_equal(access(a, 0), -1, "and the directory is gone")
    a.unsafe_free()

    var b = string_to_char_ptr("/tmp/libc_mkdir_b")
    _ = rmdir(b)
    assert_equal(mkdirat(AT_FDCWD, b, 0o755), 0, "mkdirat makes one too")
    _ = rmdir(b)
    assert_equal(access(b, 0), -1, "and it is gone the same way")
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
    # This file was made by whoever is running the test, and that is a
    # number nothing here chose -- unlike `/etc/hosts`, whose owner being
    # root means a read that lands on the high bytes of the uid answers
    # zero either way. The user id is the one field where the runner is
    # the independent fact.
    assert_equal(
        Int(st.unsafe_offset(0)[].uid()),
        Int(getuid()),
        "the owner is the one running this",
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

    # The same two, given without a path, but this time on a link: on a plain
    # file `lutimes` and `utimes` are the same call, and a link is the one thing
    # that tells them apart. The file and the link to it are given different
    # times, and each is asked back where it lives -- `stat` follows the link
    # and `lstat` does not.
    var target = string_to_char_ptr("/tmp/libc_times_us_target")
    var link = string_to_char_ptr("/tmp/libc_times_us_link")
    _ = unlink(link)
    var tfd = open(target, O_CREAT | O_RDWR, 0o644)
    assert_true(tfd >= 0, "there is a file for the link to name")
    assert_equal(symlink(target, link), 0, "and a link to it")

    tv.unsafe_offset(0)[].tv_sec = 4000000
    tv.unsafe_offset(1)[].tv_sec = 4000000
    assert_equal(utimes(target, tv), 0, "the file is given one time")
    tv.unsafe_offset(0)[].tv_sec = 4500000
    tv.unsafe_offset(1)[].tv_sec = 4500000
    assert_equal(lutimes(link, tv), 0, "and the link another")
    assert_equal(stat(target, st), 0, "the file is asked after")
    assert_equal(
        st.unsafe_offset(0)[].mtime(),
        4000000,
        "and kept the time it was given rather than the link's",
    )
    assert_equal(lstat(link, st), 0, "the link is asked after in its own right")
    assert_equal(
        st.unsafe_offset(0)[].mtime(), 4500000, "and has the time it was given"
    )

    # And the same question the other way round: `utimes` on the link follows
    # it, so the time lands on the file the link names and the link keeps its
    # own. A binding that did not follow would move the link's time instead,
    # which is the assertion above, and leave the file where it was.
    tv.unsafe_offset(0)[].tv_sec = 4600000
    tv.unsafe_offset(1)[].tv_sec = 4600000
    assert_equal(utimes(link, tv), 0, "utimes on the link follows it")
    assert_equal(stat(target, st), 0, "so the file is asked after")
    assert_equal(
        st.unsafe_offset(0)[].mtime(), 4600000, "and has the newer time"
    )
    assert_equal(lstat(link, st), 0, "and the link is asked after again")
    assert_equal(
        st.unsafe_offset(0)[].mtime(),
        4500000,
        "having kept the time that was set on it",
    )

    _ = close(tfd)
    _ = unlink(link)
    _ = unlink(target)
    link.unsafe_free()
    target.unsafe_free()

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


def test_stat_at_the_working_directory_agrees_with_stat() raises:
    """`fstatat` asks after a file relative to a directory that is
    open, and with `AT_FDCWD` there — which is what says the working
    directory instead — it is `stat`.

    Both are asked after the same file, and what is asked of them is
    that they name the same one: two rows about the same file carry
    the same inode. A call that took the path from the wrong place,
    or read the row into the wrong room, names a different file or
    none at all.

    `/dev/null` is the file asked after, being the one that is on
    every machine and cannot be moved.
    """
    var path = string_to_char_ptr("/dev/null")

    var by_stat = unsafe_alloc[Stat](1)
    assert_equal(stat(path, by_stat), 0, "/dev/null is there, and")

    var by_at = unsafe_alloc[Stat](1)
    assert_equal(
        fstatat(AT_FDCWD, path, by_at, 0), 0, "fstatat asks after it too, and"
    )
    assert_equal(
        by_at.unsafe_offset(0)[].ino(),
        by_stat.unsafe_offset(0)[].ino(),
        "the two of them name the same file",
    )

    path.unsafe_free()
    by_stat.unsafe_free()
    by_at.unsafe_free()


def test_umask_answers_with_what_it_replaced() raises:
    """`umask` is the one call here that answers with what it replaced
    rather than with what it did, and there is no getter: asking what the
    mask is means setting it and putting it back. That is also why this
    test restores the old one before asserting anything else — the mask is
    process-wide, and every file the rest of the suite makes is made under
    it, so a test that left 0o077 behind would change what the others
    create rather than fail.
    """
    var was = umask(0o077)
    assert_equal(umask(0o022), 0o077, "the answer is the mask it replaced")
    assert_equal(umask(was), 0o022, "and asking again answers the last one")


def test_the_access_time_is_read_from_its_own_slot() raises:
    """`utimensat` takes the access time first and the modified one second,
    and the two accessors that read them back are in different slots.

    Every test above hands both slots the same number and asks back
    through `mtime`, which is the right question for what those are
    testing and cannot tell the two accessors apart: with both slots
    holding 2000000, an `atime` that read `mtime`'s bytes answers the
    same number. So the two are given different ones here. `ctime` is
    the third: setting the times is itself a status change, so it has to
    come back as now rather than as either of the two dates, and the
    moment to compare it against is 2020.
    """
    var path = string_to_char_ptr("/tmp/libc_stat_two_times")
    var fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0o644)
    assert_true(fd >= 0, "a file to date")

    var ts = unsafe_alloc[timespec](2)
    ts.unsafe_offset(0)[].tv_sec = 1111111
    ts.unsafe_offset(0)[].tv_nsec = 0
    ts.unsafe_offset(1)[].tv_sec = 2222222
    ts.unsafe_offset(1)[].tv_nsec = 0
    assert_equal(
        utimensat(AT_FDCWD, path, ts, 0), 0, "the two times are set apart"
    )
    ts.unsafe_free()

    var st = unsafe_alloc[Stat](1)
    assert_equal(stat(path, st), 0, "and the file can be asked")
    assert_equal(
        st.unsafe_offset(0)[].atime(), 1111111, "atime is the first of them"
    )
    assert_equal(st.unsafe_offset(0)[].mtime(), 2222222, "mtime is the second")
    assert_true(
        st.unsafe_offset(0)[].ctime() > 1577836800,
        "and ctime is now, not either date",
    )

    st.unsafe_free()
    _ = close(fd)
    _ = unlink(path)
    path.unsafe_free()


def test_the_device_and_group_of_a_file_this_test_made() raises:
    """Four members whose values are known before the file is asked about.

    A regular file has a device and no device number of its own, so `dev`
    is non-zero and `rdev` is exactly zero — an accessor that read the
    other's bytes fails one of the two whichever way round the mistake
    was made, which is not true of any assertion that only says "not
    zero". The group is this process's effective group, since nothing
    else could have set it on a file made a moment ago, and the blocks
    are the sectors the file's own bytes took, which is the size rounded
    up to a block: more than the size, and not a whole block more.
    """
    var path = string_to_char_ptr("/tmp/libc_stat_members")
    var fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0o644)
    assert_true(fd >= 0, "a file to ask about")

    comptime SIZE = 65536
    var buffer = unsafe_alloc[UInt8](SIZE)
    for i in range(SIZE):
        buffer.unsafe_offset(i)[] = UInt8(ord("x"))
    assert_equal(
        Int(write(fd, buffer, UInt32(SIZE))), SIZE, "sixty-four kilobytes of it"
    )
    buffer.unsafe_free()
    _ = close(fd)

    var st = unsafe_alloc[Stat](1)
    assert_equal(stat(path, st), 0, "and the file can be asked")
    assert_equal(st.unsafe_offset(0)[].size(), SIZE, "its size is the bytes")
    assert_true(
        st.unsafe_offset(0)[].dev() != 0, "a file has the device it is on"
    )
    assert_equal(
        st.unsafe_offset(0)[].rdev(), 0, "and no device number of its own"
    )
    # The group on it is the one this process makes files in, and if it is
    # also in a second group the file is moved into that one. The move is
    # what makes the assertion below able to fail: with the owner and the
    # group the same number, an accessor that read the owner's bytes
    # answers the same number, and the test would be asking a question
    # whose two answers agree. `chgrp` to a group this process belongs to
    # needs no privilege, and nothing here names one it does not.
    var chosen = getegid()
    var many = getgroups(0, null_ptr[c_uint]())
    if many > 0:
        var groups = unsafe_alloc[c_uint](Int(many))
        _ = getgroups(many, groups)
        for i in range(Int(many)):
            var gid = Int32(groups.unsafe_offset(i)[])
            if gid != getegid() and gid != geteuid():
                chosen = gid
                break
        groups.unsafe_free()
    if chosen != getegid():
        assert_equal(
            chown(path, Int32(-1), chosen),
            0,
            "the file is moved into the second group",
        )
        assert_equal(stat(path, st), 0, "and asked about again")
    assert_equal(
        Int(st.unsafe_offset(0)[].gid()), Int(chosen), "the group it is in"
    )
    var held = st.unsafe_offset(0)[].blocks() * 512
    assert_true(held >= SIZE, "the blocks it takes hold all of it")
    assert_true(held <= SIZE + 16384, "and not a block more than that")

    st.unsafe_free()
    _ = unlink(path)
    path.unsafe_free()


def main() raises:
    test_mkdir_and_mkdirat()
    test_chmod_and_fchmodat()
    test_lstat_does_not_follow_a_link()
    test_mknod_makes_a_fifo()
    test_the_times()
    test_setting_times_in_microseconds()
    test_stat_at_the_working_directory_agrees_with_stat()
    test_umask_answers_with_what_it_replaced()
    test_the_access_time_is_read_from_its_own_slot()
    test_the_device_and_group_of_a_file_this_test_made()
    test_the_birth_time_is_in_the_wider_row()
    test_asking_for_less_is_asking_by_the_mask()
    test_a_link_asked_by_its_own_name()
    test_two_names_for_one_file_say_so()
    test_the_row_the_wider_answer_reads_is_one_layout()
    print("test_stat: ok")


def test_the_birth_time_is_in_the_wider_row() raises:
    """`statx` and the clock `struct stat` on Linux has no room for:
    the row carries the birth time of the file, which starts when
    the file comes into being and does not move when the file is
    written, renamed or told its permissions again -- and the row
    carries its own mask, which says the birth time it holds is a
    real field and not whatever the buffer was.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_statx_born")
        _ = unlink(path)
        var fd = open(path, O_CREAT | O_WRONLY, 0o644)
        assert_true(fd >= 0, "the file is made")
        assert_equal(
            Int(write(fd, string_to_char_ptr("abc"), 3)),
            3,
            "and holds three bytes",
        )
        _ = close(fd)

        var row = unsafe_alloc[Statx](1)
        assert_equal(
            statx(AT_FDCWD, path, 0, STATX_ALL, row),
            0,
            "statx asks and answers",
        )

        assert_true(
            (
                row.unsafe_offset(0)[].mask()
                & Int64(STATX_SIZE | STATX_BTIME | STATX_MTIME)
            )
            == Int64(STATX_SIZE | STATX_BTIME | STATX_MTIME),
            "the answer's mask stands behind size, birth and modify",
        )
        assert_equal(
            row.unsafe_offset(0)[].size(),
            3,
            "the size is the three bytes the file holds",
        )
        assert_true(
            row.unsafe_offset(0)[].btime() > 0,
            "the birth time is a real clock, not the epoch",
        )
        assert_true(
            row.unsafe_offset(0)[].mtime() >= row.unsafe_offset(0)[].btime(),
            "and the file was not modified before it existed",
        )

        _ = unlink(path)


def test_asking_for_less_is_asking_by_the_mask() raises:
    """`statx` with a mask of two fields: the row comes back with
    those two standing behind it -- the mask is not just a filter
    on the answer but the kernel's instruction to fetch, and the
    caller that wants the size and the birth time is not asking
    the kernel to gather everything else beside.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_statx_masked")
        _ = unlink(path)
        var fd = open(path, O_CREAT | O_WRONLY, 0o644)
        assert_true(fd >= 0, "the file is made")
        assert_equal(
            Int(write(fd, string_to_char_ptr("abcd"), 4)),
            4,
            "and holds four bytes",
        )
        _ = close(fd)

        var row = unsafe_alloc[Statx](1)
        assert_equal(
            statx(AT_FDCWD, path, 0, STATX_SIZE | STATX_BTIME, row),
            0,
            "the asking names size and birth time",
        )
        assert_true(
            (row.unsafe_offset(0)[].mask() & Int64(STATX_SIZE | STATX_BTIME))
            == Int64(STATX_SIZE | STATX_BTIME),
            "and the answer stands behind both",
        )
        assert_equal(
            row.unsafe_offset(0)[].size(), 4, "the size is still the size"
        )

        _ = unlink(path)


def test_a_link_asked_by_its_own_name() raises:
    """`statx` and `AT_SYMLINK_NOFOLLOW`: the link is asked after
    by its own name, and the row says it is a link whose size is
    the length of the path it carries -- which is what a link is,
    a file whose contents are another path. Without the flag the
    same call reads through, and says what the link points at.
    """
    comptime if not CompilationTarget.is_macos():
        var target = string_to_char_ptr("/tmp/libc_statx_target")
        var fd = open(target, O_CREAT | O_WRONLY, 0o644)
        assert_true(fd >= 0, "the target is a real file")
        _ = close(fd)

        var link = string_to_char_ptr("/tmp/libc_statx_link")
        _ = unlink(link)
        assert_equal(symlink(target, link), 0, "and the link points at it")

        var as_link = unsafe_alloc[Statx](1)
        assert_equal(
            statx(
                AT_FDCWD,
                link,
                AT_SYMLINK_NOFOLLOW,
                Int32(STATX_MODE | STATX_SIZE),
                as_link,
            ),
            0,
            "the link is asked after by its own name",
        )
        assert_equal(
            as_link.unsafe_offset(0)[].mode() & S_IFMT,
            S_IFLNK,
            "and the row says it is a link",
        )
        # The path is twenty-two characters, and a link is a file
        # whose contents are those characters.
        assert_equal(
            as_link.unsafe_offset(0)[].size(),
            22,
            "and its size is the length of the path it carries",
        )

        var followed = unsafe_alloc[Statx](1)
        assert_equal(
            statx(AT_FDCWD, link, 0, Int32(STATX_MODE), followed),
            0,
            "without the flag the same call reads through",
        )
        assert_equal(
            followed.unsafe_offset(0)[].mode() & S_IFMT,
            S_IFREG,
            "and says what the link points at",
        )

        _ = unlink(link)
        _ = unlink(target)


def test_two_names_for_one_file_say_so() raises:
    """`statx` and a hard link: a second name is made for the file
    and the row's link count says two -- two names, one file, and
    `AT_EMPTY_PATH` asking through the descriptor answers with the
    same size the path did, which is the same file and not a copy.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_statx_nlink")
        var second = string_to_char_ptr("/tmp/libc_statx_nlink2")
        _ = unlink(path)
        _ = unlink(second)
        var fd = open(path, O_CREAT | O_WRONLY, 0o644)
        assert_true(fd >= 0, "the file is made")
        assert_equal(
            Int(write(fd, string_to_char_ptr("xy"), 2)),
            2,
            "and holds two bytes",
        )
        _ = close(fd)

        assert_equal(link(path, second), 0, "a second name is made for it")

        var row = unsafe_alloc[Statx](1)
        assert_equal(
            statx(AT_FDCWD, path, 0, Int32(STATX_NLINK | STATX_SIZE), row),
            0,
            "the first name is asked",
        )
        assert_equal(
            row.unsafe_offset(0)[].nlink(),
            2,
            "and its count is two: two names, one file",
        )

        var through = unsafe_alloc[Statx](1)
        var fd2 = open(path, O_RDONLY, 0)
        assert_true(fd2 >= 0, "the file is open again")
        assert_equal(  # An empty path, not a null one: the kernel reads the name the
            # pointer carries and only lets the flag say the reading is of
            # the descriptor, and a pointer that carries nothing at all
            # is a fault rather than an empty name.
            statx(
                fd2,
                string_to_char_ptr(""),
                AT_EMPTY_PATH,
                Int32(STATX_SIZE),
                through,
            ),
            0,
            "the descriptor is asked by itself",
        )
        assert_equal(
            through.unsafe_offset(0)[].size(),
            2,
            "and it is the same size the path said",
        )
        _ = close(fd2)

        _ = unlink(path)
        _ = unlink(second)


def test_the_row_the_wider_answer_reads_is_one_layout() raises:
    """The offsets the wider row is read at: the kernel's own table,
    written as numbers and asked as numbers, on both of the
    machines that ask -- a row whose members sit where the table
    says they sit is a row no platform is free to move, and a
    number that moves is a number the asking finds out. The
    bytes are the row's length, the slots the mask's own count
    of what may come back, and the mask the full asking.
    """
    assert_equal(Int(STATX_SLOTS), 32, "the mask has room for thirty-two words")
    assert_equal(
        Int(STATX_MASK_OFFSET), 0, "the mask is the first word of the row"
    )
    assert_equal(Int(STATX_BLKSIZE_OFFSET), 4, "the block size sits beside it")
    assert_equal(
        Int(STATX_ATTRIBUTES_OFFSET), 8, "and the attributes beside that"
    )
    assert_equal(Int(STATX_NLINK_OFFSET), 16, "the link count has its own word")
    assert_equal(Int(STATX_UID_OFFSET), 20, "the owner's number is beside it")
    assert_equal(Int(STATX_GID_OFFSET), 24, "and the group's beside that")
    assert_equal(Int(STATX_MODE_OFFSET), 28, "the mode has its own word")
    assert_equal(Int(STATX_INO_OFFSET), 32, "the number of the file is at 32")
    assert_equal(Int(STATX_SIZE_OFFSET), 40, "the size is at 40")
    assert_equal(Int(STATX_BLOCKS_OFFSET), 48, "the blocks are at 48")
    assert_equal(
        Int(STATX_ATTRIBUTES_MASK_OFFSET), 56, "the attributes' mask is at 56"
    )
    assert_equal(Int(STATX_ATIME_OFFSET), 64, "the read time is at 64")
    assert_equal(Int(STATX_BTIME_OFFSET), 80, "the birth time is at 80")
    assert_equal(Int(STATX_CTIME_OFFSET), 96, "the change time is at 96")
    assert_equal(Int(STATX_MTIME_OFFSET), 112, "the write time is at 112")
    assert_equal(
        Int(STATX_RDEV_MAJOR_OFFSET), 128, "the device's major is at 128"
    )
    assert_equal(Int(STATX_RDEV_MINOR_OFFSET), 132, "and the minor beside it")
    assert_equal(
        Int(STATX_DEV_MAJOR_OFFSET), 136, "the other device's major at 136"
    )
    assert_equal(Int(STATX_DEV_MINOR_OFFSET), 140, "and its minor beside it")
    assert_equal(Int(STATX_BYTES), 256, "and the row is 256 bytes long")
    assert_equal(Int(STATX_ALL), 4095, "the full mask asks for everything")
