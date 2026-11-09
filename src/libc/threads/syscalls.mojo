# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <threads.h>.
#
# The C11 threads library over glibc's own thread calls. Linux only:
# Darwin has no <threads.h> at all, so importing this module there will
# not link.
#
# This module waited longer than any other, and the reason was one
# argument: `thrd_create` takes a function pointer, and for most of this
# package's life nothing here could hand C one. A `def` that captures
# nothing converts to a `thin` function value, and a thin function value
# is a code address -- the eight bytes C's `int (*)(void *)` holds -- so
# the thread this module starts is a thread that runs Mojo. What cannot
# cross is state: a thin function value carries no environment, and
# everything a start routine works on goes through its `void *`, which
# is what that argument is for.
#
# The handles are opaque, and on purpose. `thrd_t` is one word, `tss_t`
# one unsigned int, `once_flag` one int -- all sized here, and none of
# them is a number to be read. `mtx_t` is glibc's 40 bytes and `cnd_t`
# its 48, held as raw room because every call takes them by pointer and
# only libc says what is inside. Zeroing one is not initialising it:
# `mtx_init` and `cnd_init` are, and `ONCE_FLAG_INIT` -- C's `{ 0 }` --
# is this module's `once_flag()` default.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr, c_void
from libc.time import timespec
from std.sys import CompilationTarget

# How glibc answers, in the enum the header calls anonymous. A call that
# fails says which way with one of these, and `thrd_nomem` -- there
# being no way to distinguish it from a failing allocation behind the
# call -- is glibc's to give and nobody else's.
comptime thrd_success: Int32 = 0
comptime thrd_busy: Int32 = 1
comptime thrd_error: Int32 = 2
comptime thrd_nomem: Int32 = 3
comptime thrd_timedout: Int32 = 4

# What `mtx_init` is asked to make. `mtx_timed` is the only one a timed
# wait can be asked about: `cnd_timedwait` takes the mutex either way,
# but `mtx_timedlock` answers `thrd_timedout` only for a mutex made
# timed.
comptime mtx_plain: Int32 = 0
comptime mtx_recursive: Int32 = 1
comptime mtx_timed: Int32 = 2

# How many times one thread's destructor may run before the standard
# gives up on it.
comptime TSS_DTOR_ITERATIONS: Int32 = 4


struct thrd_t(TrivialRegisterPassable):
    """An opaque `thrd_t` from `<threads.h>`: which thread it is.

    glibc's is the thread's `pthread_t`, which is a `pid_t`. One word,
    and which word it is stays private, there being nothing to do with
    one besides hand it back to a call that asks, or put two of them to
    `thrd_equal`.
    """

    var _opaque: UInt64

    def __init__(out self):
        """A zeroed handle, which is no thread at all."""
        self._opaque = 0


comptime tss_t = UInt32
"""An opaque `tss_t` from `<threads.h>`: one thread-local slot.

glibc's is an unsigned int indexing its own table, and the only things
done with one are creating it, setting it, reading it back and deleting
it -- every one of which is a call here.
"""


comptime MTX_SLOTS: Int = 6 if (
    CompilationTarget.is_linux() and CompilationTarget.is_arm()
) else 5


struct mtx_t:
    """An opaque `mtx_t` from `<threads.h>`.

    glibc's is 40 bytes on x86-64 and 48 on aarch64 -- the ARM ABI
    gives `pthread_mutex_t` its own extra word -- held here as raw
    room because every call takes it by pointer and only libc says
    what is inside. The room is sized per architecture, which the
    constant can carry; the third machine is what found the
    difference.

    Zeroing one is not initialising it. `mtx_init` is what does that.
    """

    var _opaque: Array[UInt64, MTX_SLOTS]

    def __init__(out self):
        """Zeroes the object. `mtx_init` is what makes it usable."""
        self._opaque = Array[UInt64, MTX_SLOTS](fill=0)


struct cnd_t:
    """An opaque `cnd_t` from `<threads.h>`.

    glibc's is 48 bytes, the same room `pthread_cond_t` takes, held as
    raw room for the same reason as `mtx_t`'s. `cnd_init` is what makes
    one usable.
    """

    var _opaque: Array[UInt64, 6]

    def __init__(out self):
        """Zeroes the object. `cnd_init` is what makes it usable."""
        self._opaque = Array[UInt64, 6](fill=0)


