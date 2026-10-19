# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_ptr
from libc.time import timespec


# The scheduling policies, and the numbers are the same on both platforms.
comptime SCHED_OTHER: Int32 = 0
comptime SCHED_FIFO: Int32 = 1
comptime SCHED_RR: Int32 = 2


struct sched_param:
    """A C `struct sched_param`: the priority a scheduling call is asked for.

    glibc's is the one `int` and nothing else, which is 4 bytes. Darwin's
    carries a second word after the priority that the kernel writes and
    that nothing reads, so it is 8 there. The priority sits at the front
    on both, so it is the first word of the block either way.

    The block is the platform's own size rather than the larger of the
    two: `sched_getparam` writes the struct through the pointer it is
    handed, and a block shorter than the one C writes runs off the end.
    """

    comptime INT_SLOTS = 2 if CompilationTarget.is_macos() else 1

    var _slots: Array[Int32, Self.INT_SLOTS]

    def __init__(out self, priority: Int32):
        """Builds a param asking for `priority`.

        Args:
            priority: The scheduling priority, within the range the
                policy allows.
        """
        self._slots = Array[Int32, Self.INT_SLOTS](fill=0)
        self._slots[0] = priority

    def __init__(out self):
        """Zeroes the priority, which is what a fresh param is."""
        self = Self(0)

    def sched_priority(self) -> Int32:
        """The priority, the first word of the struct on both platforms."""
        return self._slots[0]

    def set_sched_priority(mut self, priority: Int32):
        """Sets the priority, leaving whatever else is in the block.

        Args:
            priority: The scheduling priority to ask for.
        """
        self._slots[0] = priority


def sched_get_priority_max(policy: Int32) -> Int32:
    """C library <sched.h> function `sched_get_priority_max`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_get_priority_max.2.html

    Prototype:
        int sched_get_priority_max(int policy);

    Description:
        The sched_get_priority_max() function retrieves the maximum scheduling priority for the specified scheduling policy.
        The policy argument specifies the scheduling policy whose maximum priority is to be retrieved. The valid values for the policy argument are SCHED_OTHER, SCHED_FIFO, and SCHED_RR, of which this package binds
        none: on Linux they are 0, 1 and 2, and asking about a policy the
        platform has no such number for fails with `EINVAL`.

    Arguments:
        policy: The policy to ask about, as a number.

    Return Value:
        On success, the maximum scheduling priority for the specified scheduling policy is returned. On error, -1 is returned, and errno is set to indicate the error.

    """
    return external_call["sched_get_priority_max", Int32, Int32](policy)


def sched_get_priority_min(policy: Int32) -> Int32:
    """C library <sched.h> function `sched_get_priority_min`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_get_priority_min.2.html

    Prototype:
        int sched_get_priority_min(int policy);

    Description:
        The sched_get_priority_min() function retrieves the minimum scheduling priority for the specified scheduling policy.
        The policy argument specifies the scheduling policy whose minimum priority is to be retrieved. The valid values for the policy argument are SCHED_OTHER, SCHED_FIFO, and SCHED_RR, of which this package binds
        none: on Linux they are 0, 1 and 2, and asking about a policy the
        platform has no such number for fails with `EINVAL`.

    Arguments:
        policy: The policy to ask about, as a number.

    Return Value:
        On success, the minimum scheduling priority for the specified scheduling policy is returned. On error, -1 is returned, and errno is set to indicate the error.

    """
    return external_call["sched_get_priority_min", Int32, Int32](policy)


def sched_getaffinity(
    pid: Int32, cpusetsize: UInt64, cpuset: c_ptr[Int32]
) -> Int32:
    """C library <sched.h> function `sched_getaffinity`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_getaffinity.2.html

    Prototype:
        int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *cpuset);

    Description:
        The sched_getaffinity() function retrieves the CPU affinity of the process specified by the pid argument.
        The pid argument specifies the process ID of the process whose CPU affinity is to be retrieved. The pid argument can be 0, in which case the calling process is asked about.

    Arguments:
        pid: Whose affinity to read, 0 being the caller.
        cpusetsize: How many bytes are behind `cpuset`, which is the
            thing that keeps libc from writing past it.
        cpuset: Where the mask is written. It is `c_ptr[Int32]` rather
            than a `cpu_set_t`, and there are no `CPU_*` macros here to
            build one with, so the bits are the caller's to set: a CPU
            is in the set when its bit is, CPU 0 being bit 0 of the
            first word.

    Return Value:
        On success, sched_getaffinity() returns 0. On error, -1 is returned, and errno is set to indicate the error.

    """
    return external_call[
        "sched_getaffinity", Int32, Int32, UInt64, c_ptr[Int32]
    ](pid, cpusetsize, cpuset)


