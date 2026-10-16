"""Tests for the `libc.unistd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import O_CREAT, O_RDONLY, open as open_with_mode
from libc.constant import AT_FDCWD, c_ptr, SEEK_END, SEEK_SET
from libc.sys.stat import Stat, fchmod, fstat, stat
from libc.unistd import (
    SC_PAGESIZE,
    SYS_getpid,
    alarm,
    chdir,
    chown,
    dup2,
    dup3,
    execv,
    execve,
    execvp,
    fchdir,
    fchown,
    fchownat,
    fpathconf,
    fsync,
    ftruncate,
    getcwd,
    getegid,
    geteuid,
    getgid,
    getopt,
    getpagesize,
    getpgid,
    getpid,
    getppid,
    getsid,
    gettid,
    getuid,
    isatty,
    lchown,
    linkat,
    lseek,
    nice,
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
    setuid,
    sleep,
    swab,
    symlinkat,
    syscall,
    sysconf,
    truncate,
    unlink,
    unlinkat,
    usleep,
    write,
    writev,
)
from libc.constant import O_RDWR, c_char, c_ptr
from libc.file import close, fclose, fopen, open
from libc.stdio import fwrite, remove
from libc.sys.socket import iovec
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


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
    assert_true(getsid(0) > 0, "and in a session")
    var moved = setpgid(0, 0)
    assert_true(
        moved == 0 or moved == -1,
        "moving into its own group answers 0, or -1 with a reason in errno",
    )


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
    # 5 is `_PC_PIPE_BUF`.
    var asked = fpathconf(fds.unsafe_offset(0)[], 5)
    assert_true(
        asked > 0 and asked <= 1 << 20,
        "a pipe has a block size, and it is a sane one",
    )
    _ = close(fds.unsafe_offset(0)[])
    _ = close(fds.unsafe_offset(1)[])
    fds.unsafe_free()


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


def main() raises:
    test_getcwd()
    test_descriptors_and_offsets()
    test_truncate_takes_a_path()
    test_links()
    test_chdir_and_fchdir()
    test_the_ids_and_the_terminal()
    test_fpathconf()
    test_getopt()
    test_swab()
    test_getpid()
    test_ids()
    test_alarm_and_sleep()
    test_nice_and_pagesize()
    test_chown_on_what_is_not_there()
    test_sysconf()
    test_usleep()
    test_process_groups()
    test_dup3()
    test_syscall_by_number()
    test_the_exec_family_refuses_what_is_not_there()
    test_setuid_and_setgid_asked_for_what_we_already_are()
    test_pread_and_pwrite_at_an_offset()
    test_readv_gathers_what_writev_scattered()
    print("test_unistd: ok")
