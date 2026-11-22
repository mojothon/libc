# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <sys/timerfd.h>.
#
# Linux only: a timer with a file descriptor in front of it, the
# way `eventfd` is a counter with one. The BSDs have kqueue and
# nothing like this, so the three here are not on the other side
# at all, and neither is the header.
# -----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr
from libc.sys.timer import itimerspec


# What the flags are worth: the two that are the `open` flags by
# another name, and the one that is not a flag but a different
# way of saying when.
comptime TFD_NONBLOCK: c_int = 2048
comptime TFD_CLOEXEC: c_int = 524288
comptime TFD_TIMER_ABSTIME: c_int = 1


def timerfd_create(clockid: c_int, flags: c_int) -> c_int:
    """C library <sys/timerfd.h> function `timerfd_create`.

    Reference:
        https://man7.org/linux/man-pages/man2/timerfd_create.2.html

    Description:
        Makes a timer that is a descriptor: what it does when it
        runs out is become readable, eight bytes saying how many
        times, which is the answer a caller waiting on many
        descriptors can take without a handler and without a
        signal -- the timer being one more thing in the list
        rather than one more thing to catch.

    Args:
        clockid: Which clock the times are read against, `CLOCK_MONOTONIC`
            being the one that does not jump.
        flags: 0, or the `TFD_` bits: `TFD_NONBLOCK` for the reading
            that answers rather than waits, `TFD_CLOEXEC` for the
            descriptor that closes itself when the next image takes
            the process over.

    Returns:
        The descriptor, or -1 with `errno` saying why.

    Notes:
        Linux-specific; the wrapper has been in the C library
        since 2.8. The timer is made disarmed, as `timer_create`
        makes one: nothing it could do happens until
        `timerfd_settime` gives it a time. What runs out is a
        byte count and not an event -- the count of how many
        times the timer has run out since it was last read,
        which is the kernel's answer to what happens when a
        caller is slow: nothing is lost, it is added up.
    """
    return external_call["timerfd_create", c_int, c_int, c_int](clockid, flags)


def timerfd_settime(
    fd: c_int,
    flags: c_int,
    new_value: c_ptr[itimerspec],
    old_value: c_ptr[itimerspec],
) -> c_int:
    """C library <sys/timerfd.h> function `timerfd_settime`.

    Reference:
        https://man7.org/linux/man-pages/man2/timerfd_settime.2.html

    Description:
        Arms the timer a descriptor stands for, or disarms it with a
        time of zero -- and answers with what was armed before, which
        is how a caller that means to put it back learns what it was.

    Args:
        fd: The descriptor the timer stands behind.
        flags: 0 for the time measured from now, `TFD_TIMER_ABSTIME`
            for the time measured against the clock itself.
        new_value: What to arm: `it_value` the time it runs out at and
            `it_interval` how often after that, an interval of zero
            being a timer that goes once and stops.
        old_value: Where the armed-before is written, or a null
            pointer where the caller does not want it.

    Returns:
        0 on success, -1 with `errno` saying why.

    Notes:
        Linux-specific; the wrapper has been in the C library
        since 2.8. The struct's order is the one worth writing
        down again: the interval is first and the time it has
        left is second, the reverse of the order they are
        normally said in. A timer asked for again while it is
        running is armed again from this moment -- the old
        count of times it has run out stays until the
        descriptor is read, and the arming says nothing
        about it.
    """
    return external_call[
        "timerfd_settime",
        c_int,
        c_int,
        c_int,
        c_ptr[itimerspec],
        c_ptr[itimerspec],
    ](fd, flags, new_value, old_value)


def timerfd_gettime(fd: c_int, curr_value: c_ptr[itimerspec]) -> c_int:
    """C library <sys/timerfd.h> function `timerfd_gettime`.

    Reference:
        https://man7.org/linux/man-pages/man2/timerfd_gettime.2.html

    Description:
        Asks the timer how long it has and how often it goes --
        the time it has left, and the interval it will keep after
        each run-out, which are the two numbers the arming took
        and the two the caller needs to know what it is waiting
        for.

    Args:
        fd: The descriptor the timer stands behind.
        curr_value: Where the answer is written: `it_value` the time
            it has left, which the running timer lowers as the clock
            runs, `it_interval` how often it goes after each run-out.

    Returns:
        0 on success, -1 with `errno` saying why.

    Notes:
        Linux-specific; the wrapper has been in the C library
        since 2.8. The time it has left is the part that moves:
        the same ask twice in a row is answered with less the
        second time, which is the clock's word that it is
        running -- and a disarmed timer answers with a time
        of zero, which is the honest word for a timer that
        will never run out.
    """
    return external_call["timerfd_gettime", c_int, c_int, c_ptr[itimerspec]](
        fd, curr_value
    )
