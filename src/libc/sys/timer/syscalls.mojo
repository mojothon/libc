# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <time.h>, the five POSIX timers that Darwin does not have.
#
# A timer here is an object of its own rather than one of the three the
# process keeps: any number of them can be made, each is armed and read
# on its own, and what it does when it runs out is said when it is made
# rather than being one fixed signal. `getitimer` and `setitimer`, which
# are in `libc.time`, are the other kind.
#
# Linux-only, which is why these are here and not there.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr
from libc.time import timespec


# What a timer is to do when it runs out, as glibc numbers it. Darwin
# has no timers to be asked about, and numbers its own `sigevent`
# differently — `SIGEV_NONE` is 0 there — because its `sigevent` is
# the one `aio` uses and not this one.
#
# `SIGEV_SIGNAL` is what a timer does when made with nothing to say
# otherwise and is offered for that reason alone: the signal arrives
# whether or not anyone asked for it. `SIGEV_NONE` is the one that can
# be asked for from here, the other two wanting either a handler or a
# function to call, and a function is a callback this package cannot
# reach.
comptime SIGEV_NONE: c_int = 1
comptime SIGEV_SIGNAL: c_int = 0

# `timer_settime`'s one flag: the time given is a moment to run out at
# rather than a span from now.
comptime TIMER_ABSTIME: c_int = 1


# glibc's `timer_t` is the one pointer, which is what `timer_create`
# fills in and the rest take. Darwin has no such type.
comptime timer_t = c_ptr[UInt8]


# Where the one member of C's `struct sigevent` that this sets sits: the
# word that says which of the three things the timer does when it runs out.
# `sigev_value` is eight bytes at 0 and `sigev_signo` four more at 8, so
# `sigev_notify` starts a new half-word at 12 — the high half of the second
# slot rather than the low half of a third.
#
# Linux only: `timer_create` does not exist on Darwin, and neither does this
# struct's shape there. The number is glibc's, and is compared with C's
# `offsetof` by `scripts/check-layouts.py` on the one platform that has it.
comptime SIGEVENT_NOTIFY_OFFSET: Int = 12


