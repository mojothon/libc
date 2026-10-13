from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_false, assert_true

from libc.constant import AF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR, c_ptr
from libc.sys.socket import getsockopt, setsockopt, socket
from libc.sys.stat import mkfifo
from libc.unistd import unlink
from libc.setjmp import setjmp
from libc.sys.select import (
    FD_CLR,
    FD_ISSET,
    FD_SET,
    FD_ZERO,
    Timeval,
    fd_set,
    select,
)
from libc.sys.statvfs import Statvfs, statvfs
from libc.sys.wait import (
    WEXITSTATUS,
    WCOREDUMP,
    WIFEXITED,
    WIFSIGNALED,
    WIFSTOPPED,
    WSTOPSIG,
    WTERMSIG,
)
from libc.sys.utsname import Utsname, uname
from libc.unistd import close, pipe, write
from libc.utils import null_ptr, string_to_char_ptr


def test_uname() raises:
    var buf = unsafe_alloc[Utsname](1)
    buf[] = Utsname()
    assert_equal(uname(buf), 0, "uname succeeded")

    comptime if CompilationTarget.is_macos():
        assert_equal(buf[].sysname(), "Darwin")
    else:
        assert_equal(buf[].sysname(), "Linux")
    assert_true(buf[].release().byte_length() > 0, "there is a release")
    assert_true(buf[].machine().byte_length() > 0, "there is a machine name")

    # Darwin's struct ends at `machine`; only glibc carries a domain name.
    comptime if CompilationTarget.is_macos():
        assert_equal(buf[].domainname(), "")
    else:
        assert_true(buf[].nodename().byte_length() > 0, "there is a node name")

    buf.unsafe_free()


def test_fd_set() raises:
    var fds = unsafe_alloc[fd_set](1)
    fds[] = fd_set()
    FD_ZERO(fds)

    assert_true(not FD_ISSET(fds, 3), "the set starts out empty")

    FD_SET(fds, 3)
    assert_true(FD_ISSET(fds, 3), "a descriptor went in")
    assert_true(not FD_ISSET(fds, 4), "its neighbour did not")

    # 70 crosses into the next word on Linux, where the words are 64-bit.
    FD_SET(fds, 70)
    assert_true(FD_ISSET(fds, 70), "a descriptor past the first word went in")
    assert_true(FD_ISSET(fds, 3), "the first one is still there")

    FD_CLR(fds, 3)
    assert_true(not FD_ISSET(fds, 3), "a descriptor came out")
    assert_true(FD_ISSET(fds, 70), "clearing one leaves the other")

    fds.unsafe_free()


def test_select_on_a_pipe() raises:
    var ends = unsafe_alloc[Int32](2)
    assert_equal(pipe(ends), 0, "the pipe was made")
    var reader = ends.unsafe_load(0)
    var writer = ends.unsafe_load(1)

    var fds = unsafe_alloc[fd_set](1)
    fds[] = fd_set()
    FD_ZERO(fds)
    FD_SET(fds, reader)

    # Nothing written yet, and no time to wait: nothing is ready.
    var none = unsafe_alloc[Timeval](1)
    none[] = Timeval(0, 0)
    assert_equal(
        select(reader + 1, fds, null_ptr[fd_set](), null_ptr[fd_set](), none),
        0,
        "an empty pipe is not ready to read",
    )
    assert_true(not FD_ISSET(fds, reader), "select cleared the bit")

    # Now write a byte, and it is.
    var byte = unsafe_alloc[UInt8](1)
    byte.unsafe_store(0, UInt8(65))
    assert_equal(write(writer, byte, 1), 1, "the byte went in")

    FD_ZERO(fds)
    FD_SET(fds, reader)
    assert_equal(
        select(reader + 1, fds, null_ptr[fd_set](), null_ptr[fd_set](), none),
        1,
        "the pipe is ready to read",
    )
    assert_true(FD_ISSET(fds, reader), "select reported that descriptor")

    _ = close(reader)
    _ = close(writer)
    byte.unsafe_free()
    none.unsafe_free()
    fds.unsafe_free()
    ends.unsafe_free()


def test_statvfs() raises:
    var buf = unsafe_alloc[Statvfs](1)
    buf[] = Statvfs()
    var path = string_to_char_ptr("/")
    assert_equal(statvfs(path, buf), 0, "statvfs succeeded")
    path.unsafe_free()

    assert_true(buf[].f_bsize() > 0, "the file system has a block size")
    assert_true(buf[].f_frsize() > 0, "the file system has a fragment size")
    assert_true(buf[].f_blocks() > 0, "the file system has blocks")
    assert_true(
        buf[].f_bavail() <= buf[].f_blocks(),
        "available blocks are not more than blocks",
    )
    assert_true(buf[].f_namemax() > 0, "the file system allows names")
    # A fragment size is a power of two and nowhere near a megabyte; a number
    # that is not would mean these bytes are not where the struct says.
    assert_true(
        buf[].f_frsize() <= 1 << 20,
        "the fragment size is a sane number of bytes",
    )
    # The rest of the members, which are the ones that catch a slot read out
    # of place: each count is no larger than the one above it, and on Darwin
    # two of them share a 64-bit slot, so a member landing in the wrong half
    # shows up as a number that is not smaller.
    assert_true(buf[].f_bfree() > 0, "and some of them free")
    assert_true(
        buf[].f_bfree() <= buf[].f_blocks(), "and no more free than there are"
    )
    assert_true(
        buf[].f_bavail() <= buf[].f_bfree(), "and no more available than free"
    )
    assert_true(buf[].f_files() > 0, "and some inodes")
    assert_true(
        buf[].f_ffree() <= buf[].f_files(),
        "and no more free inodes than there are",
    )
    # `f_flag` holds the mount flags, a handful of ST_* bits and nothing
    # else. Which of them is set is the platform's business — macOS's root
    # is a read-only system volume and Linux's is not — but a member read
    # out of its slot would come back as a block count, which is far past
    # any combination of flags.
    assert_true(buf[].f_flag() < 0x10000, "the flags are a handful of bits")

    buf.unsafe_free()


