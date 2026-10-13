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
    """Copy a `String` out into a buffer C can be given.

    The bytes go across one at a time, so what C sees is the UTF-8 the
    `String` was already holding rather than a version of it: a character
    outside ASCII arrives as its bytes, and is neither turned into one
    byte nor turned into a `?`.

    Args:
        s: The text to copy out.

    Returns:
        A pointer to a fresh buffer of `s.byte_length() + 1` bytes, the
        last of which is the NUL. It is the caller's, and
        `ptr.unsafe_free()` is what takes it back.
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
    """Wrap a C string in a `String`.

    It measures with `strlen`, so the buffer does want a NUL: one without
    one sends it reading past the end. It copies nothing either, so what
    comes back borrows the bytes and is only good while the buffer is.
    And the bytes go in as they are, so a buffer that is not UTF-8 gives
    a `String` that is not well-formed text, which is the thing
    `unsafe_from_utf8` is called unsafe for.

    Args:
        c: A NUL terminated buffer to read.

    Returns:
        The bytes up to the NUL, as a `String` that borrows them.
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

    Returns:
        A `c_ptr[T]` holding the address 0, which is what C means
        by NULL.
    """
    var address: Int = 0
    return c_ptr[T](unsafe_from_address=address)


def is_null[T: AnyType](p: c_ptr[T]) -> Bool:
    """Say whether a pointer libc handed back is NULL.

    A great many entry points here answer with a null pointer when they
    fail: `fopen` on a file that is not there, `dlopen` on a library
    that will not load, `getcwd` when the buffer is too small, `strstr`
    when the needle is not in the haystack. There is no comparing one of
    those against NULL on this side of the call, because Mojo pointers
    are not nullable and there is no null to compare them with, so
    asking what address it holds is the only way to find out.

    Args:
        p: What came back from C.

    Returns:
        True when it is NULL, which is how most of these say they
        failed. Reading through it either way is on you.
    """
    return Int(p) == 0


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
    """Check whether the platform this was compiled for is x86-64.

    It asks `CompilationTarget`, so it is the target that answers and not
    the machine the binary ends up running on: one built for x86-64 and
    run translated still says True.

    Returns:
        True when the target is x86-64.
    """
    return CompilationTarget.is_x86() and is_64bit()
