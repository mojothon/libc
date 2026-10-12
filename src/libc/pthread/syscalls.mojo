# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from libc.constant import c_ptr


struct pthread_attr_t(TrivialRegisterPassable):
    var detachstate: Int32
    var stack: c_ptr[Int8]
    var stacksize: Int
    var guardsize: Int


struct pthread_condattr_t(TrivialRegisterPassable):
    var clockid: Int32
    var pshared: Int32


def pthread_atfork(
    prepare: c_ptr[Int8], parent: c_ptr[Int8], child: c_ptr[Int8]
) -> Int32:
    """C library <pthread.h> function `pthread_atfork`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_atfork.3.html

    Args:
        prepare: The function to be called before the fork.
        parent: The function to be called in the parent process.
        child: The function to be called in the child process.

    Returns:
        0 on success, or -1 on error.
    """
    return external_call[
        "pthread_atfork", Int32, c_ptr[Int8], c_ptr[Int8], c_ptr[Int8]
    ](prepare, parent, child)


def pthread_attr_destroy(attr: pthread_attr_t) -> Int32:
    """C library <pthread.h> function `pthread_attr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_destroy.3.html

    Args:
        attr: The attribute object to be destroyed.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call["pthread_attr_destroy", Int32, pthread_attr_t](attr)


def pthread_attr_init(attr: pthread_attr_t) -> Int32:
    """C library <pthread.h> function `pthread_attr_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_init.3.html

    Args:
        attr: The attribute object to be initialized.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call["pthread_attr_init", Int32, pthread_attr_t](attr)


def pthread_attr_getdetachstate(
    attr: pthread_attr_t, detachstate: Int32
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
        "pthread_attr_getdetachstate", Int32, pthread_attr_t, Int32
    ](attr, detachstate)


def pthread_attr_setdetachstate(
    attr: pthread_attr_t, detachstate: Int32
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
        "pthread_attr_setdetachstate", Int32, pthread_attr_t, Int32
    ](attr, detachstate)


def pthread_attr_getguardsize(
    attr: c_ptr[pthread_attr_t], guardsize: c_ptr[Int32]
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
        "pthread_attr_getguardsize", Int32, c_ptr[pthread_attr_t], c_ptr[Int32]
    ](attr, guardsize)


def pthread_attr_setguardsize(
    attr: c_ptr[pthread_attr_t], guardsize: Int32
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
        "pthread_attr_setguardsize", Int32, c_ptr[pthread_attr_t], Int32
    ](attr, guardsize)


def pthread_attr_getstack(
    attr: c_ptr[pthread_attr_t],
    stackaddr: c_ptr[c_ptr[Int8]],
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
        c_ptr[c_ptr[Int8]],
        c_ptr[Int],
    ](attr, stackaddr, stacksize)


def pthread_attr_setstack(
    attr: c_ptr[pthread_attr_t], stackaddr: c_ptr[Int8], stacksize: Int
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
        "pthread_attr_setstack", Int32, c_ptr[pthread_attr_t], c_ptr[Int8], Int
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


def pthread_condattr_destroy(attr: pthread_condattr_t) -> Int32:
    """C library <pthread.h> function `pthread_condattr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_condattr_destroy.3.html

    Args:
        attr: The attribute object to be destroyed.

    Returns:
        On success, these functions return 0; on error, they return a
       nonzero error number.
    """
    return external_call["pthread_condattr_destroy", Int32, pthread_condattr_t](
        attr
    )


# ....
# 后续补充
