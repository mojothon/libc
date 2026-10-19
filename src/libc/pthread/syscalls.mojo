# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import c_ptr
from libc.time import timespec

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


# Mutex kinds. POSIX fixes no numbering for these, and the two libcs
# number them the other way round from each other: glibc has RECURSIVE
# at 1 and ERRORCHECK at 2, Darwin has ERRORCHECK at 1 and RECURSIVE
# at 2. So two of the four are one another's values, which is the
# sort of mix-up that costs nothing to make and a long time to find —
# `pthread_mutex_init` answers 0 either way, and what comes back is a
# lock of the other kind.
comptime PTHREAD_MUTEX_NORMAL: Int32 = 0
comptime PTHREAD_MUTEX_ERRORCHECK: Int32 = 1 if CompilationTarget.is_macos() else 2
comptime PTHREAD_MUTEX_RECURSIVE: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime PTHREAD_MUTEX_DEFAULT = PTHREAD_MUTEX_NORMAL

# Whether a lock may be shared between processes. SHARED is 1 on
# both; PRIVATE is 0 on glibc and 2 here.
comptime PTHREAD_PROCESS_SHARED: Int32 = 1
comptime PTHREAD_PROCESS_PRIVATE: Int32 = 2 if CompilationTarget.is_macos() else 0

# What a lock is to do about priority. These three happen to agree.
comptime PTHREAD_PRIO_NONE: Int32 = 0
comptime PTHREAD_PRIO_INHERIT: Int32 = 1
comptime PTHREAD_PRIO_PROTECT: Int32 = 2


struct pthread_mutex_t:
    """An opaque `pthread_mutex_t` from `<pthread.h>`.

    glibc's is 40 bytes and Darwin's is 64, so this holds the larger.
    Every call takes it by pointer, so libc only ever writes into it,
    and the members are not exposed: a binding cannot say what one of
    them is without knowing which layout it is looking at.

    Zeroing one is not initialising it. `pthread_mutex_init` is what
    does that. A zeroed one happens to behave as a normal lock on both
    of these libcs, which is a coincidence and not a promise.
    """

    var _opaque: Array[UInt64, 8]

    def __init__(out self):
        """Zeroes the object. `pthread_mutex_init` is what makes it usable."""
        self._opaque = Array[UInt64, 8](fill=0)


struct pthread_mutexattr_t:
    """An opaque `pthread_mutexattr_t` from `<pthread.h>`.

    glibc's is 4 bytes and Darwin's is 16, so this holds the larger;
    see `pthread_mutex_t` for why the members are not exposed.
    """

    var _opaque: Array[UInt64, 2]

    def __init__(out self):
        """Zeroes the object. `pthread_mutexattr_init` is what makes it usable.
        """
        self._opaque = Array[UInt64, 2](fill=0)


def pthread_mutex_init(
    mutex: c_ptr[pthread_mutex_t], attr: c_ptr[pthread_mutexattr_t]
) -> Int32:
    """C library <pthread.h> function `pthread_mutex_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_init.3p.html

    Prototype:
        int pthread_mutex_init(pthread_mutex_t *restrict mutex,
                               const pthread_mutexattr_t *restrict attr)

    Description:
        Makes `mutex` into a lock of the kind `attr` asks for.

    Args:
        mutex: The storage, which `pthread_mutex_destroy` gives back.
        attr: The kind, built up with the `pthread_mutexattr_*` calls
            below. `null_ptr[pthread_mutexattr_t]()` means the
            default kind, which is what most callers want.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        The answer is the error number and not -1. This package's
        other bindings answer -1 and leave it in `errno`; these do
        neither, and the difference is POSIX's rather than this
        package's.
    """
    return external_call[
        "pthread_mutex_init",
        Int32,
        c_ptr[pthread_mutex_t],
        c_ptr[pthread_mutexattr_t],
    ](mutex, attr)


