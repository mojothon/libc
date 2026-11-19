# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# Linux only: Darwin has no POSIX message queues at all -- no `mq_open`
# on the man page index, no `<mqueue.h>` to include -- so importing this
# package there will not link, the way `sys.epoll` does not.
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_long, c_ptr
from libc.time import timespec


# C's `struct mq_attr` is four `long`s in a row on every platform that
# has the header at all, which here is Linux only, so the struct carries
# its members by name and there is nothing for a platform branch to say.
# It is not registered with `scripts/check-layouts.py`, because that
# script asks C's `offsetof` the question, and the machine that compiles
# the Darwin tests has no `<mqueue.h>` to ask.


struct MqAttr(TrivialRegisterPassable):
    """A C `struct mq_attr`: what a message queue says about itself.

    The members are the four C spells, read and written as fields, the
    way `struct timespec` is. `mq_maxmsg` and `mq_msgsize` are the
    queue's shape, set when the queue is created and fixed for its
    life; `mq_flags` is whether the queue was opened non-blocking, and
    it is the only member `mq_setattr` accepts; `mq_curmsgs` is how
    many messages the queue holds right now, an answer and never a
    setting.
    """

    var mq_flags: c_long
    var mq_maxmsg: c_long
    var mq_msgsize: c_long
    var mq_curmsgs: c_long

    def __init__(out self):
        """Zeroes every member, which is what `memset` would leave behind."""
        self.mq_flags = 0
        self.mq_maxmsg = 0
        self.mq_msgsize = 0
        self.mq_curmsgs = 0

    @staticmethod
    def of(maxmsg: Int64, msgsize: Int64) -> MqAttr:
        """The attributes a new queue is created with.

        Args:
            maxmsg: How many messages the queue may hold at once.
            msgsize: How big any one message may be, in bytes.

        Returns:
            An `MqAttr` naming that shape, for `mq_open`'s fourth
            argument.
        """
        var attr = MqAttr()
        attr.mq_maxmsg = maxmsg
        attr.mq_msgsize = msgsize
        return attr


def mq_open(
    name: c_ptr[UInt8], oflag: Int32, mode: Int32, attr: c_ptr[MqAttr]
) -> Int32:
    """Libc POSIX `mq_open`.

    Args:
        name: The queue's name, which must begin with a slash.
        oflag: `O_RDONLY`, `O_WRONLY`, or `O_RDWR`, with `O_CREAT`,
            `O_EXCL`, and `O_NONBLOCK` among the bits that may ride
            along.
        mode: The permissions a created queue gets, used only when
            `oflag` carries `O_CREAT` and passed as zero otherwise --
            C's own two-argument calling of this function is this
            argument and the next set to their defaults.
        attr: The shape a created queue gets, used only when `oflag`
            carries `O_CREAT` and passed as null otherwise.

    Returns:
        A message queue descriptor on success, or -1 on error with
        `errno` set.

    Notes:
        C's `mq_open` is variadic -- `mode` and `attr` exist only when
        `O_CREAT` says so. The binding takes all four arguments and
        always passes them, which is the same call the kernel sees:
        a queue opened without `O_CREAT` reads neither.
        [Reference](https://man7.org/linux/man-pages/man3/mq_open.3.html).
        Fn signature: `mqd_t mq_open(const char *name, int oflag,
        mode_t mode, struct mq_attr *attr)`.
    """
    return external_call[
        "mq_open", Int32, c_ptr[UInt8], Int32, Int32, c_ptr[MqAttr]
    ](name, oflag, mode, attr)


def mq_close(mqd: Int32) -> Int32:
    """Libc POSIX `mq_close`.

    Args:
        mqd: The descriptor to close.

    Returns:
        0 on success, or -1 on error with `errno` set.

    Notes:
        Closing a descriptor ends this process's use of the queue, not
        the queue itself: the messages wait for whoever opens it next.
        [Reference](https://man7.org/linux/man-pages/man3/mq_close.3.html).
        Fn signature: `int mq_close(mqd_t mqdes)`.
    """
    return external_call["mq_close", Int32, Int32](mqd)


