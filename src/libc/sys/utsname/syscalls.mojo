# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


def uname() -> c_ptr[Int8]:
    """C library <sys/un.h> function `uname`.
    Returns a pointer to a `struct utsname` containing information about the
    current operating system.
    """
    return external_call["uname", c_ptr[Int8]]()