struct sigevent:
    """A C `struct sigevent`: what a timer is to do when it runs out.

    Sixty-four bytes of the kernel's, of which only the word that says
    which of the three things is to happen is named here. The block is
    kept whole because the kernel reads all of it: it is the size that
    has to be right rather than the fields, and the one field that can
    be set from here is the one that says nothing is to happen.
    """

    var _slots: Array[UInt64, 8]

    def __init__(out self):
        """Zeroes the block, which is a timer that sends `SIGALRM`."""
        self._slots = Array[UInt64, 8](fill=0)

    def _u32(self, off: Int) -> UInt32:
        """Four little-endian bytes at `off`."""
        var slot = self._slots[off // 8]
        return UInt32((slot >> UInt64((off % 8) * 8)) & 0xFFFFFFFF)

    def notify(self) -> Int32:
        """Which of the three things the timer is to do.

        Returns:
            The `sigev_notify` word, which is the second of the eight.
        """
        return Int32(self._u32(SIGEVENT_NOTIFY_OFFSET))

    def set_notify(mut self, how: Int32):
        """Says which of the three things the timer is to do.

        Args:
            how: One of the `SIGEV_*` numbers, of which only
                `SIGEV_NONE` is worth writing from here.
        """
        comptime slot = SIGEVENT_NOTIFY_OFFSET // 8
        comptime shift = UInt64((SIGEVENT_NOTIFY_OFFSET % 8) * 8)
        self._slots[slot] = (
            self._slots[slot] & ~(UInt64(0xFFFF_FFFF) << shift)
        ) | (UInt64(UInt32(how)) << shift)


struct itimerspec:
    """A C `struct itimerspec`: when a timer runs out and how often
    after that.

    Two `timespec`s, and the order they come in is the one thing about
    this struct worth writing down: the interval is first and the time
    it has left is second, the reverse of the order they are normally
    said in.
    """

    var it_interval: timespec
    var it_value: timespec

    def __init__(out self):
        """Zeroes both, which is a timer that is not armed."""
        self.it_interval = timespec()
        self.it_value = timespec()


def timer_create(
    clockid: c_int, sevp: c_ptr[sigevent], timerid: c_ptr[timer_t]
) -> c_int:
    """C library <time.h> function `timer_create`.

    Reference:
        https://man7.org/linux/man-pages/man3/timer_create.3.html

    Prototype:
        int timer_create(clockid_t clockid, struct sigevent *sevp,
                         timer_t *timerid)

    Description:
        Makes a timer and writes its name into `timerid`. The name is
        what every other call here takes, so that a timer can be asked
        about without being named anywhere else.

    Args:
        clockid: Which clock the times are read against, `CLOCK_MONOTONIC`
            being the one that does not jump.
        sevp: What the timer is to do when it runs out, or `NULL` for
            `SIGALRM`.
        timerid: Where the name of the new timer is written.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        The timer is made disarmed. Nothing it could do happens until
        `timer_settime` gives it a time.

        `sevp` says what happens when it runs out and there are three
        answers: a signal, a function called on a new thread, or
        nothing. Only the third can be asked for from here. The other
        two want a callback or a handler that a caller of this package
        has no way to give, and asking for a signal is what leaving
        `sevp` NULL already does.
    """

    return external_call[
        "timer_create", c_int, c_int, c_ptr[sigevent], c_ptr[timer_t]
    ](clockid, sevp, timerid)


def timer_delete(timerid: timer_t) -> c_int:
    """C library <time.h> function `timer_delete`.

    Reference:
        https://man7.org/linux/man-pages/man3/timer_delete.3.html

    Prototype:
        int timer_delete(timer_t timerid)

    Description:
        Takes a timer away. One that is armed and deleted does not run
        out afterwards, which is the reason to delete one rather than
        leave it: an armed timer holds the process's clock awake.

    Args:
        timerid: The timer to take away, as `timer_create` named it.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        The name is not one after this, and asking again with it is
        answered rather than silently done: a second delete is the
        `EINVAL` that says the number is not a timer.
    """

    return external_call["timer_delete", c_int, timer_t](timerid)


def timer_settime(
    timerid: timer_t,
    flags: c_int,
    new_value: c_ptr[itimerspec],
    old_value: c_ptr[itimerspec],
) -> c_int:
    """C library <time.h> function `timer_settime`.

    Reference:
        https://man7.org/linux/man-pages/man3/timer_settime.3.html

    Prototype:
        int timer_settime(timer_t timerid, int flags,
                          const struct itimerspec *new_value,
                          struct itimerspec *old_value)

    Description:
        Arms a timer, or re-arms one that is already armed, from the
        two times in `new_value`: how long until it first runs out, and
        how long between the times after that.

    Args:
        timerid: The timer to arm.
        flags: 0, or `TIMER_ABSTIME` for a `new_value` that is a
            moment rather than a span.
        new_value: When it runs out and how often after that.
        old_value: Where the settings it had are written, or `NULL`
            for not asking.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        An interval of zero is a timer that runs out once; an interval
        that is not zero is one that keeps running out. A time of zero
        for the first is how a timer is disarmed, and it is the only
        way to stop one that is armed: there is no separate call for
        stopping.
    """

    return external_call[
        "timer_settime",
        c_int,
        timer_t,
        c_int,
        c_ptr[itimerspec],
        c_ptr[itimerspec],
    ](timerid, flags, new_value, old_value)


def timer_gettime(timerid: timer_t, curr_value: c_ptr[itimerspec]) -> c_int:
    """C library <time.h> function `timer_gettime`.

    Reference:
        https://man7.org/linux/man-pages/man3/timer_gettime.3.html

    Prototype:
        int timer_gettime(timer_t timerid, struct itimerspec *curr_value)

    Description:
        How long a timer has left before it next runs out, and how
        often it does so after that.

    Args:
        timerid: The timer to ask about.
        curr_value: Where the answer is written.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        A time of zero is a timer that has run out and is not armed
        again, which is both the answer for one that has been and the
        answer for one that was never armed. Which of the two it is is
        not something the call says.
    """

    return external_call["timer_gettime", c_int, timer_t, c_ptr[itimerspec]](
        timerid, curr_value
    )


def timer_getoverrun(timerid: timer_t) -> c_int:
    """C library <time.h> function `timer_getoverrun`.

    Reference:
        https://man7.org/linux/man-pages/man3/timer_getoverrun.3.html

    Prototype:
        int timer_getoverrun(timer_t timerid)

    Description:
        How many times a timer has run out on top of the one that is
        waiting to be noticed.

    Args:
        timerid: The timer to ask about.

    Returns:
        The overrun count, or -1 with `errno` set.

    Notes:
        A timer that runs out while the last running out of it has not
        been noticed yet is counted rather than queued, and this is
        that count. It is cleared by the notice, which for a signal is
        the delivery of it — and a timer made with `SIGEV_NONE` is
        never notified, so it is never cleared either.
    """

    return external_call["timer_getoverrun", c_int, timer_t](timerid)