def pthread_mutex_destroy(mutex: c_ptr[pthread_mutex_t]) -> Int32:
    """C library <pthread.h> function `pthread_mutex_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_destroy.3p.html

    Prototype:
        int pthread_mutex_destroy(pthread_mutex_t *mutex)

    Description:
        Gives back whatever `pthread_mutex_init` took for `mutex`.

    Args:
        mutex: The lock, which nobody is to be holding.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Destroying a lock somebody holds, or one that was never
        initialised, is undefined.
    """
    return external_call[
        "pthread_mutex_destroy", Int32, c_ptr[pthread_mutex_t]
    ](mutex)


def pthread_mutex_lock(mutex: c_ptr[pthread_mutex_t]) -> Int32:
    """C library <pthread.h> function `pthread_mutex_lock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_lock.3p.html

    Prototype:
        int pthread_mutex_lock(pthread_mutex_t *mutex)

    Description:
        Takes `mutex`, waiting until it comes free.

    Args:
        mutex: The lock.

    Returns:
        0 on success, or the error number on failure. `EDEADLK`
        comes back for locking one this caller already holds where
        the lock is not recursive.

    Notes:
        This waits. A test calling it on a lock somebody else holds
        is a test that stops.
    """
    return external_call["pthread_mutex_lock", Int32, c_ptr[pthread_mutex_t]](
        mutex
    )


def pthread_mutex_trylock(mutex: c_ptr[pthread_mutex_t]) -> Int32:
    """C library <pthread.h> function `pthread_mutex_trylock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_trylock.3p.html

    Prototype:
        int pthread_mutex_trylock(pthread_mutex_t *mutex)

    Description:
        Takes `mutex` if it is free, and says so without waiting if
        it is not.

    Args:
        mutex: The lock.

    Returns:
        0 on success, `EBUSY` where somebody else holds it, or
        another error number.

    Notes:
        This is the one to reach for in a test: it cannot hang.
    """
    return external_call[
        "pthread_mutex_trylock", Int32, c_ptr[pthread_mutex_t]
    ](mutex)


def pthread_mutex_unlock(mutex: c_ptr[pthread_mutex_t]) -> Int32:
    """C library <pthread.h> function `pthread_mutex_unlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_unlock.3p.html

    Prototype:
        int pthread_mutex_unlock(pthread_mutex_t *mutex)

    Description:
        Gives `mutex` up.

    Args:
        mutex: The lock, which this caller holds.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Unlocking a lock this caller does not hold is undefined on
        most platforms and silently permitted on some.
    """
    return external_call["pthread_mutex_unlock", Int32, c_ptr[pthread_mutex_t]](
        mutex
    )


def pthread_mutexattr_init(attr: c_ptr[pthread_mutexattr_t]) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_init.3p.html

    Prototype:
        int pthread_mutexattr_init(pthread_mutexattr_t *attr)

    Description:
        Makes `attr` into the default lock attributes.

    Args:
        attr: The storage, which `pthread_mutexattr_destroy` gives
            back.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        `attr` says nothing until this has run. The zeroed object
        `__init__` makes is not the same as this.
    """
    return external_call[
        "pthread_mutexattr_init", Int32, c_ptr[pthread_mutexattr_t]
    ](attr)


def pthread_mutexattr_destroy(attr: c_ptr[pthread_mutexattr_t]) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_destroy.3p.html

    Prototype:
        int pthread_mutexattr_destroy(pthread_mutexattr_t *attr)

    Description:
        Gives back whatever `pthread_mutexattr_init` took.

    Args:
        attr: The attributes.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Destroying the attributes once the lock is made — the usual
        order — leaves the lock alone.
    """
    return external_call[
        "pthread_mutexattr_destroy", Int32, c_ptr[pthread_mutexattr_t]
    ](attr)