struct once_flag:
    """An opaque `once_flag` from `<threads.h>`: whether something has
    run yet.

    C spells its initial value with a brace pair holding a zero, so
    this struct's default -- a zeroed state -- is that initial value
    spelled in Mojo. `call_once` is what moves it, and there is no way
    back: once it has run, the flag stays run.
    """

    var _state: UInt32

    def __init__(out self):
        """The flag as `ONCE_FLAG_INIT` leaves it: nothing has run."""
        self._state = 0


# -------------------------------------------------------
# Threads.


def thrd_create(
    thr: c_ptr[thrd_t],
    func: def(c_ptr[c_void]) thin -> Int32,
    arg: c_ptr[c_void],
) -> Int32:
    """C library <threads.h> function `thrd_create`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_create.3.html

    Prototype:
        int thrd_create(thrd_t *thr, thrd_start_t func, void *arg)

    Description:
        Starts a second thread of control, which calls `func` with
        `arg` and whose ID is written to `thr`.

        This is the call the whole module was waiting on. `func` has to
        be a `def` that captures nothing -- a `thin` function value --
        because that is the only kind this side can turn into the code
        address C's `thrd_start_t` holds. What the thread is to work on
        goes through `arg`: point it at a block from `unsafe_alloc` and
        mind that the thread and the caller are now reading the same
        bytes at the same time.

        The thread it starts ends when `func` returns its `Int32`, or
        where `thrd_exit` says so. `thrd_join` is what reads that
        number back; a thread nobody joins and nobody detached keeps
        its resources for good.

    Args:
        thr: Where to write the new thread's ID.
        func: What the thread is to run.
        arg: Handed to `func` unchanged.

    Returns:
        `thrd_success`, or `thrd_nomem` when the system cannot make
        another thread.
    """
    return external_call[
        "thrd_create",
        Int32,
        c_ptr[thrd_t],
        def(c_ptr[c_void]) thin -> Int32,
        c_ptr[c_void],
    ](thr, func, arg)


def thrd_equal(lhs: thrd_t, rhs: thrd_t) -> Int32:
    """C library <threads.h> function `thrd_equal`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_equal.3.html

    Prototype:
        int thrd_equal(thrd_t lhs, thrd_t rhs)

    Description:
        Says whether two thread IDs name the same thread. Nonzero
        means they do, and zero means they are two threads.

        The asymmetry is worth keeping in mind, because it is the
        opposite of what a caller is usually testing: the question
        asked across threads is rarely "is it me" and usually "is it
        not me", and that answer is the zero.

    Args:
        lhs: One thread's ID.
        rhs: The other's.

    Returns:
        Nonzero when the two name one thread, zero when they do not.
    """
    return external_call["thrd_equal", Int32, thrd_t, thrd_t](lhs, rhs)


def thrd_current() -> thrd_t:
    """C library <threads.h> function `thrd_current`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_current.3.html

    Prototype:
        thrd_t thrd_current(void)

    Description:
        Names the thread that asked.

    Returns:
        The calling thread's ID.

    Notes:
        Never fails, and the ID is not a number to be read:
        `thrd_equal` is how two are compared.
    """
    return external_call["thrd_current", thrd_t]()


def thrd_sleep(duration: c_ptr[timespec], remaining: c_ptr[timespec]) -> Int32:
    """C library <threads.h> function `thrd_sleep`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_sleep.3.html

    Prototype:
        int thrd_sleep(const struct timespec *duration, struct timespec *remaining)

    Description:
        Holds the calling thread for `duration`, or until a signal
        that is not ignored arrives, whichever is first.

        A signal cuts the sleep short and writes how much of it was
        left into `remaining`, which is what makes the call usable in
        a loop: sleep again with what is left until the answer is not
        an interruption.

    Args:
        duration: How long to hold the thread.
        remaining: Where to write the part of the duration that did
            not pass, or a null pointer to throw that away.

    Returns:
        0 when the whole duration passed, -1 when a signal cut it
        short, and a value less than -1 when the call itself failed.
    """
    return external_call["thrd_sleep", Int32, c_ptr[timespec], c_ptr[timespec]](
        duration, remaining
    )


