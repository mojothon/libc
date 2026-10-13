# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from std.utils.static_tuple import StaticTuple
from libc.constant import c_int, c_ptr


# What `accept4` is asked for, and both of them differ: SOCK_NONBLOCK is
# 2048 here and 16384 there, SOCK_CLOEXEC 524288 here and 16777216 there.
comptime SOCK_NONBLOCK: Int32 = 16384 if CompilationTarget.is_macos() else 2048
comptime SOCK_CLOEXEC: Int32 = 16777216 if CompilationTarget.is_macos() else 524288


struct socketaddr(TrivialRegisterPassable):
    """A socket address, as C's `struct sockaddr` has it: a family and
    fourteen bytes whose meaning is up to the family.

    Every call here takes a pointer to one of these whatever the family
    really is, because that is what C asks for and how it tells them
    apart. For `AF_INET` the first two bytes of `sa_data` are the port in
    network order and the four after that are the address, with the rest
    zero; for `AF_UNIX` it is a path. Nothing here packs or unpacks any
    of that for you.
    """

    var sa_family: UInt16
    var sa_data: StaticTuple[UInt8, 14]


def bind(
    socket: Int32, address: c_ptr[socketaddr], address_len: UInt32
) -> Int32:
    """Libc POSIX `bind` function.

    Reference: https://man7.org/linux/man-pages/man3/bind.3p.html
    Fn signature: int bind(int socket, const struct socketaddr *address, UInt32 address_len)

    Args:
        socket: Which socket, by its descriptor.
        address: The address to give it, which is what it is known by from
            then on.
        address_len: How big the address is.

    Returns:
        0, or -1 with `errno` set.
    """
    return external_call["bind", Int32, Int32, c_ptr[socketaddr], UInt32](
        socket, address, address_len
    )


def recvfrom(
    socket: Int32,
    buffer: c_ptr[UInt8],
    length: UInt64,
    flags: Int32,
    address: c_ptr[socketaddr],
    address_len: c_ptr[UInt32],
) -> Int:
    """Libc POSIX `recvfrom` function.

    Reference: https://man7.org/linux/man-pages/man3/recvfrom.3p.html
    Fn signature: ssize_t recvfrom(int socket, void *restrict buffer, size_t length, int flags, struct sockaddr *restrict address, UInt32 *restrict address_len)

    Args:
        socket: Which socket to read from.
        buffer: Where to put what comes in.
        length: How much room there is in the buffer.
        flags: `MSG_*` flags for this one call, or 0 for none.
        address: Where to put the address it came from, or a null pointer
            if that does not matter.
        address_len: In: how much room there is for the address. Out: how
            much of it was used.

    Returns:
        How many bytes came in, or -1 with `errno` set. 0 means the other
        end is finished, which is only the same as no bytes at all for a
        socket that works in datagrams.
    """
    return external_call[
        "recvfrom",
        Int,
        Int32,
        c_ptr[UInt8],
        UInt64,
        Int32,
        c_ptr[socketaddr],
        c_ptr[UInt32],
    ](socket, buffer, length, flags, address, address_len)


def recv(
    socket: Int32, buffer: c_ptr[UInt8], length: UInt64, flags: Int32
) -> Int:
    """Libc POSIX `recv` function.

    Reference: https://man7.org/linux/man-pages/man3/recv.3p.html
    Fn signature: ssize_t recv(int socket, void *buffer, size_t length, int flags)

    Args:
        socket: Which socket to read from.
        buffer: Where to put what comes in.
        length: How much room there is in the buffer.
        flags: `MSG_*` flags for this one call, or 0 for none.

    Returns:
        How many bytes came in, or -1 with `errno` set. 0 means the other
        end is finished, which is only the same as no bytes at all for a
        socket that works in datagrams.
    """
    return external_call[
        "recv",
        Int,  # FnName, RetType
        Int32,
        c_ptr[UInt8],
        UInt64,
        Int32,  # Args
    ](socket, buffer, length, flags)


def send(
    socket: Int32, buffer: c_ptr[UInt8], length: UInt64, flags: Int32
) -> Int:
    """Libc POSIX `send` function.

    Reference: https://man7.org/linux/man-pages/man3/send.3p.html
    Fn signature: ssize_t send(int socket, const void *buffer, size_t length, int flags)

    Args:
        socket: Which socket to write to.
        buffer: Where the bytes to send are.
        length: How many bytes to send.
        flags: `MSG_*` flags for this one call, or 0 for none.

    Returns:
        How many bytes it took, which on a socket that works as a stream
        can be fewer than were handed over, or -1 with `errno` set.
    """
    return external_call[
        "send",
        Int,  # FnName, RetType
        Int32,
        c_ptr[UInt8],
        UInt64,
        Int32,  # Args
    ](socket, buffer, length, flags)


