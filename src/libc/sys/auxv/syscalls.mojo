# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

# What `getauxval` is asked for. Linux keeps this table on the stack
# for the loader to hand over; Darwin has no such table and no
# `getauxval` either, so the number here is only where it exists.
comptime AT_NULL: UInt64 = 0
comptime AT_PAGESZ: UInt64 = 0 if CompilationTarget.is_macos() else 6


def getauxval(type: UInt64) -> UInt64:
    """C library <sys/auxv.h> function `getauxval`.

    Reference:
        https://man7.org/linux/man-pages/man3/getauxval.3.html

    Args:
        type: The identifier associated with the value to retrieve.

    Returns:
        The value associated with the given identifier, or 0 if the identifier is not found.
    """
    return external_call["getauxval", UInt64, UInt64](type)