def thrd_exit(res: Int32) -> c_void:
    """C library <threads.h> function `thrd_exit`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_exit.3.html

    Prototype:
        void thrd_exit(int res)

    Description:
        Ends the thread that calls it, which is what returning from
        the start routine does, and leaves `res` for `thrd_join` to
        find.

        Called from the first thread it ends the process, the same as
        `exit`, but without a return value a caller could read.

    Args:
        res: What the thread is to be said to have answered.
    """
    return external_call["thrd_exit", c_void, Int32](res)


def thrd_detach(thr: thrd_t) -> Int32:
    """C library <threads.h> function `thrd_detach`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_detach.3.html

    Prototype:
        int thrd_detach(thrd_t thr)

    Description:
        Tells the library that this thread's resources may be given
        back when it finishes, no one being going to join it.

    Args:
        thr: The thread to be detached.

    Returns:
        `thrd_success`, or `thrd_error` where the thread is not one
        that can be detached.
    """
    return external_call["thrd_detach", Int32, thrd_t](thr)


def thrd_join(thr: thrd_t, res: c_ptr[Int32]) -> Int32:
    """C library <threads.h> function `thrd_join`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_join.3.html

    Prototype:
        int thrd_join(thrd_t thr, int *res)

    Description:
        Waits for a thread to finish and, unless `res` is null, writes
        there the `Int32` it answered -- what its start routine
        returned, or what `thrd_exit` was given.

        Joining is what makes reading a thread's work without a lock
        honest: the thread that wrote it has ended, and the join is
        what says so. A thread that has been detached cannot be
        joined, and this answers `thrd_error` for it.

    Args:
        thr: The thread to wait for.
        res: Where to write what it answered, or a null pointer to
            throw that away.

    Returns:
        `thrd_success`, or `thrd_error` where the thread cannot be
        joined.
    """
    return external_call["thrd_join", Int32, thrd_t, c_ptr[Int32]](thr, res)


def thrd_yield() -> c_void:
    """C library <threads.h> function `thrd_yield`.

    Reference:
        https://man7.org/linux/man-pages/man3/thrd_yield.3.html

    Prototype:
        void thrd_yield(void)

    Description:
        Offers the rest of this thread's turn to the other threads
        that want it, which the scheduler is free to decline.

    Notes:
        A hint and nothing more: nothing it says can be tested, and a
        program that needs one thread to wait for another needs a
        mutex and a condition variable, not a yield.
    """
    return external_call["thrd_yield", c_void]()


# -------------------------------------------------------
# The once.


def call_once(flag: c_ptr[once_flag], once_fn: def() thin -> None) -> c_void:
    """C library <threads.h> function `call_once`.

    Reference:
        https://man7.org/linux/man-pages/man3/call_once.3.html

    Prototype:
        void call_once(once_flag *flag, void (*func)(void))

    Description:
        Runs `once_fn`, and keeps running it never again: however many
        threads ask, and however close together, the first one to get
        there runs it and every later one waits until it is done and
        is told it already happened.

        `once_fn` has to be a `def` that captures nothing -- a `thin`
        function value -- and it takes no argument, so everything it
        is to work on has to be reachable without one. C gives a flag
        its starting state with a brace pair holding a zero, which is
        what this module's `once_flag()` default makes; there is no
        constant to bind, the initializer being an initializer and
        not a value.

    Args:
        flag: The flag that says whether it has run.
        once_fn: What is to run at most once.
    """
    return external_call[
        "call_once", c_void, c_ptr[once_flag], def() thin -> None
    ](flag, once_fn)


# -------------------------------------------------------
# Mutexes.


def mtx_init(mtx: c_ptr[mtx_t], kind: Int32) -> Int32:
    """C library <threads.h> function `mtx_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/mtx_init.3.html

    Prototype:
        int mtx_init(mtx_t *mtx, int kind)

    Description:
        Makes `mtx` a usable mutex of the kind asked for, which is
        what turns a zeroed `mtx_t` into a lock.

        The kinds are `mtx_plain`, which is the one that only locks;
        `mtx_recursive`, which lets the thread that holds it hold it
        again without stopping; and `mtx_timed`, which is the only one
        `mtx_timedlock` can time out on. `mtx_plain` and `mtx_timed`
        may be put together, and `mtx_plain` and `mtx_recursive`
        likewise; asking for nothing at all is not a kind.

    Args:
        mtx: The mutex to make usable.
        kind: Which kind, from the `mtx_*` constants.

    Returns:
        `thrd_success`, or `thrd_nomem` where there is nothing to make
        it out of.
    """
    return external_call["mtx_init", Int32, c_ptr[mtx_t], Int32](mtx, kind)