def pthread_mutexattr_settype(
    attr: c_ptr[pthread_mutexattr_t], kind: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_settype`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_settype.3p.html

    Prototype:
        int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type)

    Description:
        Says what kind of lock this is to be: whether taking one twice
        is to be caught, allowed, or lose.

    Args:
        attr: The attributes, from `pthread_mutexattr_init`.
        kind: `PTHREAD_MUTEX_NORMAL`, `PTHREAD_MUTEX_ERRORCHECK`,
            `PTHREAD_MUTEX_RECURSIVE` or `PTHREAD_MUTEX_DEFAULT`.

    Returns:
        0 on success, or `EINVAL` where `kind` is none of them.

    Notes:
        **The kinds are not numbered the same on both platforms.**
        ERRORCHECK and RECURSIVE are 1 and 2 here and 2 and 1 on
        glibc, so the constants above, not bare integers, are what
        to pass. A lock of the wrong kind works until it does not,
        and `pthread_mutex_init` says nothing either time.
    """
    return external_call[
        "pthread_mutexattr_settype",
        Int32,
        c_ptr[pthread_mutexattr_t],
        Int32,
    ](attr, kind)


def pthread_mutexattr_gettype(
    attr: c_ptr[pthread_mutexattr_t], kind: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_gettype`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_gettype.3p.html

    Prototype:
        int pthread_mutexattr_gettype(
            const pthread_mutexattr_t *restrict attr, int *restrict type)

    Description:
        Says what kind of lock this is.

    Args:
        attr: The attributes.
        kind: Where the answer is to be written. Compare what comes
            back against `PTHREAD_MUTEX_NORMAL`,
            `PTHREAD_MUTEX_RECURSIVE` and `PTHREAD_MUTEX_ERRORCHECK`
            rather than against a number, the same as when setting it.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_mutexattr_gettype",
        Int32,
        c_ptr[pthread_mutexattr_t],
        c_ptr[Int32],
    ](attr, kind)


def pthread_mutexattr_setpshared(
    attr: c_ptr[pthread_mutexattr_t], pshared: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_setpshared`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_setpshared.3p.html

    Prototype:
        int pthread_mutexattr_setpshared(pthread_mutexattr_t *attr,
                                         int pshared)

    Description:
        Says whether a lock made from `attr` may be shared between
        processes.

    Args:
        attr: The attributes, from `pthread_mutexattr_init`.
        pshared: `PTHREAD_PROCESS_SHARED` or
            `PTHREAD_PROCESS_PRIVATE`.

    Returns:
        0 on success, or `EINVAL` where it is neither.

    Notes:
        PRIVATE is 0 on glibc and 2 here, while SHARED is 1 on both.
        Pass the constants above.
    """
    return external_call[
        "pthread_mutexattr_setpshared",
        Int32,
        c_ptr[pthread_mutexattr_t],
        Int32,
    ](attr, pshared)


def pthread_mutexattr_getpshared(
    attr: c_ptr[pthread_mutexattr_t], pshared: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_getpshared`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_getpshared.3p.html

    Prototype:
        int pthread_mutexattr_getpshared(
            const pthread_mutexattr_t *restrict attr, int *restrict pshared)

    Description:
        Says whether a lock made from `attr` may be shared between
    processes.

    Args:
        attr: The attributes.
        pshared: Where the answer is to be written, as
            `PTHREAD_PROCESS_SHARED` or `PTHREAD_PROCESS_PRIVATE`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_mutexattr_getpshared",
        Int32,
        c_ptr[pthread_mutexattr_t],
        c_ptr[Int32],
    ](attr, pshared)


def pthread_mutexattr_setprotocol(
    attr: c_ptr[pthread_mutexattr_t], protocol: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_setprotocol`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_setprotocol.3p.html

    Prototype:
        int pthread_mutexattr_setprotocol(pthread_mutexattr_t *attr,
                                          int protocol)

    Description:
        Says what a lock made from `attr` is to do about the priority
        of whoever holds it.

    Args:
        attr: The attributes, from `pthread_mutexattr_init`.
        protocol: `PTHREAD_PRIO_NONE`, `PTHREAD_PRIO_INHERIT` or
            `PTHREAD_PRIO_PROTECT`.

    Returns:
        0 on success, or `EINVAL` where it is none of them.

    Notes:
        All three are optional in POSIX, and a libc asked for one it
        does not carry answers `ENOTSUP`. These three are numbered
        the same on both platforms, which is the exception here
        rather than the rule.
    """
    return external_call[
        "pthread_mutexattr_setprotocol",
        Int32,
        c_ptr[pthread_mutexattr_t],
        Int32,
    ](attr, protocol)


def pthread_mutexattr_getprotocol(
    attr: c_ptr[pthread_mutexattr_t], protocol: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_getprotocol`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_getprotocol.3p.html

    Prototype:
        int pthread_mutexattr_getprotocol(
            const pthread_mutexattr_t *restrict attr, int *restrict protocol)

    Description:
        Says what a lock made from `attr` is to do about the priority
        of whoever holds it.

    Args:
        attr: The attributes.
        protocol: Where the answer is to be written, as
            `PTHREAD_PRIO_NONE`, `PTHREAD_PRIO_INHERIT` or
            `PTHREAD_PRIO_PROTECT`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_mutexattr_getprotocol",
        Int32,
        c_ptr[pthread_mutexattr_t],
        c_ptr[Int32],
    ](attr, protocol)