def sendto(
    socket: Int32,
    message: c_ptr[UInt8],
    length: UInt64,
    flags: Int32,
    dest_addr: c_ptr[socketaddr],
    dest_len: UInt32,
) -> Int:
    """Libc POSIX `sendto` function.

    Reference: https://man7.org/linux/man-pages/man3/sendto.3p.html
    Fn signature: ssize_t sendto(int socket, const void *message, size_t length, int flags, const struct sockaddr *dest_addr, UInt32 dest_len)

    Args:
        socket: Which socket to write to.
        message: Where the bytes to send are.
        length: How many bytes to send.
        flags: `MSG_*` flags for this one call, or 0 for none.
        dest_addr: Where to send it, which a socket with no connection of
            its own needs and a connected one may leave out.
        dest_len: How big the address is.

    Returns:
        How many bytes it took, which can be fewer than were handed over,
        or -1 with `errno` set.
    """
    return external_call[
        "sendto",
        Int,  # FnName, RetType
        Int32,
        c_ptr[UInt8],
        UInt64,
        Int32,
        c_ptr[socketaddr],
        UInt32,  # Args
    ](socket, message, length, flags, dest_addr, dest_len)


struct iovec(TrivialRegisterPassable):
    """One piece of a scattered read or write: where it starts and how
    long it is.
    """

    var iov_base: c_ptr[UInt8]
    var iov_len: UInt64

    def __init__(out self, iov_base: c_ptr[UInt8], iov_len: UInt64):
        """One piece: `iov_len` bytes starting at `iov_base`.

        Args:
            iov_base: Where the piece starts.
            iov_len: How many bytes long it is. C takes this as `size_t`,
                which is 64 bits on both platforms this package targets.
        """
        self.iov_base = iov_base
        self.iov_len = iov_len


struct msghdr(TrivialRegisterPassable):
    """One message for `sendmsg`, holding the address it goes to and the
    pieces it is made of, which are not all in one place.
    """

    var msg_name: c_ptr[UInt8]
    # `socklen_t`, 32 bits and unsigned on both platforms. It was `UInt16`
    # here, and the struct came out 56 bytes either way because the padding
    # after it swallows the difference, which is how it went unnoticed: C
    # writes four bytes at `msg_namelen`, and a 16-bit field reads the low
    # half of them.
    var msg_namelen: UInt32
    var msg_iov: c_ptr[iovec]
    var msg_iovlen: UInt64
    var msg_control: c_ptr[UInt8]
    var msg_controllen: UInt64
    var msg_flags: Int32


def sendmsg(sockfd: Int32, msg: c_ptr[msghdr], flags: Int32) -> Int64:
    """Libc POSIX `sendmsg` function.

    Reference: https://man7.org/linux/man-pages/man3/sendmsg.3p.html
    Fn signature: ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags)

    Args:
        sockfd: Which socket to write to.
        msg: The message: where it goes, and where the pieces of it are
            when they are not all in one place.
        flags: `MSG_*` flags for this one call, or 0 for none.

    Returns:
        How many bytes it took, or -1 with `errno` set.
    """
    return external_call["sendmsg", Int64, Int32, c_ptr[msghdr], Int32](
        sockfd, msg, flags
    )


def socket(domain: Int32, type: Int32, protocol: Int32) -> Int32:
    """Libc POSIX `socket` function.

    Reference: https://man7.org/linux/man-pages/man3/socket.3p.html
    Fn signature: int socket(int domain, int type, int protocol)

    Args:
        domain: Which address family, as one of the `AF_*`.
        type: What kind of socket, as one of the `SOCK_*`.
        protocol: Which protocol to speak, which is 0 for the one that
            goes without saying given the other two; otherwise one of the
            `IPPROTO_*`.

    Returns:
        A descriptor for the new socket, or -1 with `errno` set. It is
        closed with `close` here when it is no longer wanted.
    """
    return external_call[
        "socket", Int32, Int32, Int32, Int32  # FnName, RetType  # Args
    ](domain, type, protocol)