def mtx_lock(mtx: c_ptr[mtx_t]) -> Int32:
    """C library <threads.h> function `mtx_lock`.

    Reference:
        https://man7.org/linux/man-pages/man3/mtx_lock.3.html

    Prototype:
        int mtx_lock(mtx_t *mtx)

    Description:
        Takes the mutex, waiting as long as it takes for whoever holds
        it to let go.

    Args:
        mtx: The mutex to take.

    Returns:
        `thrd_success`, or `thrd_error` where the argument is not a
        mutex this library made.
    """
    return external_call["mtx_lock", Int32, c_ptr[mtx_t]](mtx)


def mtx_timedlock(mtx: c_ptr[mtx_t], until: c_ptr[timespec]) -> Int32:
    """C library <threads.h> function `mtx_timedlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/mtx_timedlock.3.html

    Prototype:
        int mtx_timedlock(mtx_t *restrict mtx, const struct timespec *ts)

    Description:
        Takes the mutex, waiting only until the absolute time `until`
        on the wall clock -- `CLOCK_REALTIME`, the same one `timespec`
        usually carries -- and answering `thrd_timedout` when it
        cannot have it by then.

        Absolute, not relative: an argument read from the clock now
        and handed over a moment later is already late. The mutex has
        to have been made `mtx_timed`, or the wait is not one that can
        be timed.

    Args:
        mtx: The mutex to take.
        until: The time to give up at.

    Returns:
        `thrd_success`, `thrd_timedout` when the time passed first, or
        `thrd_error` where the mutex was not made timed or the
        argument is not one of this library's.
    """
    return external_call["mtx_timedlock", Int32, c_ptr[mtx_t], c_ptr[timespec]](
        mtx, until
    )


def mtx_trylock(mtx: c_ptr[mtx_t]) -> Int32:
    """C library <threads.h> function `mtx_trylock`.

    Reference:
        https://man7.org/linux/man-pages/man3/mtx_trylock.3.html

    Prototype:
        int mtx_trylock(mtx_t *mtx)

    Description:
        Takes the mutex only if nobody holds it right now, and says so
        rather than waiting.

    Args:
        mtx: The mutex to take.

    Returns:
        `thrd_success` when it took it, `thrd_busy` when somebody else
        holds it, or `thrd_error` where the argument is not a mutex
        this library made.
    """
    return external_call["mtx_trylock", Int32, c_ptr[mtx_t]](mtx)


def mtx_unlock(mtx: c_ptr[mtx_t]) -> Int32:
    """C library <threads.h> function `mtx_unlock`.

    Reference:
        https://man7.org/linux/man-pages/man3/mtx_unlock.3.html

    Prototype:
        int mtx_unlock(mtx_t *mtx)

    Description:
        Lets go of the mutex, letting whichever thread has been
        waiting longest at it have a turn.

    Args:
        mtx: The mutex to let go of.

    Returns:
        `thrd_success`, or `thrd_error` where this thread does not
        hold it.
    """
    return external_call["mtx_unlock", Int32, c_ptr[mtx_t]](mtx)


def mtx_destroy(mtx: c_ptr[mtx_t]) -> c_void:
    """C library <threads.h> function `mtx_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/mtx_destroy.3.html

    Prototype:
        void mtx_destroy(mtx_t *mtx)

    Description:
        Gives the mutex back to the pool of nothing, after which it is
        not a mutex until `mtx_init` says so again.

        A mutex somebody still holds, or is waiting at, must not be
        destroyed: the call says nothing when this is done wrong, and
        what breaks does so later, somewhere else.

    Args:
        mtx: The mutex that is no longer needed.
    """
    return external_call["mtx_destroy", c_void, c_ptr[mtx_t]](mtx)


# -------------------------------------------------------
# Condition variables.


def cnd_init(cnd: c_ptr[cnd_t]) -> Int32:
    """C library <threads.h> function `cnd_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/cnd_init.3.html

    Prototype:
        int cnd_init(cnd_t *cond)

    Description:
        Makes `cnd` a usable condition variable, which is what turns a
        zeroed `cnd_t` into something a thread can wait at.

        A condition variable carries no state of its own about whether
        what is being waited for has happened. The thing waited for
        lives in the caller's data, guarded by the mutex the pair is
        always handed together.

    Args:
        cnd: The condition variable to make usable.

    Returns:
        `thrd_success`, or `thrd_nomem` where there is nothing to make
        it out of.
    """
    return external_call["cnd_init", Int32, c_ptr[cnd_t]](cnd)


