# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


struct rusage(TrivialRegisterPassable):
    """Opaque `struct rusage` from <sys/resource.h>."""

    pass


def waitpid(pid: Int32, status: c_ptr[Int32], options: Int32) -> Int32:
    return external_call["waitpid", Int32, Int32, c_ptr[Int32], Int32](
        pid, status, options
    )


def wait(status: c_ptr[Int32]) -> Int32:
    return waitpid(-1, status, 0)


def wait4(
    pid: Int32, status: c_ptr[Int32], options: Int32, rusage: c_ptr[rusage]
) -> Int32:
    return waitpid(pid, status, options)


def wait4Impl(
    pid: Int32, status: c_ptr[Int32], options: Int32, rusage: c_ptr[rusage]
) -> Int32:
    return wait4(pid, status, options, rusage)
