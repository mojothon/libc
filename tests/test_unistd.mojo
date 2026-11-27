"""Tests for the `libc.unistd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true
from libc.constant import AT_SYMLINK_NOFOLLOW

from libc.fcntl import (
    O_WRONLY,
    FD_CLOEXEC,
    F_GETFD,
    O_CREAT,
    O_NOCTTY,
    O_RDONLY,
    O_DIRECTORY,
    O_RDWR,
    fcntl,
    open as open_with_mode,
)
from libc.constant import (
    AT_EMPTY_PATH,
    c_ulong,
    EPERM,
    UInt32,
    AT_FDCWD,
    ENOMEM,
    EBADF,
    ENOTDIR,
    ENOENT,
    ERANGE,
    c_ptr,
    c_uint,
    SEEK_END,
    SEEK_SET,
    c_void,
)
from libc.signal import SIGALRM, SIGKILL, kill
from libc.string import strcmp
from libc.stdlib import _Exit, exit, grantpt, posix_openpt, ptsname, unlockpt
from libc.time import CLOCK_MONOTONIC, clock_gettime, timespec
from libc.sys.stat import Stat, fchmod, fstat, mkdir, stat
from libc.sys.utsname import Utsname, uname
from libc.sys.io import ioperm, iopl
from libc.sys.wait import WEXITSTATUS, WIFEXITED, WIFSIGNALED, WTERMSIG, waitpid
from libc.time import ITIMER_REAL, getitimer, itimerval, setitimer
from libc.unistd import (
    CS_PATH,
    PC_ASYNC_IO,
    PC_CHOWN_RESTRICTED,
    PC_FILESIZEBITS,
    PC_LINK_MAX,
    PC_MAX_CANON,
    PC_MAX_INPUT,
    PC_NAME_MAX,
    PC_NO_TRUNC,
    PC_PATH_MAX,
    PC_PIPE_BUF,
    PC_PRIO_IO,
    PC_SYMLINK_MAX,
    PC_SYNC_IO,
    PC_VDISABLE,
    SC_CLK_TCK,
    SC_JOB_CONTROL,
    SC_MQ_PRIO_MAX,
    SC_NPROCESSORS_ONLN,
    SC_OPEN_MAX,
    SC_PAGESIZE,
    SYS_getpid,
    access,
    alarm,
    chdir,
    CLOSE_RANGE_CLOEXEC,
    chown,
    confstr,
    close_range,
    closefrom,
    faccessat,
    dup,
    dup2,
    dup3,
    endusershell,
    execv,
    execve,
    execveat,
    fexecve,
    execvpe,
    syncfs,
    setfsgid,
    chroot,
    setfsuid,
    execvp,
    fchdir,
    fchown,
    fchownat,
    fork,
    fpathconf,
    fsync,
    ftruncate,
    getcwd,
    brk,
    getdomainname,
    getdtablesize,
    getegid,
    geteuid,
    getgid,
    getgroups,
    gethostid,
    gethostname,
    sethostname,
    fchownat,
    getlogin,
    getlogin_r,
    getopt,
    getpagesize,
    getpgid,
    getpgrp,
    getpid,
    getppid,
    getsid,
    gettid,
    getuid,
    getusershell,
    getwd,
    isatty,
    lchown,
    link,
    linkat,
    lseek,
    nice,
    pathconf,
    pause,
    pipe,
    pread,
    pwrite,
    read,
    readlink,
    readlinkat,
    readv,
    setegid,
    seteuid,
    setgid,
    setpgid,
    setregid,
    setreuid,
    setsid,
    setuid,
    setusershell,
    sleep,
    swab,
    sync,
    symlink,
    symlinkat,
    syscall,
    sysconf,
    ttyslot,
    tcgetpgrp,
    tcsetpgrp,
    truncate,
    sbrk,
    ttyname,
    ttyname_r,
    ualarm,
    unlink,
    rmdir,
    unlinkat,
    usleep,
    write,
    writev,
    getresgid,
    getresuid,
    setresgid,
    setresuid,
    personality,
    ADDR_NO_RANDOMIZE,
    setdomainname,
)
from libc.constant import c_char, c_ptr
from libc.errno import get_errno, set_errno
from libc.file import close, fclose, fopen, open
from libc.stdio import fwrite, remove
from libc.sys.socket import iovec
from libc.utils import char_ptr_to_string, is_null, null_ptr, string_to_char_ptr


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


def test_gethostname() raises:
    """One name, asked for twice: through `gethostname` and through
    `uname`'s `nodename`, which POSIX says are the same. Neither is
    written down here — a machine is named by whoever set it up, and
    both CI runners are named different things.

    A buffer well over the longest hostname there is, so that the one
    thing the platforms disagree about — what they do when the name
    does not fit — is never reached.
    """
    var room = unsafe_alloc[UInt8](256)
    for i in range(256):
        room.unsafe_offset(i)[] = 0

    assert_equal(Int(gethostname(room, 256)), 0, "the name is asked for")
    var name = char_ptr_to_string(room)
    assert_true(name.byte_length() > 0, "and it is not empty")
    assert_true(name.byte_length() < 256, "and it fits, NUL and all")

    var node = unsafe_alloc[Utsname](1)
    assert_equal(Int(uname(node)), 0, "the kernel says about itself")
    assert_equal(
        name, node[].nodename(), "the same as `uname` says under `nodename`"
    )

    room.unsafe_free()
    node.unsafe_free()


def test_ids() raises:
    """`getgid` and `getegid`, and setting an id to what it already is."""
    assert_true(getgid() >= 0, "the real group id is not negative")
    assert_true(getegid() >= 0, "and neither is the effective one")

    # Handing an effective id the value it already has is the only way to
    # call these from a test without changing what the process may do.
    assert_equal(seteuid(geteuid()), 0, "seteuid to the current euid")
    assert_equal(setegid(getegid()), 0, "setegid to the current egid")


def test_alarm_and_sleep() raises:
    """Both can be asked for nothing, and neither one waits.

    `alarm` answers with the seconds left on the alarm it replaced, and that
    is the one number about it this suite can read: a second's worth is armed
    and taken back in the next breath, so what comes back is that second with
    nothing spent. Asked twice for nothing it says 0 both times, which is
    also what `close` says -- `close` is one line away in the module, takes
    the same `c_uint` and returns the same `c_uint` -- and a binding pointed
    at it is a test that passes while the process is being handed a signal
    instead of an answer.
    """
    assert_equal(alarm(0), 0, "no alarm was set, so none was replaced")
    assert_equal(sleep(0), 0, "and there was nothing to sleep through")

    # And a second is a second: the clock is read either side of it, since
    # `sleep`'s own answer of 0 is what `close` answers too, and `close` is one
    # line away in the module with the same argument and the same answer.
    var before = unsafe_alloc[timespec](1)
    before.unsafe_offset(0)[] = timespec()
    assert_equal(clock_gettime(CLOCK_MONOTONIC, before), 0, "the clock is read")
    assert_equal(sleep(1), 0, "a second is asked for")
    var after = unsafe_alloc[timespec](1)
    after.unsafe_offset(0)[] = timespec()
    assert_equal(clock_gettime(CLOCK_MONOTONIC, after), 0, "and read again")
    var waited = (
        Int(after.unsafe_offset(0)[].tv_sec)
        - Int(before.unsafe_offset(0)[].tv_sec)
    ) * 1000000000 + (
        Int(after.unsafe_offset(0)[].tv_nsec)
        - Int(before.unsafe_offset(0)[].tv_nsec)
    )
    assert_true(waited >= 900000000, "which took about a second to be over")
    before.unsafe_free()
    after.unsafe_free()

    assert_equal(alarm(10), 0, "ten seconds are asked for, and none was there")
    var left = alarm(0)
    # A whole second between the two calls is the only way to lose one, and
    # they are microseconds apart.
    assert_true(
        left == 10 or left == 9,
        "and taking it back says the ten it had left, less what was spent",
    )


def test_nice_and_pagesize() raises:
    # What `nice` answers with is not the same on the two platforms: Linux
    # gives back the niceness it came to and Darwin gives 0 or -1, so all
    # that can be asked of it here is that asking twice says the same thing.
    assert_equal(nice(0), nice(0), "the answer does not depend on the asking")
    assert_true(getpagesize() > 0, "a page is some number of bytes")


def test_chown_on_what_is_not_there() raises:
    """All four say -1 for a file that does not exist, and one file tells the
    pair apart without a privilege.

    Giving a real file to somebody else is not a thing a test should do,
    so this is the part of them a test can safely ask about -- with one
    addition. A link whose target is not there is the file that separates
    `chown` from `lchown`: the first follows it and finds nothing, the
    second changes the link itself, which this process already owns.
    Nothing about that needs an id the test does not have.
    """
    var nowhere = string_to_char_ptr("/nonexistent/libc-test")

    assert_equal(chown(nowhere, getuid(), getgid()), -1)
    assert_equal(lchown(nowhere, getuid(), getgid()), -1)
    assert_equal(fchown(-1, getuid(), getgid()), -1, "no such descriptor")
    # `-1` is refused before the two ids are read, so a swap answers `-1` too.
    # A descriptor that exists is what tells them apart: a file given to the
    # owner it already has is a change to nothing and answers 0, and the swap
    # asks for descriptor 501 or 1000 -- the uid read as a number -- which no
    # process has.
    var owned = string_to_char_ptr("/tmp/libc_fchown")
    _ = unlink(owned)
    var fd = open_with_mode(owned, O_CREAT | O_RDONLY, 0o600)
    assert_true(fd >= 0, "a file was made to be owned")
    assert_equal(
        fchown(fd, getuid(), getgid()), 0, "it is given to the owner it has"
    )
    _ = close(fd)
    _ = unlink(owned)
    assert_equal(fchownat(-1, nowhere, getuid(), getgid(), 0), -1)
    # The `at` call is asked by a descriptor and a relative name, which
    # is what the first argument is for: the file is given to the owner
    # it already has through the directory it stands in, and answers 0.
    # A swap reads the owner as the descriptor -- a number no descriptor
    # is -- and the relative name has nowhere to go, so the ask is
    # refused; a swap reads the flags as the group, and the group the
    # file is given to is not the one it had.
    # A run that failed before its taking-down leaves the folder behind,
    # and the making is refused by what a failed run left -- so the
    # asking starts by clearing what is there, which answers -1 when
    # there is nothing to clear.
    _ = unlink(string_to_char_ptr("/tmp/libc_fchown_dir/libc_fchown"))
    _ = rmdir(string_to_char_ptr("/tmp/libc_fchown_dir"))
    var folder = string_to_char_ptr("/tmp/libc_fchown_dir")
    assert_equal(mkdir(folder, 0o700), 0, "the directory is made")
    var inside = string_to_char_ptr("/tmp/libc_fchown_dir/libc_fchown")
    var fd3 = open_with_mode(inside, O_CREAT | O_RDONLY, 0o600)
    assert_true(fd3 >= 0, "the file to be owned is made inside it")
    _ = close(fd3)
    var dfd = open_with_mode(folder, O_RDONLY, 0)
    assert_true(dfd >= 0, "and the directory is opened for the ask")
    var rel = string_to_char_ptr("libc_fchown")
    assert_equal(
        fchownat(dfd, rel, getuid(), getgid(), 0),
        0,
        "the ask by descriptor and relative name is answered",
    )
    # The group the ask leaves on the file is read back from the file
    # itself -- a directory on one platform takes the group of the
    # place it stands in, so the file is what tells, and a swap that
    # reads the flags as the group gives it a different one.
    var st = unsafe_alloc[Stat](1)
    st.unsafe_offset(0)[] = Stat()
    assert_equal(
        Int(stat(inside, st)), 0, "the file is asked what group it is in"
    )
    assert_equal(
        st.unsafe_offset(0)[].gid(),
        Int(getgid()),
        "and the group the ask leaves is the one the caller is in",
    )
    assert_equal(
        fchownat(getuid(), rel, -1, getgid(), 0),
        -1,
        "and the swap reads the owner as a descriptor that is not",
    )
    assert_equal(close(dfd), 0, "the directory is given back")
    _ = unlink(inside)
    _ = rmdir(folder)
    inside.unsafe_free()
    folder.unsafe_free()
    rel.unsafe_free()
    st.unsafe_free()

    var link = string_to_char_ptr("/tmp/libc_dangling_link")
    _ = unlink(link)
    assert_equal(symlink(nowhere, link), 0, "a name is given to nothing")
    assert_equal(
        chown(link, getuid(), getgid()),
        -1,
        "`chown` follows it and finds nothing",
    )
    assert_equal(get_errno(), ENOENT, "and says which nothing it found")
    assert_equal(
        lchown(link, getuid(), getgid()), 0, "`lchown` changes the link itself"
    )
    _ = unlink(link)

    nowhere.unsafe_free()


def test_pread_and_pwrite_at_an_offset() raises:
    """`pread` and `pwrite` carry an offset that does not fit in a byte.

    The offset used to go to C as one byte, so anything past 255 landed
    somewhere else in the file and came back as whatever was there. This
    reads 300 bytes in, which is past what a byte can say.
    """
    var path = string_to_char_ptr("/tmp/libc-test-at-offset.bin")
    var write = string_to_char_ptr("w+")

    var stream = fopen(path, write)
    assert_true(Int(UInt(stream)) != 0)

    # 300 of one letter and then 300 of another, so where the read lands
    # says which offset it read from.
    var block = unsafe_alloc[c_char](600)
    for i in range(300):
        block.unsafe_offset(i)[] = 97
    for i in range(300):
        block.unsafe_offset(300 + i)[] = 98
    assert_equal(fwrite(block, 1, 600, stream), 600)
    assert_equal(fclose(stream), 0)

    var fd = open(path, O_RDWR)
    assert_true(fd >= 0)

    var got = unsafe_alloc[c_char](9)
    got.unsafe_offset(8)[] = 0
    assert_equal(pread(fd, got, 8, 300), 8, "eight bytes from 300 in")
    assert_equal(char_ptr_to_string(got), "bbbbbbbb")

    var hello = string_to_char_ptr("hello")
    assert_equal(pwrite(fd, hello, 5, 400), 5, "five bytes written at 400")
    assert_equal(pread(fd, got, 5, 400), 5)
    got.unsafe_offset(5)[] = 0
    assert_equal(char_ptr_to_string(got), "hello")

    assert_equal(close(fd), 0)
    assert_equal(remove(path), 0)

    block.unsafe_free()
    got.unsafe_free()
    path.unsafe_free()
    write.unsafe_free()
    hello.unsafe_free()


def test_sysconf() raises:
    """`sysconf` and the page size, which two calls agree on."""
    var page = sysconf(SC_PAGESIZE)
    assert_true(page > 0, "sysconf knows how big a page is")
    assert_equal(
        Int(page), Int(getpagesize()), "and says the same as getpagesize"
    )


def test_sysconf_names_the_knobs_it_answers_for() raises:
    """The `_SC_*` numbers differ on every one of the eighty, so a knob
    asked by the other platform's number is a knob nothing answers for.

    What is checked is that a handful of them answer at all, and that the
    answer is the plausible one for what they are about: a page size, a
    clock rate, and a count of processors. None of them is a number this
    test could have written down, because none of them is the same on the
    two sides.
    """
    set_errno(0)
    var cpus = sysconf(SC_NPROCESSORS_ONLN)
    assert_true(cpus > 0, "there is at least one processor online")
    assert_true(get_errno() == 0, "and the count is an answer, not a failure")

    var ticks = sysconf(SC_CLK_TCK)
    assert_true(ticks > 0, "the clock ticks")

    var open_max = sysconf(SC_OPEN_MAX)
    assert_true(
        open_max > 0 and open_max < 1 << 30,
        "and there is a ceiling on open descriptors",
    )

    # Job control is a feature and not a count: POSIX fixes the answer
    # at 1 when the system has it, which Linux does, and the item beside
    # it in the header answers -1 -- not supported -- so a number read
    # one low is caught rather than believed. Darwin numbers its items
    # its own way, and the same question is asked there only for an
    # answer at all.
    comptime if CompilationTarget.is_linux():
        assert_equal(
            Int(sysconf(SC_JOB_CONTROL)),
            1,
            "and job control is a feature it has",
        )
    else:
        assert_true(
            Int(sysconf(SC_JOB_CONTROL)) >= 0,
            "and job control is asked for and answered",
        )

    # A queue's priorities have a ceiling, and on Linux, which has the
    # queues, the item beside it in the header answers the refusal: a
    # number read one low is caught rather than believed. Darwin has no
    # POSIX message queues to have a ceiling for -- its item answers
    # the refusal, which is a true answer and not a number to press.
    comptime if CompilationTarget.is_linux():
        var priorities = sysconf(SC_MQ_PRIO_MAX)
        assert_true(
            priorities > 0,
            "and a message queue has priorities to choose from",
        )


def test_confstr_answers_for_the_default_path() raises:
    """`confstr` hands back a string rather than a number, and the one
    variable worth asking for is `CS_PATH`: the default search path.

    It is asked twice, the first time with no buffer at all, which is how
    the call is meant to be sized — the answer is how many bytes it needs,
    terminator included, and nothing is written. The second time it is
    given a buffer of exactly that size, and what comes back is the same
    length and a path with a colon in it.
    """
    # NULL and 0: ask only how long the answer is.
    var wanted = confstr(CS_PATH, null_ptr[UInt8](), 0)
    assert_true(
        wanted > 0,
        "confstr says how long the default path is, and it is not empty",
    )

    var buf = unsafe_alloc[UInt8](Int(wanted))
    for i in range(Int(wanted)):
        buf.unsafe_store(i, 0)
    var got = confstr(CS_PATH, buf, wanted)
    assert_equal(got, wanted, "and hands back the same length when asked")
    var path = char_ptr_to_string(buf)
    assert_true(
        path.byte_length() > 0,
        "and the buffer holds something",
    )
    assert_true(
        String(path).find(":") != -1,
        "and it is a search path, so it has a separator in it",
    )
    buf.unsafe_free()


def test_usleep() raises:
    """A sleep that is over before it is noticed."""
    assert_equal(Int(usleep(1000)), 0, "a thousand microseconds pass")


def test_process_groups() raises:
    """Which group and which session this process is in.

    `setsid` is not called here: it would make the test process a session
    leader and leave it there, which is a thing to do to a process on
    purpose and not by the way.
    """
    assert_true(getpgid(0) > 0, "this process is in a process group")
    assert_equal(getpgid(0), getpgrp(), "the group `getpgrp` names, also")
    assert_true(getsid(0) > 0, "and this process is in a session")
    # A child that moves itself into a group of its own keeps the session it
    # was born into, so the two answers come apart there: `getpgid`, the call
    # one signature away, reads the group and would name the child itself.
    var session = getsid(0)
    var grouped = fork()
    if grouped == 0:
        _ = setpgid(0, 0)
        if getsid(0) != session or getsid(0) == getpid():
            _ = exit(8)
        _ = exit(0)
    assert_true(grouped > 0, "there is a child to ask")
    var its_session = unsafe_alloc[Int32](1)
    its_session.unsafe_store(0, 0)
    assert_equal(
        waitpid(grouped, its_session, 0), grouped, "and it is waited for"
    )
    assert_equal(
        Int(WEXITSTATUS(its_session.unsafe_load())),
        0,
        "and the session it kept is not the group it made",
    )
    its_session.unsafe_free()
    # The group this process is in is not its own -- not yet -- and naming it
    # is a move to where it already is, which answers 0. Both numbers are then
    # not 0, which is what lets the two be told apart: handed over swapped, the
    # call names that group as the process to move, and the only process this
    # one may move is itself.
    var me = getpid()
    var group = getpgid(0)
    assert_equal(
        setpgid(me, group), 0, "moving into the group it is already in"
    )

    var moved = setpgid(0, 0)
    assert_true(
        moved == 0 or moved == -1,
        "moving into its own group answers 0, or -1 with a reason in errno",
    )
    # A new group is named after the process that made it, and the session it
    # is in belongs to whoever started it. Both numbers are positive, so a
    # binding asking for the session instead -- one call away in the header --
    # answers something that reads like a group.
    if moved == 0:
        assert_equal(getpgid(0), getpid(), "and it is named after this process")


def test_readv_gathers_what_writev_scattered() raises:
    """Two buffers written as a pair come back as the same pair.

    `writev` was here on its own for a while, which left nothing able to
    read what it writes: this is the round trip, and it is what says the
    pieces of an `iovec` land where C reads them — a member out of place
    shows up as the wrong text in the wrong half, or nothing read at all.
    """
    var ends = unsafe_alloc[Int32](2)
    assert_equal(pipe(ends), 0, "a pipe is made")
    var reader = ends.unsafe_load(0)
    var writer = ends.unsafe_load(1)

    var head = string_to_char_ptr("head")
    var tail = string_to_char_ptr("body")
    var scattered = unsafe_alloc[iovec](2)
    var out0 = iovec(head, UInt64(4))
    var out1 = iovec(tail, UInt64(4))
    scattered.unsafe_offset(0)[] = out0
    scattered.unsafe_offset(1)[] = out1
    assert_equal(
        writev(writer, scattered.unsafe_bitcast[UInt8](), 2),
        8,
        "both buffers went out",
    )

    # Eight bytes each for four-byte reads, zeroed so what is read ends
    # where it should: neither piece gets a NUL of its own.
    var first = unsafe_alloc[UInt8](8)
    var second = unsafe_alloc[UInt8](8)
    for i in range(8):
        first.unsafe_store(i, 0)
        second.unsafe_store(i, 0)

    var gathered = unsafe_alloc[iovec](2)
    var in0 = iovec(first, UInt64(4))
    var in1 = iovec(second, UInt64(4))
    gathered.unsafe_offset(0)[] = in0
    gathered.unsafe_offset(1)[] = in1
    assert_equal(
        readv(reader, gathered.unsafe_bitcast[UInt8](), 2), 8, "and came back"
    )
    assert_equal(char_ptr_to_string(first), "head", "the first piece first")
    assert_equal(char_ptr_to_string(second), "body", "the second piece second")

    head.unsafe_free()
    tail.unsafe_free()
    scattered.unsafe_free()
    gathered.unsafe_free()
    first.unsafe_free()
    second.unsafe_free()
    ends.unsafe_free()
    _ = close(reader)
    _ = close(writer)


def test_descriptors_and_offsets() raises:
    """`dup2` is given the descriptor to copy and then the number to copy
    it onto, and both are one type, so they can change places and nothing
    says a word. `lseek` is given the offset and then where to measure it
    from; `ftruncate` takes a length and the file is that long after.
    """
    var path = string_to_char_ptr("/tmp/libc_unistd_me")
    # Started from nothing, because the file is opened without `O_TRUNC`: a
    # longer file left behind by an interrupted run is still that long after
    # five bytes are written over the front of it, and the first `SEEK_END`
    # below measures what was there rather than what this wrote.
    _ = unlink(path)
    var fd = open_with_mode(path, O_CREAT | O_RDWR, 0o644)
    assert_true(fd >= 0, "the file is there to be written")

    assert_equal(
        write(fd, string_to_char_ptr("hello"), 5), 5, "wrote five bytes"
    )
    assert_equal(lseek(fd, 0, SEEK_END), 5, "lseek measures from the end")
    assert_equal(lseek(fd, 0, SEEK_SET), 0, "and from the start")

    assert_equal(dup2(fd, 10), 10, "dup2 hands back the number it was given")
    assert_equal(lseek(10, 0, SEEK_END), 5, "and that one is the same file")

    assert_equal(fsync(fd), 0, "fsync says it is down on the disk")

    assert_equal(ftruncate(fd, 3), 0, "ftruncate takes a length")
    var st = unsafe_alloc[Stat](1)
    assert_equal(fstat(fd, st), 0, "and the file can be asked about")
    assert_equal(st.unsafe_offset(0)[].size(), 3, "it is three bytes long now")
    st.unsafe_free()

    _ = close(10)
    _ = close(fd)
    _ = unlink(path)
    path.unsafe_free()


def test_truncate_takes_a_path() raises:
    """The same thing as `ftruncate`, asked for by name instead.

    `truncate` takes a path, which means it needs write permission on the
    file — and the mode handed to `open` with `O_CREAT` does not arrive on
    arm64 Darwin, being variadic. So the permissions are set with
    `fchmod`, which is not variadic, before the descriptor is closed and
    the path is used.
    """
    var path = string_to_char_ptr("/tmp/libc_truncate_me")
    var fd = open_with_mode(path, O_CREAT | O_RDWR, 0o644)
    assert_equal(
        write(fd, string_to_char_ptr("abcdef"), 6), 6, "wrote six bytes"
    )
    assert_equal(fchmod(fd, 0o644), 0, "and its permissions are set")
    _ = close(fd)

    assert_equal(truncate(path, 2), 0, "truncate takes a path and a length")
    var st = unsafe_alloc[Stat](1)
    assert_equal(stat(path, st), 0, "and the file can be asked")
    assert_equal(st.unsafe_offset(0)[].size(), 2, "it is two bytes long now")
    st.unsafe_free()
    _ = unlink(path)
    path.unsafe_free()


def test_links() raises:
    """`linkat` gives a file a second name and `symlinkat` gives it a name
    that points at one; `readlink` is what says which of the two a name
    is, and `nlink` is what says the first one was made.
    """
    var path = string_to_char_ptr("/tmp/libc_linked")
    var fd = open_with_mode(path, O_CREAT | O_RDWR, 0o644)
    _ = close(fd)

    var hard = string_to_char_ptr("/tmp/libc_hard_name")
    _ = unlink(hard)
    assert_equal(
        linkat(AT_FDCWD, path, AT_FDCWD, hard, 0),
        0,
        "linkat makes a second name for it",
    )

    var soft = string_to_char_ptr("/tmp/libc_soft_name")
    _ = unlink(soft)
    assert_equal(
        symlinkat(path, AT_FDCWD, soft), 0, "symlinkat makes a name that points"
    )

    var buf = unsafe_alloc[UInt8](64)
    for i in range(64):
        buf.unsafe_store(i, 0)
    assert_equal(readlink(soft, buf, 64), 16, "readlink reads where it points")
    assert_equal(
        char_ptr_to_string(buf), "/tmp/libc_linked", "and that is the file"
    )

    var again = unsafe_alloc[UInt8](64)
    for i in range(64):
        again.unsafe_store(i, 0)
    assert_equal(
        readlinkat(AT_FDCWD, soft, again, 64), 16, "readlinkat reads it too"
    )
    assert_equal(
        char_ptr_to_string(again), "/tmp/libc_linked", "and says the same thing"
    )

    var st = unsafe_alloc[Stat](1)
    assert_equal(stat(path, st), 0, "the file can be asked")
    assert_equal(st.unsafe_offset(0)[].nlink(), 2, "and it has two names")
    st.unsafe_free()

    assert_equal(unlinkat(AT_FDCWD, hard, 0), 0, "unlinkat takes one away")
    buf.unsafe_free()
    again.unsafe_free()
    _ = unlink(soft)
    _ = unlink(path)
    path.unsafe_free()
    hard.unsafe_free()
    soft.unsafe_free()


def test_chdir_and_fchdir() raises:
    """Both move the whole process, so this goes to `/tmp` and comes back
    to where it started.
    """
    var start = unsafe_alloc[UInt8](256)
    assert_true(Int(UInt(getcwd(start, 256))) != 0, "where it began is known")

    var tmp = string_to_char_ptr("/tmp")
    assert_equal(chdir(tmp), 0, "chdir takes a path")

    # The root rather than the directory the process is already standing in:
    # from `/tmp` a descriptor on `/tmp` would move nothing, and `close` -- the
    # call one line away, taking the same descriptor and answering the same 0
    # -- would look exactly like a move.
    var fd = open(string_to_char_ptr("/"), O_RDONLY)
    assert_true(fd >= 0, "the directory opens")
    assert_equal(fchdir(fd), 0, "fchdir takes a descriptor")
    # And it is a move rather than an answer: where the process is now is
    # `/tmp`, which is asked of it. `close` takes the same descriptor and
    # answers the same 0 and moves nothing.
    var now_here = unsafe_alloc[UInt8](256)
    now_here.unsafe_store(0, 0)
    assert_true(
        Int(UInt(getcwd(now_here, 256))) != 0, "where it is now is known"
    )
    assert_equal(
        char_ptr_to_string(now_here),
        "/",
        "and it is where the descriptor was",
    )
    now_here.unsafe_free()
    _ = close(fd)

    assert_equal(chdir(start), 0, "and it comes back")
    start.unsafe_free()
    tmp.unsafe_free()


def test_the_ids_and_the_terminal() raises:
    assert_true(getppid() > 0, "there is a parent process")
    comptime if not CompilationTarget.is_macos():
        # The main thread of a process has that process's own number, and
        # `fork` -- the call one line away with the same answer of a positive
        # number -- would have made a process instead of answering.
        assert_equal(
            Int(gettid()), Int(getpid()), "and it is this process's own"
        )

    # A child knows which process its parent is, and "a positive number" is
    # not that: `fork` itself answers with one of those here. The only
    # witness is a child comparing what it is told with who told it.
    var parent = getpid()
    var child = fork()
    if child == 0:
        if getppid() != parent:
            _ = exit(8)
        _ = exit(0)
    assert_true(child > 0, "there is a child to ask")
    var by_whom = unsafe_alloc[Int32](1)
    by_whom.unsafe_store(0, 0)
    assert_equal(waitpid(child, by_whom, 0), child, "and it is waited for")
    assert_equal(
        Int(WEXITSTATUS(by_whom.unsafe_load())),
        0,
        "and the child named the process that forked it",
    )
    by_whom.unsafe_free()

    # Not standard input, which is a terminal when somebody is watching
    # and not when they are not: `/dev/null` is never one.
    var nothing = string_to_char_ptr("/dev/null")
    var fd = open(nothing, O_RDONLY)
    assert_true(fd >= 0, "/dev/null opens")
    assert_equal(isatty(fd), 0, "and it is not a terminal")
    assert_true(is_null(ttyname(fd)), "so it has no name to give back")
    var name = unsafe_alloc[UInt8](256)
    assert_true(
        ttyname_r(fd, name, 256) != 0,
        "and ttyname_r answers with the error number itself, not with -1",
    )
    name.unsafe_free()
    _ = close(fd)
    nothing.unsafe_free()


def test_fpathconf() raises:
    """`fpathconf` is asked about a pipe, which is the one thing both
    platforms answer the same way for.

    `_PC_PIPE_BUF` is the largest write a pipe will do in one piece, and
    a pipe is the one kind of file descriptor where the answer is not
    left to the filesystem: XNU answers `PIPE_BUF` for a pipe without
    consulting anything else, and glibc's answer is a constant too. The
    two differ — 512 on Darwin, 4096 on Linux — so what is asserted is
    that the call answers at all, and that the value is a plausible
    block size.

    Asking a directory for `_PC_LINK_MAX` used to stand in for this, and
    Darwin answers -1 for it: the man page allows an implementation to
    have no limit for a variable it is asked about and to say so with -1
    and `errno` untouched.
    """
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "there is a pipe to ask about")
    var asked = fpathconf(fds.unsafe_offset(0)[], PC_PIPE_BUF)
    assert_true(
        asked > 0 and asked <= 1 << 20,
        "a pipe has a block size, and it is a sane one",
    )
    _ = close(fds.unsafe_offset(0)[])
    _ = close(fds.unsafe_offset(1)[])
    fds.unsafe_free()


def test_pathconf_agrees_with_fpathconf() raises:
    """`pathconf` asks of a path what `fpathconf` asks of a descriptor,
    and the two have to answer the same for the same file.

    The knob is named rather than written down, for the reason the
    `_PC_*` constants were bound: `PC_PIPE_BUF` is 5 on Linux and 6 on
    Darwin, so a number written into this test would have answered -1
    with `EINVAL` on one of them.
    """
    var path = string_to_char_ptr("/tmp")
    var fd = open(path, O_RDONLY)
    assert_true(fd >= 0, "/tmp opens")

    var by_fd = fpathconf(fd, PC_PIPE_BUF)
    var by_path = pathconf(path, PC_PIPE_BUF)
    assert_equal(by_path, by_fd, "and the path answers what the descriptor did")
    assert_true(by_path > 0, "with a block size, not a refusal")

    _ = close(fd)
    path.unsafe_free()


def test_the_pc_knobs_are_the_platforms_own_numbers() raises:
    """The `_PC_*` numbers are not the same on both sides, and a binding
    that hardcoded Linux's would answer EINVAL on Darwin for every one of
    them. What is checked here is the part that can be checked without a
    call: that the POSIX nine sit in order and one apart, which is what
    makes them safe to name in a test.
    """
    # glibc numbers from 0 and XNU from 1, so every one of the nine POSIX
    # knobs is one along on Darwin.
    assert_equal(
        Int(PC_LINK_MAX),
        1 if CompilationTarget.is_macos() else 0,
        "PC_LINK_MAX is the first of the knobs",
    )
    assert_equal(
        Int(PC_MAX_CANON - PC_LINK_MAX),
        1,
        "and the next one follows straight after it",
    )
    assert_equal(
        Int(PC_VDISABLE - PC_LINK_MAX),
        8,
        "and there are nine of them in a row",
    )


def test_getopt() raises:
    """`getopt` takes the count, then the arguments, then the letters it
    is to look for, and answers with the letter it found.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](3)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("-a")
    argv.unsafe_offset(2)[] = null_ptr[UInt8]()
    assert_equal(
        getopt(2, argv, string_to_char_ptr("a")),
        Int32(ord("a")),
        "getopt finds the option it was asked about",
    )
    argv.unsafe_free()