def cnd_signal(cnd: c_ptr[cnd_t]) -> Int32:
    """C library <threads.h> function `cnd_signal`.

    Reference:
        https://man7.org/linux/man-pages/man3/cnd_signal.3.html

    Prototype:
        int cnd_signal(cnd_t *cond)

    Description:
        Wakes one of the threads waiting at the condition variable, if
        there is one, and does nothing at all if there is not.

        That last half is the trap: a signal sent before anybody waits
        is a signal lost, and the waiter then waits until a timed wait
        saves it. Waking every waiter instead is `cnd_broadcast`.

        The mutex does not go with it -- the caller is expected to
        hold the mutex whose guard the wait is under, and to let go of
        it when it is done saying what changed.

    Args:
        cnd: The condition variable to signal.

    Returns:
        `thrd_success`, or `thrd_error` where the argument is not a
        condition variable this library made.
    """
    return external_call["cnd_signal", Int32, c_ptr[cnd_t]](cnd)


def cnd_broadcast(cnd: c_ptr[cnd_t]) -> Int32:
    """C library <threads.h> function `cnd_broadcast`.

    Reference:
        https://man7.org/linux/man-pages/man3/cnd_broadcast.3.html

    Prototype:
        int cnd_broadcast(cnd_t *cond)

    Description:
        Wakes every thread waiting at the condition variable, where
        `cnd_signal` would have woken one of them.

        For something any number of threads may be waiting to hear --
        a state that unblocks all of them at once -- this is the call;
        for work where each waiter would only fight the others for the
        same job, waking one is the point and `cnd_signal` is the
        cheaper way to do it.

    Args:
        cnd: The condition variable to wake everyone at.

    Returns:
        `thrd_success`, or `thrd_error` where the argument is not a
        condition variable this library made.
    """
    return external_call["cnd_broadcast", Int32, c_ptr[cnd_t]](cnd)


def cnd_wait(cnd: c_ptr[cnd_t], mtx: c_ptr[mtx_t]) -> Int32:
    """C library <threads.h> function `cnd_wait`.

    Reference:
        https://man7.org/linux/man-pages/man3/cnd_wait.3.html

    Prototype:
        int cnd_wait(cnd_t *cond, mtx_t *mutex)

    Description:
        Lets go of the mutex the calling thread holds, and waits at
        the condition variable until somebody signals it -- then takes
        the mutex back before answering.

        The wait is without a clock: a signal sent before the thread
        got here is a signal lost, and the thread waits for the next
        one. `cnd_timedwait` is the way to wait with a way out.

        The mutex has to be held on the way in. The atomic letting go
        and waiting is what keeps the thing being waited for from
        changing between the check and the sleep.

    Args:
        cnd: The condition variable to wait at.
        mtx: The mutex guarding the thing waited for, held by this
            thread.

    Returns:
        `thrd_success`, or `thrd_error` where the mutex is not held by
        this thread or the pair is not this library's.
    """
    return external_call["cnd_wait", Int32, c_ptr[cnd_t], c_ptr[mtx_t]](
        cnd, mtx
    )


def cnd_timedwait(
    cnd: c_ptr[cnd_t], mtx: c_ptr[mtx_t], until: c_ptr[timespec]
) -> Int32:
    """C library <threads.h> function `cnd_timedwait`.

    Reference:
        https://man7.org/linux/man-pages/man3/cnd_timedwait.3.html

    Prototype:
        int cnd_timedwait(cnd_t *restrict cond, mtx_t *restrict mutex, const struct timespec *ts)

    Description:
        Waits at the condition variable like `cnd_wait`, but only
        until the absolute time `until` on the wall clock, and answers
        `thrd_timedout` when nothing signaled it by then.

        Absolute, not relative: an argument read from the clock now
        and handed over a moment later is already late, and the honest
        way to wait a while is to read the clock, add the while, and
        wait until that.

        Waking up is not knowing. `thrd_success` says the wait was
        signaled, and says nothing about whether what is waited for
        has happened: the caller takes the mutex back and looks.

    Args:
        cnd: The condition variable to wait at.
        mtx: The mutex guarding the thing waited for, held by this
            thread.
        until: The time to give up at.

    Returns:
        `thrd_success` when it was signaled, `thrd_timedout` when the
        time passed first, or `thrd_error` where the mutex is not
        held by this thread.
    """
    return external_call[
        "cnd_timedwait", Int32, c_ptr[cnd_t], c_ptr[mtx_t], c_ptr[timespec]
    ](cnd, mtx, until)


