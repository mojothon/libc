# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import unsafe_stack_allocation
from std.sys import CompilationTarget

from libc.constant import c_ptr


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
