from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.errno import get_errno, set_errno
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
from libc.sys.stat import Stat, stat
from libc.sys.statvfs import Statvfs, statvfs
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
    # `f_flag` holds the mount flags, of which ST_RDONLY is 1. The root of a
    # running system is writable, so it should not be set.
    assert_equal(buf[].f_flag() & 1, 0, "the root is not read only")

    buf.unsafe_free()


def test_errno() raises:
    set_errno(0)
    assert_equal(get_errno(), 0, "errno starts out clear")

    # A path that cannot exist leaves ENOENT behind, which is what set_errno
    # exists to clear.
    var missing = string_to_char_ptr("/nonexistent-path-for-libc-tests")
    var buf = unsafe_alloc[Stat](1)
    buf[] = Stat()
    assert_equal(stat(missing, buf), -1, "stat failed")
    assert_equal(get_errno(), 2, "the failure left ENOENT in errno")

    set_errno(0)
    assert_equal(get_errno(), 0, "set_errno cleared it")

    missing.unsafe_free()
    buf.unsafe_free()


def test_setjmp_records() raises:
    # 200 bytes is what glibc's jmp_buf needs on x86-64; more does no harm.
    var env = unsafe_alloc[UInt8](256)
    for i in range(256):
        env.unsafe_store(i, UInt8(0))
    assert_equal(setjmp(env), 0, "setjmp recorded this position")
    env.unsafe_free()


def main() raises:
    test_uname()
    test_fd_set()
    test_select_on_a_pipe()
    test_statvfs()
    test_errno()
    test_setjmp_records()
    print("test_sys: ok")