def socketpair(
    domain: Int32, type: Int32, protocol: Int32, sv: c_ptr[Int32]
) -> Int32:
    """Libc POSIX `socketpair` function.

    Reference: https://man7.org/linux/man-pages/man3/socketpair.3p.html
    Fn signature: int socketpair(int domain, int type, int protocol, int sv[2])

    Args:
        domain: Which address family, as one of the `AF_*`.
        type: What kind of socket, as one of the `SOCK_*`.
        protocol: Which protocol to speak, which is 0 for the one that
            goes without saying given the other two.
        sv: Room for two descriptors, which this fills in.

    Returns:
        0, or -1 with `errno` set. What is written into one end of the
        pair comes out of the other, and both have to be closed when they
        are no longer wanted.
    """
    return external_call[
        "socketpair",
        Int32,
        Int32,
        Int32,
        Int32,
        c_ptr[Int32],  # FnName, RetType  # Args
    ](domain, type, protocol, sv)


def connect(
    socket: Int32, address: c_ptr[socketaddr], address_len: UInt32
) -> Int32:
    """Libc POSIX `connect` function.

    Reference: https://man7.org/linux/man-pages/man3/connect.3p.html
    Fn signature: int connect(int socket, const struct socketaddr *address, UInt32 address_len)

    Args:
        socket: Which socket, by its descriptor.
        address: Where to connect to.
        address_len: How big the address is.

    Returns:
        0, or -1 with `errno` set. For a socket that works as a stream
        this is when the connection is made; for one that works in
        datagrams it only says where to send by default, and nothing is
        sent yet.
    """
    return external_call[
        "connect",
        Int32,
        Int32,
        c_ptr[socketaddr],
        UInt32,  # FnName, RetType  # Args
    ](socket, address, address_len)


def listen(socket: Int32, backlog: Int32) -> Int32:
    """Libc POSIX `listen` function.

    Reference: https://man7.org/linux/man-pages/man3/listen.3p.html
    Fn signature: int listen(int socket, int backlog)

    Args:
        socket: Which socket, by its descriptor, which has to have been
            bound to an address already.
        backlog: How many connections may be waiting to be accepted at
            once. What happens to the ones after that is up to the
            system: some turn them away and some leave them hanging.

    Returns:
        0, or -1 with `errno` set.
    """
    return external_call["listen", Int32, Int32, Int32](socket, backlog)


def accept(
    socket: Int32, address: c_ptr[socketaddr], address_len: c_ptr[UInt32]
) -> Int32:
    """Libc POSIX `accept` function.

    Reference: https://man7.org/linux/man-pages/man3/accept.3p.html
    Fn signature: int accept(int socket, struct socketaddr *restrict address, UInt32 *restrict address_len)

    Args:
        socket: Which socket to take a connection from, which has to be
            listening already.
        address: Where to put the address of what connected, or a null
            pointer if that does not matter.
        address_len: In: how much room there is for the address. Out: how
            much of it was used.

    Returns:
        A descriptor for the connection, which is a socket of its own and
        has to be closed when it is done with, or -1 with `errno` set.
        The one being listened to stays open and keeps listening.
    """
    return external_call[
        "accept",
        Int32,
        Int32,
        c_ptr[socketaddr],
        c_ptr[UInt32],  # FnName, RetType  # Args
    ](socket, address, address_len)


def getsockname(
    socket: Int32, address: c_ptr[socketaddr], address_len: c_ptr[UInt32]
) -> Int32:
    """Libc POSIX `getsockname` function.

    Reference: https://man7.org/linux/man-pages/man3/getsockname.3p.html
    Fn signature: int getsockname(int socket, struct socketaddr *restrict address, UInt32 *restrict address_len)

    Args:
        socket: Which socket, by its descriptor.
        address: Where to put the address this end is bound to.
        address_len: In: how much room there is for the address. Out: how
            much of it was used.

    Returns:
        0, or -1 with `errno` set.
    """
    return external_call[
        "getsockname",
        Int32,
        Int32,
        c_ptr[socketaddr],
        c_ptr[UInt32],  # FnName, RetType  # Args
    ](socket, address, address_len)


def getpeername(
    socket: Int32, address: c_ptr[socketaddr], address_len: c_ptr[UInt32]
) -> Int32:
    """Libc POSIX `getpeername` function.

    Reference: https://man7.org/linux/man-pages/man3/getpeername.3p.html
    Fn signature: int getpeername(int socket, struct socketaddr *restrict address, UInt32 *restrict address_len)

    Args:
        socket: Which socket, by its descriptor.
        address: Where to put the address of the other end.
        address_len: In: how much room there is for the address. Out: how
            much of it was used.

    Returns:
        0, or -1 with `errno` set. A socket with no other end has none to
        give, and says so with `ENOTCONN`.
    """
    return external_call[
        "getpeername",
        Int32,
        Int32,
        c_ptr[socketaddr],
        c_ptr[UInt32],  # FnName, RetType  # Args
    ](socket, address, address_len)


