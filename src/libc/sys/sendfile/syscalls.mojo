# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


def sendfile(
    out_fd: Int32, in_fd: Int32, offset: c_ptr[Int64], count: Int64
) -> Int64:
    """C library <sys/sendfile.h> function `sendfile`.

    Reference:
        https://man7.org/linux/man-pages/man2/sendfile.2.html

    Args:
        out_fd: Output file descriptor.
        in_fd: Input file descriptor.
        offset: Offset in bytes.
        count: Number of bytes to transfer.

    Description:
        sendfile() transfers data between two file descriptors.

    Returns:
        Int64: number of bytes transferred.
    """
    return external_call["sendfile", Int64, Int32, Int32, c_ptr[Int64], Int64](
        out_fd, in_fd, offset, count
    )