def test_dup3() raises:
    """`dup3` is `dup2` with the flags decided at the same time, so the
    new descriptor comes back already as asked rather than being told
    afterwards with `fcntl`.

    The number it is asked to use is one this test had and had let go,
    so nothing that was already open is closed to make room for it.
    """
    comptime if not CompilationTarget.is_macos():
        var ends = unsafe_alloc[Int32](2)
        assert_equal(pipe(ends), 0, "a pipe to copy the reading end of")

        var spare = unsafe_alloc[Int32](2)
        assert_equal(pipe(spare), 0, "and another only for the number")
        var number = spare.unsafe_load(0)
        _ = close(number)
        _ = close(spare.unsafe_load(1))
        spare.unsafe_free()

        var copy = dup3(ends.unsafe_load(0), number, 0)
        assert_equal(
            copy, number, "dup3 hands back the number it was asked for"
        )

        var going = unsafe_alloc[UInt8](1)
        going.unsafe_offset(0)[] = 0x7E
        assert_equal(
            write(ends.unsafe_load(1), going, 1), 1, "a byte goes into the pipe"
        )

        var coming = unsafe_alloc[UInt8](1)
        assert_equal(
            read(copy, coming, 1), 1, "and it comes back out of the copy"
        )
        assert_equal(Int(coming.unsafe_load()), 0x7E, "and it is the same byte")

        going.unsafe_free()
        coming.unsafe_free()
        ends.unsafe_free()
        _ = close(copy)
        _ = close(ends.unsafe_load(0))
        _ = close(ends.unsafe_load(1))


