# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr, c_short, c_ulong
from libc.time import timespec

comptime POLLIN = 0x0001
"""There is data to read, or a connection to accept."""

comptime POLLPRI = 0x0002
"""There is urgent out-of-band data to read."""

comptime POLLOUT = 0x0004
"""Writing would not block."""

comptime POLLERR = 0x0008
"""The descriptor is in error. Set in `revents` whatever was asked for."""

comptime POLLHUP = 0x0010
"""The other end hung up. Set in `revents` whatever was asked for."""

comptime POLLNVAL = 0x0020
"""The descriptor is not open. Set in `revents` whatever was asked for."""

comptime POLLRDNORM = 0x0040
"""There is ordinary data to read, which is the same as `POLLIN` here."""

comptime POLLRDBAND = 0x0080
"""There is priority data to read."""

comptime POLLWRNORM = 0x0100
"""Writing ordinary data would not block, which is the same as `POLLOUT`."""

comptime POLLWRBAND = 0x0200
"""Writing priority data would not block."""

comptime POLL_TIMEOUT_INFINITE = -1
"""The timeout that waits forever, rather than one meaning right now."""


struct pollfd(TrivialRegisterPassable):
    """A C `struct pollfd`: one descriptor and what to ask about it.

    Eight bytes, laid out `int fd; short events; short revents;`. `events`
    is what is asked about and `revents` is what `poll` writes back, which
    always includes whatever it found and may include `POLLERR`, `POLLHUP`
    or `POLLNVAL` whether they were asked for or not.
    """

    var fd: Int32
    """The descriptor to watch. A negative one is skipped."""

    var events: c_short
    """The `POLL*` bits being asked about."""

    var revents: c_short
    """What `poll` found; read this after the call, not `events`."""

    def __init__(out self):
        """Builds one watching nothing: fd -1 is ignored by `poll`."""
        self.fd = -1
        self.events = 0
        self.revents = 0

    def __init__(out self, fd: Int32, events: c_short):
        """Builds one watching `fd` for the given bits.

        Args:
            fd: The descriptor to watch.
            events: The `POLL*` bits to ask about, or'd together.
        """
        self.fd = fd
        self.events = events
        self.revents = 0


def poll(fds: c_ptr[pollfd], nfds: c_ulong, timeout: Int32) -> Int32:
    """Libc POSIX `poll`, which waits on an array of descriptors.

    Args:
        fds: The array of descriptors, holding `nfds` entries.
        nfds: How many entries that array holds.
        timeout: Milliseconds to wait, 0 to return at once, or
            `POLL_TIMEOUT_INFINITE` to wait for something to happen.

    Returns:
        How many descriptors have a bit set in `revents`, 0 if nothing
        became ready before the timeout, or -1 on error with `errno` set.

    Notes:
        `select` is the older of the two and cannot watch a descriptor
        numbered 1024 or above; `poll` has no such ceiling, because it is
        given an array rather than a bitmap of fixed width.

        The descriptors that were ready are the ones whose `revents` is not
        zero. Nothing clears them for you, and a set cleared once before a
        loop is enough: `poll` writes the whole field each time.

        [Reference](https://man7.org/linux/man-pages/man2/poll.2.html).
        Fn signature:
            `int poll(struct pollfd *fds, nfds_t nfds, int timeout)`.
    """
    return external_call[
        "poll",
        Int32,
        c_ptr[pollfd],
        c_ulong,
        Int32,
    ](fds, nfds, timeout)


def ppoll(
    fds: c_ptr[pollfd],
    nfds: c_ulong,
    timeout: c_ptr[timespec],
    sigmask: c_ptr[NoneType],
) -> Int32:
    """Libc Linux `ppoll`, which takes a nanosecond timeout and a mask.

    Args:
        fds: The array of descriptors, holding `nfds` entries.
        nfds: How many entries that array holds.
        timeout: How long to wait, or a null pointer to wait forever.
        sigmask: The signal mask to apply while waiting, or a null pointer
            to leave the current one alone.

    Returns:
        How many descriptors have a bit set in `revents`, 0 if nothing
        became ready before the timeout, or -1 on error with `errno` set.

    Notes:
        The difference from `poll` is the rhythm of waiting: milliseconds
        and no mask, or a `timespec` and a mask applied atomically around
        the wait, which is the part `sigprocmask` followed by `poll` cannot
        promise, there being a moment between the two when a signal arrives
        unmasked and is lost.

        [Reference](https://man7.org/linux/man-pages/man2/poll.2.html).
        Fn signature:
            `int ppoll(struct pollfd *fds, nfds_t nfds,
            const struct timespec *timeout, const sigset_t *sigmask)`.
    """
    return external_call[
        "ppoll",
        Int32,
        c_ptr[pollfd],
        c_ulong,
        c_ptr[timespec],
        c_ptr[NoneType],
    ](fds, nfds, timeout, sigmask)