def sched_getcpucount() -> Int32:
    """C library <sched.h> function `sched_getcpucount`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_getcpucount.2.html

    Prototype:
        int sched_getcpucount(void);

    Description:
        The sched_getcpucount() function returns the number of CPUs in the system.

    Return Value:
        The number of CPUs in the system.
    Notes:
        Darwin and the other BSDs only. glibc declares this in <sched.h> but
        exports no such symbol, there it is a macro over `sched_getaffinity`
        and `CPU_COUNT`, so on Linux this cannot be called.

    """
    return external_call["sched_getcpucount", Int32]()


def sched_getparam(pid: Int32, param: c_ptr[sched_param]) -> Int32:
    """C library <sched.h> function `sched_getparam`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_getparam.2.html

    Prototype:
        int sched_getparam(pid_t pid, struct sched_param *param);

    Description:
        The sched_getparam() function retrieves the scheduling parameters for the specified process.
        The pid argument specifies the process ID of the process whose scheduling parameters are to be retrieved. The pid argument can be 0, in which case the calling process is asked about.

    Arguments:
        pid: Whose parameters to read, 0 being the caller.
        param: Where they are written, as `sched_param` above, which is
            a struct of the one field C gives it.

    Return Value:
        On success, sched_getparam() returns 0. On error, -1 is returned, and errno is set to indicate the error.

    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call[
            "sched_getparam", Int32, Int32, c_ptr[sched_param]
        ](pid, param)


def sched_getscheduler(pid: Int32) -> Int32:
    """C library <sched.h> function `sched_getscheduler`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_getscheduler.2.html

    Prototype:
        int sched_getscheduler(pid_t pid);

    Description:
        The sched_getscheduler() function retrieves the scheduling policy and parameters for the specified process.
        The pid argument can be 0, in which case the calling process is asked about.
        What comes back is the policy itself, as a number, and this package binds no
        `SCHED_*` constants to compare it against: on Linux `SCHED_OTHER` is 0,
        `SCHED_FIFO` 1 and `SCHED_RR` 2.

    Arguments:
        pid: Whose policy to read, 0 being the caller.

    Return Value:
        On success, the policy is returned as a number. On error, -1 is
        returned, and errno is set to indicate the error.
    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call["sched_getscheduler", Int32, Int32](pid)


def sched_rr_get_interval(pid: Int32, interval: c_ptr[timespec]) -> Int32:
    """C library <sched.h> function `sched_rr_get_interval`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_rr_get_interval.2.html

    Prototype:
        int sched_rr_get_interval(pid_t pid, struct timespec *interval);

    Description:
        The sched_rr_get_interval() function retrieves the time slice for a round-robin scheduling policy for the specified process.
        The pid argument specifies the process ID of the process whose time slice is to be retrieved. The pid argument can be 0, in which case the calling process is changed.
        The interval argument is where the slice is written, as `timespec` above.

    Arguments:
        pid: Whose slice to read, 0 being the caller.
        interval: Where the slice is written.

    Return Value:
        On success, 0 is returned and `interval` is filled in. On error, -1
        is returned, and errno is set to indicate the error.

    """
    return external_call[
        "sched_rr_get_interval", Int32, Int32, c_ptr[timespec]
    ](pid, interval)