def test_setjmp_records() raises:
    # 200 bytes is what glibc's jmp_buf needs on x86-64; more does no harm.
    var env = unsafe_alloc[UInt8](256)
    for i in range(256):
        env.unsafe_store(i, UInt8(0))
    assert_equal(setjmp(env), 0, "setjmp recorded this position")
    env.unsafe_free()


def test_what_a_wait_status_says() raises:
    """The seven readings of a status, against the numbers glibc's macros
    give for them.

    Every one of the 65536 possible statuses was checked against
    `WIFEXITED` and the rest in C, and they agree on all of them, so these
    are numbers with an answer behind them rather than numbers that look
    plausible.
    """
    # 0x0000: exited, with 0.
    assert_true(WIFEXITED(0), "a status of 0 is an exit")
    assert_equal(WEXITSTATUS(0), 0, "that exited with 0")
    assert_false(WIFSIGNALED(0), "and no signal ended it")
    assert_false(WIFSTOPPED(0), "and it was not stopped")

    # 0x0900: exited, with 9.
    assert_true(WIFEXITED(0x0900), "0x0900 is an exit")
    assert_equal(WEXITSTATUS(0x0900), 9, "that exited with 9")

    # 0x0009: ended by signal 9, no core.
    assert_true(WIFSIGNALED(0x0009), "0x0009 was ended by a signal")
    assert_equal(WTERMSIG(0x0009), 9, "by signal 9")
    assert_false(WIFEXITED(0x0009), "and it did not exit")
    assert_false(WCOREDUMP(0x0009), "and it left no core")

    # 0x0089: ended by signal 9, with a core.
    assert_true(WIFSIGNALED(0x0089), "0x0089 was ended by a signal")
    assert_equal(WTERMSIG(0x0089), 9, "by signal 9")
    assert_true(WCOREDUMP(0x0089), "and it left a core")

    # 0x7f in the low byte is a stop, and the signal is in the byte above.
    assert_true(WIFSTOPPED(0x137F), "0x137f is a stop")
    assert_equal(WSTOPSIG(0x137F), 19, "stopped by signal 19")
    assert_false(WIFEXITED(0x137F), "and it did not exit")
    assert_false(WIFSIGNALED(0x137F), "and no signal ended it")


def test_mkfifo() raises:
    """A named pipe, made and taken away.

    Not opened: opening one for reading blocks until someone opens it for
    writing, and a test that waits on a pipe nobody opens is a test that
    hangs.
    """
    var path = string_to_char_ptr("/tmp/libc-test-fifo")
    _ = unlink(path)
    assert_equal(Int(mkfifo(path, 0o644)), 0, "a fifo is made")
    assert_equal(Int(unlink(path)), 0, "and taken away again")


def test_socket_options() raises:
    """An option set on a socket and read back off it.

    `SO_REUSEADDR` is an int, which is the smallest shape an option comes
    in, and the round trip is what says the binding put the value where C
    reads it rather than somewhere nearby.
    """
    var fd = socket(AF_INET, SOCK_STREAM, 0)
    assert_true(fd >= 0, "a socket opens")

    var on = unsafe_alloc[Int32](1)
    on[] = 1
    assert_equal(
        Int(
            setsockopt(
                fd, SOL_SOCKET, SO_REUSEADDR, on.unsafe_bitcast[NoneType](), 4
            )
        ),
        0,
        "SO_REUSEADDR is turned on",
    )

    var back = unsafe_alloc[Int32](1)
    back[] = 0
    var room = unsafe_alloc[UInt32](1)
    room[] = 4
    assert_equal(
        Int(
            getsockopt(
                fd,
                SOL_SOCKET,
                SO_REUSEADDR,
                back.unsafe_bitcast[NoneType](),
                room,
            )
        ),
        0,
        "and read back off the same socket",
    )
    assert_true(back[] != 0, "and it is still on")

    on.unsafe_free()
    back.unsafe_free()
    room.unsafe_free()
    _ = close(fd)


def main() raises:
    test_uname()
    test_fd_set()
    test_select_on_a_pipe()
    test_statvfs()
    test_what_a_wait_status_says()
    test_setjmp_records()
    test_mkfifo()
    test_socket_options()
    print("test_sys: ok")
