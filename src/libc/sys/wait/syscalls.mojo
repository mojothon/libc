# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_ptr
from libc.signal import siginfo_t


# What `waitpid` is asked for. `WNOHANG` and `WUNTRACED` are the same
# number on both platforms; `WCONTINUED` is 8 here and 16 there.
comptime WNOHANG: Int32 = 1
comptime WUNTRACED: Int32 = 2
comptime WCONTINUED: Int32 = 16 if CompilationTarget.is_macos() else 8

# What `waitid` is asked for, which is a different set from the three
# above. `P_ALL`, `P_PID` and `P_PGID` say which children and are 0, 1
# and 2 on both platforms, and `WEXITED` is 4 on both. `WSTOPPED` and
# `WNOWAIT` are not the same: `WSTOPPED` is 2 here and 8 there, and
# `WNOWAIT` is 0x01000000 here and 0x20 there.
comptime P_ALL: Int32 = 0
comptime P_PID: Int32 = 1
comptime P_PGID: Int32 = 2
comptime WEXITED: Int32 = 4
comptime WSTOPPED: Int32 = 8 if CompilationTarget.is_macos() else 2
comptime WNOWAIT: Int32 = 32 if CompilationTarget.is_macos() else 16777216

# What the `si_code` of a child says: that it left of its own accord,
# that it was killed, and that it was killed and a core file written.
comptime CLD_EXITED: Int32 = 1
comptime CLD_KILLED: Int32 = 2
comptime CLD_DUMPED: Int32 = 3


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


def waitid(
    idtype: Int32, id: Int32, infop: c_ptr[siginfo_t], options: Int32
) -> Int32:
    """Libc POSIX `waitid`, which waits for a child and says what it
    did in a `siginfo_t` rather than in a status word.

    Args:
        idtype: `P_PID` for the child `id` names, `P_PGID` for any in
            the process group `id` names, or `P_ALL` for any child at
            all, in which case `id` is not looked at.
        id: The pid or the process group, which `P_ALL` ignores.
        infop: Where the answer is written: `si_pid`, `si_uid`,
            `si_status` and `si_code` are the four that say something.
        options: `WEXITED`, `WSTOPPED`, `WCONTINUED`, `WNOWAIT` or any
            combination of them, and at least one of the first three.

    Returns:
        0 where a child was reported on, or -1 with `errno` set. It is
        the one in here that does not answer with the pid, the pid
        being in the `siginfo_t` instead.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/waitid.2.html).
        Fn signature: `int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options)`.

        `WNOWAIT` is what makes it more than another way of saying
        `waitpid`: the child is reported on and left there, so the
        same child can be waited for again — by a second `waitid`, or
        by `waitpid`, which is then the one that takes it back.

        `si_pid` and 0 are how the two ways of failing tell
        themselves apart: a successful call zeroes the whole of the
        `siginfo_t` before filling it in, and `WNOHANG` given to a
        `waitid` that has nothing to report leaves `si_pid` at 0 and
        answers 0 rather than -1, which no other call in here does.
    """
    return external_call[
        "waitid", Int32, Int32, Int32, c_ptr[siginfo_t], Int32
    ](idtype, id, infop, options)


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


# What a wait status says. C has these as macros, which is to say they are
# text substitution: no types, no way to name one or pass it along, and
# nothing for a debugger to step into. Here they are functions.
#
# The low seven bits say which signal ended the process and zero says none
# did, the next eight say the exit status or the stop signal, and bit 7 says
# a core was dumped. Linux and Darwin agree on all of that.
#
# `WIFCONTINUED` is not here: it is 0xffff here and 0x13 on Darwin, and a
# test would have to really continue a really stopped process to say which,
# so it is left out rather than guessed at.


def WIFEXITED(status: Int32) -> Bool:
    """Whether the process ended by exiting, as C's `WIFEXITED`.

    Args:
        status: What `wait`, `waitpid` or `wait4` wrote into its status
            argument.

    Returns:
        True when the process chose its own ending, so `WEXITSTATUS` has
        something to say.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wait.3p.html).
        False when a signal ended it or stopped it, in which case it is
        `WTERMSIG` or `WSTOPSIG` that has something to say instead.
    """
    return (status & 0x7F) == 0


def WEXITSTATUS(status: Int32) -> Int32:
    """The status the process exited with, as C's `WEXITSTATUS`.

    Args:
        status: A status `WIFEXITED` says was an exit.

    Returns:
        The low eight bits of what was given to `exit`, which is all of it
        that survives: anything above 255 is gone before this sees it.
    """
    return (status >> 8) & 0xFF


def WIFSIGNALED(status: Int32) -> Bool:
    """Whether a signal ended the process, as C's `WIFSIGNALED`.

    Args:
        status: What a wait call wrote.

    Returns:
        True when a signal ended it and it did not merely stop, so
        `WTERMSIG` has something to say.
    """
    var low = status & 0x7F
    return low != 0 and low != 0x7F


def WTERMSIG(status: Int32) -> Int32:
    """The signal that ended the process, as C's `WTERMSIG`.

    Args:
        status: A status `WIFSIGNALED` says was a signal.

    Returns:
        The signal's number.
    """
    return status & 0x7F


def WIFSTOPPED(status: Int32) -> Bool:
    """Whether the process is stopped rather than ended, as C's
    `WIFSTOPPED`.

    Args:
        status: What a wait call wrote.

    Returns:
        True when the process is stopped rather than ended, so `WSTOPSIG`
        has something to say.

    Notes:
        A status like this only comes back when the wait was asked for with
        `WUNTRACED`, or when the process is being traced.
    """
    return (status & 0xFF) == 0x7F


def WSTOPSIG(status: Int32) -> Int32:
    """The signal that stopped the process, as C's `WSTOPSIG`.

    Args:
        status: A status `WIFSTOPPED` says was a stop.

    Returns:
        The signal's number.
    """
    return (status >> 8) & 0xFF


def WCOREDUMP(status: Int32) -> Bool:
    """Whether a core was dumped, as C's `WCOREDUMP`.

    Args:
        status: A status `WIFSIGNALED` says was a signal.

    Returns:
        True when the ending left a core behind.

    Notes:
        Not in POSIX, and it is a promise about the past rather than a
        setting: the core is written by the kernel on the way out, and a
        resource limit of 0 on core size is one way for this to be false
        of a signal that would otherwise have written one.
    """
    return (status & 0x80) != 0


def wait3(status: c_ptr[Int32], options: Int32, usage: c_ptr[rusage]) -> Int32:
    """Libc BSD `wait3` function.

    Description:
        Waits for any child to leave, and says what it used while it
        was here.

    Args:
        status: Where to write how it left, which is written to, or a
            null pointer where that is not wanted.
        options: Which of the `W` names to wait by — `WNOHANG` to come
            back at once where none has left, and 0 to wait.
        usage: Where to write what the child used, which is written
            to, or a null pointer where that is not wanted.

    Returns:
        The number of the child that left, or -1 where there was none
        to wait for, with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wait3.3.html).
        Fn signature: `pid_t wait3(int *stat_loc, int options,
            struct rusage *rusage)`.

        This is `wait4` without the pid, which is to say it waits for
        any child rather than for one it is named: `wait4` takes the
        pid as its first argument and is otherwise this. Both are the
        ones that say what the child used, which `waitpid` does not.

        `rusage` is bound in this module, and is what `usage` points
        at.
    """
    return external_call["wait3", Int32, c_ptr[Int32], Int32, c_ptr[rusage]](
        status, options, usage
    )