def test_syscall_by_number() raises:
    """`syscall` is a call by number, for the ones the C library has
    no name of its own for. `SYS_getpid` is the number of one it
    does have a name for, which is what makes it possible to check:
    what comes back has to be this process, the same as `getpid`
    says.

    It is the only shape of `syscall` there is here, the binding
    taking the number alone and no arguments after it.
    """
    assert_equal(
        Int(syscall(SYS_getpid)),
        Int(getpid()),
        "syscall by number says the same as getpid does",
    )


def test_the_exec_family_refuses_what_is_not_there() raises:
    """`execv`, `execve` and `execvp` replace the process with
    another program, and only come back if they could not, which
    makes a program that is not there the one thing they can safely
    be given.

    `execvp` is the one that goes and looks for the name rather
    than being told a path, so it is given a bare name, that being
    the shape it is for.
    """
    var name = string_to_char_ptr("mojo-libc-no-such-program")
    var argv = unsafe_alloc[c_ptr[UInt8]](2)
    argv.unsafe_offset(0)[] = name
    argv.unsafe_offset(1)[] = null_ptr[UInt8]()

    assert_equal(
        execv(name, argv), -1, "execv comes back when there is no such program"
    )

    var envp = unsafe_alloc[c_ptr[UInt8]](1)
    envp.unsafe_offset(0)[] = null_ptr[UInt8]()
    assert_equal(execve(name, argv, envp), -1, "and so does execve")

    assert_equal(
        execvp(name, argv), -1, "and execvp, which looks rather than is told"
    )

    envp.unsafe_free()
    argv.unsafe_free()
    name.unsafe_free()

    # The bare name of a program that is on the path, which is the one shape
    # that tells `execv` from `execvp`: one is told a path and refuses a name
    # with no slash in it, and the other goes and looks. Both are asked in a
    # child, because the one that succeeds does not come back.
    var shell = string_to_char_ptr("sh")
    var args = unsafe_alloc[c_ptr[UInt8]](4)
    args.unsafe_offset(0)[] = shell
    args.unsafe_offset(1)[] = string_to_char_ptr("-c")
    args.unsafe_offset(2)[] = string_to_char_ptr("exit 7")
    args.unsafe_offset(3)[] = null_ptr[UInt8]()

    var child = fork()
    if child == 0:
        _ = execv(shell, args)
        # It came back, which is the answer under test: `execv` was handed a
        # name rather than a path.
        _ = exit(3)
    assert_true(child > 0, "there is a child for `execv` to be tried in")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_store(0, 0)
    assert_equal(waitpid(child, status, 0), child, "and it is waited for")
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        3,
        "execv refuses a name with no path in it",
    )
    status.unsafe_free()

    var second = fork()
    if second == 0:
        _ = execvp(shell, args)
        _ = exit(3)
    assert_true(second > 0, "and one for `execvp`")
    var second_status = unsafe_alloc[Int32](1)
    second_status.unsafe_store(0, 0)
    assert_equal(
        waitpid(second, second_status, 0), second, "which is waited for"
    )
    assert_equal(
        Int(WEXITSTATUS(second_status.unsafe_load())),
        7,
        "execvp goes and looks, and the shell runs",
    )
    second_status.unsafe_free()
    args.unsafe_free()
    shell.unsafe_free()


