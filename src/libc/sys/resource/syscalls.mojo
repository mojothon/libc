# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_ptr
from libc.sys.wait import rusage


# Whose usage `getrusage` is asked about. The same on both platforms.
# Which limit is meant. The two platforms number them differently:
# Linux has RLIMIT_NOFILE at 7 and RLIMIT_AS at 9, Darwin at 8 and 5.
comptime RLIMIT_NOFILE: Int32 = 8 if CompilationTarget.is_macos() else 7
comptime RLIMIT_AS: Int32 = 5 if CompilationTarget.is_macos() else 9

comptime RUSAGE_SELF: Int32 = 0
comptime RUSAGE_CHILDREN: Int32 = -1

# Whose priority it is that `getpriority` and `setpriority` work with, which
# is what tells a process id, a process group and a user apart. The same
# three numbers on both platforms.
comptime PRIO_PROCESS: Int32 = 0
comptime PRIO_PGRP: Int32 = 1
comptime PRIO_USER: Int32 = 2


struct Rlimit(TrivialRegisterPassable):
    """A C `struct rlimit`: the soft and the hard limit.

    `rlim_t` is 64-bit on both platforms this package targets, which is why
    these are not `UInt32`: `getrlimit` would overwrite eight more bytes than
    this struct has.
    """

    var rlim_cur: UInt64
    var rlim_max: UInt64

    def __init__(out self):
        """Zeroes both limits."""
        self.rlim_cur = 0
        self.rlim_max = 0


def getrlimit(resource: Int32, rlimit: c_ptr[Rlimit]) -> Int32:
    """C library <sys/resource.h> function `getrlimit`.

    Reference:
        https://man7.org/linux/man-pages/man2/getrlimit.2.html

    Args:
        resource: The resource to get the limit for.
        rlimit: The limit to get.

    Returns:
        0 on success.
    """
    return external_call["getrlimit", Int32, Int32, c_ptr[Rlimit]](
        resource, rlimit
    )


def setrlimit(resource: Int32, rlimit: c_ptr[Rlimit]) -> Int32:
    """C library <sys/resource.h> function `setrlimit`.

    Reference:
        https://man7.org/linux/man-pages/man2/setrlimit.2.html

    Args:
        resource: The resource to set the limit for.
        rlimit: The limit to set.
    Returns:
        0 on success.
    """
    return external_call["setrlimit", Int32, Int32, c_ptr[Rlimit]](
        resource, rlimit
    )


def prlimit(
    pid: Int32,
    resource: Int32,
    new_limit: c_ptr[Rlimit],
    old_limit: c_ptr[Rlimit],
) -> Int32:
    """C library <sys/resource.h> function `prlimit`.

    Reference:
        https://man7.org/linux/man-pages/man2/prlimit.2.html

    Args:
        pid: The process ID to set the limit for.
        resource: The resource to set the limit for.
        new_limit: The new limit to set.
        old_limit: The old limit to set.

    Returns:
        0 on success.
    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call[
            "prlimit", Int32, Int32, Int32, c_ptr[Rlimit], c_ptr[Rlimit]
        ](pid, resource, new_limit, old_limit)


def getrusage(who: Int32, usage: c_ptr[rusage]) -> Int32:
    """Libc POSIX `getrusage`.

    Args:
        who: `RUSAGE_SELF` for the calling process, `RUSAGE_CHILDREN` for its
            terminated children.
        usage: Where to store the accounting.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/getrusage.2.html).
        Fn signature: `int getrusage(int who, struct rusage *usage)`.
    """
    return external_call["getrusage", Int32, Int32, c_ptr[rusage]](who, usage)


def getpriority(which: Int32, who: UInt32) -> Int32:
    """C library <sys/resource.h> function `getpriority`.

    Reference:
        https://man7.org/linux/man-pages/man2/getpriority.2.html

    Prototype:
        int getpriority(int which, id_t who)

    Description:
        The getpriority() function reads the niceness of a process, process
        group or user, which is the number the scheduler weighs when sharing
        the processor out: the lower it is, the more of the processor that
        gets. Twenty points either side of zero is the range, with twenty
        reserved in it and available to be raised by whoever owns the
        process, while going lower than whatever it started at is a thing
        privileges are needed for.

    Arguments:
        which: Whether `who` names a process, a group or a user, one of
            `PRIO_PROCESS`, `PRIO_PGRP` and `PRIO_USER`.
        who: Who to ask about, understood according to `which`. Zero means
            the caller: this process, its group, or the user running it.

    Return Value:
        The niceness, somewhere from -20 to 19. Minus one is a niceness
        rather than an answer, so it cannot be told from failure by looking
        at it: set errno to 0 first, and then this returning -1 with errno
        set is what failure looks like. Asking errno anything without having
        zeroed it reads whatever an earlier call left behind.
    """
    return external_call["getpriority", Int32, Int32, UInt32](which, who)


def setpriority(which: Int32, who: UInt32, prio: Int32) -> Int32:
    """C library <sys/resource.h> function `setpriority`.

    Reference:
        https://man7.org/linux/man-pages/man2/setpriority.2.html

    Prototype:
        int setpriority(int which, id_t who, int prio)

    Description:
        The setpriority() function sets the niceness of a process, process
        group or user.

        Lowering it takes privileges, so this is mostly used the other way:
        raising a niceness gives the processor back to whatever else wants
        it, and any process may do that much to itself. Going back down is
        not then something it is allowed to do on its own, short of root —
        which is why being careful about which way this is being moved
        matters more than it looks.

    Arguments:
        which: Whether `who` names a process, a group or a user, one of
            `PRIO_PROCESS`, `PRIO_PGRP` and `PRIO_USER`.
        who: Who to set the niceness of, understood according to `which`.
            Zero means the caller.
        prio: The niceness to set, from -20 to 19. Anything outside is
            quietly pulled to whichever end it passed, so asking for 100
            gives 19 rather than an error.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error: EPERM for trying to lower a niceness
        without being allowed to, ESRCH when nothing matches `which` and
        `who`, and EINVAL when `which` is none of the three.
    """
    return external_call["setpriority", Int32, Int32, UInt32, Int32](
        which, who, prio
    )


def nice(inc: Int32) -> Int32:
    """C library <unistd.h> function `nice`.

    Reference:
        https://man7.org/linux/man-pages/man2/nice.2.html

    Prototype:
        int nice(int inc)

    Description:
        The nice() function moves this process's niceness by `inc`, which is
        the older and smaller way of doing what `setpriority` does: it can
        only reach the caller, it can only be told how far to move rather
        than where to land, and a negative `inc` asks for privileges and is
        answered with EPERM on failure. `getpriority` is how the result is
        read afterwards, this having nothing to say about it.

    Arguments:
        inc: How much to add to the niceness. Zero asks for no change and
            so reads it, in the roundabout way this allows.

    Return Value:
        The new niceness on success, or -1 with errno set on failure, which
        is the same trouble `getpriority` has: -1 being both one of the
        answers and the failure signal is why errno has to be zeroed before
        and read after, to know which of the two this was.
    """
    return external_call["nice", Int32, Int32](inc)
