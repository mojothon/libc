# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


struct Timeval(TrivialRegisterPassable):
    var tv_sec: Int32
    var tv_usec: Int32


def select(
    nfds: Int32,
    read_set: c_ptr[NoneType],
    write_set: c_ptr[NoneType],
    error_set: c_ptr[NoneType],
    timeout: c_ptr[Timeval],
) -> Int32:
    """C library <sys/select.h> function `select`.

    Reference:
        https://pubs.opengroup.org/onlinepubs/9699919799/functions/select.html

    Args:
        nfds: Number of file descriptors to check.
        read_set: Set of file descriptors to check for read availability.
        write_set: Set of file descriptors to check for write availability.
        error_set: Set of file descriptors to check for error availability.
        timeout: Timeout in seconds and microseconds .

    Returns:
        Int32: number of file descriptors ready .
    """
    return external_call[
        "select",
        Int32,
        Int32,
        c_ptr[NoneType],
        c_ptr[NoneType],
        c_ptr[NoneType],
        c_ptr[Timeval],
    ](nfds, read_set, write_set, error_set, timeout)