def sched_setaffinity(
    pid: Int32, cpusetsize: UInt64, cpuset: c_ptr[Int32]
) -> Int32:
    """C library <sched.h> function `sched_setaffinity`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_setaffinity.2.html

    Prototype:
        int sched_setaffinity(pid_t pid, size_t cpusetsize, const cpu_set_t *cpuset);

    Description:
        The sched_setaffinity() function sets the CPU affinity of the process specified by the pid argument to the set of CPUs specified by the cpuset argument.
        The pid argument specifies the process ID of the process whose CPU affinity is to be set. The pid argument can be 0, in which case the calling process is changed.
        The cpuset argument specifies the set of CPUs for which the process's CPU affinity is to be set. The cpuset argument must not be NULL: Linux answers a null pointer with `EFAULT`., in which case the process's current CPU affinity is cleared.
        The cpusetsize argument specifies the size of the cpuset argument in bytes. The size of the cpuset argument must be at least sizeof(cpu_set_t).

    Arguments:
        pid: Whose affinity to set, 0 being the caller.
        cpusetsize: How many bytes are behind `cpuset`.
        cpuset: The mask to set, as `c_ptr[Int32]`, there being no
            `CPU_*` macros here to build one with: a CPU is in the set
            when its bit is.

    Return Value:
        On success, sched_setaffinity() returns 0. On error, -1 is returned, and errno is set to indicate the error.

    """
    return external_call[
        "sched_setaffinity", Int32, Int32, UInt64, c_ptr[Int32]
    ](pid, cpusetsize, cpuset)


def sched_setparam(pid: Int32, param: c_ptr[sched_param]) -> Int32:
    """C library <sched.h> function `sched_setparam`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_setparam.2.html

    Prototype:
        int sched_setparam(pid_t pid, const struct sched_param *param);

    Description:
        The sched_setparam() function sets the scheduling parameters for the specified process.
        The pid argument specifies the process ID of the process whose scheduling parameters are to be changed. The pid argument can be 0, in which case the calling process is changed.

    Arguments:
        pid: Whose parameters to change, 0 being the caller.
        param: The parameters, of which there is the one, and it wants
            to be within what `sched_get_priority_min` and
            `sched_get_priority_max` answer for the policy already in
            force, or the call fails with `EINVAL`.

    Return Value:
        On success, sched_setparam() returns 0. On error, -1 is returned, and errno is set to indicate the error.

    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call[
            "sched_setparam", Int32, Int32, c_ptr[sched_param]
        ](pid, param)


def sched_setscheduler(
    pid: Int32, policy: Int32, param: c_ptr[sched_param]
) -> Int32:
    """C library <sched.h> function `sched_setscheduler`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_setscheduler.2.html

    Prototype:
        int sched_setscheduler(pid_t pid, int policy, const struct sched_param *param);

    Description:
        The sched_setscheduler() function sets the scheduling policy and parameters for the specified process.
        The policy and the priority in the param argument are what the process is given.
        The pid argument specifies the process ID of the process whose scheduling policy and parameters are to be changed. The pid argument can be 0, in which case the calling process is changed.
        The policy argument specifies the new scheduling policy for the process. The valid values for the policy argument are SCHED_OTHER, SCHED_FIFO, and SCHED_RR.
        The param argument specifies the new scheduling parameters, of which the
        structure has the one field: there is no `sched_slice` in `sched_param`,
        on Linux or anywhere else, and the round-robin slice is asked for with
        `sched_rr_get_interval` and set by the kernel.

    Arguments:
        pid: Whose policy to change, 0 being the caller.
        policy: The policy as a number, this package binding no
            `SCHED_*` constants: on Linux they are 0, 1 and 2.
        param: The parameters, and the priority in them wants to be
            within the range for the policy being set.

    Return Value:
        On success, sched_setscheduler() returns 0. On error, -1 is returned, and errno is set to indicate the error.

    """
    return external_call[
        "sched_setscheduler", Int32, Int32, Int32, c_ptr[sched_param]
    ](pid, policy, param)


def sched_yield() -> Int32:
    """C library <sched.h> function `sched_yield`.

    Reference:
        https://man7.org/linux/man-pages/man2/sched_yield.2.html

    Prototype:
        int sched_yield(void)

    Description:
        The sched_yield() function causes the calling thread to relinquish the CPU.
        The function is designed to give other threads a chance to run. The exact semantics are system-dependent.

    Return Value:
        On success, zero is returned. On error, -1 is returned, and errno is set to indicate the error.

    """
    return external_call["sched_yield", Int32]()
