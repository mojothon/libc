# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import c_ptr

# POSIX leaves the values of these two up to the platform. glibc
# says JOINABLE is 0 and DETACHED is 1; Darwin says 1 and 2. A test
# that wants the opposite of the one it just read should ask for
# the other constant rather than pick a number.
comptime PTHREAD_CREATE_JOINABLE: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime PTHREAD_CREATE_DETACHED: Int32 = 2 if CompilationTarget.is_macos() else 1


struct pthread_attr_t:
    """An opaque `pthread_attr_t` from `<pthread.h>`.

    glibc's is 56 bytes and Darwin's is 64, so this holds the larger: every
    call takes it by pointer, which means libc only ever writes into it. The
    members are unavailable on purpose — a binding cannot tell you the
    detachstate without knowing which layout it is looking at.
    """

    # Words rather than bytes: C asks for eight-byte alignment, and `memset`
    # aside nothing here promises an unaligned one is acceptable.
    var _opaque: Array[UInt64, 8]

    def __init__(out self):
        """Zeroes the object. `pthread_attr_init` is what makes it usable."""
        self._opaque = Array[UInt64, 8](fill=0)


struct pthread_condattr_t:
    """An opaque `pthread_condattr_t` from `<pthread.h>`.

    glibc's is 4 bytes and Darwin's is 16, so this holds the larger; see
    `pthread_attr_t` for why the members are not exposed.
    """

    var _opaque: Array[UInt64, 2]

    def __init__(out self):
        """Zeroes the object. `pthread_condattr_init` is what makes it usable.
        """
        self._opaque = Array[UInt64, 2](fill=0)


def pthread_atfork(
    prepare: c_ptr[UInt8], parent: c_ptr[UInt8], child: c_ptr[UInt8]
) -> Int32:
    """C library <pthread.h> function `pthread_atfork`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_atfork.3.html

    Args:
        prepare: The function to be called before the fork.
        parent: The function to be called in the parent process.
        child: The function to be called in the child process.

    Notes:
        All three are C function pointers. Mojo cannot make one, so the only
        thing a Mojo caller can honestly pass is a null pointer for each.

        That is not the end of it. glibc exports this one as
        pthread_atfork@GLIBC_2.2.5 and exports no default version, so a
        lookup by name does not find it: the call cannot be made from
        Mojo at all, null pointers or not. A C program links it easily
        enough, which is what makes the difference easy to miss.

    Returns:
        0 on success, or -1 on error.
    """
    return external_call[
        "pthread_atfork", Int32, c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]
    ](prepare, parent, child)


def pthread_attr_destroy(attr: c_ptr[pthread_attr_t]) -> Int32:
    """C library <pthread.h> function `pthread_attr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_destroy.3.html

    Args:
        attr: The attribute object to be destroyed.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call["pthread_attr_destroy", Int32, c_ptr[pthread_attr_t]](
        attr
    )


def pthread_attr_init(attr: c_ptr[pthread_attr_t]) -> Int32:
    """C library <pthread.h> function `pthread_attr_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_init.3.html

    Args:
        attr: The attribute object to be initialized.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call["pthread_attr_init", Int32, c_ptr[pthread_attr_t]](
        attr
    )


def pthread_attr_getdetachstate(
    attr: c_ptr[pthread_attr_t], detachstate: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getdetachstate`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getdetachstate.3.html

    Args:
        attr: The attribute object to be queried.
        detachstate: The value of the detachstate attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_getdetachstate",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[Int32],
    ](attr, detachstate)


def pthread_attr_setdetachstate(
    attr: c_ptr[pthread_attr_t], detachstate: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setdetachstate`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setdetachstate.3.html

    Args:
        attr: The attribute object to be set.
        detachstate: The value of the detachstate attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_setdetachstate", Int32, c_ptr[pthread_attr_t], Int32
    ](attr, detachstate)


def pthread_attr_getguardsize(
    attr: c_ptr[pthread_attr_t], guardsize: c_ptr[UInt64]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getguardsize`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getguardsize.3.html

    Args:
        attr: The attribute object to be queried.
        guardsize: The value of the guardsize attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_getguardsize", Int32, c_ptr[pthread_attr_t], c_ptr[UInt64]
    ](attr, guardsize)


def pthread_attr_setguardsize(
    attr: c_ptr[pthread_attr_t], guardsize: UInt64
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setguardsize`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setguardsize.3.html

    Args:
        attr: The attribute object to be set.
        guardsize: The value of the guardsize attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_setguardsize", Int32, c_ptr[pthread_attr_t], UInt64
    ](attr, guardsize)


def pthread_attr_getstack(
    attr: c_ptr[pthread_attr_t],
    stackaddr: c_ptr[c_ptr[UInt8]],
    stacksize: c_ptr[Int],
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getstack`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getstack.3.html

    Args:
        attr: The attribute object to be queried.
        stackaddr: The value of the stackaddr attribute.
        stacksize: The value of the stacksize attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_getstack",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[c_ptr[UInt8]],
        c_ptr[Int],
    ](attr, stackaddr, stacksize)


def pthread_attr_setstack(
    attr: c_ptr[pthread_attr_t], stackaddr: c_ptr[UInt8], stacksize: Int
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setstack`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setstack.3.html

    Args:
        attr: The attribute object to be set.
        stackaddr: The value of the stackaddr attribute.
        stacksize: The value of the stacksize attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_setstack", Int32, c_ptr[pthread_attr_t], c_ptr[UInt8], Int
    ](attr, stackaddr, stacksize)


def pthread_attr_setstacksize(
    attr: c_ptr[pthread_attr_t], stacksize: Int
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setstacksize`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setstacksize.3.html

    Args:
        attr: The attribute object to be set.
        stacksize: The value of the stacksize attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_setstacksize", Int32, c_ptr[pthread_attr_t], Int
    ](attr, stacksize)


def pthread_attr_getstacksize(
    attr: c_ptr[pthread_attr_t], stacksize: c_ptr[Int]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getstacksize`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getstacksize.3.html

    Args:
        attr: The attribute object to be queried.
        stacksize: The value of the stacksize attribute.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_attr_getstacksize", Int32, c_ptr[pthread_attr_t], c_ptr[Int]
    ](attr, stacksize)


def pthread_condattr_destroy(attr: c_ptr[pthread_condattr_t]) -> Int32:
    """C library <pthread.h> function `pthread_condattr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_condattr_destroy.3.html

    Args:
        attr: The attribute object to be destroyed.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call[
        "pthread_condattr_destroy", Int32, c_ptr[pthread_condattr_t]
    ](attr)


# ....
# 后续补充
