"""Tests for the `libc.unistd` bindings."""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.unistd import (
    SC_PAGESIZE,
    alarm,
    chown,
    fchown,
    fchownat,
    getcwd,
    getegid,
    geteuid,
    getgid,
    getpagesize,
    getpid,
    getuid,
    lchown,
    getsid,
    getpgid,
    nice,
    setegid,
    setpgid,
    seteuid,
    sleep,
    pipe,
    pread,
    pwrite,
    readv,
    swab,
    sysconf,
    usleep,
    writev,
)
from libc.constant import O_RDWR, c_char, c_ptr
from libc.file import close, fclose, fopen, open
from libc.stdio import fwrite, remove
from libc.sys.socket import iovec
from libc.utils import char_ptr_to_string, string_to_char_ptr


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


def main() raises:
    test_getcwd()
    test_swab()
    test_getpid()
    test_ids()
    test_alarm_and_sleep()
    test_nice_and_pagesize()
    test_chown_on_what_is_not_there()
    test_sysconf()
    test_usleep()
    test_process_groups()
    test_pread_and_pwrite_at_an_offset()
    test_readv_gathers_what_writev_scattered()
    print("test_unistd: ok")
