# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr
from libc.time import timespec

comptime FD_SETSIZE = 1024
"""How many descriptors an `fd_set` can hold; 1024 on both platforms."""


struct Timeval(TrivialRegisterPassable):
    """A C `struct timeval`: seconds plus microseconds.

    `tv_sec` is a 64-bit `time_t` on both platforms, and `tv_usec` is a 32-bit
    `suseconds_t` on Darwin but a 64-bit `long` on Linux, so it is stored in a
    full slot; zero the struct and it reads correctly either way.
    """

    var tv_sec: Int64
    var tv_usec: Int64

    def __init__(out self):
        """Zeroes both members, which is the timeout that never expires."""
        self.tv_sec = 0
        self.tv_usec = 0

    def __init__(out self, sec: Int64, usec: Int64):
        """Builds the given timeout.

        Args:
            sec: The seconds.
            usec: The microseconds to add to them.
        """
        self.tv_sec = sec
        self.tv_usec = usec


struct fd_set:
    """A C `fd_set`: the descriptor bits `select` watches.

    Both platforms make it 128 bytes, but Linux's words are 64-bit and
    Darwin's are 32-bit, so a descriptor lands in a different bit on each.
    The bits are kept in 64-bit words and `FD_SET`, `FD_CLR` and `FD_ISSET`
    work out which bit a descriptor means.
    """

    var _words: Array[UInt64, 16]

    def __init__(out self):
        """Zeroes the set, which is what `FD_ZERO` leaves behind."""
        self._words = Array[UInt64, 16](fill=0)


def _word_of(fd: Int32) -> Int:
    """The 64-bit word a descriptor's bit lives in."""
    return Int(fd) // 64


def _bit_of(fd: Int32) -> Int:
    """The bit inside that word, counted the way the platform counts."""
    comptime if CompilationTarget.is_macos():
        # 32-bit words, two to a slot: the odd ones use the upper half.
        return (Int(fd) % 32) + 32 * ((Int(fd) // 32) % 2)
    else:
        return Int(fd) % 64


def FD_ZERO(fds: c_ptr[fd_set]) raises:
    """Empties a set, which every `select` call starts with.

    Args:
        fds: The set to empty.
    """
    var words = fds.unsafe_bitcast[UInt64]()
    for i in range(16):
        words.unsafe_store(i, UInt64(0))


def FD_SET(fds: c_ptr[fd_set], fd: Int32) raises:
    """Adds a descriptor to a set.

    Args:
        fds: The set to add to.
        fd: The descriptor to add, below `FD_SETSIZE`.
    """
    var words = fds.unsafe_bitcast[UInt64]()
    var word = _word_of(fd)
    words.unsafe_store(word, words.unsafe_load(word) | _mask(fd))


def FD_CLR(fds: c_ptr[fd_set], fd: Int32) raises:
    """Removes a descriptor from a set.

    Args:
        fds: The set to remove from.
        fd: The descriptor to remove, below `FD_SETSIZE`.
    """
    var words = fds.unsafe_bitcast[UInt64]()
    var word = _word_of(fd)
    words.unsafe_store(word, words.unsafe_load(word) & ~_mask(fd))


def FD_ISSET(fds: c_ptr[fd_set], fd: Int32) raises -> Bool:
    """Whether `select` reported a descriptor as ready.

    Args:
        fds: The set `select` handed back.
        fd: The descriptor to ask about, below `FD_SETSIZE`.

    Returns:
        True if the descriptor's bit is still set.
    """
    var words = fds.unsafe_bitcast[UInt64]()
    return (words.unsafe_load(_word_of(fd)) & _mask(fd)) != 0


def _mask(fd: Int32) -> UInt64:
    """The single bit standing for a descriptor."""
    return UInt64(1) << UInt64(_bit_of(fd))


def select(
    nfds: Int32,
    readfds: c_ptr[fd_set],
    writefds: c_ptr[fd_set],
    exceptfds: c_ptr[fd_set],
    timeout: c_ptr[Timeval],
) -> Int32:
    """Libc POSIX `select`.

    Args:
        nfds: One past the highest descriptor in any of the sets.
        readfds: The descriptors to watch for reading, or a null pointer.
        writefds: The descriptors to watch for writing, or a null pointer.
        exceptfds: The descriptors to watch for errors, or a null pointer.
        timeout: How long to wait, or a null pointer to wait forever.

    Returns:
        How many descriptors are ready, 0 if the timeout expired, or -1 on
        error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/select.2.html).
        Fn signature:
            `int select(int nfds, fd_set *readfds, fd_set *writefds,
            fd_set *exceptfds, struct timeval *timeout)`.
    """
    return external_call[
        "select",
        Int32,
        Int32,
        c_ptr[fd_set],
        c_ptr[fd_set],
        c_ptr[fd_set],
        c_ptr[Timeval],
    ](nfds, readfds, writefds, exceptfds, timeout)


def pselect(
    nfds: Int32,
    readfds: c_ptr[fd_set],
    writefds: c_ptr[fd_set],
    exceptfds: c_ptr[fd_set],
    timeout: c_ptr[timespec],
    sigmask: c_ptr[NoneType],
) -> Int32:
    """Libc POSIX `pselect`, which takes a nanosecond timeout and a mask.

    Args:
        nfds: One past the highest descriptor in any of the sets.
        readfds: The descriptors to watch for reading, or a null pointer.
        writefds: The descriptors to watch for writing, or a null pointer.
        exceptfds: The descriptors to watch for errors, or a null pointer.
        timeout: How long to wait, or a null pointer to wait forever.
        sigmask: The signal mask to apply while waiting, or a null pointer.

    Returns:
        How many descriptors are ready, 0 if the timeout expired, or -1 on
        error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/select.2.html).
        Fn signature:
            `int pselect(int nfds, fd_set *readfds, fd_set *writefds,
            fd_set *exceptfds, const struct timespec *timeout,
            const sigset_t *sigmask)`.
    """
    return external_call[
        "pselect",
        Int32,
        Int32,
        c_ptr[fd_set],
        c_ptr[fd_set],
        c_ptr[fd_set],
        c_ptr[timespec],
        c_ptr[NoneType],
    ](nfds, readfds, writefds, exceptfds, timeout, sigmask)
