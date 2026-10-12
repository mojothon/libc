# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


def getrandom(buf: c_ptr[UInt8], buflen: UInt64, flags: UInt32) -> Int:
    """C library <sys/random.h> function `getrandom`.

    Reference:
        https://man7.org/linux/man-pages/man2/getrandom.2.html

    Args:
        buf: The buffer to store the random data.
        buflen: The length of the buffer.
        flags: The flags to use for getrandom.

    Returns:
        How many bytes were written, which can be fewer than were asked
        for, or -1 on failure with `errno` set.

    Notes:
        What comes back is a signed count, because -1 is how a failure is
        reported; read through an unsigned type it would come out as the
        largest number that type can hold, and a caller asking whether
        anything went wrong would never see it.

        Asking for more than 256 bytes at a time with `GRND_INSECURE`, or
        at all from a device that has nothing to give, is what makes it
        come back short.
    """
    return external_call["getrandom", Int, c_ptr[UInt8], UInt64, UInt32](
        buf, buflen, flags
    )
