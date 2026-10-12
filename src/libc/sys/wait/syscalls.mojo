# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


struct rusage(TrivialRegisterPassable):
    """A C `struct rusage`: the accounting a wait call can report.

    Linux and Darwin lay this out the same way — two `struct timeval`s and then
    fourteen `long`s — except that `tv_usec` is 32-bit on Darwin, so the slot
    reads correctly only if the struct was zeroed first, which `__init__` does.
    """

    var ru_utime_sec: Int64
    var ru_utime_usec: Int64
    var ru_stime_sec: Int64
    var ru_stime_usec: Int64
    var ru_maxrss: Int64
    var ru_ixrss: Int64
    var ru_idrss: Int64
    var ru_isrss: Int64
    var ru_minflt: Int64
    var ru_majflt: Int64
    var ru_nswap: Int64
    var ru_inblock: Int64
    var ru_oublock: Int64
    var ru_msgsnd: Int64
    var ru_msgrcv: Int64
    var ru_nsignals: Int64
    var ru_nvcsw: Int64
    var ru_nivcsw: Int64

    def __init__(out self):
        """Zeroes every member."""
        self.ru_utime_sec = 0
        self.ru_utime_usec = 0
        self.ru_stime_sec = 0
        self.ru_stime_usec = 0
        self.ru_maxrss = 0
        self.ru_ixrss = 0
        self.ru_idrss = 0
        self.ru_isrss = 0
        self.ru_minflt = 0
        self.ru_majflt = 0
        self.ru_nswap = 0
        self.ru_inblock = 0
        self.ru_oublock = 0
        self.ru_msgsnd = 0
        self.ru_msgrcv = 0
        self.ru_nsignals = 0
        self.ru_nvcsw = 0
        self.ru_nivcsw = 0


def waitpid(pid: Int32, status: c_ptr[Int32], options: Int32) -> Int32:
    """Libc POSIX `waitpid`.

    Args:
        pid: The child to wait for, or -1 for any child.
        status: Where to store the exit status, or a null pointer.
        options: `WNOHANG`, `WUNTRACED`, `WCONTINUED`, or 0.

    Returns:
        The pid of the child that changed state, 0 with `WNOHANG` when nothing
        has, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/waitpid.2.html).
        Fn signature: `pid_t waitpid(pid_t pid, int *wstatus, int options)`.
    """
    return external_call["waitpid", Int32, Int32, c_ptr[Int32], Int32](
        pid, status, options
    )


def wait(status: c_ptr[Int32]) -> Int32:
    """Libc POSIX `wait`, which waits for any child.

    Args:
        status: Where to store the exit status, or a null pointer.

    Returns:
        The pid of the child that exited, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/waitpid.2.html).
        Fn signature: `pid_t wait(int *wstatus)`.
    """
    return waitpid(-1, status, 0)


def wait4(
    pid: Int32, status: c_ptr[Int32], options: Int32, usage: c_ptr[rusage]
) -> Int32:
    """Libc BSD `wait4`, which also reports resource use.

    Args:
        pid: The child to wait for, or -1 for any child.
        status: Where to store the exit status, or a null pointer.
        options: `WNOHANG`, `WUNTRACED`, `WCONTINUED`, or 0.
        usage: Where to store the child's accounting, or a null pointer.

    Returns:
        The pid of the child that changed state, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/wait4.2.html).
        Fn signature:
            `pid_t wait4(pid_t pid, int *wstatus, int options,
            struct rusage *rusage)`.
    """
    return external_call[
        "wait4", Int32, Int32, c_ptr[Int32], Int32, c_ptr[rusage]
    ](pid, status, options, usage)
