# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr


def setjmp(env: c_ptr[UInt8]) -> Int32:
    """Libc `setjmp`, which records where execution is.

    Args:
        env: Where to store the saved registers. C's `jmp_buf` is 200 bytes on
            x86-64 glibc and a different size elsewhere, so give this at least
            `sizeof(jmp_buf)` bytes for the platform you are on.

    Returns:
        0 when it recorded the position, or the value `longjmp` was called
        with when it is returning to one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/setjmp.3.html).
        Fn signature: `int setjmp(jmp_buf env)`.
    """
    return external_call["setjmp", Int32, c_ptr[UInt8]](env)


def longjmp(env: c_ptr[UInt8], val: Int32) raises:
    """Libc `longjmp`, which jumps back to where `setjmp` recorded.

    Args:
        env: The position `setjmp` recorded.
        val: The value `setjmp` should appear to return, or 1 if you pass 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/longjmp.3.html).
        Fn signature: `void longjmp(jmp_buf env, int val)`.

        Undefined from Mojo. This jumps over Mojo frames without running the
        destructors they would run, so anything holding memory at the jump
        target leaks, and Mojo's own error handling has no idea it happened.
        It is bound because it exists, not because it works.
    """
    external_call["longjmp", NoneType, c_ptr[UInt8], Int32](env, val)