def test_execve_hands_over_the_arguments_and_the_environment() raises:
    """A program that runs is the only way to see which list went where.

    `execve` is only ever watched failing above, and a program that is not
    there fails the same way whichever list is in which slot. So this one
    runs: `/bin/echo` prints the arguments it is given, and the environment
    it is handed has a single entry that is not an argument. Swapping the two
    makes the output that entry instead, or nothing at all.
    """
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "a pipe to read the program through")

    var child = fork()
    assert_true(child >= 0, "a child to become the program")
    if child == 0:
        _ = dup2(fds.unsafe_load(1), 1)
        _ = close(fds.unsafe_load(0))
        _ = close(fds.unsafe_load(1))

        var program = string_to_char_ptr("/bin/echo")
        var argv = unsafe_alloc[c_ptr[UInt8]](3)
        argv.unsafe_offset(0)[] = string_to_char_ptr("echo")
        argv.unsafe_offset(1)[] = string_to_char_ptr("from-the-arguments")
        argv.unsafe_offset(2)[] = null_ptr[UInt8]()
        var envp = unsafe_alloc[c_ptr[UInt8]](2)
        envp.unsafe_offset(0)[] = string_to_char_ptr(
            "MARK=from-the-environment"
        )
        envp.unsafe_offset(1)[] = null_ptr[UInt8]()
        _ = execve(program, argv, envp)
        _ = _Exit(127)
    _ = close(fds.unsafe_load(1))

    var status = unsafe_alloc[Int32](1)
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    var said = unsafe_alloc[UInt8](64)
    for i in range(64):
        said.unsafe_offset(i)[] = 0
    var got = read(fds.unsafe_load(0), said, 63)
    _ = close(fds.unsafe_load(0))
    assert_true(got > 0, "the program said something")
    assert_equal(
        char_ptr_to_string(said),
        "from-the-arguments\n",
        "and it is the argument list, not the environment",
    )

    said.unsafe_free()
    status.unsafe_free()
    fds.unsafe_free()


def test_setuid_and_setgid_asked_for_what_we_already_are() raises:
    """`setuid` and `setgid` change who the process is, which an
    ordinary process may only do to someone it already is. Asked
    for the id it has, each answers 0 and nothing has changed.

    Asked for root, an ordinary process is refused — that being the
    one answer that can be counted on only when it is not root
    already, which is why it is asked conditionally.
    """
    assert_equal(setuid(getuid()), 0, "setuid asked for the id we already have")
    assert_equal(setgid(getgid()), 0, "and setgid asked for the one it has")

    if geteuid() != 0:
        assert_equal(setuid(0), -1, "and an ordinary process is refused root")


def test_setreuid_and_setregid_name_both_ids_at_once() raises:
    """`setreuid` and `setregid` take the two ids in one call, and -1 is
    how one of them is left alone.

    Asked for the pair the process already has, each answers 0 and
    neither id has moved; asked for -1 twice, the same. What cannot be
    asked is the swap, which an ordinary process is allowed and a
    privileged one is not, so the test stays on the pair it has.
    """
    var uid = getuid()
    var euid = geteuid()
    assert_equal(setreuid(uid, euid), 0, "setreuid asked for the pair we have")
    assert_equal(getuid(), uid, "and the real id is the one it was")
    assert_equal(geteuid(), euid, "and so is the effective one")
    assert_equal(setreuid(-1, -1), 0, "and asked for neither, it sets neither")
    assert_equal(getuid(), uid, "which leaves the real one alone")
    assert_equal(geteuid(), euid, "and the effective one too")

    var gid = getgid()
    var egid = getegid()
    assert_equal(setregid(gid, egid), 0, "setregid asked for the pair we have")
    assert_equal(getgid(), gid, "and the real group id is the one it was")
    assert_equal(getegid(), egid, "and so is the effective one")
    assert_equal(setregid(-1, -1), 0, "and asked for neither, it sets neither")


def test_asking_after_the_machine_and_the_process() raises:
    """`getdtablesize` says how many descriptors may be open at once,
    `getdomainname` the name of the NIS domain this machine is in,
    `getgroups` which groups besides its own this process is in,
    `gethostid` the number this machine is known by, `getpgrp` which
    process group this one is in, and `getwd` the directory it is in.

    Each is asked a thing that holds on both platforms, and none is
    held to what the answer is. What a machine is called, what number
    it is known by, which groups a process is in and where it is
    standing are all for the machine to say; holding the two platforms
    to agreeing on any of them would be asking for something they
    need not agree on.

    What each is held to instead is the shape of its answer. A number
    of descriptors is more than none. A domain name is written, and
    may be nothing at all. `getgroups` asked with no room says how
    many there are and writes nothing, and asked again with that much
    room says the same number and writes them. A process group is
    never 0, being numbered for the process that leads it. And `getwd`
    hands back the buffer it was given, with a path in it.
    """
    assert_true(
        getdtablesize() > 0, "there is room for some descriptors, however few"
    )

    var domain = unsafe_alloc[UInt8](256)
    assert_equal(
        getdomainname(domain, 256), 0, "the domain name is written, and"
    )
    comptime if CompilationTarget.is_macos():
        # Not what it says: a machine with no domain is one with none, and
        # Darwin's `utsname` stops at `machine`, so there is no second way to
        # ask. All that is asked is that a name fits the room it was given.
        assert_true(
            char_ptr_to_string(domain).byte_length() < 256,
            "what is written fits the room it was given",
        )
    else:
        # glibc keeps the same name in `utsname`, so the two are asked to
        # agree. Without that, all this test said about `getdomainname` was
        # that it wrote fewer than 256 bytes, which `gethostname` -- same
        # signature, same buffer, next line in the module -- also says.
        var node = unsafe_alloc[Utsname](1)
        assert_equal(uname(node), 0, "uname answers on this platform, and")
        assert_equal(
            char_ptr_to_string(domain),
            node[].domainname(),
            "the name `uname` carries under `domainname`",
        )
        node.unsafe_free()
    domain.unsafe_free()

    # Asked with no room, it says how many there are.
    var howmany = getgroups(0, null_ptr[c_uint]())
    assert_true(howmany >= 0, "getgroups says how many groups there are")
    if howmany > 0:
        var list = unsafe_alloc[c_uint](Int(howmany))
        assert_equal(
            getgroups(howmany, list),
            howmany,
            "and asked again with room for them, it says the same",
        )
        list.unsafe_free()

    # Asked twice, it says the same thing: it is this machine's number
    # and not a happening.
    assert_equal(
        gethostid(), gethostid(), "gethostid says the same number twice"
    )

    assert_true(
        getpgrp() > 0, "a process group is numbered for the process leading it"
    )

    var wd = unsafe_alloc[UInt8](4096)
    var handed_back = getwd(wd)
    assert_true(
        Int(UInt(handed_back)) == Int(UInt(wd)),
        "getwd hands back the room it was given",
    )
    assert_true(
        char_ptr_to_string(wd).byte_length() > 0, "and there is a path in it"
    )
    wd.unsafe_free()


def test_walking_the_shells_a_user_may_have() raises:
    """`setusershell`, `getusershell` and `endusershell` walk the list
    of shells a user may have, the first putting the walk back at its
    beginning and the last shutting it.

    The walk is one walk, and its place is kept between calls, so the
    three are asked in that order: put back at the beginning, asked
    for the first, then shut. What comes back points into storage the
    library keeps, so it is read before the next call and not held.

    Which shells are on the list is the machine's own to say, so it is
    not held to any particular one — only to there being a first one,
    and to its being a path rather than nothing.
    """
    setusershell()
    var first = getusershell()
    assert_true(
        Int(UInt(first)) != 0, "there is a first shell on the list, and"
    )
    assert_true(
        char_ptr_to_string(first).byte_length() > 0,
        "it is a path and not nothing",
    )
    # A path, and this is what says so: `getlogin` hands back a name instead,
    # being the call next to it in the module with the same answer of a
    # pointer, and the name of somebody on the machine does not begin at the
    # root.
    assert_true(
        char_ptr_to_string(first).startswith("/"),
        "and it begins at the root, which is where a path begins",
    )
    endusershell()


def test_ualarm_is_the_timer_that_getitimer_reads() raises:
    """`ualarm` is `ITIMER_REAL` in microseconds, so the two bindings can
    check each other: one sets the timer and the other is asked what it
    says.

    The reading is the half worth having. `ualarm` answers with what was
    left of the timer it replaced rather than with what it was given, so
    a call that did nothing and a call that worked both answer 0 the
    first time — it is the countdown that `getitimer` reports afterwards
    that says the microseconds arrived somewhere.

    Nine hundred and ninety-nine thousandths of a second, and taken back
    before it can run out: a `SIGALRM` left pending ends the process, and
    it would do it in whatever ran next rather than here.

    Under a second on purpose. glibc passes the microseconds straight to
    `setitimer`'s `tv_usec`, which will not take a million or more, so a
    timer of a second or longer is `EINVAL` there and a timer of a second
    or longer on Darwin; the only count that means the same thing on both
    is one below a million, and a test that used ten seconds would be
    testing the platform.
    """
    var nothing = unsafe_alloc[itimerval](1)
    nothing.unsafe_offset(0)[] = itimerval()
    assert_equal(
        setitimer(ITIMER_REAL, nothing, null_ptr[itimerval]()),
        0,
        "no timer is pending to begin with",
    )

    comptime ASKED_FOR: UInt32 = 999_000
    assert_equal(
        ualarm(ASKED_FOR, 0),
        0,
        "so the microseconds that come back are the none that were left",
    )

    var current = unsafe_alloc[itimerval](1)
    current.unsafe_offset(0)[] = itimerval()
    assert_equal(
        getitimer(ITIMER_REAL, current), 0, "and the timer it set is read"
    )
    assert_equal(
        current.unsafe_offset(0)[].it_value_sec,
        0,
        "as a countdown of no seconds at all",
    )
    assert_true(
        current.unsafe_offset(0)[].it_value_usec > 990_000
        and current.unsafe_offset(0)[].it_value_usec <= Int64(ASKED_FOR),
        "but of the microseconds it was given, in their own slot",
    )
    assert_equal(
        current.unsafe_offset(0)[].it_interval_sec,
        0,
        "with nothing to repeat, because the interval was nothing",
    )
    assert_equal(
        current.unsafe_offset(0)[].it_interval_usec,
        0,
        "microseconds and all",
    )

    var left = ualarm(0, 0)
    assert_true(
        left > 990_000 and left <= ASKED_FOR,
        "and taking it back answers with the microseconds that were left",
    )

    assert_equal(
        getitimer(ITIMER_REAL, current), 0, "and nothing is pending after"
    )
    assert_equal(current.unsafe_offset(0)[].it_value_sec, 0, "no seconds left")
    assert_equal(
        current.unsafe_offset(0)[].it_value_usec, 0, "and no microseconds"
    )

    nothing.unsafe_free()
    current.unsafe_free()


