from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.dirent import dirent
from libc.pthread import pthread_attr_t, pthread_condattr_t
from libc.sched import timespec as sched_timespec
from libc.sys.resource import Rlimit, getrlimit, getrusage
from libc.sys.socket import msghdr, socketaddr
from libc.sys.stat import Stat, fstat, stat, timespec, timeval
from libc.sys.wait import rusage

from libc.time import tm
from libc.time import timespec as time_timespec
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
    # `struct stat` is 144 bytes on Linux and 148 on Darwin; the slot
    # array is sized for the larger of the two so that the buffer
    # `stat` writes into can never be smaller than what the kernel
    # is going to write. The 152 here is the size of the struct, not
    # a per-platform difference.
    assert_equal(stride[Stat](), 152, "struct stat is 152 bytes")
    assert_equal(stride[rusage](), 144, "struct rusage is 144 bytes")
    assert_equal(stride[Rlimit](), 16, "struct rlimit is 16 bytes")
    assert_equal(stride[timeval](), 16, "struct timeval is 16 bytes")
    assert_equal(stride[timespec](), 16, "struct timespec is 16 bytes")

    # Three packages have their own `struct timespec`, and C has one width.
    assert_equal(
        stride[sched_timespec](), 16, "libc.sched's timespec is 16 bytes"
    )
    assert_equal(
        stride[time_timespec](), 16, "libc.time's timespec is 16 bytes"
    )
    assert_equal(stride[tm](), 56, "struct tm is 56 bytes")
    assert_equal(stride[socketaddr](), 16, "struct sockaddr is 16 bytes")
    assert_equal(stride[msghdr](), 56, "struct msghdr is 56 bytes")
    # 280 covers both: glibc's is 280 and Darwin's 272, and `d_name`
    # sits at 19 in one and 12 in the other, so the struct holds the
    # larger and reads each member at the offset that fits.
    assert_equal(stride[dirent](), 280, "struct dirent is 280 bytes")

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
    # the mode and a timestamp are. The device number is left out on Darwin:
    # `/dev/null` is a synthetic device there, and `rdev` answers 0.
    comptime if not CompilationTarget.is_macos():
        assert_true(buf[].rdev() != 0, "/dev/null has a device number")
    assert_true(buf[].mode() != 0, "/dev/null has a mode")
    assert_true(buf[].mtime() > 0, "/dev/null has a timestamp")

    buf.unsafe_free()


def test_stat_on_a_regular_file() raises:
    # The members whose offsets differ between the platforms: `st_mode` and
    # `st_nlink` are 4 and 6 bytes in on Darwin but 24 and 16 on Linux, and
    # `st_blksize` is 32 bits there and 64 here. /etc/hosts is a regular file
    # owned by root on both, which is what makes the numbers checkable.
    var path = string_to_char_ptr("/etc/hosts")
    var buf = unsafe_alloc[Stat](1)
    buf[] = Stat()
    assert_equal(stat(path, buf), 0, "stat succeeded")

    assert_true(buf[].mode() != 0, "the file has a mode")
    assert_equal(buf[].nlink(), 1, "/etc/hosts has one link")
    assert_equal(buf[].uid(), 0, "/etc/hosts is owned by root")
    assert_true(buf[].size() > 0, "/etc/hosts is not empty")
    assert_true(
        buf[].blksize() > 0 and buf[].blksize() <= 1 << 20,
        "the file has a plausible block size",
    )

    buf.unsafe_free()
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


def test_sched_timespec_seconds_are_wide_enough() raises:
    # `sched_rr_get_interval` fills one of these in, and C writes eight bytes
    # at `tv_sec`. A 32-bit field there reads back the low half of whatever
    # was written and says nothing about it.
    var p = unsafe_alloc[sched_timespec](1)
    p[] = sched_timespec()
    p[].tv_sec = 1 << 40
    assert_equal(p[].tv_sec, 1 << 40, "tv_sec holds a second past 2038")
    p.unsafe_free()


def test_msghdr_namelen_is_32_bits() raises:
    # `socklen_t` is 32 bits, and C writes four bytes there. A 16-bit field
    # would not even take the value, so this is a test that compiles or does
    # not. The struct is 56 bytes either way, which is why the size alone
    # says nothing about it.
    var p = unsafe_alloc[msghdr](1)
    p[].set_msg_namelen(70000)
    assert_equal(
        Int(p[].msg_namelen()), 70000, "msg_namelen holds a 32-bit length"
    )
    p.unsafe_free()


def main() raises:
    test_sizes()
    test_sched_timespec_seconds_are_wide_enough()
    test_msghdr_namelen_is_32_bits()
    test_stat_reads_a_real_file()
    test_stat_on_a_regular_file()
    test_rusage_and_rlimit()
    print("test_layout: ok")
