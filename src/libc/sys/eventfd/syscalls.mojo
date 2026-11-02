# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <sys/eventfd.h>.
#
# Linux only: a counter with a file descriptor in front of it. The
# BSDs have kqueue and nothing like this, so the three here are not
# on the other side at all, and neither is the header.
#
# Two of the three are only conveniences — `eventfd_read` and
# `eventfd_write` are an eight-byte read and an eight-byte write with
# the answer already interpreted — but they are what the header
# offers and what programs using it reach for.
# -----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_uint


# What the flags are worth: the two that are the `open` flags by
# another name, and the one that is not a flag at all but a different
# way of counting.
comptime EFD_SEMAPHORE: c_int = 1
comptime EFD_CLOEXEC: c_int = 524288
comptime EFD_NONBLOCK: c_int = 2048


def eventfd(initval: c_uint, flags: c_int) -> c_int:
    """C library <sys/eventfd.h> function `eventfd`.

    Reference:
        https://man7.org/linux/man-pages/man2/eventfd.2.html

    Prototype:
        int eventfd(unsigned int initval, int flags)

    Description:
        Makes a counter the kernel keeps: one unsigned 64-bit number,
        reached through a descriptor, that `eventfd_write` adds to and
        `eventfd_read` takes the whole of. The descriptor is the point
        of it — it can be handed to `poll`, `epoll` or `read`, which
        is how one thread or process tells another that something has
        happened.

    Args:
        initval: What the counter starts at.
        flags: `EFD_CLOEXEC` to have it closed on `exec`,
            `EFD_NONBLOCK` for the reads that would otherwise wait,
            and `EFD_SEMAPHORE` for the counting described below, in
            any combination of the three.

    Returns:
        The descriptor, or -1 with `errno` set.

    Notes:
        Without `EFD_SEMAPHORE` a read takes the whole count and
        leaves zero behind; with it a read takes one and leaves the
        rest, which is what makes the counter usable as a semaphore.
        Two quite different things, then, and the difference is one
        flag.

        Linux-specific, which the man page says on its first line.
        The BSDs have kqueue instead, and there is no equivalent on
        the other side: calling this there will not link.

        The count is one number and not a queue of them: two writes
        of 1 and one write of 2 leave the same thing behind.
    """
    return external_call["eventfd", c_int, c_uint, c_int](initval, flags)


def eventfd_write(fd: c_int, value: UInt64) -> c_int:
    """C library <sys/eventfd.h> function `eventfd_write`.

    Reference:
        https://man7.org/linux/man-pages/man2/eventfd.2.html

    Prototype:
        int eventfd_write(int fd, eventfd_t value)

    Description:
        Adds to the counter: the eight bytes given are added to what
        is already there, and whatever is waiting on the other end is
        woken. Comes back at once, and says nothing about whether
        anyone has taken the count since.

    Args:
        fd: An eventfd descriptor.
        value: How much to add.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        The counter is 64 bits wide and unsigned, and the very
        largest value is kept back: `0xFFFFFFFFFFFFFFFF` is refused
        with `EINVAL` rather than added. Adding to one that has got
        that close is refused as well, with `EAGAIN` on a
        nonblocking descriptor and a wait on one that is not.

        A glibc convenience, and one that is only in this header:
        what it does is what an eight-byte `write` to the descriptor
        does, and the two are interchangeable.
    """
    return external_call["eventfd_write", c_int, c_int, UInt64](fd, value)


def eventfd_read(fd: c_int, value: c_ptr[UInt64]) -> c_int:
    """C library <sys/eventfd.h> function `eventfd_read`.

    Reference:
        https://man7.org/linux/man-pages/man2/eventfd.2.html

    Prototype:
        int eventfd_read(int fd, eventfd_t *value)

    Description:
        Takes from the counter: the whole of it, or one out of it
        when the descriptor was made with `EFD_SEMAPHORE`, and where
        it is put is filled in either way.

    Args:
        fd: An eventfd descriptor.
        value: Where the count taken is put.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        On a descriptor made without `EFD_NONBLOCK` this waits for
        something to be there: a read of a counter standing at zero
        does not come back until something has been added to it, and
        that is what makes the descriptor worth handing to `poll` in
        the first place. `EAGAIN` is what the nonblocking one answers
        with instead of waiting.

        A glibc convenience: what it does is what an eight-byte
        `read` from the descriptor does, and the two are
        interchangeable.
    """
    return external_call["eventfd_read", c_int, c_int, c_ptr[UInt64]](fd, value)