def cnd_destroy(cnd: c_ptr[cnd_t]) -> c_void:
    """C library <threads.h> function `cnd_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/cnd_destroy.3.html

    Prototype:
        void cnd_destroy(cnd_t *cond)

    Description:
        Gives the condition variable back, after which it is not one
        until `cnd_init` says so again.

        A condition variable somebody is still waiting at must not be
        destroyed; the call says nothing when this is done wrong.

    Args:
        cnd: The condition variable that is no longer needed.
    """
    return external_call["cnd_destroy", c_void, c_ptr[cnd_t]](cnd)


# -------------------------------------------------------
# Thread-local slots.


def tss_create(
    key: c_ptr[tss_t], dtor: def(c_ptr[c_void]) thin -> None
) -> Int32:
    """C library <threads.h> function `tss_create`.

    Reference:
        https://man7.org/linux/man-pages/man3/tss_create.3.html

    Prototype:
        int tss_create(tss_t *tss_id, tss_dtor_t destructor)

    Description:
        Makes a thread-local slot, one per thread, and writes its key
        to `key`. Every thread sees its own value at the key and
        nothing at it before it sets one.

        `dtor` is run on a thread's value for this key when that
        thread ends, once per value and at most `TSS_DTOR_ITERATIONS`
        times, which is the standard's bound on a destructor that
        keeps setting the slot on its way out. It has to be a `def`
        that captures nothing -- a `thin` function value -- and it may
        be a null pointer, which is the way to have a slot with
        nothing to clean up.

    Args:
        key: Where to write the new slot's key.
        dtor: What to run on each thread's value when that thread
            ends, or a null pointer.

    Returns:
        `thrd_success`, or `thrd_nomem` where there is nothing to make
        it out of.
    """
    return external_call[
        "tss_create",
        Int32,
        c_ptr[tss_t],
        def(c_ptr[c_void]) thin -> None,
    ](key, dtor)


def tss_get(key: tss_t) -> c_ptr[c_void]:
    """C library <threads.h> function `tss_get`.

    Reference:
        https://man7.org/linux/man-pages/man3/tss_get.3.html

    Prototype:
        void *tss_get(tss_t tss_id)

    Description:
        Reads what the calling thread has put in the slot, which is
        nothing -- a null pointer -- until it has put something there.

        The same key answers a different pointer on every thread,
        which is the whole point of the slot: what one thread put
        there is invisible to the others.

    Args:
        key: The slot to read.

    Returns:
        What this thread last set, or null when it has set nothing.
    """
    return external_call["tss_get", c_ptr[c_void], tss_t](key)


def tss_set(key: tss_t, value: c_ptr[c_void]) -> Int32:
    """C library <threads.h> function `tss_set`.

    Reference:
        https://man7.org/linux/man-pages/man3/tss_set.3.html

    Prototype:
        int tss_set(tss_t tss_id, void *val)

    Description:
        Puts `value` in the slot, for this thread and nobody else.

        Setting a new value where there was one does not run the
        destructor on the old: the destructor is for the thread
        ending, and the old pointer's life is the caller's from the
        moment the new value covers it.

    Args:
        key: The slot to put it in.
        value: What this thread is to read back.

    Returns:
        `thrd_success`, or `thrd_error` where the key is not one this
        library made.
    """
    return external_call["tss_set", Int32, tss_t, c_ptr[c_void]](key, value)


def tss_delete(key: tss_t) -> c_void:
    """C library <threads.h> function `tss_delete`.

    Reference:
        https://man7.org/linux/man-pages/man3/tss_delete.3.html

    Prototype:
        void tss_delete(tss_t tss_id)

    Description:
        Takes the slot away. Values already set in it are not run
        through the destructor by this call -- the destructor is for
        threads ending, and what it is to be run on after the slot is
        gone is the standard's to leave unspecified.

    Args:
        key: The slot that is no longer needed.
    """
    return external_call["tss_delete", c_void, tss_t](key)