def test_access_dup_and_link() raises:
    """The three whose suffix a test had been standing on: `linkat` was
    asked and `link` was not, `dup2` and `dup3` were asked and `dup` was
    not, and `access` was called by nothing at all.

    `access` is the awkward one, because its modes are numbers this package
    does not name: `F_OK` is 0 and asks only whether the path is there,
    which is what a caller usually means and what the shell's `test -e` is.
    """
    var path = string_to_char_ptr("/tmp/libc_access_me")
    var fd = open_with_mode(path, O_CREAT | O_RDWR, 0o644)
    assert_true(fd >= 0, "the file is there")

    assert_equal(access(path, 0), 0, "F_OK finds what exists")

    var missing = string_to_char_ptr("/tmp/libc_not_there_at_all")
    _ = unlink(missing)
    assert_equal(access(missing, 0), -1, "and does not find what does not")
    missing.unsafe_free()

    # `dup` takes nothing but a descriptor, and what it hands back is a
    # second name for the same open file rather than a copy of it. `fstat`
    # says so by agreeing about the inode, which two opens of one path would
    # also do — the difference is that this one shares the offset.
    var copy = dup(fd)
    assert_true(copy >= 0, "dup answers a descriptor")
    assert_true(copy != fd, "and not the one it was handed")

    var original = unsafe_alloc[Stat](1)
    var second = unsafe_alloc[Stat](1)
    assert_equal(fstat(fd, original), 0, "the descriptor can be asked about")
    assert_equal(fstat(copy, second), 0, "and so can the second name")
    assert_equal(
        second.unsafe_offset(0)[].ino(),
        original.unsafe_offset(0)[].ino(),
        "both name one inode",
    )
    original.unsafe_free()
    second.unsafe_free()
    _ = close(copy)

    var hard = string_to_char_ptr("/tmp/libc_link_name")
    _ = unlink(hard)
    assert_equal(link(path, hard), 0, "link gives the file a second name")
    # `symlink`, the call one signature away, would have made a name that
    # points at the file instead of one that is it: the inode's link count
    # is what says which of the two happened.
    var counted = unsafe_alloc[Stat](1)
    assert_equal(stat(path, counted), 0, "the file can be asked")
    assert_equal(
        counted.unsafe_offset(0)[].nlink(), 2, "a second name is a second link"
    )
    counted.unsafe_free()
    assert_equal(access(hard, 0), 0, "which is a path like any other")
    _ = unlink(hard)
    assert_equal(access(hard, 0), -1, "and unlinking it takes it away")

    hard.unsafe_free()
    _ = close(fd)
    _ = unlink(path)
    path.unsafe_free()


def test_the_foreground_group_of_a_terminal() raises:
    """A terminal has one process group in the foreground of it, and
    these two calls are how that group is read and how it is set.

    Which group it is cannot be asked of the terminal this process is
    on, there being none: run from CI, standard input is a pipe, and run
    from a shell it would be answering about the terminal the shell is
    on. So the whole of it happens in a child that makes a terminal of
    its own -- it takes a session of its own, and a session leader with
    no terminal takes the first one it opens -- and the numbers it finds
    are handed back down a pipe rather than asserted where they are
    found, so that a wrong one is reported by the test that asked for it
    and not lost in a child's own output.

    Two of the numbers are the same group seen twice: the child's own,
    which a session leader's is its pid, and what the terminal says once
    it has taken it. The third is a different group on purpose -- a
    grandchild put into a group of its own -- because setting a terminal
    to the group it already names would pass whether or not anything was
    written down. That is the whole difference between this test and one
    that only checks that the call returned 0.

    The group that is refused is one in no session at all, which is a
    pid that cannot be there rather than a pid that was looked for. What
    is checked of it is that the answer is -1 and that the terminal
    still names the group it named before: a call that fails having
    changed nothing is the other half of one that succeeds having
    changed something.
    """
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "there is a pipe to report down")
    var read_fd = fds.unsafe_offset(0)[]
    var report_fd = fds.unsafe_offset(1)[]

    # Every number the child goes to find has a place of its own, so
    # that one it never reached is a number and not a guess. -9 is not
    # the id of anything.
    var found = unsafe_alloc[Int32](8)
    for slot in range(8):
        found.unsafe_offset(slot)[] = -9

    var child = fork()
    if child == 0:
        found.unsafe_offset(0)[] = setsid()
        # `O_NOCTTY` is asked for on the master and not on the far end:
        # the master is not a terminal this session can take in any
        # case, and taking the far end is exactly what is wanted here.
        var master = posix_openpt(O_RDWR | O_NOCTTY)
        if master >= 0:
            _ = grantpt(master)
            _ = unlockpt(master)
            var name = char_ptr_to_string(ptsname(master))
            var path = string_to_char_ptr(name)
            var slave = open(path, O_RDWR)
            path.unsafe_free()
            if slave >= 0:
                found.unsafe_offset(1)[] = getpgrp()
                found.unsafe_offset(2)[] = tcgetpgrp(slave)

                found.unsafe_offset(3)[] = tcsetpgrp(slave, getpgrp() + 1000000)
                found.unsafe_offset(4)[] = tcgetpgrp(slave)

                var grandchild = fork()
                if grandchild == 0:
                    # Nothing to do but stay in its group. It is let go
                    # of after the terminal has named it, and the pipe
                    # never carries a byte, so this reads forever.
                    var held = unsafe_alloc[UInt8](1)
                    _ = read(read_fd, held.unsafe_bitcast[c_void](), c_uint(1))
                    _ = exit(0)

                # Put into a group of its own from this side as well as
                # its own, so that the group is there to be named
                # whichever of the two gets there first.
                _ = setpgid(grandchild, grandchild)
                found.unsafe_offset(7)[] = grandchild
                found.unsafe_offset(5)[] = tcsetpgrp(slave, grandchild)
                found.unsafe_offset(6)[] = tcgetpgrp(slave)

                _ = kill(grandchild, SIGKILL)
                var reaped = unsafe_alloc[Int32](1)
                reaped.unsafe_offset(0)[] = 0
                _ = waitpid(grandchild, reaped, 0)
                reaped.unsafe_free()
            # Neither descriptor is closed here. Closing the master
            # hangs up the terminal this child has just made its own,
            # and a hangup is a `SIGHUP` to the session that owns it --
            # which is this child, so the signal would arrive before the
            # numbers were written down and the report would be an empty
            # pipe instead. Left to the exit, the descriptors are closed
            # after the exit status is already settled, and the same
            # hangup is then asked of a process that is on its way out.

        # Read back after the child has ended, so that a child which
        # never got this far leaves nothing to wait on: the pipe is
        # empty and its write end is gone, and the read answers 0.
        _ = write(report_fd, found.unsafe_bitcast[c_void](), c_uint(32))
        _ = exit(0)

    assert_true(child > 0, "there is a child to ask")
    _ = close(report_fd)
    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it ended of its own accord"
    )
    assert_equal(
        WEXITSTATUS(status.unsafe_load()),
        0,
        "having finished what it went to do",
    )
    status.unsafe_free()

    assert_equal(
        read(read_fd, found.unsafe_bitcast[c_void](), c_uint(32)),
        32,
        "and every number it found came back down the pipe",
    )

    var leader = Int(found.unsafe_offset(1)[])
    assert_equal(
        Int(found.unsafe_offset(0)[]),
        Int(child),
        "the child leads a session of its own, and it is the one it was",
    )
    assert_equal(leader, Int(child), "so its group is itself")
    assert_equal(
        Int(found.unsafe_offset(2)[]),
        leader,
        "and the terminal it opened says that group is in the foreground",
    )
    assert_equal(
        Int(found.unsafe_offset(3)[]), -1, "a group in no session is refused"
    )
    assert_equal(
        Int(found.unsafe_offset(4)[]),
        leader,
        "and the refusal left the terminal naming the group it named",
    )
    assert_equal(
        Int(found.unsafe_offset(5)[]), 0, "a group in the session is taken"
    )
    assert_equal(
        Int(found.unsafe_offset(6)[]),
        Int(found.unsafe_offset(7)[]),
        "and the terminal names that group and not the one before it",
    )
    assert_true(
        Int(found.unsafe_offset(7)[]) != leader,
        "which is a different group, so the two answers cannot be the same one",
    )

    _ = close(read_fd)
    found.unsafe_free()
    fds.unsafe_free()

    assert_equal(
        tcgetpgrp(-1), -1, "and a descriptor that is no terminal has no group"
    )
    assert_equal(tcsetpgrp(-1, getpgrp()), -1, "nor takes one")


def test_getlogin_and_getlogin_r_ask_the_same_question() raises:
    """`getlogin` answers into storage of the library's own and
    `getlogin_r` into the caller's buffer, and they are the same
    question about the same accounting file, so whichever way this
    machine answers it, the two have to agree: a name for one is the
    name for the other, and no name for one is no name for the other.
    """
    var name = getlogin()
    var mine = ""
    if not is_null(name):
        mine = char_ptr_to_string(name)

    var room = unsafe_alloc[UInt8](256)
    var written = getlogin_r(room, 256)
    if mine == "":
        assert_true(
            Int(written) != 0,
            "no name to hand back means the reentrant one fails too",
        )
    else:
        assert_equal(
            Int(written), 0, "a name means the reentrant one writes it"
        )
        assert_equal(char_ptr_to_string(room), mine, "and it is the same name")
        assert_equal(
            Int(getlogin_r(room, 1)),
            Int(ERANGE),
            "a buffer too small for any name is refused with ERANGE",
        )
    room.unsafe_free()


def test_sync_comes_back() raises:
    """`sync` asks for the kernel's held-back writes to be started on
    their way, waits for the asking rather than for the writing, and
    reports nothing back — so what a suite can ask of it is that the
    asking is over when it comes back.
    """
    sync()


def test_ttyslot_counts_a_line_or_none() raises:
    """`ttyslot` says which line of the machine's login file the
    controlling terminal is on. Both of those are the machine's own —
    this suite has no controlling terminal, and a machine with no
    login file is answered 0 whatever terminal it is on — so the
    floor is what can be said anywhere: a line number, or the 0 that
    says there is not one.
    """
    assert_true(
        Int(ttyslot()) >= 0,
        "a line number or the 0 that says there is not one",
    )


def test_pause_comes_back_because_a_signal_arrived() raises:
    """`pause` waits for a signal, and a suite that waits is one that
    stops -- so the signal is arranged before the waiting starts.

    The child arms `ualarm` for a tenth of a second and calls `pause`.
    Nothing here has installed a handler for `SIGALRM`, so what it does
    when it arrives is what it does by default: it ends the child. That
    is the assertion, and it is the strong one: the child is ended by
    the very signal it went to wait for, which cannot happen unless the
    waiting happened first.

    A `pause` that came back instead would leave the child to exit on
    its own, and the parent tells the two apart by `WIFSIGNALED` --
    ended by a signal, or by an exit -- and by the signal's name, so
    the wrong signal is not read as the right one.
    """
    var child = fork()
    if child == 0:
        _ = ualarm(100000, 0)
        _ = pause()
        _ = exit(0)

    assert_true(child > 0, "there is a child to wait for")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    assert_true(
        WIFSIGNALED(status.unsafe_load()),
        "a signal ended it, and the only signal it was waiting for is the one",
    )
    assert_equal(
        WTERMSIG(status.unsafe_load()),
        SIGALRM,
        "the one the alarm was armed with",
    )
    status.unsafe_free()


