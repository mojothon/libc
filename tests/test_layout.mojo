from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.pthread import pthread_attr_t, pthread_condattr_t
from libc.sys.resource import Rlimit, getrlimit, getrusage
from libc.sys.socket import socketaddr
from libc.fcntl import open
from libc.sys.stat import Stat, fstat, stat, timespec, timeval
from libc.sys.wait import rusage
from libc.unistd import close, unlink, write
from libc.time import tm
from libc.utils import string_to_char_ptr
from libc.wchar import mbstate_t

# RLIMIT_NOFILE is 7 on Linux and 8 on Darwin.
comptime RLIMIT_NOFILE = Int32(8) if CompilationTarget.is_macos() else Int32(7)


def stride[T: AnyType]() -> Int:
    """The distance between two elements, which is what C calls `sizeof`.

    `sizeof` is not reachable from Mojo, so this measures the same thing by
    laying out two of them. A struct whose size disagrees with C is one libc
    will write past the end of.
    """
    var p = unsafe_alloc[T](2)
    var gap = Int(p.unsafe_offset(1)) - Int(p)
    p.unsafe_free()
    return gap


def test_sizes() raises:
    assert_equal(stride[Stat](), 144, "struct stat is 144 bytes")
    assert_equal(stride[rusage](), 144, "struct rusage is 144 bytes")
    assert_equal(stride[Rlimit](), 16, "struct rlimit is 16 bytes")
    assert_equal(stride[timeval](), 16, "struct timeval is 16 bytes")
    assert_equal(stride[timespec](), 16, "struct timespec is 16 bytes")
    assert_equal(stride[tm](), 56, "struct tm is 56 bytes")
    assert_equal(stride[socketaddr](), 16, "struct sockaddr is 16 bytes")

    # Opaque: bigger than what either platform has, so libc cannot overrun it.
    assert_true(
        stride[mbstate_t]() >= 16, "mbstate_t holds at least the real state"
    )
    assert_true(
        stride[pthread_attr_t]() >= 56, "pthread_attr_t holds glibc's 56 bytes"
    )
    assert_true(
        stride[pthread_condattr_t]() >= 4,
        "pthread_condattr_t holds glibc's 4 bytes",
    )


def test_stat_reads_a_real_file() raises:
    var buf = unsafe_alloc[Stat](1)
    buf[] = Stat()

    var c_path = string_to_char_ptr("/dev/null")
    assert_equal(stat(c_path, buf), 0, "stat succeeded")
    c_path.unsafe_free()

    # A character device, so the size is not meaningful, but the device number,
    # the mode and a timestamp are.
    assert_true(buf[].rdev() != 0, "/dev/null has a device number")
    assert_true(buf[].mode() != 0, "/dev/null has a mode")
    assert_true(buf[].mtime() > 0, "/dev/null has a timestamp")

    buf.unsafe_free()


def test_stat_on_a_regular_file() raises:
    # The members whose offsets differ between the platforms: `st_mode` and
    # `st_nlink` are 4 and 6 bytes in on Darwin but 24 and 16 on Linux, and
    # `st_blksize` is 32 bits there and 64 here.
    var path = string_to_char_ptr("/tmp/libc-layout-test")
    var fd = open(path, 65, 384)  # O_WRONLY | O_CREAT, then 0600
    assert_true(fd >= 0, "the file was created")
    _ = write(fd, string_to_char_ptr("x"), 1)

    var buf = unsafe_alloc[Stat](1)
    buf[] = Stat()
    assert_equal(fstat(fd, buf), 0, "fstat succeeded")

    assert_true(buf[].mode() != 0, "the file has a mode")
    assert_equal(buf[].nlink(), 1, "a new file has one link")
    assert_true(buf[].uid() > 0, "the file has an owner")
    assert_equal(buf[].size(), 1, "the file holds the byte written")
    assert_true(
        buf[].blksize() > 0 and buf[].blksize() <= 1 << 20,
        "the file has a plausible block size",
    )

    buf.unsafe_free()
    _ = close(fd)
    _ = unlink(path)
    path.unsafe_free()


def test_rusage_and_rlimit() raises:
    var usage = unsafe_alloc[rusage](1)
    usage[] = rusage()
    assert_equal(getrusage(0, usage), 0, "getrusage succeeded")  # RUSAGE_SELF
    # Any process that has run at all has a high-water mark.
    assert_true(usage[].ru_maxrss > 0, "maxrss was reported")
    usage.unsafe_free()

    var limit = unsafe_alloc[Rlimit](1)
    limit[] = Rlimit()
    assert_equal(getrlimit(RLIMIT_NOFILE, limit), 0, "getrlimit succeeded")
    assert_true(limit[].rlim_cur > 0, "there is a soft limit on descriptors")
    assert_true(
        limit[].rlim_max >= limit[].rlim_cur, "the hard limit is not lower"
    )
    limit.unsafe_free()


def main() raises:
    test_sizes()
    test_stat_reads_a_real_file()
    test_stat_on_a_regular_file()
    test_rusage_and_rlimit()
    print("test_layout: ok")