def pthread_mutexattr_setprioceiling(
    attr: c_ptr[pthread_mutexattr_t], prioceiling: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_setprioceiling`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_setprioceiling.3p.html

    Prototype:
        int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *attr,
                                             int prioceiling)

    Description:
        Says the priority a thread is to run at while it holds a
        lock made from `attr`.

    Args:
        attr: The attributes, from `pthread_mutexattr_init`.
        prioceiling: The priority, which is what
            `pthread_mutex_getprioceiling` reads back.

    Returns:
        0 on success, or `EINVAL` where no such priority is to be
        had.

    Notes:
        Only means anything with `PTHREAD_PRIO_PROTECT`. Where what
        is asked for is above anything this machine can give,
        `EINVAL` comes back; the highest there is is what
        `sched_get_priority_max` says.
    """
    return external_call[
        "pthread_mutexattr_setprioceiling",
        Int32,
        c_ptr[pthread_mutexattr_t],
        Int32,
    ](attr, prioceiling)


def pthread_mutexattr_getprioceiling(
    attr: c_ptr[pthread_mutexattr_t], prioceiling: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_mutexattr_getprioceiling`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutexattr_getprioceiling.3p.html

    Prototype:
        int pthread_mutexattr_getprioceiling(
            const pthread_mutexattr_t *restrict attr, int *restrict prioceiling)

    Description:
        Says the priority a thread is to run at while it holds a
        lock made from `attr`.

    Args:
        attr: The attributes.
        prioceiling: Where the answer is to be written.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_mutexattr_getprioceiling",
        Int32,
        c_ptr[pthread_mutexattr_t],
        c_ptr[Int32],
    ](attr, prioceiling)