def test_brk_and_sbrk_move_the_end_of_the_data_segment() raises:
    """`sbrk` moves the program break a distance and says where it was, and
    `sbrk(0)` reads the break without moving it — which is what makes the
    two answer each other: the place the move reports is the place the
    reading had, and the reading afterwards is that place plus what was
    asked for.

    Putting it back with `brk` is asked only where it can be done. glibc
    moves the break to whatever it is handed; Darwin does not implement the
    call at all — `Libc/emulated/brk.c` answers `ENOMEM` and returns without
    looking at its argument — so what is asserted there is the refusal and
    the reading that says nothing moved. The call is bound without a return
    value for the same reason: one platform says `int` and the other
    `void *`.

    The move is one made and one taken back, and nothing is asked of the
    allocator in between: the break is the allocator's to grow by the same
    means, and a caller that leaves it somewhere else has rearranged a
    house it does not keep the keys to.
    """
    var here = sbrk(0)
    assert_true(Int(UInt(here)) != 0, "the break is somewhere")

    var was = sbrk(64)
    assert_equal(
        Int(UInt(was)), Int(UInt(here)), "and it says where the break was"
    )

    var now = sbrk(0)
    assert_equal(
        Int(UInt(now)),
        Int(UInt(here)) + 64,
        "and the break has moved by what was asked",
    )

    comptime if CompilationTarget.is_macos():
        set_errno(0)
        brk(here)
        assert_equal(
            get_errno(),
            ENOMEM,
            "the call Darwin does not have refuses, and says why",
        )
        assert_equal(
            Int(UInt(sbrk(0))),
            Int(UInt(now)),
            "and the break has not moved, which is what refusing means here",
        )
    else:
        brk(here)
        assert_equal(
            Int(UInt(sbrk(0))),
            Int(UInt(here)),
            "and it is back where reading found it",
        )


def test_the_saying_of_a_program_by_way_of_a_descriptor() raises:
    """`execveat` -- what `execve` does of a path,
    said by way of a directory descriptor: the saying
    looked for in the directory `fd` opens, or, with
    `AT_EMPTY_PATH` and an empty saying, in the very
    file `fd` itself opens. A child is asked for, the
    saying is made, and what the child comes back with
    is what the program it became says to come back
    with. A saying that is not there is refused, and
    the child that could not become anything comes back
    saying so. The word is Linux's own, and Darwin has
    no call that takes it.
    """
    comptime if not CompilationTarget.is_macos():
        # a program said by way of the directory it lives in
        var bin = open_with_mode(
            string_to_char_ptr("/bin").unsafe_bitcast[UInt8](),
            O_RDONLY | O_DIRECTORY,
        )
        assert_true(bin >= 0, "the directory the program lives in is open")
        var child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](4)
            var a0 = string_to_char_ptr("sh")
            var a1 = string_to_char_ptr("-c")
            var a2 = string_to_char_ptr("exit 42")
            argv.unsafe_offset(0)[] = a0.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(1)[] = a1.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(2)[] = a2.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(3)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](1)
            envp.unsafe_offset(0)[] = null_ptr[UInt8]()
            _ = execveat(
                bin,
                string_to_char_ptr("sh").unsafe_bitcast[UInt8](),
                argv,
                envp,
                Int32(0),
            )
            # the saying that does not come back: a child that could
            # not become anything says so with its own number
            _ = _Exit(111)
        assert_true(child > 0, "there is a child to say the program")
        var status = unsafe_alloc[Int32](1)
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child went an exit")
        assert_equal(WEXITSTATUS(status.unsafe_load()), 42, "with what it said")
        _ = close(bin)
        # a program said by way of its own descriptor, with an empty
        # saying and `AT_EMPTY_PATH`
        var sh = open_with_mode(
            string_to_char_ptr("/bin/sh").unsafe_bitcast[UInt8](), O_RDONLY
        )
        assert_true(sh >= 0, "the program's own descriptor is open")
        child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](4)
            var a0 = string_to_char_ptr("sh")
            var a1 = string_to_char_ptr("-c")
            var a2 = string_to_char_ptr("exit 43")
            argv.unsafe_offset(0)[] = a0.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(1)[] = a1.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(2)[] = a2.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(3)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](1)
            envp.unsafe_offset(0)[] = null_ptr[UInt8]()
            _ = execveat(
                sh,
                string_to_char_ptr("").unsafe_bitcast[UInt8](),
                argv,
                envp,
                Int32(AT_EMPTY_PATH),
            )
            _ = _Exit(112)
        assert_true(child > 0, "there is a child for the empty saying")
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child went an exit")
        assert_equal(
            WEXITSTATUS(status.unsafe_load()), 43, "with what the program said"
        )
        _ = close(sh)
        # a saying that is not there: refused, and the child that
        # could not become anything says so
        bin = open_with_mode(
            string_to_char_ptr("/bin").unsafe_bitcast[UInt8](),
            O_RDONLY | O_DIRECTORY,
        )
        assert_true(bin >= 0, "the directory is open again")
        child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](1)
            argv.unsafe_offset(0)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](1)
            envp.unsafe_offset(0)[] = null_ptr[UInt8]()
            _ = execveat(
                bin,
                string_to_char_ptr("no/such/program").unsafe_bitcast[UInt8](),
                argv,
                envp,
                Int32(0),
            )
            _ = _Exit(113)
        assert_true(child > 0, "there is a child for the saying that fails")
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child came back")
        assert_equal(WEXITSTATUS(status.unsafe_load()), 113, "saying it failed")
        _ = close(bin)


def test_the_program_said_by_its_own_descriptor_alone() raises:
    """`fexecve` -- what `execve` does of a path, said
    by way of the very file itself, with no path at
    all: the program is the file `fd` opens, which is
    the way a program that cannot trust the
    directories on the way says itself. A child is
    asked for, the saying is made, and what the child
    comes back with is what the program it became says
    to come back with. A descriptor that is not a
    program is refused, and the child that could not
    become anything comes back saying so. The word is
    POSIX's own saying, and Linux links it from the
    library a just-in-time run looks words up in;
    Darwin's libSystem keeps no such symbol to look up.
    """
    comptime if not CompilationTarget.is_macos():
        var sh = open_with_mode(
            string_to_char_ptr("/bin/sh").unsafe_bitcast[UInt8](), O_RDONLY
        )
        assert_true(sh >= 0, "the program's own descriptor is open")
        var child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](4)
            var a0 = string_to_char_ptr("sh")
            var a1 = string_to_char_ptr("-c")
            var a2 = string_to_char_ptr("exit 44")
            argv.unsafe_offset(0)[] = a0.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(1)[] = a1.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(2)[] = a2.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(3)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](1)
            envp.unsafe_offset(0)[] = null_ptr[UInt8]()
            _ = fexecve(sh, argv, envp)
            _ = _Exit(114)
        assert_true(child > 0, "there is a child to say the program")
        var status = unsafe_alloc[Int32](1)
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child went an exit")
        assert_equal(WEXITSTATUS(status.unsafe_load()), 44, "with what it said")
        _ = close(sh)
        # a descriptor that is not a program: refused, and the child
        # that could not become anything says so
        var room = open_with_mode(
            string_to_char_ptr("/etc/hostname").unsafe_bitcast[UInt8](),
            O_RDONLY,
        )
        assert_true(room >= 0, "a file that is no program is open")
        child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](1)
            argv.unsafe_offset(0)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](1)
            envp.unsafe_offset(0)[] = null_ptr[UInt8]()
            _ = fexecve(room, argv, envp)
            _ = _Exit(115)
        assert_true(child > 0, "there is a child for the asking that fails")
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child came back")
        assert_equal(WEXITSTATUS(status.unsafe_load()), 115, "saying it failed")
        _ = close(room)


def test_the_saying_looked_for_in_the_path_and_said_its_own_names() raises:
    """`execvpe` -- what `execvp` does of a file said
    with no path, looked for in the directories the
    PATH keeps, said with the caller's own room of
    names: the program the file becomes is told what
    the caller says, not what the shell around it
    keeps. A child is asked for, the saying is made,
    and what the child comes back with is what the
    program it became says to come back with -- which
    the program only says if the names really arrived.
    A file that is not in the directories the PATH
    keeps is refused, and the child that could not
    become anything comes back saying so. The word is
    GNU's own, and Darwin has no call that says it.
    """
    comptime if not CompilationTarget.is_macos():
        var child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](4)
            var a0 = string_to_char_ptr("sh")
            var a1 = string_to_char_ptr("-c")
            var a2 = string_to_char_ptr(
                'test "$MYWORD" = from_envp && exit 45 || exit 46'
            )
            argv.unsafe_offset(0)[] = a0.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(1)[] = a1.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(2)[] = a2.unsafe_bitcast[UInt8]()
            argv.unsafe_offset(3)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](2)
            var e0 = string_to_char_ptr("MYWORD=from_envp")
            envp.unsafe_offset(0)[] = e0.unsafe_bitcast[UInt8]()
            envp.unsafe_offset(1)[] = null_ptr[UInt8]()
            _ = execvpe(
                string_to_char_ptr("sh").unsafe_bitcast[UInt8](),
                argv,
                envp,
            )
            _ = _Exit(116)
        assert_true(child > 0, "there is a child to say the program")
        var status = unsafe_alloc[Int32](1)
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child went an exit")
        # 45 is what the program says only if the name really
        # arrived in the room the caller gave
        assert_equal(
            WEXITSTATUS(status.unsafe_load()), 45, "with what the name carried"
        )
        # a file that is not in the directories the PATH keeps:
        # refused, and the child says so
        child = fork()
        if child == 0:
            var argv = unsafe_alloc[c_ptr[UInt8]](1)
            argv.unsafe_offset(0)[] = null_ptr[UInt8]()
            var envp = unsafe_alloc[c_ptr[UInt8]](1)
            envp.unsafe_offset(0)[] = null_ptr[UInt8]()
            _ = execvpe(
                string_to_char_ptr("no-such-program-at-all").unsafe_bitcast[
                    UInt8
                ](),
                argv,
                envp,
            )
            _ = _Exit(117)
        assert_true(child > 0, "there is a child for the saying that fails")
        status.unsafe_store(0, 0)
        assert_equal(waitpid(child, status, 0), child, "and it is waited for")
        assert_true(WIFEXITED(status.unsafe_load()), "the child came back")
        assert_equal(WEXITSTATUS(status.unsafe_load()), 117, "saying it failed")


