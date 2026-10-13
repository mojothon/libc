from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import *
from libc.dlfcn import RTLD_GLOBAL, RTLD_LAZY, RTLD_NOW
from libc.fcntl import F_LOCK, F_TLOCK, F_TEST, F_ULOCK, O_TMPFILE
from libc.sched import SCHED_FIFO, SCHED_OTHER, SCHED_RR
from libc.signal import (
    SIGSTKSZ,
    SIGKILL,
    SIGTERM,
    SIGHUP,
    SIG_DFL,
    SIG_IGN,
    SIG_ERR,
    SIG_BLOCK,
    SIG_UNBLOCK,
    SIG_SETMASK,
)
from libc.stdlib import (
    HUGE_VAL,
    HUGE_VALF,
    LONG_MAX,
    LONG_MIN,
    PATH_MAX,
    RAND_MAX,
    ULLONG_MAX,
    ULONG_MAX,
)
from libc.sys.prctl import PR_GET_NAME, PR_GET_TSC, PR_SET_NAME, PR_SET_TSC
from libc.sys.random import GRND_INSECURE
from libc.sys.resource import (
    PRIO_PGRP,
    PRIO_PROCESS,
    PRIO_USER,
    RUSAGE_CHILDREN,
    RUSAGE_SELF,
)
from libc.sys.socket import SOCK_CLOEXEC, SOCK_NONBLOCK
from libc.sys.wait import WCONTINUED, WNOHANG, WUNTRACED
from libc.time import CLOCKS_PER_SEC
from libc.unistd import SC_PAGESIZE


def test_int_bounds() raises:
    assert_equal(Int(INT_MIN), -2147483648)
    assert_equal(Int(INT_MAX), 2147483647)


def test_c_types() raises:
    assert_equal(Int(c_schar(-1)), -1)
    assert_equal(Int(c_uchar(255)), 255)
    assert_equal(Int(c_short(-2)), -2)
    assert_equal(Int(c_ushort(65535)), 65535)
    assert_equal(Int(c_int(-3)), -3)
    assert_equal(Int(c_uint(4294967295)), 4294967295)
    assert_equal(Int(c_long(-4)), -4)
    assert_equal(Int(c_ulong(5)), 5)


def test_stdio_constants() raises:
    assert_equal(STDIN_FILENO, 0)
    assert_equal(STDOUT_FILENO, 1)
    assert_equal(STDERR_FILENO, 2)
    assert_equal(SEEK_SET, 0)
    assert_equal(SEEK_CUR, 1)
    assert_equal(SEEK_END, 2)


def test_signal_constants() raises:
    assert_equal(SIGHUP, 1)
    assert_equal(SIGKILL, 9)
    assert_equal(SIGTERM, 15)
    assert_equal(SIG_DFL, 0)
    assert_equal(SIG_IGN, 1)
    assert_equal(SIG_ERR, -1)
    assert_equal(SIG_BLOCK, 0)
    assert_equal(SIG_UNBLOCK, 1)
    assert_equal(SIG_SETMASK, 2)
    # The one of these that differs: 131072 on Darwin, 8192 here.
    assert_equal(
        Int(SIGSTKSZ), 131072 if CompilationTarget.is_macos() else 8192
    )


def test_the_rest() raises:
    assert_equal(RTLD_LAZY, 1)
    assert_equal(RTLD_NOW, 2)
    assert_equal(Int(RTLD_GLOBAL), 8 if CompilationTarget.is_macos() else 256)
    assert_equal(WNOHANG, 1)
    assert_equal(WUNTRACED, 2)
    assert_equal(Int(WCONTINUED), 16 if CompilationTarget.is_macos() else 8)
    assert_equal(RUSAGE_SELF, 0)
    assert_equal(RUSAGE_CHILDREN, -1)
    assert_equal(Int(PRIO_PROCESS), 0)
    assert_equal(Int(PRIO_PGRP), 1)
    assert_equal(Int(PRIO_USER), 2)
    assert_equal(RAND_MAX, 2147483647)
    assert_equal(Int(LONG_MAX), 9223372036854775807)
    assert_equal(Int(LONG_MIN), -9223372036854775808)
    assert_equal(Int(ULONG_MAX), 18446744073709551615)
    assert_equal(Int(ULLONG_MAX), 18446744073709551615)
    # Written as a literal past what a float can hold, which is infinity.
    assert_true(HUGE_VAL > 1e308, "HUGE_VAL is infinity")
    assert_true(HUGE_VALF > 1e38, "HUGE_VALF is infinity")
    assert_equal(Int(PATH_MAX), 1024 if CompilationTarget.is_macos() else 4096)
    assert_equal(Int(CLOCKS_PER_SEC), 1000000)
    assert_equal(F_ULOCK, 0)
    assert_equal(F_LOCK, 1)
    assert_equal(F_TLOCK, 2)
    assert_equal(F_TEST, 3)
    assert_equal(O_TMPFILE, 4259840)
    assert_equal(Int(SC_PAGESIZE), 29 if CompilationTarget.is_macos() else 30)
    assert_equal(
        Int(SOCK_NONBLOCK), 16384 if CompilationTarget.is_macos() else 2048
    )
    assert_equal(
        Int(SOCK_CLOEXEC), 16777216 if CompilationTarget.is_macos() else 524288
    )
    assert_equal(SCHED_OTHER, 0)
    assert_equal(SCHED_FIFO, 1)
    assert_equal(SCHED_RR, 2)
    assert_equal(GRND_INSECURE, 4)
    assert_equal(PR_SET_NAME, 15)
    assert_equal(PR_GET_NAME, 16)
    assert_equal(PR_GET_TSC, 25)
    assert_equal(PR_SET_TSC, 26)


def main() raises:
    test_int_bounds()
    test_c_types()
    test_stdio_constants()
    test_signal_constants()
    test_the_rest()
    print("test_constant: ok")