def pthread_mutex_getprioceiling(
    mutex: c_ptr[pthread_mutex_t], prioceiling: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_mutex_getprioceiling`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_getprioceiling.3p.html

    Prototype:
        int pthread_mutex_getprioceiling(
            const pthread_mutex_t *restrict mutex, int *restrict prioceiling)

    Description:
        Says the priority a thread runs at while it holds `mutex`.

    Args:
        mutex: The lock.
        prioceiling: Where the answer is to be written.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Optional in POSIX, so a libc that does not carry it answers
        `ENOTSUP`.
    """
    return external_call[
        "pthread_mutex_getprioceiling",
        Int32,
        c_ptr[pthread_mutex_t],
        c_ptr[Int32],
    ](mutex, prioceiling)


def pthread_mutex_setprioceiling(
    mutex: c_ptr[pthread_mutex_t], prioceiling: Int32, old: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_mutex_setprioceiling`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_mutex_setprioceiling.3p.html

    Prototype:
        int pthread_mutex_setprioceiling(pthread_mutex_t *restrict mutex,
                                         int prioceiling, int *restrict old_ceiling)

    Description:
        Sets the priority a thread is to run at while it holds
        `mutex`, and says what it was before.

    Args:
        mutex: The lock, which this caller holds.
        prioceiling: The priority.
        old: Where the one that was there before is to be written.
            `null_ptr[Int32]()` means do not bother saying.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Optional in POSIX. Setting it is a no-op where the priority
        asked for is above what this machine can give.
    """
    return external_call[
        "pthread_mutex_setprioceiling",
        Int32,
        c_ptr[pthread_mutex_t],
        Int32,
        c_ptr[Int32],
    ](mutex, prioceiling, old)


struct pthread_cond_t:
    """An opaque `pthread_cond_t` from `<pthread.h>`.

    48 bytes here and on glibc, which is the one size these two agree
    on among the synchronisation objects — the others differ by a
    factor of two or more. Every call takes it by pointer and the
    members are not exposed.

    As with `pthread_mutex_t`, zeroing one is not initialising it.
    """

    var _opaque: Array[UInt64, 6]

    def __init__(out self):
        """Zeroes the object. `pthread_cond_init` is what makes it usable."""
        self._opaque = Array[UInt64, 6](fill=0)


struct pthread_rwlock_t:
    """An opaque `pthread_rwlock_t` from `<pthread.h>`.

    glibc's is 56 bytes and Darwin's is 200, so this holds the larger.
    The gap is the widest in the header — Darwin carries the lock's
    owner and its whole wait queue inside the object, while glibc
    reaches for them through pointers.

    Every call takes it by pointer and the members are not exposed.
    Zeroing one is not initialising it.
    """

    var _opaque: Array[UInt64, 25]

    def __init__(out self):
        """Zeroes the object. `pthread_rwlock_init` is what makes it usable."""
        self._opaque = Array[UInt64, 25](fill=0)


struct pthread_rwlockattr_t:
    """An opaque `pthread_rwlockattr_t` from `<pthread.h>`.

    glibc's is 8 bytes and Darwin's is 24, so this holds the larger.
    """

    var _opaque: Array[UInt64, 3]

    def __init__(out self):
        """Zeroes the object. `pthread_rwlockattr_init` is what makes it
        usable.
        """
        self._opaque = Array[UInt64, 3](fill=0)


def pthread_cond_init(
    cond: c_ptr[pthread_cond_t], attr: c_ptr[pthread_condattr_t]
) -> Int32:
    """C library <pthread.h> function `pthread_cond_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cond_init.3p.html

    Prototype:
        int pthread_cond_init(pthread_cond_t *restrict cond,
                              const pthread_condattr_t *restrict attr)

    Description:
        Makes `cond` into a thing a thread can wait on.

    Args:
        cond: The storage, which `pthread_cond_destroy` gives back.
        attr: What it is to be, built up with `pthread_condattr_*`.
            `null_ptr[pthread_condattr_t]()` means the default, which
            is what most callers want.

    Returns:
        0 on success, or the error number on failure — the error
        number, not -1, and `errno` is left alone.

    Notes:
        Only `pthread_condattr_init`, `_destroy`, `_setpshared` and
        `_getpshared` are here. `pthread_condattr_setclock` and
        `_getclock` are optional in POSIX, and Darwin declares
        neither — it has no choice of clock to offer — so they are
        left out rather than bound and found missing on one of the
        two runs.
    """
    return external_call[
        "pthread_cond_init",
        Int32,
        c_ptr[pthread_cond_t],
        c_ptr[pthread_condattr_t],
    ](cond, attr)


def pthread_cond_destroy(cond: c_ptr[pthread_cond_t]) -> Int32:
    """C library <pthread.h> function `pthread_cond_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cond_destroy.3p.html

    Prototype:
        int pthread_cond_destroy(pthread_cond_t *cond)

    Description:
        Gives back whatever `pthread_cond_init` took for `cond`.

    Args:
        cond: The thing waited on, which nobody is to be waiting on.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Destroying one that still has waiters is undefined, and there
        is no way to ask whether it has any.
    """
    return external_call["pthread_cond_destroy", Int32, c_ptr[pthread_cond_t]](
        cond
    )


def pthread_cond_signal(cond: c_ptr[pthread_cond_t]) -> Int32:
    """C library <pthread.h> function `pthread_cond_signal`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cond_signal.3p.html

    Prototype:
        int pthread_cond_signal(pthread_cond_t *cond)

    Description:
        Wakes one of the threads waiting on `cond`.

    Args:
        cond: The thing waited on.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        It does not say which one, and with nobody waiting it does
        nothing and says 0. That it is a no-op rather than an error
        is the ordinary way to use it.
    """
    return external_call["pthread_cond_signal", Int32, c_ptr[pthread_cond_t]](
        cond
    )


def pthread_cond_broadcast(cond: c_ptr[pthread_cond_t]) -> Int32:
    """C library <pthread.h> function `pthread_cond_broadcast`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cond_broadcast.3p.html

    Prototype:
        int pthread_cond_broadcast(pthread_cond_t *cond)

    Description:
        Wakes every thread waiting on `cond`.

    Args:
        cond: The thing waited on.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Like `pthread_cond_signal`, with nobody waiting it says 0
        having done nothing.
    """
    return external_call[
        "pthread_cond_broadcast", Int32, c_ptr[pthread_cond_t]
    ](cond)


def pthread_cond_wait(
    cond: c_ptr[pthread_cond_t], mutex: c_ptr[pthread_mutex_t]
) -> Int32:
    """C library <pthread.h> function `pthread_cond_wait`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cond_wait.3p.html

    Prototype:
        int pthread_cond_wait(pthread_cond_t *restrict cond,
                              pthread_mutex_t *restrict mutex)

    Description:
        Waits on `cond`, letting go of `mutex` while it does and
        taking it again before it returns.

    Args:
        cond: The thing waited on.
        mutex: The lock, which this caller holds and which guards
            whatever it is waiting to be told about.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        **This waits.** With nobody to wake it, it waits for good, so
        the test file does not call it. `pthread_cond_timedwait`
        below is the same call with a time on it, and is the one to
        reach for.

        It can answer having been woken for no reason at all — a
        spurious wake-up — which is why what it guards is always
        asked about again in a loop rather than taken on faith.
    """
    return external_call[
        "pthread_cond_wait",
        Int32,
        c_ptr[pthread_cond_t],
        c_ptr[pthread_mutex_t],
    ](cond, mutex)


def pthread_cond_timedwait(
    cond: c_ptr[pthread_cond_t],
    mutex: c_ptr[pthread_mutex_t],
    abstime: c_ptr[timespec],
) -> Int32:
    """C library <pthread.h> function `pthread_cond_timedwait`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cond_timedwait.3p.html

    Prototype:
        int pthread_cond_timedwait(pthread_cond_t *restrict cond,
                                   pthread_mutex_t *restrict mutex,
                                   const struct timespec *restrict abstime)

    Description:
        Waits on `cond` no later than `abstime`, letting go of
        `mutex` while it does and taking it again before it returns.

    Args:
        cond: The thing waited on.
        mutex: The lock, which this caller holds.
        abstime: When to give up, as an absolute `CLOCK_REALTIME`
            time — not a duration, which is the usual way to get
            this wrong.

    Returns:
        0 on success, `ETIMEDOUT` where the time came and went, or
        another error number.

    Notes:
        The clock is not a choice here: it is whichever the
        condition variable was made with, and since Darwin does not
        offer `pthread_condattr_setclock`, `CLOCK_REALTIME` is the
        only one in practice on both.

        A time already past is safe to hand it. That comes straight
        back having timed out, which is what lets a test call it.
    """
    return external_call[
        "pthread_cond_timedwait",
        Int32,
        c_ptr[pthread_cond_t],
        c_ptr[pthread_mutex_t],
        c_ptr[timespec],
    ](cond, mutex, abstime)


def pthread_condattr_init(attr: c_ptr[pthread_condattr_t]) -> Int32:
    """C library <pthread.h> function `pthread_condattr_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_condattr_init.3p.html

    Prototype:
        int pthread_condattr_init(pthread_condattr_t *attr)

    Description:
        Makes `attr` into the default condition attributes.

    Args:
        attr: The storage, which `pthread_condattr_destroy` gives
        back.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_condattr_init", Int32, c_ptr[pthread_condattr_t]
    ](attr)


def pthread_condattr_getpshared(
    attr: c_ptr[pthread_condattr_t], pshared: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_condattr_getpshared`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_condattr_getpshared.3p.html

    Prototype:
        int pthread_condattr_getpshared(
            const pthread_condattr_t *restrict attr, int *restrict pshared)

    Description:
        Says whether a condition variable made from `attr` may be
        shared between processes.

    Args:
        attr: The attributes.
        pshared: Where the answer is to be written, as
            `PTHREAD_PROCESS_SHARED` or `PTHREAD_PROCESS_PRIVATE`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_condattr_getpshared",
        Int32,
        c_ptr[pthread_condattr_t],
        c_ptr[Int32],
    ](attr, pshared)