def shutdown(socket: Int32, how: Int32) -> Int32:
    """Libc POSIX `shutdown` function.

    Reference: https://man7.org/linux/man-pages/man3/shutdown.3p.html
    Fn signature: int shutdown(int socket, int how)

    Args:
        socket: Which socket, by its descriptor.
        how: `SHUT_RD` to stop reading, `SHUT_WR` to stop writing, or
            `SHUT_RDWR` for both.

    Returns:
        0, or -1 with `errno` set. This is not `close`: the socket is
        still there and still has to be closed, and stopping the writing
        end is what sends the end of it to the other side.
    """
    return external_call[
        "shutdown", Int32, Int32, Int32  # FnName, RetType  # Args
    ](socket, how)


def close(socket: Int32) -> Int32:
    """Libc POSIX `close` function.

    Reference: https://man7.org/linux/man-pages/man3/close.3p.html
    Fn signature: int close(int socket)

    Args:
        socket: Which socket, by its descriptor.

    Returns:
        0, or -1 with `errno` set. The descriptor is gone either way once
        this comes back, so what it says is whether the last of it was
        done and not whether to keep using it.
    """
    return external_call["close", Int32, Int32](  # FnName, RetType  # Args
        socket
    )


def accept4(
    socket: Int32,
    address: c_ptr[socketaddr],
    address_len: c_ptr[UInt32],
    flags: Int32,
) -> Int32:
    """Libc POSIX `accept4` function.

    Reference: https://man7.org/linux/man-pages/man2/accept4.2.html
    Fn signature: int accept4(int socket, struct socketaddr *restrict address, UInt32 *restrict address_len, int flags)

    Args:
        socket: Which socket to take a connection from, which has to be
            listening already.
        address: Where to put the address of what connected, or a null
            pointer if that does not matter.
        address_len: In: how much room there is for the address. Out: how
            much of it was used.
        flags: `SOCK_NONBLOCK` to put the new socket in non-blocking mode
            and `SOCK_CLOEXEC` to close it on `exec`, or both together.
            Both are Linux-only and their values are not the same as the
            `O_NONBLOCK` and `O_CLOEXEC` used everywhere else, so take
            them from `<sys/socket.h>` rather than writing the numbers
            down.

    Returns:
        A descriptor for the connection, which is a socket of its own and
        has to be closed when it is done with, or -1 with `errno` set.
    """
    return external_call[
        "accept4",
        Int32,
        Int32,
        c_ptr[socketaddr],
        c_ptr[UInt32],
        Int32,  # FnName, RetType  # Args
    ](socket, address, address_len, flags)


def getsockopt(
    sockfd: c_int,
    level: c_int,
    optname: c_int,
    optval: c_ptr[NoneType],
    optlen: c_ptr[UInt32],
) -> c_int:
    """Libc POSIX `getsockopt` function.

    Args:
        sockfd: A socket.
        level: Which layer owns the option, as one of the `SOL_*`.
        optname: Which option, as one of the `SO_*`.
        optval: Where to write the value, whose shape is the option's.
        optlen: How much room `optval` has, and how much was written.

    Returns:
        0 on success. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/getsockopt.2.html).
        Fn signature: `int getsockopt(int sockfd, int level, int optname,
        void *restrict optval, socklen_t *restrict optlen)`.

        `optval` is `void *` because each option has a shape of its own:
        `SO_REUSEADDR` is an int, `SO_RCVTIMEO` is a `timeval`. Passing an
        `int` where a `timeval` belongs is accepted and wrong, and nothing
        here can tell them apart — the option's own page says which.
    """
    return external_call[
        "getsockopt", c_int, c_int, c_int, c_int, c_ptr[NoneType], c_ptr[UInt32]
    ](sockfd, level, optname, optval, optlen)


def setsockopt(
    sockfd: c_int,
    level: c_int,
    optname: c_int,
    optval: c_ptr[NoneType],
    optlen: UInt32,
) -> c_int:
    """Libc POSIX `setsockopt` function.

    Args:
        sockfd: A socket.
        level: Which layer owns the option, as one of the `SOL_*`.
        optname: Which option, as one of the `SO_*`.
        optval: The value, whose shape is the option's.
        optlen: How big that value is.

    Returns:
        0 on success. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/setsockopt.2.html).
        Fn signature: `int setsockopt(int sockfd, int level, int optname,
        const void *optval, socklen_t optlen)`.

        The same shape caveat as `getsockopt`: `optlen` is what keeps an
        `int` from being read as a `timeval`, and it is on the caller to
        say it right.
    """
    return external_call[
        "setsockopt", c_int, c_int, c_int, c_int, c_ptr[NoneType], UInt32
    ](sockfd, level, optname, optval, optlen)
