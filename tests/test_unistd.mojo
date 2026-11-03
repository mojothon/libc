"""Tests for the `libc.unistd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import O_CREAT, O_RDONLY, open as open_with_mode
from libc.constant import (
    AT_FDCWD,
    ENOENT,
    ERANGE,
    c_ptr,
    c_uint,
    O_NOCTTY,
    O_RDWR,
    SEEK_END,
    SEEK_SET,
    c_void,
)
from libc.signal import SIGALRM, SIGKILL, kill
from libc.stdlib import _Exit, exit, grantpt, posix_openpt, ptsname, unlockpt
from libc.sys.stat import Stat, fchmod, fstat, stat
from libc.sys.utsname import Utsname, uname
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
    SC_NPROCESSORS_ONLN,
    SC_OPEN_MAX,
    SC_PAGESIZE,
    SYS_getpid,
    access,
    alarm,
    chdir,
    chown,
    confstr,
    dup,
    dup2,
    dup3,
    endusershell,
    execv,
    execve,
    execvp,
    fchdir,
    fchown,
    fchownat,
    fork,
    fpathconf,
    fsync,
    ftruncate,
    getcwd,
    getdomainname,
    getdtablesize,
    getegid,
    geteuid,
    getgid,
    getgroups,
    gethostid,
    gethostname,
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
    ttyname,
    ttyname_r,
    ualarm,
    unlink,
    unlinkat,
    usleep,
    write,
    writev,
)
from libc.constant import O_RDWR, c_char, c_ptr
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

    var fd = open(string_to_char_ptr("/tmp"), O_RDONLY)
    assert_true(fd >= 0, "the directory opens")
    assert_equal(fchdir(fd), 0, "fchdir takes a descriptor")
    _ = close(fd)

    assert_equal(chdir(start), 0, "and it comes back")
    start.unsafe_free()
    tmp.unsafe_free()


def test_the_ids_and_the_terminal() raises:
    assert_true(getppid() > 0, "there is a parent process")
    comptime if not CompilationTarget.is_macos():
        assert_true(gettid() > 0, "and this thread has an id")

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
    print("test_unistd: ok")