def pthread_condattr_setpshared(
    attr: c_ptr[pthread_condattr_t], pshared: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_condattr_setpshared`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_condattr_setpshared.3p.html

    Prototype:
        int pthread_condattr_setpshared(pthread_condattr_t *attr,
                                        int pshared)

    Description:
        Says whether a condition variable made from `attr` may be
        shared between processes.

    Args:
        attr: The attributes, from `pthread_condattr_init`.
        pshared: `PTHREAD_PROCESS_SHARED` or
            `PTHREAD_PROCESS_PRIVATE`.

    Returns:
        0 on success, or `EINVAL` where it is neither.

    Notes:
        PRIVATE is 0 on glibc and 2 here, so pass the constant
        rather than a number. See `pthread_mutexattr_setpshared`.
    """
    return external_call[
        "pthread_condattr_setpshared",
        Int32,
        c_ptr[pthread_condattr_t],
        Int32,
    ](attr, pshared)


def pthread_rwlock_init(
    rwlock: c_ptr[pthread_rwlock_t], attr: c_ptr[pthread_rwlockattr_t]
) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_init.3p.html

    Prototype:
        int pthread_rwlock_init(pthread_rwlock_t *restrict rwlock,
                                const pthread_rwlockattr_t *restrict attr)

    Description:
        Makes `rwlock` into a lock that any number of readers or one
        writer may hold.

    Args:
        rwlock: The storage, which `pthread_rwlock_destroy` gives back.
        attr: What kind, built up with `pthread_rwlockattr_*`, or
            `null_ptr[pthread_rwlockattr_t]()` for the default.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_rwlock_init",
        Int32,
        c_ptr[pthread_rwlock_t],
        c_ptr[pthread_rwlockattr_t],
    ](rwlock, attr)


def pthread_rwlock_destroy(rwlock: c_ptr[pthread_rwlock_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_destroy.3p.html

    Prototype:
        int pthread_rwlock_destroy(pthread_rwlock_t *rwlock)

    Description:
        Gives back whatever `pthread_rwlock_init` took.

    Args:
        rwlock: The lock, which nobody is to be holding.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_rwlock_destroy", Int32, c_ptr[pthread_rwlock_t]
    ](rwlock)


def pthread_rwlock_rdlock(rwlock: c_ptr[pthread_rwlock_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_rdlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_rdlock.3p.html

    Prototype:
        int pthread_rwlock_rdlock(pthread_rwlock_t *rwlock)

    Description:
        Takes `rwlock` to read, waiting while somebody writes.

    Args:
        rwlock: The lock.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        This waits. It is called here with nobody else holding the
        lock, which is the only reason it is safe in a test.
    """
    return external_call[
        "pthread_rwlock_rdlock", Int32, c_ptr[pthread_rwlock_t]
    ](rwlock)


def pthread_rwlock_tryrdlock(rwlock: c_ptr[pthread_rwlock_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_tryrdlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_tryrdlock.3p.html

    Prototype:
        int pthread_rwlock_tryrdlock(pthread_rwlock_t *rwlock)

    Description:
        Takes `rwlock` to read if it is free for reading, and says
        so without waiting if it is not.

    Args:
        rwlock: The lock.

    Returns:
        0 on success, or `EBUSY` where a writer holds it.

    Notes:
        This is the one to reach for in a test: it cannot hang.
    """
    return external_call[
        "pthread_rwlock_tryrdlock", Int32, c_ptr[pthread_rwlock_t]
    ](rwlock)


def pthread_rwlock_wrlock(rwlock: c_ptr[pthread_rwlock_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_wrlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_wrlock.3p.html

    Prototype:
        int pthread_rwlock_wrlock(pthread_rwlock_t *rwlock)

    Description:
        Takes `rwlock` to write, waiting until nobody holds it at
        all.

    Args:
        rwlock: The lock.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        This waits. Called with nobody else holding the lock, it
        comes straight back.
    """
    return external_call[
        "pthread_rwlock_wrlock", Int32, c_ptr[pthread_rwlock_t]
    ](rwlock)


def pthread_rwlock_trywrlock(rwlock: c_ptr[pthread_rwlock_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_trywrlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_trywrlock.3p.html

    Prototype:
        int pthread_rwlock_trywrlock(pthread_rwlock_t *rwlock)

    Description:
        Takes `rwlock` to write if it is free altogether, and says
        so without waiting if it is not.

    Args:
        rwlock: The lock.

    Returns:
        0 on success, or `EBUSY` where anybody holds it.

    Notes:
        This is the one to reach for in a test: it cannot hang.
    """
    return external_call[
        "pthread_rwlock_trywrlock", Int32, c_ptr[pthread_rwlock_t]
    ](rwlock)


def pthread_rwlock_unlock(rwlock: c_ptr[pthread_rwlock_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlock_unlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlock_unlock.3p.html

    Prototype:
        int pthread_rwlock_unlock(pthread_rwlock_t *rwlock)

    Description:
        Gives `rwlock` up, whether it was held to read or to write.

    Args:
        rwlock: The lock, which this caller holds.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Unlocking one this caller does not hold is undefined on most
        platforms and silently permitted on some.
    """
    return external_call[
        "pthread_rwlock_unlock", Int32, c_ptr[pthread_rwlock_t]
    ](rwlock)


def pthread_rwlockattr_init(attr: c_ptr[pthread_rwlockattr_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlockattr_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlockattr_init.3p.html

    Prototype:
        int pthread_rwlockattr_init(pthread_rwlockattr_t *attr)

    Description:
        Makes `attr` into the default read-write lock attributes.

    Args:
        attr: The storage, which `pthread_rwlockattr_destroy` gives
            back.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_rwlockattr_init", Int32, c_ptr[pthread_rwlockattr_t]
    ](attr)


def pthread_rwlockattr_destroy(attr: c_ptr[pthread_rwlockattr_t]) -> Int32:
    """C library <pthread.h> function `pthread_rwlockattr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlockattr_destroy.3p.html

    Prototype:
        int pthread_rwlockattr_destroy(pthread_rwlockattr_t *attr)

    Description:
        Gives back whatever `pthread_rwlockattr_init` took.

    Args:
        attr: The attributes.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_rwlockattr_destroy", Int32, c_ptr[pthread_rwlockattr_t]
    ](attr)


