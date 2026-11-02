# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_ptr


# Linux's own: Darwin's getentropy takes no flags.
comptime GRND_INSECURE: UInt32 = 4


def getentropy(buf: c_ptr[UInt8], size: UInt64) -> Int32:
    """C library <sys/random.h> function `getentropy`.

    Reference:
        https://man7.org/linux/man-pages/man3/getentropy.3.html

    Args:
        buf: The buffer to store the random data.
        size: How many bytes to fill, which is at most 256.

    Returns:
        0, or -1 with `errno` set — `EIO` when more than 256 bytes are
        asked for, and whatever the kernel has to say otherwise.

    Notes:
        The portable one of the pair: Darwin has it as well, so this is
        the call to use where `getrandom` is not there. C declares it in
        `<unistd.h>` as well as here, which is the usual arrangement for
        a function that both platforms agreed on late.

        Two hundred and fifty-six bytes is the whole of a call, and the
        limit is the same on both — not because the kernel runs out but
        because a longer request would be one a caller could not tell
        apart from a short one. A caller that needs more asks again.

        The bytes are not a stream: nothing here advances a position, so
        two calls are two independent answers rather than a continuation.
    """
    return external_call["getentropy", Int32, c_ptr[UInt8], UInt64](buf, size)


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

        `getrandom` is Linux-specific, the man page says so on its first
        line. The BSDs use `arc4random_buf` or read from `/dev/urandom`.
    """
    comptime if CompilationTarget.is_macos():
        return -1
    else:
        return external_call["getrandom", Int, c_ptr[UInt8], UInt64, UInt32](
            buf, buflen, flags
        )
