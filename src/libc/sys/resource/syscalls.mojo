# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr
from libc.sys.wait import rusage


# Whose usage `getrusage` is asked about. The same on both platforms.
comptime RUSAGE_SELF: Int32 = 0
comptime RUSAGE_CHILDREN: Int32 = -1


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