def pthread_rwlockattr_getpshared(
    attr: c_ptr[pthread_rwlockattr_t], pshared: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_rwlockattr_getpshared`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlockattr_getpshared.3p.html

    Prototype:
        int pthread_rwlockattr_getpshared(
        const pthread_rwlockattr_t *restrict attr, int *restrict pshared)

    Description:
        Says whether a lock made from `attr` may be shared between
    processes.

    Args:
        attr: The attributes.
        pshared: Where the answer is to be written, as
            `PTHREAD_PROCESS_SHARED` or `PTHREAD_PROCESS_PRIVATE`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_rwlockattr_getpshared",
        Int32,
        c_ptr[pthread_rwlockattr_t],
        c_ptr[Int32],
    ](attr, pshared)


def pthread_rwlockattr_setpshared(
    attr: c_ptr[pthread_rwlockattr_t], pshared: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_rwlockattr_setpshared`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_rwlockattr_setpshared.3p.html

    Prototype:
        int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *attr,
                                          int pshared)

    Description:
        Says whether a lock made from `attr` may be shared between
        processes.

    Args:
        attr: The attributes, from `pthread_rwlockattr_init`.
        pshared: `PTHREAD_PROCESS_SHARED` or
            `PTHREAD_PROCESS_PRIVATE`.

    Returns:
        0 on success, or `EINVAL` where it is neither.

    Notes:
        PRIVATE is 0 on glibc and 2 here, so pass the constant
        rather than a number. See `pthread_mutexattr_setpshared`.
    """
    return external_call[
        "pthread_rwlockattr_setpshared",
        Int32,
        c_ptr[pthread_rwlockattr_t],
        Int32,
    ](attr, pshared)
