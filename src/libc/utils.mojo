# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.sys.info import is_64bit

from .constant import c_char, c_int, c_ptr, c_schar, c_void


def strlen(s: c_ptr[UInt8]) -> Int:
    """
    Libc POSIX `strlen` function.

    Reference: https://man7.org/linux/man-pages/man3/strlen.3p.html
    Fn signature: size_t strlen(const char *s)

    Args: s: A pointer to a C string.
    Returns: The length of the string.
    """
    return external_call["strlen", Int, c_ptr[UInt8]](s)


def exit(status: c_int):
    """Libc POSIX `exit` function.

    Reference: https://man7.org/linux/man-pages/man3/exit.3.html
    Fn signature: void exit(int status)

    Args:
        status: The exit status.
    Returns:
        Nothing: this one does not come back. What is buffered is
        written out and the process is over by the time it would
        have.
    """
    _ = external_call["exit", c_void, c_int](status)


def string_to_char_ptr(s: String) -> c_ptr[UInt8]:
    """
    Convert a string(only ASCII-characters) to a char pointer.

    The returned buffer is NUL terminated and owned by the caller: release
    it with `ptr.unsafe_free()` when it is no longer needed.
    """
    var length = s.byte_length()
    var ptr = unsafe_alloc[UInt8](length + 1)
    var i = 0
    for byte in s.bytes():
        ptr.unsafe_store(i, byte)
        i += 1
    ptr.unsafe_store(length, 0)
    return ptr


def char_ptr_to_string(c: c_ptr[UInt8]) -> String:
    """
    Convert a char pointer to a string.
    """
    var length = strlen(c)
    return String(unsafe_from_utf8=Span[UInt8](unsafe_ptr=c, length=length))


def null_ptr[T: AnyType]() -> c_ptr[T]:
    """
    Build a null `T *` to hand to C.

    Mojo pointers are non-nullable, which leaves no spelling for the NULL
    plenty of libc entry points expect: `strtok`'s continuation call,
    `time`'s destination, `nanosleep`'s remainder. Building one from the
    address 0 at runtime is the way out.

    Use it only as an argument. Never read through it.
    """
    var address: Int = 0
    return c_ptr[T](unsafe_from_address=address)


struct CString(TrivialRegisterPassable, Writable):
    """A borrowed view over a NUL terminated C string."""

    var data: c_ptr[c_schar]

    def __init__(out self, data: c_ptr[c_char]):
        self.data = data.unsafe_bitcast[c_schar]()

    def __str__(self) -> String:
        """
        Convert a CString to a String.
        """
        var bytes = self.data.unsafe_bitcast[UInt8]()
        return String(
            unsafe_from_utf8=Span[UInt8](unsafe_ptr=bytes, length=strlen(bytes))
        )

    def write_to[W: Writer](self, mut writer: W):
        """Write the wrapped C string, so `print()` and `String()` work."""
        writer.write(self.__str__())


@inline(.nodebug)
def is_x86_64() -> Bool:
    """
    Check if the current platform is x86_64.
    """
    return CompilationTarget.is_x86() and is_64bit()
