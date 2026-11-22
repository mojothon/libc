# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_ptr
from std.sys import CompilationTarget
from libc.time import timespec


# The scheduling policies. POSIX fixes a number for none of them, and
# the two platforms happen to agree on one out of the three: OTHER is
# 0 here and 1 there, FIFO is 1 here and 4 there, and RR is 2 on
# both. That last one is a coincidence rather than a rule, and it is
# the sort of thing a reader would otherwise take for granted and then
# carry to the other two.
comptime SCHED_OTHER: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime SCHED_FIFO: Int32 = 4 if CompilationTarget.is_macos() else 1
comptime SCHED_RR: Int32 = 2


# Where the priority sits: first, on both platforms. Darwin's struct has a
# second word after it — a `char __opaque[4]` the kernel writes and nothing
# here reads — which is why its param is 8 bytes against glibc's 4.
#
# Numbers from glibc's `sched.h` and XNU's, and checked with C's `offsetof`
# by `scripts/check-layouts.py`.
comptime SCHED_PARAM_PRIORITY_OFFSET: Int = 0


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
        self._slots[SCHED_PARAM_PRIORITY_OFFSET // 4] = priority

    def __init__(out self):
        """Zeroes the priority, which is what a fresh param is."""
        self = Self(0)

    def sched_priority(self) -> Int32:
        """The priority, the first word of the struct on both platforms."""
        return self._slots[SCHED_PARAM_PRIORITY_OFFSET // 4]

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


# `sched_getcpucount` is not here. It is FreeBSD's, and neither platform this
# package targets has it: glibc's `<sched.h>` does not declare it and exports
# no such symbol, and Darwin's `<sched.h>` — a link to `pthread/sched.h` — has
# only `sched_yield` and the two priority bounds. Counting the bits of a set
# `sched_getaffinity` filled in is what is left, and is what the test does.


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
        policy: The policy as a number. `SCHED_OTHER` is bound here
            and is 0 on Linux and 1 on Darwin; the real-time policies
            are the caller's to name, and to have the privilege for.
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


def sched_getcpu() -> Int32:
    """C library <sched.h> function `sched_getcpu`.

    Reference:
        https://man7.org/linux/man-pages/man3/sched_getcpu.3.html

    Description:
        Which processor the calling thread is running on, as a
        number -- the one answer a caller that means to pin work,
        to watch a thread move, or to ask after the fairness of
        a schedule starts from.

    Returns:
        The number of the processor, starting from zero.

    Notes:
        The wrapper has been in the C library since 2.6, and
        the answer is a reading and not a promise: a thread
        that the scheduler moves is answered with a different
        number the next time, which is not a lie but a word
        about when the question was asked. The caller that
        wants the reading to stay is the caller that sets the
        affinity, which is the other side of this header.
    """
    return external_call["sched_getcpu", Int32]()


def getcpu(cpu: c_ptr[UInt32], node: c_ptr[UInt32]) -> Int32:
    """C library <sched.h> function `getcpu`.

    Reference:
        https://man7.org/linux/man-pages/man2/getcpu.2.html

    Description:
        Which processor and which node of the machine's memory the
        calling thread is running on, written where the caller
        points -- the pair behind `sched_getcpu`'s one number, the
        node being the half of the answer that says which memory
        is near.

    Args:
        cpu: Where the processor number is written, or a null
            pointer where the caller does not want it.
        node: Where the node number is written, or a null pointer
            where the caller does not want it.

    Returns:
        0 on success, -1 with `errno` saying why.

    Notes:
        The wrapper has been in the C library since 2.29, and
        the asking takes what it takes: either pointer may be
        null, the kernel writing only what is asked for, which
        is how a caller that wants one half of the pair asks
        for one half of the pair. The numbers are the same
        reading `sched_getcpu` gives, taken with the node
        beside it -- and they are readings, both: a thread
        that moves between the ask and the use of the answer
        is a thread whose answer has aged, and the caller
        that minds pins the thread first.
    """
    return external_call["getcpu", Int32, c_ptr[UInt32], c_ptr[UInt32]](
        cpu, node
    )