def test_the_whole_mount_waited_for_by_way_of_one_file() raises:
    """`syncfs` -- what `sync` does of every file at
    once, said of one: the writing the file `fd` opens
    waits for is waited for, all of it, the whole
    mount the file lives on. A file written to is
    waited for by way of itself, and the asking comes
    back having handed over everything the mount owes
    its way to the storage; a descriptor that is not a
    file is refused with `errno` saying so. The word
    is GNU's own, and Darwin has no call that says
    it.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/mojo_syncfs.txt")
        _ = unlink(path)
        var fd = open_with_mode(path, O_CREAT | O_RDWR, 0o600)
        assert_true(fd >= 0, "a file on the mount to be waited for")
        var said = string_to_char_ptr("flush me")
        _ = write(fd, said, c_uint(8))
        set_errno(0)
        assert_equal(Int(syncfs(fd)), 0, "the whole mount is waited for")
        assert_equal(Int(get_errno()), 0, "with no word of refusal")
        # and the file is still open: the asking waited, it did not
        # take the file away
        assert_true(
            Int(write(fd, said, c_uint(8))) >= 0,
            "the file the mount was waited for by way of is still open",
        )
        _ = close(fd)
        _ = unlink(path)
        # a descriptor that is not a file is refused
        set_errno(0)
        assert_equal(
            Int(syncfs(Int32(999999))),
            -1,
            "a descriptor that is not a file is refused",
        )
        assert_equal(Int(get_errno()), Int(EBADF), "with errno saying so")


def test_the_file_keeping_said_as_something_beside() raises:
    """`setfsuid` and `setfsgid` -- who the
    file-keeping is said as: the user and the group
    the kernel checks a file's keeping against when a
    file is opened, kept beside the user and the
    group the asking runs as. Said with nothing -- a
    -1 -- the asking only says who it is; said with
    who it already is, the answer is who it was,
    which is the same, twice; and asking again finds
    what the first saying left, still there. Nothing
    the asking refuses is said as a refusal, so the
    test asks again and the second answer is what the
    first saying made. Both words are GNU's own, and
    Darwin has no call that says either.
    """
    comptime if not CompilationTarget.is_macos():
        # said with nothing: only who it is
        var who = setfsuid(Int32(-1))
        assert_true(who >= 0, "the asking says who the file-keeping is said as")
        var what = setfsgid(Int32(-1))
        assert_true(what >= 0, "and what group, said the same way")
        # said with who it already is: the answer is who it was,
        # which is the same
        var said = setfsuid(who)
        assert_equal(
            Int(said),
            Int(who),
            "said back where it was, the answer is who it was",
        )
        var said_g = setfsgid(what)
        assert_equal(
            Int(said_g), Int(what), "and the group, said back, the same"
        )
        # and asking again finds what the first saying left
        var left = setfsuid(Int32(-1))
        assert_equal(
            Int(left), Int(who), "the saying left what it found, still there"
        )
        var left_g = setfsgid(Int32(-1))
        assert_equal(
            Int(left_g), Int(what), "and the group, still what it found"
        )


def test_the_root_said_again() raises:
    """`chroot` -- where / begins, said again: the
    directory the saying says becomes the asking's
    own root, and everything said after is looked for
    under it, whatever stands above it being no
    longer part of the view. A root that is not
    there is refused with `errno` saying so; a file
    that is not a directory is refused the same way;
    and a directory there is -- which is a saying the
    kernel keeps for the privileged -- is answered by
    the root moving, the file that stood outside
    being no longer where the saying of it finds
    anything.
    """
    # what is refused before the privilege is asked is said
    # differently by the two platforms: Linux checks the saying
    # first and refuses a root that is not there or a file that
    # is not a directory, while Darwin asks after the privilege
    # and refuses a caller without it, whatever the saying said
    comptime if not CompilationTarget.is_macos():
        # a root that is not there
        # a root that is not there
        set_errno(0)
        assert_equal(
            Int(chroot(string_to_char_ptr("/no/such/root/at/all"))),
            -1,
            "a root that is not there is refused",
        )
        assert_equal(Int(get_errno()), Int(ENOENT), "with errno saying so")
        # a file that is not a directory
        set_errno(0)
        assert_equal(
            Int(chroot(string_to_char_ptr("/etc/hostname"))),
            -1,
            "a file that is not a directory is refused",
        )
        assert_equal(Int(get_errno()), Int(ENOTDIR), "with errno saying so")

    # a directory there is: the privileged saying. Where the
    # asking may say it, the root moves and the file outside is
    # no longer found; where it may not, the refusal is said.
    _ = mkdir(string_to_char_ptr("/tmp/mojo_jail_root"), 0o755)
    set_errno(0)
    var moved = chroot(string_to_char_ptr("/tmp/mojo_jail_root"))
    if moved == 0:
        assert_true(
            Int(open(string_to_char_ptr("/etc/hostname"), Int32(0))) < 0,
            "the file that stood outside is no longer found",
        )
        assert_equal(
            Int(get_errno()), Int(ENOENT), "because / now begins under the jail"
        )
    else:
        assert_equal(
            Int(get_errno()),
            Int(EPERM),
            "the saying is kept for the privileged",
        )
        assert_equal(
            Int(rmdir(string_to_char_ptr("/tmp/mojo_jail_root"))),
            0,
            "and the room is taken back",
        )


def test_the_machine_said_its_name_again() raises:
    """`sethostname` -- who the machine says it is,
    said again: the name the asking of a host comes
    back with is what the saying makes it, for the
    length that goes with it. The name as it stands
    is asked for first, and said back where it
    already is -- which, where the asking may say
    it, the machine keeps, coming back having said
    the same; and where the asking may not, the
    refusal is what is said, the name being what it
    was either way, which the asking of it after
    proves.
    """
    var room = unsafe_alloc[c_char](256)
    assert_equal(
        Int(gethostname(room, 256)),
        0,
        "who the machine says it is is asked for first",
    )
    var said = sethostname(room, 256)
    if said == 0:
        # the machine keeps its name, having said the same
        var again = unsafe_alloc[c_char](256)
        assert_equal(Int(gethostname(again, 256)), 0, "the asking comes back")
        assert_equal(
            Int(strcmp(again, room)),
            0,
            "with the name the saying left, which is the one it had",
        )
    else:
        assert_equal(
            Int(get_errno()),
            Int(EPERM),
            "the saying is the kernel's own keeping",
        )
        var again = unsafe_alloc[c_char](256)
        assert_equal(
            Int(gethostname(again, 256)), 0, "the asking comes back after"
        )
        assert_equal(
            Int(strcmp(again, room)),
            0,
            "and the name is what it was",
        )


def test_the_keeping_said_by_way_of_a_directory() raises:
    """`fchownat` -- who keeps the file, said by way
    of a directory: the saying of `path` is looked
    for beside the file `fd` opens, or beside the
    root of the asking when `fd` is `AT_FDCWD`. A
    saying with no file under it is refused with
    `errno` saying so; a link leading nowhere, said
    with `AT_SYMLINK_NOFOLLOW`, is answered -- the
    keeping of the link itself, which is there
    whether the file it leads to is or not; and said
    without, the saying looks for the file the link
    leads to, which is nowhere, and is refused the
    same way a saying of nothing is. Who keeps what
    is left as it is, said with nothing to change --
    which the file answers.
    """
    # a saying with no file under it
    set_errno(0)
    assert_equal(
        Int(
            fchownat(
                Int32(AT_FDCWD),
                string_to_char_ptr("/no/such/file/at/all"),
                Int32(-1),
                Int32(-1),
                Int32(0),
            )
        ),
        -1,
        "a saying with no file under it is refused",
    )
    assert_equal(Int(get_errno()), Int(ENOENT), "with errno saying so")
    # a link leading nowhere: said as a link, answered;
    # said through, refused
    _ = symlink(
        string_to_char_ptr("/no/target/at/all"),
        string_to_char_ptr("/tmp/mojo_fco_link"),
    )
    set_errno(0)
    assert_equal(
        Int(
            fchownat(
                Int32(AT_FDCWD),
                string_to_char_ptr("/tmp/mojo_fco_link"),
                Int32(-1),
                Int32(-1),
                Int32(AT_SYMLINK_NOFOLLOW),
            )
        ),
        0,
        "the link itself is who is said, and the saying is answered",
    )
    set_errno(0)
    assert_equal(
        Int(
            fchownat(
                Int32(AT_FDCWD),
                string_to_char_ptr("/tmp/mojo_fco_link"),
                Int32(-1),
                Int32(-1),
                Int32(0),
            )
        ),
        -1,
        "said through, the saying looks for what the link leads to",
    )
    assert_equal(
        Int(get_errno()), Int(ENOENT), "and is refused, it being nowhere"
    )
    _ = unlink(string_to_char_ptr("/tmp/mojo_fco_link"))
    # who keeps what is left as it is, said with nothing to change --
    # the file the asking itself made, whose keeping is its own to say
    var kept = string_to_char_ptr("/tmp/mojo_fco_kept.txt")
    var kfd = open_with_mode(kept, O_CREAT | O_RDWR, 0o600)
    assert_true(kfd >= 0, "a file whose keeping is the asking's own to say")
    _ = close(kfd)
    set_errno(0)
    assert_equal(
        Int(
            fchownat(
                Int32(AT_FDCWD),
                kept,
                Int32(-1),
                Int32(-1),
                Int32(0),
            )
        ),
        0,
        "said with nothing to change, the file answers",
    )
    assert_equal(Int(get_errno()), 0, "with no word of refusal")
    _ = unlink(kept)


def main() raises:
    test_getcwd()
    test_descriptors_and_offsets()
    test_truncate_takes_a_path()
    test_links()
    test_chdir_and_fchdir()
    test_the_ids_and_the_terminal()
    test_asking_after_the_machine_and_the_process()
    test_walking_the_shells_a_user_may_have()
    test_fpathconf()
    test_pathconf_agrees_with_fpathconf()
    test_the_pc_knobs_are_the_platforms_own_numbers()
    test_sysconf_names_the_knobs_it_answers_for()
    test_confstr_answers_for_the_default_path()
    test_getopt()
    test_swab()
    test_sync_comes_back()
    test_getpid()
    test_gethostname()
    test_getlogin_and_getlogin_r_ask_the_same_question()
    test_ids()
    test_alarm_and_sleep()
    test_nice_and_pagesize()
    test_chown_on_what_is_not_there()
    test_sysconf()
    test_ttyslot_counts_a_line_or_none()
    test_usleep()
    test_process_groups()
    test_the_foreground_group_of_a_terminal()
    test_dup3()
    test_a_span_of_descriptors_closes_at_one_descent()
    test_marking_a_span_for_the_next_image()
    test_the_question_taken_at_a_directory()
    test_the_link_itself_and_not_where_it_leads()
    test_a_span_with_no_top()
    test_access_dup_and_link()
    test_syscall_by_number()
    test_the_exec_family_refuses_what_is_not_there()
    test_execve_hands_over_the_arguments_and_the_environment()
    test_setuid_and_setgid_asked_for_what_we_already_are()
    test_setreuid_and_setregid_name_both_ids_at_once()
    test_pread_and_pwrite_at_an_offset()
    test_readv_gathers_what_writev_scattered()
    test_ualarm_is_the_timer_that_getitimer_reads()
    test_pause_comes_back_because_a_signal_arrived()
    test_brk_and_sbrk_move_the_end_of_the_data_segment()
    test_the_three_numbers_of_the_user_and_the_group()
    test_the_saying_of_the_three_numbers()
    test_the_persona_kept_and_said_again()
    test_the_saying_of_the_domain_the_machine_stands_in()
    test_the_word_for_the_ports_of_the_machine()
    test_the_saying_of_a_program_by_way_of_a_descriptor()
    test_the_program_said_by_its_own_descriptor_alone()
    test_the_saying_looked_for_in_the_path_and_said_its_own_names()
    test_the_whole_mount_waited_for_by_way_of_one_file()
    test_the_file_keeping_said_as_something_beside()
    test_the_root_said_again()
    test_the_machine_said_its_name_again()
    test_the_keeping_said_by_way_of_a_directory()
    print("test_unistd: ok")


def test_a_span_of_descriptors_closes_at_one_descent() raises:
    """`close_range` and the span: three descriptors are made,
    one below the span and two inside it, and one call closes
    the two -- the one below the span still answers, which is
    the proof that the span closed what it named and nothing
    else, and the ones inside answer with `EBADF`, which is
    the proof they are gone.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_close_span")
        var low = open_with_mode(path, O_CREAT | O_RDWR, 0o600)
        assert_true(low >= 0, "the descriptor below the span is open")
        var inside_a = dup(low)
        var inside_b = dup(low)
        assert_true(
            inside_a >= 0 and inside_b >= 0, "and two more sit inside the span"
        )

        assert_equal(
            close_range(UInt32(inside_a), UInt32(inside_b), 0),
            0,
            "the span closes at one descent",
        )
        assert_equal(
            fcntl(low, F_GETFD, 0), 0, "the one below the span still answers"
        )
        assert_equal(
            fcntl(inside_a, F_GETFD, 0), -1, "the first inside is gone"
        )
        assert_equal(get_errno(), EBADF, "and gone is what EBADF says")
        assert_equal(fcntl(inside_b, F_GETFD, 0), -1, "and so is the second")

        _ = close(low)
        _ = unlink(path)