def mq_unlink(name: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `mq_unlink`.

    Args:
        name: The queue's name, which must begin with a slash.

    Returns:
        0 on success, or -1 on error with `errno` set.

    Notes:
        The queue is not gone while a descriptor still names it, but no
        new one can be opened by that name.
        [Reference](https://man7.org/linux/man-pages/man3/mq_unlink.3.html).
        Fn signature: `int mq_unlink(const char *name)`.
    """
    return external_call["mq_unlink", Int32, c_ptr[UInt8]](name)


def mq_getattr(mqd: Int32, attr: c_ptr[MqAttr]) -> Int32:
    """Libc POSIX `mq_getattr`.

    Args:
        mqd: The descriptor to describe.
        attr: Where to store the description.

    Returns:
        0 on success, or -1 on error with `errno` set.

    Notes:
        The `mq_flags` this answers is about the descriptor, not the
        queue; `mq_curmsgs` is a moment, not a promise.
        [Reference](https://man7.org/linux/man-pages/man3/mq_getattr.3.html).
        Fn signature: `int mq_getattr(mqd_t mqdes, struct mq_attr *attr)`.
    """
    return external_call["mq_getattr", Int32, Int32, c_ptr[MqAttr]](mqd, attr)


def mq_setattr(mqd: Int32, new: c_ptr[MqAttr], old: c_ptr[MqAttr]) -> Int32:
    """Libc POSIX `mq_setattr`.

    Args:
        mqd: The descriptor to change.
        new: The wanted attributes, of which only `mq_flags` is read --
            and of it only `O_NONBLOCK` means anything.
        old: Where the descriptor's previous attributes are stored, or
            null to leave them unread.

    Returns:
        0 on success, or -1 on error with `errno` set.

    Notes:
        A queue's shape is fixed at creation; this changes only whether
        this descriptor blocks.
        [Reference](https://man7.org/linux/man-pages/man3/mq_setattr.3.html).
        Fn signature: `int mq_setattr(mqd_t mqdes, const struct mq_attr
        *newattr, struct mq_attr *oldattr)`.
    """
    return external_call[
        "mq_setattr", Int32, Int32, c_ptr[MqAttr], c_ptr[MqAttr]
    ](mqd, new, old)


def mq_send(
    mqd: Int32, msg: c_ptr[UInt8], msg_len: UInt64, msg_prio: UInt32
) -> Int32:
    """Libc POSIX `mq_send`.

    Args:
        mqd: The descriptor to send on.
        msg: The message, whose length must not pass the queue's
            `mq_msgsize`.
        msg_len: The message's length, in bytes.
        msg_prio: The message's priority; higher arrives first.

    Returns:
        0 on success, or -1 on error with `errno` set. On a queue
        opened without `O_NONBLOCK`, a full queue waits.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mq_send.3.html).
        Fn signature: `int mq_send(mqd_t mqdes, const char *msg_ptr,
        size_t msg_len, unsigned int msg_prio)`.
    """
    return external_call["mq_send", Int32, Int32, c_ptr[UInt8], UInt64, UInt32](
        mqd, msg, msg_len, msg_prio
    )


def mq_receive(
    mqd: Int32, msg: c_ptr[UInt8], msg_len: UInt64, msg_prio: c_ptr[UInt32]
) -> Int64:
    """Libc POSIX `mq_receive`.

    Args:
        mqd: The descriptor to receive on.
        msg: Where the message is stored, whose room must not fall
            short of the queue's `mq_msgsize`.
        msg_len: The room the buffer has, in bytes.
        msg_prio: Where the message's priority is stored, or null to
            leave it unread.

    Returns:
        How many bytes the message holds, or -1 on error with `errno`
        set. On a queue opened without `O_NONBLOCK`, an empty queue
        waits.

    Notes:
        The oldest of the highest-priority messages is the one that
        comes out.
        [Reference](https://man7.org/linux/man-pages/man3/mq_receive.3.html).
        Fn signature: `ssize_t mq_receive(mqd_t mqdes, char *msg_ptr,
        size_t msg_len, unsigned int *msg_prio)`.
    """
    return external_call[
        "mq_receive", Int64, Int32, c_ptr[UInt8], UInt64, c_ptr[UInt32]
    ](mqd, msg, msg_len, msg_prio)


def mq_timedsend(
    mqd: Int32,
    msg: c_ptr[UInt8],
    msg_len: UInt64,
    msg_prio: UInt32,
    abs_timeout: c_ptr[timespec],
) -> Int32:
    """Libc POSIX `mq_timedsend`.

    Args:
        mqd: The descriptor to send on.
        msg: The message, whose length must not pass the queue's
            `mq_msgsize`.
        msg_len: The message's length, in bytes.
        msg_prio: The message's priority; higher arrives first.
        abs_timeout: When to stop waiting, on the clock
            `CLOCK_REALTIME` reads.

    Returns:
        0 on success, or -1 on error with `errno` set; a timeout that
        passed with the queue still full sets `ETIMEDOUT`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mq_timedsend.3.html).
        Fn signature: `int mq_timedsend(mqd_t mqdes, const char
        *msg_ptr, size_t msg_len, unsigned int msg_prio, const struct
        timespec *abs_timeout)`.
    """
    return external_call[
        "mq_timedsend",
        Int32,
        Int32,
        c_ptr[UInt8],
        UInt64,
        UInt32,
        c_ptr[timespec],
    ](mqd, msg, msg_len, msg_prio, abs_timeout)


def mq_timedreceive(
    mqd: Int32,
    msg: c_ptr[UInt8],
    msg_len: UInt64,
    msg_prio: c_ptr[UInt32],
    abs_timeout: c_ptr[timespec],
) -> Int64:
    """Libc POSIX `mq_timedreceive`.

    Args:
        mqd: The descriptor to receive on.
        msg: Where the message is stored, whose room must not fall
            short of the queue's `mq_msgsize`.
        msg_len: The room the buffer has, in bytes.
        msg_prio: Where the message's priority is stored, or null to
            leave it unread.
        abs_timeout: When to stop waiting, on the clock
            `CLOCK_REALTIME` reads.

    Returns:
        How many bytes the message holds, or -1 on error with `errno`
        set; a timeout that passed with the queue still empty sets
        `ETIMEDOUT`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mq_timedreceive.3.html).
        Fn signature: `ssize_t mq_timedreceive(mqd_t mqdes, char
        *msg_ptr, size_t msg_len, unsigned int *msg_prio, const struct
        timespec *abs_timeout)`.
    """
    return external_call[
        "mq_timedreceive",
        Int64,
        Int32,
        c_ptr[UInt8],
        UInt64,
        c_ptr[UInt32],
        c_ptr[timespec],
    ](mqd, msg, msg_len, msg_prio, abs_timeout)
