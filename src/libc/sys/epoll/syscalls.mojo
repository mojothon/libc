# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# Linux only: Darwin has kqueue instead, so importing this package there will
# not link.
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


def epoll_create(size: Int32) -> Int32:
    """C library <sys/epoll.h> function `epoll_create`.

    Reference:
        https://man7.org/linux/man-pages/man2/epoll_create.2.html

    Args:
        size: The size of the epoll instance.

    Description:
        Creates a new epoll instance.

    Returns:
        The file descriptor of the new epoll instance.
    """
    return external_call["epoll_create", Int32, Int32](size)


def epoll_create1(flags: Int32) -> Int32:
    """C library <sys/epoll.h> function `epoll_create1`.

    Reference:
        https://man7.org/linux/man-pages/man2/epoll_create1.2.html

    Args:
        flags: Flags to control the behavior of the epoll instance.

    Description:
        Creates a new epoll instance with the specified flags.
    Returns:
        The file descriptor of the new epoll instance.
    """
    return external_call["epoll_create1", Int32, Int32](flags)


struct epoll_event:
    """A C `struct epoll_event`: the events to watch and the tag to report.

    glibc declares the struct packed, so `data` sits 4 bytes in rather than 8,
    which is why it is kept as raw bytes instead of a `UInt64`: Mojo aligns an
    8-byte member to 8 and would hand C a 16-byte struct.

    The tag is a union — a pointer, a file descriptor, or two integers — so it
    is read back with `data_u64` or `data_fd`, whichever you put in. The bytes
    are assembled little-endian, which is what x86-64 and arm64 both are.
    """

    var events: UInt32
    var data: Array[UInt8, 8]

    def __init__(out self, events: UInt32, data: UInt64):
        """Builds an event tagged with the given 64-bit value.

        Args:
            events: The `EPOLLIN`, `EPOLLOUT`, ... bits to watch for.
            data: The tag to hand back when the event fires.
        """
        self.events = events
        self.data = Array[UInt8, 8](fill=0)
        var value = data
        for i in range(8):
            self.data[i] = UInt8(value & 0xFF)
            value >>= 8

    def __init__(out self, events: UInt32, fd: Int32):
        """Builds an event tagged with a file descriptor.

        Args:
            events: The `EPOLLIN`, `EPOLLOUT`, ... bits to watch for.
            fd: The descriptor to hand back when the event fires.
        """
        self = Self(events, UInt64(Int(fd) & 0xFFFFFFFF))

    def data_u64(self) -> UInt64:
        """The tag, read as a 64-bit value."""
        var value: UInt64 = 0
        for i in range(8):
            value |= UInt64(self.data[i]) << UInt64(8 * (7 - i))
        return value

    def data_fd(self) -> Int32:
        """The tag, read as the file descriptor it was built with."""
        return Int32(Int(self.data_u64() & 0xFFFFFFFF))


def epoll_ctl(
    epfd: Int32, op: Int32, fd: Int32, event: c_ptr[epoll_event]
) -> Int32:
    """C library <sys/epoll.h> function `epoll_ctl`.

    Reference:
        https://man7.org/linux/man-pages/man2/epoll_ctl.2.html

    Args:
        epfd: The file descriptor of the epoll instance.
        op: The operation to perform on the epoll instance.
        fd: The file descriptor of the epoll instance.
        event: The event to add or modify in the epoll instance.

    Description:
        Adds or modifies an event in the epoll instance.

    Returns:
        0 on success, or -1 on error.
    """
    return external_call[
        "epoll_ctl", Int32, Int32, Int32, Int32, c_ptr[epoll_event]
    ](epfd, op, fd, event)


def epoll_pwait(
    epfd: Int32,
    events: c_ptr[epoll_event],
    maxevents: Int32,
    timeout: Int32,
    sigmask: c_ptr[NoneType],
) -> Int32:
    """C library <sys/epoll.h> function `epoll_pwait`.

    Reference:
        https://man7.org/linux/man-pages/man2/epoll_pwait.2.html

    Args:
        epfd: The file descriptor of the epoll instance.
        events: The events to wait for.
        maxevents: The maximum number of events to wait for.
        timeout: The timeout in milliseconds.
        sigmask: The signal mask to apply to the wait.

    Description:
        Waits for events on the epoll instance.

    Returns:
        The number of events that were signaled, or -1 on error.
    """
    return external_call[
        "epoll_pwait",
        Int32,
        Int32,
        c_ptr[epoll_event],
        Int32,
        Int32,
        c_ptr[NoneType],
    ](epfd, events, maxevents, timeout, sigmask)


struct timespec(TrivialRegisterPassable):
    var tv_sec: Int64
    var tv_nsec: Int64


def epoll_pwait2(
    epfd: Int32,
    events: c_ptr[epoll_event],
    maxevents: Int32,
    timeout: c_ptr[timespec],
    sigmask: c_ptr[NoneType],
) -> Int32:
    """C library <sys/epoll.h> function `epoll_pwait2`.

    Reference:
        https://man7.org/linux/man-pages/man2/epoll_pwait.2.html

    Args:
        epfd: The file descriptor of the epoll instance.
        events: The events to wait for.
        maxevents: The maximum number of events to wait for.
        timeout: The timeout in milliseconds.
        sigmask: The signal mask to apply to the wait.

    Description:
        Waits for events on the epoll instance.

    Returns:
        The number of events that were signaled, or -1 on error.
    """
    return external_call[
        "epoll_pwait2",
        Int32,
        Int32,
        c_ptr[epoll_event],
        Int32,
        c_ptr[timespec],
        c_ptr[NoneType],
    ](epfd, events, maxevents, timeout, sigmask)


def epoll_wait(
    epfd: Int32, events: c_ptr[epoll_event], maxevents: Int32, timeout: Int32
) -> Int32:
    """C library <sys/epoll.h> function `epoll_wait`.

    Reference:
        https://man7.org/linux/man-pages/man2/epoll_wait.2.html

    Args:
        epfd: The file descriptor of the epoll instance.
        events: The events to wait for.
        maxevents: The maximum number of events to wait for.
        timeout: The timeout in milliseconds.

    Description:
        Waits for events on the epoll instance.

    Returns:
        The number of events that were signaled, or -1 on error.
    """
    return external_call[
        "epoll_wait", Int32, Int32, c_ptr[epoll_event], Int32, Int32
    ](epfd, events, maxevents, timeout)
