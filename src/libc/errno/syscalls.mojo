# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import unsafe_stack_allocation
from std.sys import CompilationTarget

from libc.constant import c_ptr


def set_errno(value: Int32) raises:
    """Set the value of the `errno` global variable for the current thread.

    Args:
        value: The value to set `errno` to.

    Notes:
        `errno` is a macro in C, so this writes through `__errno_location()` on
        glibc and `__error()` on Darwin, the two symbols `get_errno` reads.
        Nothing in libc clears it, which is the usual reason to want this.
    """
    comptime if CompilationTarget.is_macos():
        external_call["__error", c_ptr[Int32]]()[] = value
    else:
        external_call["__errno_location", c_ptr[Int32]]()[] = value


def get_errno() -> Int32:
    """Get a copy of the current value of the `errno` global variable for the
    current thread.

    Returns:
        A copy of the current value of `errno` for the current thread.
    """

    comptime if CompilationTarget.is_macos():
        # macOS exports `__error()` instead of the glibc `__errno_location()`.
        return external_call["__error", c_ptr[Int32]]()[]
    else:
        return external_call["__errno_location", c_ptr[Int32]]()[]