def test_marking_a_span_for_the_next_image() raises:
    """`close_range` and `CLOSE_RANGE_CLOEXEC`: the span is not
    closed -- every descriptor in it still answers -- but each
    has been told to close itself when the next image takes the
    process over, and the flag `fcntl` reads back is the proof:
    the close-on-exec bit, set on the two inside the span and
    not on the one outside it.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_close_marked")
        var low = open_with_mode(path, O_CREAT | O_RDWR, 0o600)
        assert_true(low >= 0, "the descriptor below the span is open")
        var inside_a = dup(low)
        var inside_b = dup(low)
        assert_true(
            inside_a >= 0 and inside_b >= 0, "and two more sit inside the span"
        )

        assert_equal(
            close_range(
                UInt32(inside_a), UInt32(inside_b), CLOSE_RANGE_CLOEXEC
            ),
            0,
            "the span is marked, not closed",
        )
        assert_equal(
            fcntl(inside_a, F_GETFD, 0),
            FD_CLOEXEC,
            "the first is marked for the next image",
        )
        assert_equal(
            fcntl(inside_b, F_GETFD, 0), FD_CLOEXEC, "and so is the second"
        )
        assert_equal(
            fcntl(low, F_GETFD, 0), 0, "and the one below the span is neither"
        )

        _ = close(low)
        _ = close(inside_a)
        _ = close(inside_b)
        _ = unlink(path)


def test_the_question_taken_at_a_directory() raises:
    """`faccessat`: the asking `access` does, of a path named
    relative to a directory that is open -- and the flag is
    the part `access` has never had: a link asked by its own
    name, `AT_SYMLINK_NOFOLLOW` saying the link and not the
    file it leads to.
    """
    comptime if not CompilationTarget.is_macos():
        var there = open_with_mode(string_to_char_ptr("/tmp"), O_RDONLY, 0)
        assert_true(there >= 0, "the directory is open")
        var path = string_to_char_ptr("/tmp/libc_faccessat_made")
        var fd = open_with_mode(path, O_CREAT | O_WRONLY, 0o600)
        assert_true(fd >= 0, "the file is made")
        _ = close(fd)

        assert_equal(
            faccessat(there, string_to_char_ptr("libc_faccessat_made"), 0, 0),
            0,
            "the relative name is asked and answered",
        )
        assert_equal(
            faccessat(there, string_to_char_ptr("libc_faccessat_gone"), 0, 0),
            -1,
            "and the name that is not, is not",
        )
        assert_equal(get_errno(), ENOENT, "and not-there is what ENOENT says")

        _ = unlink(path)
        _ = close(there)


def test_a_span_with_no_top() raises:
    """`closefrom`: the span with no top -- the descriptors from
    `lowfd` up all closed at one descent, the one below the
    start of the span still answering and the ones from the
    start up answering `EBADF`. A binding that closed the
    other end of the span would be told by the descriptor
    below, which survives, and by the one at the start,
    which does not.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_closefrom_made")
        var low = open_with_mode(path, O_CREAT | O_RDWR, 0o600)
        assert_true(low >= 0, "the descriptor below the span is open")
        var mid = dup(low)
        var high = dup(low)
        assert_true(mid >= 0 and high >= 0, "and two more sit above it")

        closefrom(mid)
        # The call reports nothing: a span with no top is a call that cannot be refused.
        assert_equal(fcntl(low, F_GETFD, 0), 0, "the one below still answers")
        assert_equal(
            fcntl(mid, F_GETFD, 0),
            -1,
            "the one at the start of the span is gone",
        )
        assert_equal(get_errno(), EBADF, "and gone is what EBADF says")
        assert_equal(fcntl(high, F_GETFD, 0), -1, "and so is the one above it")

        _ = close(low)
        _ = unlink(path)


def test_the_link_itself_and_not_where_it_leads() raises:
    """`faccessat` and `AT_SYMLINK_NOFOLLOW`: a link that leads
    nowhere, asked by `access`, is answered for the file it
    would lead to -- which is nothing, so no. Asked with the
    flag, the link itself is what the kernel looks at, and a
    link is a file whose contents are the name it carries:
    reachable, whatever it points at.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_faccessat_dangling")
        _ = unlink(path)
        assert_equal(
            symlink(string_to_char_ptr("/tmp/libc_faccessat_nowhere"), path),
            0,
            "the link is made, at a name that leads nowhere",
        )

        assert_equal(
            access(path, 0), -1, "the following ask sees nothing at the end"
        )
        assert_equal(get_errno(), ENOENT, "and nothing is what ENOENT says")
        assert_equal(
            faccessat(AT_FDCWD, path, 0, AT_SYMLINK_NOFOLLOW),
            0,
            "the flag asks after the link, and the link is there",
        )

        _ = unlink(path)


def test_the_three_numbers_of_the_user_and_the_group() raises:
    """`getresuid` and `getresgid` -- the three numbers of the
    user and of the group, written each where they are
    pointed at: the one the process was born with is the one
    `getuid` says, the one its permissions are read by is the
    one `geteuid` says, and the one it was and could be again
    is had here and nowhere else. The asking of the group
    says the same three for the group it stands in. The
    asking is had where the kernel keeps the third number --
    Darwin's libSystem has no such call to ask.
    """
    comptime if not CompilationTarget.is_macos():
        var r = unsafe_alloc[UInt32](1)
        var e = unsafe_alloc[UInt32](1)
        var sv = unsafe_alloc[UInt32](1)
        assert_equal(
            Int(getresuid(r, e, sv)), 0, "the user's three numbers are had"
        )
        assert_equal(
            Int(r.unsafe_offset(0)[]),
            Int(getuid()),
            "and the real one is the one getuid says",
        )
        assert_equal(
            Int(e.unsafe_offset(0)[]),
            Int(geteuid()),
            "and the effective one is the one geteuid says",
        )
        assert_true(
            Int(sv.unsafe_offset(0)[]) >= 0,
            "and the saved one is a number the process was",
        )
        var gr = unsafe_alloc[UInt32](1)
        var ge = unsafe_alloc[UInt32](1)
        var gs = unsafe_alloc[UInt32](1)
        assert_equal(
            Int(getresgid(gr, ge, gs)), 0, "the group's three numbers are had"
        )
        assert_equal(
            Int(gr.unsafe_offset(0)[]),
            Int(getgid()),
            "and the real one is the one getgid says",
        )
        assert_equal(
            Int(ge.unsafe_offset(0)[]),
            Int(getegid()),
            "and the effective one is the one getegid says",
        )
        assert_true(
            Int(gs.unsafe_offset(0)[]) >= 0,
            "and the saved one is a number the process was",
        )
        r.unsafe_free()
        e.unsafe_free()
        sv.unsafe_free()
        gr.unsafe_free()
        ge.unsafe_free()
        gs.unsafe_free()


def test_the_saying_of_the_three_numbers() raises:
    """`setresuid` and `setresgid` -- the saying of the three
    numbers of the user and of the group: the asking of three
    words that are all nothing leaves what is there, the
    saying of the numbers the process already is is answered
    with nothing done and nothing said, and the saying of
    three numbers the process is not is refused with `EPERM`.
    The read-back asks again, and the numbers are what they
    were. The setting is had where the kernel keeps the third
    number -- Darwin's libSystem has no such call to say -- and the word being the machine's
    own ground, the asking is had where the machine has ports, which
    aarch64 does not.
    """
    comptime if not CompilationTarget.is_macos():
        var r = unsafe_alloc[UInt32](1)
        var e = unsafe_alloc[UInt32](1)
        var sv = unsafe_alloc[UInt32](1)
        assert_equal(
            Int(getresuid(r, e, sv)), 0, "the user's three numbers are had"
        )
        assert_equal(
            Int(
                setresuid(
                    c_uint(0xFFFFFFFF), c_uint(0xFFFFFFFF), c_uint(0xFFFFFFFF)
                )
            ),
            0,
            "and the asking of three words that are nothing leaves them",
        )
        assert_equal(
            Int(
                setresuid(
                    r.unsafe_offset(0)[],
                    e.unsafe_offset(0)[],
                    sv.unsafe_offset(0)[],
                )
            ),
            0,
            "and the saying of what is already said is nothing done",
        )
        assert_equal(
            Int(setresuid(c_uint(0), c_uint(0), c_uint(0))),
            -1,
            "and the saying of numbers the process is not is refused",
        )
        assert_equal(
            Int(get_errno()),
            EPERM,
            "and the refusal says the process may not say them",
        )
        var gr = unsafe_alloc[UInt32](1)
        var ge = unsafe_alloc[UInt32](1)
        var gs = unsafe_alloc[UInt32](1)
        assert_equal(
            Int(getresgid(gr, ge, gs)), 0, "the group's three numbers are had"
        )
        assert_equal(
            Int(
                setresgid(
                    c_uint(0xFFFFFFFF), c_uint(0xFFFFFFFF), c_uint(0xFFFFFFFF)
                )
            ),
            0,
            "and the group's asking of nothing leaves them too",
        )
        assert_equal(
            Int(
                setresgid(
                    gr.unsafe_offset(0)[],
                    ge.unsafe_offset(0)[],
                    gs.unsafe_offset(0)[],
                )
            ),
            0,
            "and the saying of what is already said is nothing done either",
        )
        assert_equal(
            Int(setresgid(c_uint(0), c_uint(0), c_uint(0))),
            -1,
            "and the saying of numbers the process is not is refused the same",
        )
        assert_equal(
            Int(get_errno()),
            EPERM,
            "and the refusal says the process may not say them",
        )
        r.unsafe_free()
        e.unsafe_free()
        sv.unsafe_free()
        gr.unsafe_free()
        ge.unsafe_free()
        gs.unsafe_free()


def test_the_persona_kept_and_said_again() raises:
    """`personality` -- the word of how the kernel presents
    itself to what the process does: the asking of the
    biggest number there is says what the persona is and
    leaves it, the saying of the word for the unshuffled
    addresses makes that word the persona and says back the
    one it replaced, and the saying of what the saying said
    back puts the persona the process was keeping back where
    it was. The asking is had where the kernel keeps it --
    Darwin's libSystem has no such call to ask.
    """
    comptime if not CompilationTarget.is_macos():
        var born = Int(personality(c_ulong(0xFFFFFFFFFFFFFFFF)))
        assert_true(born >= 0, "the persona is asked and the asking says it")
        var said = Int(personality(ADDR_NO_RANDOMIZE))
        assert_equal(
            said,
            born,
            "and the saying says back the one it replaced",
        )
        var now = Int(personality(c_ulong(0xFFFFFFFFFFFFFFFF)))
        assert_true(
            (now & Int(ADDR_NO_RANDOMIZE)) != 0,
            "and the word said is the word the persona keeps",
        )
        var put_back = Int(personality(c_ulong(born)))
        assert_equal(
            put_back,
            now,
            "and the saying of what was there says back what replaced it",
        )
        var after = Int(personality(c_ulong(0xFFFFFFFFFFFFFFFF)))
        assert_equal(
            after,
            born,
            "and the persona is what it was when the process was made",
        )


def test_the_saying_of_the_domain_the_machine_stands_in() raises:
    """`setdomainname` -- the saying again of the name of the
    network domain the machine stands in, which is the NIS
    domain and not the hostname: the saying of it is had by
    a process that is allowed to say it, and a process that
    is not is refused with `EPERM` whatever the name it
    says, even the name the machine already goes by, the
    asking of a name too long for the kernel's word being
    refused the same way before the kernel looks at what is
    said. The saying is had where the kernel keeps the
    domain -- Darwin's libSystem has no such call to say.
    """
    comptime if not CompilationTarget.is_macos():
        var room = unsafe_alloc[UInt8](256)
        for i in range(256):
            room.unsafe_offset(i)[] = 0
        assert_equal(
            Int(getdomainname(room, 256)),
            0,
            "the domain the machine stands in is had",
        )
        assert_equal(
            Int(setdomainname(room, 256)),
            -1,
            "and the saying of it is refused to a process that may not",
        )
        assert_equal(
            Int(get_errno()),
            EPERM,
            "and the refusal says the process may not say it",
        )
        var long = unsafe_alloc[UInt8](70)
        for i in range(70):
            long.unsafe_offset(i)[] = UInt8(0x78)
        assert_equal(
            Int(setdomainname(long, 70)),
            -1,
            "and the saying of a name too long is refused the same way",
        )
        assert_equal(
            Int(get_errno()),
            EPERM,
            "and the refusal comes before the kernel looks at what is said",
        )
        room.unsafe_free()
        long.unsafe_free()


def test_the_word_for_the_ports_of_the_machine() raises:
    """`ioperm` and `iopl` -- the word for the ports of the
    machine: the asking to have the ports is refused with
    `EPERM` to a process that is not allowed to ask, and the
    asking to give up what the process never had is answered
    with nothing done, there being nothing to give up -- the
    word for some ports being `ioperm` and the word for all
    of them at once being `iopl`. The word is had where the
    machine has ports -- Darwin's libSystem has no such call
    to say.
    """
    comptime if not CompilationTarget.is_macos() and not CompilationTarget.is_arm():
        assert_equal(
            Int(ioperm(0x80, 1, 1)),
            -1,
            "the asking to have a port is refused to a process that may not",
        )
        assert_equal(
            Int(get_errno()),
            EPERM,
            "and the refusal says the process may not ask",
        )
        assert_equal(
            Int(ioperm(0x80, 1, 0)),
            0,
            "and the asking to give up what was never had is nothing done",
        )
        assert_equal(
            Int(iopl(3)),
            -1,
            "and the whole word for all the ports is refused the same way",
        )
        assert_equal(
            Int(get_errno()),
            EPERM,
            "and the refusal says the process may not ask that either",
        )
        assert_equal(
            Int(iopl(0)),
            0,
            "and the giving up of all of them is nothing done too",
        )
