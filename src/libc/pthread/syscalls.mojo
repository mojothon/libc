# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import c_ptr
from libc.sched import sched_param
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

# Whether a thread made from an attribute object is to take its
# scheduling from the caller or carry its own settings. INHERIT is 0
# on glibc and 1 here; EXPLICIT is 1 and 2.
comptime PTHREAD_INHERIT_SCHED: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime PTHREAD_EXPLICIT_SCHED: Int32 = 2 if CompilationTarget.is_macos() else 1

# How far a thread's contention reaches. SYSTEM is 0 on glibc and 1
# here; PROCESS is 1 and 2. Darwin notes in its own header that it
# supports SYSTEM only, which is the one thing to know about asking
# for PROCESS there.
comptime PTHREAD_SCOPE_SYSTEM: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime PTHREAD_SCOPE_PROCESS: Int32 = 2 if CompilationTarget.is_macos() else 1


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


def pthread_attr_getschedparam(
    attr: c_ptr[pthread_attr_t], param: c_ptr[sched_param]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getschedparam`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getschedparam.3.html

    Prototype:
        int pthread_attr_getschedparam(const pthread_attr_t *restrict attr,
                                       struct sched_param *restrict param)

    Description:
        Reads the scheduling priority an attribute object carries.

    Args:
        attr: The attribute object to be queried.
        param: Where the priority is written, as a `sched_param`.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        The policy is a separate setting kept by
        `pthread_attr_getschedpolicy`; this one is the priority alone.
    """
    return external_call[
        "pthread_attr_getschedparam",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[sched_param],
    ](attr, param)


def pthread_attr_setschedparam(
    attr: c_ptr[pthread_attr_t], param: c_ptr[sched_param]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setschedparam`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setschedparam.3.html

    Prototype:
        int pthread_attr_setschedparam(pthread_attr_t *restrict attr,
                                       const struct sched_param *restrict param)

    Description:
        Sets the scheduling priority an attribute object carries.

    Args:
        attr: The attribute object.
        param: The priority, as a `sched_param`.

    Returns:
        0 on success, or the error number on failure.

    Notes:
        Nothing checks the priority against the policy here — the two
        are kept apart and are put together when a thread is made.
    """
    return external_call[
        "pthread_attr_setschedparam",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[sched_param],
    ](attr, param)


def pthread_attr_getschedpolicy(
    attr: c_ptr[pthread_attr_t], policy: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getschedpolicy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getschedpolicy.3.html

    Prototype:
        int pthread_attr_getschedpolicy(const pthread_attr_t *restrict attr,
                                        int *restrict policy)

    Description:
        Reads the scheduling policy an attribute object carries.

    Args:
        attr: The attribute object to be queried.
        policy: Where the policy is written, as one of the `SCHED_*`
            constants from `libc.sched`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_attr_getschedpolicy",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[Int32],
    ](attr, policy)


def pthread_attr_setschedpolicy(
    attr: c_ptr[pthread_attr_t], policy: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setschedpolicy`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setschedpolicy.3.html

    Prototype:
        int pthread_attr_setschedpolicy(pthread_attr_t *attr, int policy)

    Description:
        Sets the scheduling policy an attribute object carries.

    Args:
        attr: The attribute object.
        policy: One of the `SCHED_*` constants.

    Returns:
        0 on success, or `ENOTSUP` where the policy is not one this
        platform runs.

    Notes:
        The number is not the same on both: `SCHED_FIFO` is 1 on glibc
        and 4 here. Take the constant from `libc.sched` rather than
        writing the digit down.
    """
    return external_call[
        "pthread_attr_setschedpolicy", Int32, c_ptr[pthread_attr_t], Int32
    ](attr, policy)


def pthread_attr_getinheritsched(
    attr: c_ptr[pthread_attr_t], inheritsched: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getinheritsched`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getinheritsched.3.html

    Prototype:
        int pthread_attr_getinheritsched(
        const pthread_attr_t *restrict attr, int *restrict inheritsched)

    Description:
        Says whether a thread made from these attributes is to take
        its scheduling from the caller or carry its own.

    Args:
        attr: The attribute object to be queried.
        inheritsched: Where the answer is written, as
        `PTHREAD_INHERIT_SCHED` or `PTHREAD_EXPLICIT_SCHED`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_attr_getinheritsched",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[Int32],
    ](attr, inheritsched)


def pthread_attr_setinheritsched(
    attr: c_ptr[pthread_attr_t], inheritsched: Int32
) -> Int32:
    """C library <pthread.h> function `pthread_attr_setinheritsched`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setinheritsched.3.html

    Prototype:
        int pthread_attr_setinheritsched(pthread_attr_t *attr,
                                         int inheritsched)

    Description:
        Says whether a thread made from these attributes is to take
        its scheduling from the caller or carry its own.

    Args:
        attr: The attribute object.
        inheritsched: `PTHREAD_INHERIT_SCHED` or
            `PTHREAD_EXPLICIT_SCHED`.

    Returns:
        0 on success, or `EINVAL` where it is neither.

    Notes:
        INHERIT is 0 on glibc and 1 here, and EXPLICIT is 1 and 2 —
        a test that wants the other one should name it rather than
        flip a bit.
    """
    return external_call[
        "pthread_attr_setinheritsched", Int32, c_ptr[pthread_attr_t], Int32
    ](attr, inheritsched)


def pthread_attr_getscope(
    attr: c_ptr[pthread_attr_t], scope: c_ptr[Int32]
) -> Int32:
    """C library <pthread.h> function `pthread_attr_getscope`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_getscope.3.html

    Prototype:
        int pthread_attr_getscope(const pthread_attr_t *restrict attr,
                                  int *restrict contentionscope)

    Description:
        Reads how far the threads made from these attributes are to
        contend with one another.

    Args:
        attr: The attribute object to be queried.
        scope: Where the answer is written, as `PTHREAD_SCOPE_SYSTEM`
            or `PTHREAD_SCOPE_PROCESS`.

    Returns:
        0 on success, or the error number on failure.
    """
    return external_call[
        "pthread_attr_getscope",
        Int32,
        c_ptr[pthread_attr_t],
        c_ptr[Int32],
    ](attr, scope)


def pthread_attr_setscope(attr: c_ptr[pthread_attr_t], scope: Int32) -> Int32:
    """C library <pthread.h> function `pthread_attr_setscope`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_attr_setscope.3.html

    Prototype:
        int pthread_attr_setscope(pthread_attr_t *attr, int contentionscope)

    Description:
        Says how far the threads made from these attributes are to
        contend with one another.

    Args:
        attr: The attribute object.
        scope: `PTHREAD_SCOPE_SYSTEM` or `PTHREAD_SCOPE_PROCESS`.

    Returns:
        0 on success, `ENOTSUP` where the platform runs only one of
        them, or `EINVAL` where it is neither.

    Notes:
        Darwin's own header says it supports SYSTEM only, so asking
        for PROCESS there is expected to be refused rather than to
        change anything. The two numbers differ across platforms in
        any case: SYSTEM is 0 on glibc and 1 here.
    """
    return external_call[
        "pthread_attr_setscope", Int32, c_ptr[pthread_attr_t], Int32
    ](attr, scope)


# Whether a thread may be cancelled, and if so, when. POSIX fixes
# neither pair of numbers, and the two platforms disagree on both:
# ENABLE is 0 on glibc and 1 here, DEFERRED is 0 and 2. It is worth
# knowing that on Darwin these are laid out as two bits — ENABLE is
# 0x01 and DEFERRED is 0x02 — so 0 is not the neutral value there
# that it is here.
comptime PTHREAD_CANCEL_ENABLE: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime PTHREAD_CANCEL_DISABLE: Int32 = 0 if CompilationTarget.is_macos() else 1
comptime PTHREAD_CANCEL_DEFERRED: Int32 = 2 if CompilationTarget.is_macos() else 0
comptime PTHREAD_CANCEL_ASYNCHRONOUS: Int32 = (
    0 if CompilationTarget.is_macos() else 1
)


# This one conforms to `TrivialRegisterPassable`, which no other
# struct in the package does. The others are opaque blocks that go to
# libc by pointer and are written into there; this is a handle that
# `pthread_self` hands back by value and that `pthread_equal` takes
# two of, and being copied around is the whole of what happens to it.
# It is one machine word on both platforms, so it fits.
struct pthread_t(TrivialRegisterPassable):
    """An opaque `pthread_t` from `<pthread.h>`: which thread it is.

    glibc's is the thread's `pid_t`; Darwin's a pointer to a struct
    it keeps. Both are one word, and which of the two this is stays
    private, there being nothing to do with one besides hand it back
    to a call that asks, or put two of them to `pthread_equal`.
    """

    var _opaque: UInt64

    def __init__(out self):
        """A zeroed handle, which is no thread at all."""
        self._opaque = 0


def pthread_self() -> pthread_t:
    """C library <pthread.h> function `pthread_self`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_self.3.html

    Prototype:
        pthread_t pthread_self(void)

    Description:
        Names the thread that asked.

    Returns:
        The calling thread's ID.

    Notes:
        Never fails, and the ID is not a number to be read: on Darwin
        it is a pointer. `pthread_equal` is how two are compared.
    """
    return external_call["pthread_self", pthread_t]()


def pthread_equal(t1: pthread_t, t2: pthread_t) -> Int32:
    """C library <pthread.h> function `pthread_equal`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_equal.3.html

    Prototype:
        int pthread_equal(pthread_t t1, pthread_t t2)

    Description:
        Says whether two thread IDs are the same thread.

    Args:
        t1: One thread ID.
        t2: The other.

    Returns:
        Nonzero if the two are the same thread, 0 if they are not.

    Notes:
        Thread IDs are not compared with `==` in portable code, this
        being the call that does it. On Darwin the ID is a pointer.
    """
    return external_call["pthread_equal", Int32, pthread_t, pthread_t](t1, t2)


def pthread_detach(thread: pthread_t) -> Int32:
    """C library <pthread.h> function `pthread_detach`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_detach.3.html

    Prototype:
        int pthread_detach(pthread_t thread);

    Description:
        Tells the library that this thread's resources may be given
        back when it finishes, no one being going to join it.

    Args:
        thread: The thread to be detached.

    Returns:
        0 on success, `EINVAL` where the thread is not joinable, or
        `ESRCH` where no such thread was found.
    """
    return external_call["pthread_detach", Int32, pthread_t](thread)


def pthread_cancel(thread: pthread_t) -> Int32:
    """C library <pthread.h> function `pthread_cancel`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_cancel.3.html

    Prototype:
        int pthread_cancel(pthread_t thread);

    Description:
        Asks that a thread be cancelled.

    Args:
        thread: The thread to be cancelled.

    Returns:
        0 on success, or `ESRCH` where no such thread was found.

    Notes:
        A request rather than an act: it is held against the thread
        and taken up at a cancellation point, of which
        `pthread_testcancel` is one, unless the thread has cancelled
        disabled. It is bound and not called here: what it asks for
        cannot be taken back, and a test that asked it of itself
        could not go on to check anything.
    """
    return external_call["pthread_cancel", Int32, pthread_t](thread)


def pthread_setcancelstate(state: Int32, oldstate: c_ptr[Int32]) -> Int32:
    """C library <pthread.h> function `pthread_setcancelstate`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_setcancelstate.3.html

    Prototype:
        int pthread_setcancelstate(int state, int *oldstate);

    Description:
        Says whether this thread is to be cancellable, and hands back
        what it was.

    Args:
        state: `PTHREAD_CANCEL_ENABLE` or `PTHREAD_CANCEL_DISABLE`.
        oldstate: Where the state it had before is written, or
            `null_ptr[Int32]()` where that is not wanted.

    Returns:
        0 on success, or `EINVAL` where `state` is neither.
    """
    return external_call["pthread_setcancelstate", Int32, Int32, c_ptr[Int32]](
        state, oldstate
    )


def pthread_setcanceltype(type: Int32, oldtype: c_ptr[Int32]) -> Int32:
    """C library <pthread.h> function `pthread_setcanceltype`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_setcanceltype.3.html

    Prototype:
        int pthread_setcanceltype(int type, int *oldtype);

    Description:
        Says when a cancellation asked of this thread is to be taken
        up, and hands back what it was.

    Args:
        type: `PTHREAD_CANCEL_DEFERRED` or
            `PTHREAD_CANCEL_ASYNCHRONOUS`.
        oldtype: Where the type it had before is written, or
            `null_ptr[Int32]()` where that is not wanted.

    Returns:
        0 on success, or `EINVAL` where `type` is neither.

    Notes:
        ASYNCHRONOUS, which lets a thread be stopped anywhere it
        happens to be rather than at a point it asked for, is not
        something to ask of a thread whose cleanup one is not
        certain of.
    """
    return external_call["pthread_setcanceltype", Int32, Int32, c_ptr[Int32]](
        type, oldtype
    )


def pthread_testcancel() raises:
    """C library <pthread.h> function `pthread_testcancel`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_testcancel.3.html

    Prototype:
        void pthread_testcancel(void);

    Description:
        Puts a cancellation point here: a cancellation asked of this
        thread is taken up at this line if there is one waiting.

    Notes:
        Does nothing and comes back at once where nothing is waiting,
        which is the case this is called under here. It is the
        opposite of harmless where something is, the thread ending
        at this line rather than carrying on.
    """
    external_call["pthread_testcancel", NoneType]()


# A key is a number the library hands out rather than a pointer to
# anything, and it is a different width on the two platforms: an
# `unsigned int` on glibc and an `unsigned long` here. It is called by
# whichever of the two this one uses, that being what the calls take,
# and it is not wrapped in anything, since there is nothing to hide:
# a key is passed around and compared with nothing, and the only calls
# it answers to are the four in this group.
comptime pthread_key_t = UInt64 if CompilationTarget.is_macos() else UInt32


def pthread_key_create(
    key: c_ptr[pthread_key_t], destructor: c_ptr[UInt8]
) -> Int32:
    """C library <pthread.h> function `pthread_key_create`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_key_create.3.html

    Prototype:
        int pthread_key_create(pthread_key_t *key, void (*)(void *));

    Description:
        Has the library set aside a slot this thread may keep one
        thing in, and hands back the key that names it.

    Args:
        key: Where the new key is written.
        destructor: What is to be done with what is in the slot when
            the thread ends. A Mojo closure cannot be made into a C
            function pointer, so what goes here is
            `null_ptr[UInt8]()`, which is to say nothing at all: the
            value is left where it is when the thread ends.

    Returns:
        0 on success, `EAGAIN` where the library is out of keys, or
        `ENOMEM` where it cannot make another.

    Notes:
        The slot starts out holding nothing, and every thread has its
        own under the same key. `pthread_key_delete` gives it back.
    """
    return external_call[
        "pthread_key_create", Int32, c_ptr[pthread_key_t], c_ptr[UInt8]
    ](key, destructor)


def pthread_getspecific(key: pthread_key_t) -> c_ptr[UInt8]:
    """C library <pthread.h> function `pthread_getspecific`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_getspecific.3.html

    Prototype:
        void *pthread_getspecific(pthread_key_t key);

    Description:
        Reads what this thread has put in the slot `key` names.

    Args:
        key: The key `pthread_key_create` handed back.

    Returns:
        What was put there, or NULL where nothing was: every thread
        starts with nothing in it. `is_null` is how it is asked.
    """
    return external_call["pthread_getspecific", c_ptr[UInt8], pthread_key_t](
        key
    )


def pthread_setspecific(key: pthread_key_t, value: c_ptr[UInt8]) -> Int32:
    """C library <pthread.h> function `pthread_setspecific`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_setspecific.3.html

    Prototype:
        int pthread_setspecific(pthread_key_t key, const void *value);

    Description:
        Puts one thing in the slot `key` names, for this thread.

    Args:
        key: The key `pthread_key_create` handed back.
        value: What to put there, or `null_ptr[UInt8]()` for nothing.

    Returns:
        0 on success, or `ENOMEM` where the library has no room.

    Notes:
        What is in the slot is a pointer and is not copied, and
        nothing happens to whatever was there before. Where a
        destructor was given to `pthread_key_create`, the thread's
        ending is what calls it; giving nothing there, as is the only
        thing that can be done from Mojo, means the value is left
        alone when the thread ends.
    """
    return external_call[
        "pthread_setspecific", Int32, pthread_key_t, c_ptr[UInt8]
    ](key, value)


def pthread_key_delete(key: pthread_key_t) -> Int32:
    """C library <pthread.h> function `pthread_key_delete`.

    Reference:
        https://man7.org/linux/man-pages/man3/pthread_key_delete.3.html

    Prototype:
        int pthread_key_delete(pthread_key_t key);

    Description:
        Gives the slot `key` names back to the library.

    Args:
        key: The key `pthread_key_create` handed back.

    Returns:
        0 on success, or `EINVAL` where the key is not one that was
        handed out.

    Notes:
        Whatever the thread had in the slot is not disposed of here,
        and no destructor runs: a thread that kept something in it is
        to see to that itself first.
    """
    return external_call["pthread_key_delete", Int32, pthread_key_t](key)


def pthread_sigmask(
    how: Int32, set: c_ptr[UInt8], oldset: c_ptr[UInt8]
) -> Int32:
    """Libc POSIX `pthread_sigmask` function.

    Description:
        Says which signals this thread is to be handed, which is a
        thing each thread keeps for itself and not one the process
        keeps.

    Args:
        how: Which of the `SIG_` names to do it by — `SIG_BLOCK` to
            add to what is blocked, `SIG_UNBLOCK` to take away, and
            `SIG_SETMASK` to say the whole of it.
        set: The set of signals `how` is about, which is read, or a
            null pointer where nothing is to be changed.
        oldset: Where to put the mask as it was before, which is
            written to, or a null pointer where that is not wanted.

    Returns:
        0 where it was said, or a number that says what went wrong,
        which is not in `errno`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/pthread_sigmask.3.html).
        Fn signature: `int pthread_sigmask(int how,
            const sigset_t *restrict set, sigset_t *restrict oldset)`.

        This is `sigprocmask` for one thread rather than for the
        process, and in a process of one thread the two are the same
        call; POSIX does not say which `sigprocmask` does in a
        process of many, which is why this is the one to call there.

        Which signals are blocked is kept per thread, but what a
        signal does when it is delivered is kept for the whole
        process, so blocking one in one thread does not stop another
        thread from being given it.

        `set` and `oldset` are `sigset_t`, which is not laid out the
        same on the two platforms and is not bound here: a block of
        zeroes big enough for either, filled by `sigemptyset`, is
        what is handed in.
    """
    return external_call[
        "pthread_sigmask", Int32, Int32, c_ptr[UInt8], c_ptr[UInt8]
    ](how, set, oldset)


def pthread_kill(thread: pthread_t, sig: Int32) -> Int32:
    """Libc POSIX `pthread_kill` function.

    Description:
        Sends a signal to one thread.

    Args:
        thread: The thread to send it to, which is `pthread_self`
            for this one.
        sig: Which signal to send, or 0 to send none and only ask
            whether the thread is there.

    Returns:
        0 where it was sent, or a number that says what went wrong,
        which is not in `errno`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/pthread_kill.3.html).
        Fn signature: `int pthread_kill(pthread_t thread, int sig)`.

        This is `kill` for a thread rather than for a process, and it
        is the only one that can send to one: `kill` sends to a
        process and whichever of its threads takes it is not a thing
        a caller can say.

        Signal 0 is the one that sends nothing. What it does instead
        is the check, which is what makes it the only signal worth
        sending in a test: whether the thread is there is answered
        without disturbing it.

        What the signal does when it arrives is whatever the whole
        process has been told for that number, which is `sigaction`'s
        to say and not this call's.
    """
    return external_call["pthread_kill", Int32, pthread_t, Int32](thread, sig)
