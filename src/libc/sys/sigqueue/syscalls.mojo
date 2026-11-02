# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <signal.h>, the three of it that Darwin does not have.
#
# Sending a signal is `kill` and waiting for one is `sigwait`, and
# both are in `libc.signal` because both platforms have them. These
# three are the ones that do more: a signal sent with a number riding
# along with it, and a wait that takes the signal out of the queue
# and says everything about it rather than only which one it was.
# Linux-only, which is why they are here and not there.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr
from libc.signal import siginfo_t
from libc.time import timespec


# What `si_code` says about where a signal came from: 0 for one the
# kernel sent on a user's behalf, and -1 for one queued with a
# number along with it.
comptime SI_USER: c_int = 0
comptime SI_QUEUE: c_int = -1


def sigqueue(pid: c_int, sig: c_int, value: Int64) -> c_int:
    """C library <signal.h> function `sigqueue`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigqueue.3.html

    Prototype:
        int sigqueue(pid_t pid, int sig, const union sigval value)

    Description:
        Sends a signal with a number riding along with it, which
        `kill` has nowhere to put. The number is what makes a queue
        of them: signals of one kind are usually a single bit —
        either one has arrived or none has — and these are counted,
        each with its own number, so nothing sent this way is lost
        for having been sent twice.

    Args:
        pid: Who to send it to.
        sig: Which signal.
        value: The number to send with it, which is the `sival_int`
            half of the `sigval` union.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        The number is eight bytes wide in C, being the wider half of
        a union whose other half is a pointer; what is sent here is
        the number half, and it is the whole eight bytes that go.

        Linux-specific: `sigqueue(3)` says so on its first line, and
        the header on the other side does not declare it at all.

        The receiver has to be waiting the right way: a signal sent
        to a process whose handler for it is the default is not a
        thing a program can read the number out of. What reads it is
        `sigwaitinfo`, or a handler installed with `SA_SIGINFO`.
    """
    return external_call["sigqueue", c_int, c_int, c_int, Int64](
        pid, sig, value
    )


def sigwaitinfo(set: c_ptr[UInt8], info: c_ptr[siginfo_t]) -> c_int:
    """C library <signal.h> function `sigwaitinfo`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigwaitinfo.2.html

    Prototype:
        int sigwaitinfo(const sigset_t *set, siginfo_t *info)

    Description:
        Waits for one of the signals in `set` and takes it out of the
        queue, answering with which one it was and writing everything
        known about it into `info`: who sent it, why, and the number
        that was sent along with it. Unlike a handler, it is called
        at a time of the program's own choosing, and the signal never
        runs any handler at all.

    Args:
        set: The signals to wait for, as bytes — see `sigaddset`.
        info: Where what is known about the signal is written.

    Returns:
        The signal number, or -1 with `errno` set.

    Notes:
        The signals waited for have to be blocked first, which is
        `sigprocmask`: a signal that is not blocked is delivered
        rather than queued, and there is then nothing here to take.

        Linux-specific: the header on the other side declares neither
        this nor `sigtimedwait`, and `sigwait` is there instead.

        This waits. `sigtimedwait` is the one that can be given a
        time to stop waiting at.
    """
    return external_call["sigwaitinfo", c_int, c_ptr[UInt8], c_ptr[siginfo_t]](
        set, info
    )


def sigtimedwait(
    set: c_ptr[UInt8], info: c_ptr[siginfo_t], timeout: c_ptr[timespec]
) -> c_int:
    """C library <signal.h> function `sigtimedwait`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigwaitinfo.2.html

    Prototype:
        int sigtimedwait(const sigset_t *set, siginfo_t *info,
                         const struct timespec *timeout)

    Description:
        `sigwaitinfo` with a time to give up at: it waits for one of
        the signals in `set`, takes it out of the queue and answers
        with which it was, or, should none have arrived before the
        time is up, gives up and says so.

    Args:
        set: The signals to wait for, as bytes — see `sigaddset`.
        info: Where what is known about the signal is written, which
            is left alone when the wait timed out.
        timeout: How long to wait; both fields zero means not at all.

    Returns:
        The signal number, or -1 with `errno` set — `EAGAIN` for a
        wait that ran out of time.

    Notes:
        Linux-specific: the header on the other side declares neither
        this nor `sigwaitinfo`, and `sigwait` is there instead.

        A timeout of zero seconds is a question, not a wait: it asks
        whether one has arrived already and comes back either way,
        which is what makes it safe to call with nothing to wait for.
    """
    return external_call[
        "sigtimedwait", c_int, c_ptr[UInt8], c_ptr[siginfo_t], c_ptr[timespec]
    ](set, info, timeout)
