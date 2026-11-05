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
from libc.network import in_addr


# What `accept4` is asked for, and both of them differ: SOCK_NONBLOCK is
# 2048 here and 16384 there, SOCK_CLOEXEC 524288 here and 16777216 there.
comptime SOCK_NONBLOCK: Int32 = 16384 if CompilationTarget.is_macos() else 2048
comptime SOCK_CLOEXEC: Int32 = 16777216 if CompilationTarget.is_macos() else 524288


# Where the family sits, and where Darwin's `sa_len` does. glibc's
# `struct sockaddr` starts with a two-byte `sa_family`; XNU's starts with a
# one-byte `sa_len` and puts a one-byte `sa_family` after it, so the family
# is at 1 there and the length at 0. Both are sixteen bytes, which is why
# the size alone never showed this.
#
# Numbers from `bits/socket.h` and XNU `sys/socket.h`, and checked with C's
# `offsetof` by `scripts/check-layouts.py` — `sa_len` only on Darwin, where
# it exists, and the script says so on Linux rather than skipping it.
comptime SOCKADDR_SLOTS: Int = 8
comptime SOCKADDR_LEN_OFFSET: Int = 0
comptime SOCKADDR_FAMILY_OFFSET: Int = 1 if CompilationTarget.is_macos() else 0

# Where an `AF_INET` address keeps its two numbers. C names them `sin_port`
# and `sin_addr`, and they land in the same place on both platforms: the
# two bytes after the family, then the four after those. They are the same
# offsets on Darwin because its `sa_len` and family fill the same two bytes
# between them that glibc spends on a two-byte family alone -- which is the
# reason one pair of numbers serves both, and `check-layouts.py` asks C's
# `offsetof` about `sockaddr_in` on each.
comptime SOCKADDR_INET_PORT_OFFSET: Int = 2
comptime SOCKADDR_INET_ADDRESS_OFFSET: Int = 4


struct socketaddr:
    """A socket address, as C's `struct sockaddr` has it: a family and
    fourteen bytes whose meaning is up to the family.

    Every call here takes a pointer to one of these whatever the family
    really is, because that is what C asks for and how it tells them
    apart. For `AF_INET` the first two bytes of `sa_data` are the port in
    network order and the four after that are the address, with the rest
    zero; for `AF_UNIX` it is a path, and nothing here packs or unpacks
    that one for you. `AF_INET` is packed and unpacked: `set_inet_port`
    and `set_inet_address` write the two numbers where C's `sockaddr_in`
    keeps them, and the reading halves give them back.

    The two platforms do not put the family in the same place. glibc's
    leads with a two-byte `sa_family` and Darwin's puts a `sa_len` byte
    in front of it, so there the family is one byte at offset 1, and
    `sa_len` wants filling in with the size of the whole address before
    the address is handed to C. Both structs are sixteen bytes, which is
    why the size alone never showed this. So the bytes are held as they
    come and the family is set and read by method, `set_family` writing
    `sa_len` too where the platform has one.
    """

    var _slots: Array[UInt16, SOCKADDR_SLOTS]

    def __init__(out self):
        """Zeroes all sixteen bytes, which is what `memset` would leave."""
        self._slots = Array[UInt16, SOCKADDR_SLOTS](fill=0)

    def _byte(self, off: Int) -> UInt8:
        """The one byte at `off`."""
        return UInt8((self._slots[off // 2] >> UInt16((off % 2) * 8)) & 0xFF)

    def _set_byte(mut self, off: Int, value: UInt8) -> None:
        """Writes one byte at `off`, leaving its neighbour alone."""
        var at = off // 2
        var shift = UInt16((off % 2) * 8)
        var mask = UInt16(0xFF) << shift
        self._slots[at] = (self._slots[at] & (mask ^ UInt16(0xFFFF))) | (
            UInt16(value) << shift
        )

    def _u16(self, off: Int) -> UInt16:
        """The two bytes at a two-aligned `off`, little-endian."""
        return UInt16((self._slots[off // 2] >> UInt16((off % 2) * 8)) & 0xFFFF)

    def _set_u16(mut self, off: Int, value: UInt16) -> None:
        """Writes the two bytes at a two-aligned `off`, leaving the rest."""
        var slot = off // 2
        var shift = UInt16((off % 2) * 8)
        var keep = (UInt16(0xFF) << shift) ^ UInt16(0xFFFF)
        self._slots[slot] = (self._slots[slot] & keep) | (value << shift)

    def _u16be(self, off: Int) -> UInt16:
        """The two bytes at a two-aligned `off`, big-endian.

        Which is the order the network counts in and this machine does
        not, so these are the two bytes as they lie with the first one
        high: 0x1F, 0x90 reads as 0x1F90.
        """
        return (UInt16(self._byte(off)) << 8) | UInt16(self._byte(off + 1))

    def _set_u16be(mut self, off: Int, value: UInt16) -> None:
        """Writes the two bytes at a two-aligned `off`, first one high."""
        self._set_byte(off, UInt8((value >> 8) & 0xFF))
        self._set_byte(off + 1, UInt8(value & 0xFF))

    def _u32(self, off: Int) -> UInt32:
        """The four bytes at a four-aligned `off`, as the word they lie in.

        Little-endian, like the machine: the byte at `off` is the low one.
        This is how `s_addr` holds an address -- the wire's bytes, read as
        the number this machine would make of them.
        """
        var at = off // 2
        return UInt32(self._slots[at]) | (UInt32(self._slots[at + 1]) << 16)

    def _set_u32(mut self, off: Int, value: UInt32) -> None:
        """Writes four bytes at a four-aligned `off`, low byte first."""
        var at = off // 2
        self._slots[at] = UInt16(value & 0xFFFF)
        self._slots[at + 1] = UInt16((value >> 16) & 0xFFFF)

    def family(self) -> UInt16:
        """The address family, `AF_INET` and friends."""
        comptime if CompilationTarget.is_macos():
            return UInt16(self._byte(SOCKADDR_FAMILY_OFFSET))
        else:
            return self._u16(SOCKADDR_FAMILY_OFFSET)

    def set_family(mut self, value: UInt16) -> None:
        """Sets the family, and `sa_len` with it where Darwin has one."""
        comptime if CompilationTarget.is_macos():
            self._set_byte(
                SOCKADDR_LEN_OFFSET, 16
            )  # the size of a struct sockaddr
            self._set_byte(SOCKADDR_FAMILY_OFFSET, UInt8(value))
        else:
            self._set_u16(SOCKADDR_FAMILY_OFFSET, value)

    def byte(self, off: Int) -> UInt8:
        """The byte at `off` of the sixteen, the family's own data."""
        return self._byte(off)

    def set_byte(mut self, off: Int, value: UInt8) -> None:
        """Writes the byte at `off` of the sixteen, as the family asks."""
        self._set_byte(off, value)

    def inet_port(self) -> UInt16:
        """The `AF_INET` port, in the order a port is said in.

        The two bytes are in network order on the wire, which is the
        opposite of the order this machine counts in: port 8080 goes down
        as 0x1F and then 0x90, and reads back here as 8080 rather than as
        0x901F. This is the `ntohs` half of the pair, done on the bytes
        already in place.
        """
        return self._u16be(SOCKADDR_INET_PORT_OFFSET)

    def set_inet_port(mut self, port: UInt16) -> None:
        """Writes an `AF_INET` port into the two bytes, in network order.

        This is the `htons` half, and it is what `bind` and `connect` read:
        a port written the other way round is a different port, and the
        one call would wait on a number the other never asks for.

        Args:
            port: The port, in the order a port is said in. 0 leaves the
                choice to the kernel, which `getsockname` is then asked
                about.
        """
        self._set_u16be(SOCKADDR_INET_PORT_OFFSET, port)

    def inet_address(self) -> in_addr:
        """The `AF_INET` address, as C's `struct in_addr` holds one.

        The four bytes go in as they lie, which is network order and so
        also what `s_addr` holds: on these little-endian machines the 0x7F
        of 127.0.0.1 is the low byte of the word and the number reads
        0x0100007F, the one `inet_addr` gives for the same text.
        `inet_ntoa` is what prints it back, and `INADDR_LOOPBACK` is that
        same number.
        """
        var answer = in_addr()
        answer.s_addr = self._u32(SOCKADDR_INET_ADDRESS_OFFSET)
        return answer

    def set_inet_address(mut self, address: in_addr) -> None:
        """Writes an `AF_INET` address into the four bytes, as `in_addr`
        holds one: network order, the bytes as they lie.

        Args:
            address: The address, from `inet_addr` or `inet_pton` or one of
                the `INADDR_*` numbers.
        """
        self._set_u32(SOCKADDR_INET_ADDRESS_OFFSET, address.s_addr)


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


# Where each member of C's `struct msghdr` sits. The first three agree and
# the rest do not: glibc makes `msg_iovlen` and `msg_controllen` `size_t`,
# XNU makes them `int` and `socklen_t`, four bytes each, so Darwin's struct
# is 48 bytes with `msg_flags` at 44 and glibc's is 56 with it at 48 — the
# one member that is in the high half of a word on one platform and a word
# of its own on the other.
#
# Numbers from `bits/socket.h` and XNU `sys/socket.h`, and all seven are
# compared with C's `offsetof` on both platforms by
# `scripts/check-layouts.py`.
comptime MSGHDR_SLOTS: Int = 7
comptime MSGHDR_NAME_OFFSET: Int = 0
comptime MSGHDR_NAMELEN_OFFSET: Int = 8
comptime MSGHDR_IOV_OFFSET: Int = 16
comptime MSGHDR_IOVLEN_OFFSET: Int = 24
comptime MSGHDR_CONTROL_OFFSET: Int = 32
comptime MSGHDR_CONTROLLEN_OFFSET: Int = 40
comptime MSGHDR_FLAGS_OFFSET: Int = 44 if CompilationTarget.is_macos() else 48


# The `struct cmsghdr` that heads ancillary data is not the same struct
# twice, and the difference is in the length's width, which moves every
# member behind it. glibc's is sixteen bytes: the length is a `size_t`
# at 0, the level and the type are ints at 8 and 12, and the data begins
# at 16. XNU's is twelve: the length is a `socklen_t` at 0, the level and
# the type are at 4 and 8, and the data begins at 12. A control message
# built with glibc's shape answers EINVAL from XNU, which is how the
# descriptor test found this — every shape of the wrong one, at every
# room `CMSG_SPACE` of the right one suggests, refused.
#
# `CMSGHDR_LEN_ONE` is `CMSG_LEN` of one descriptor and
# `CMSGHDR_SPACE_ONE` is `CMSG_SPACE` of it, the length and the room an
# ancillary message of one descriptor travels in. The offsets and widths
# are compared with C's `offsetof` and `sizeof` on both platforms by
# `scripts/check-layouts.py`.
comptime CMSGHDR_LEN_OFFSET: Int = 0
comptime CMSGHDR_LEN_BYTES: Int = 4 if CompilationTarget.is_macos() else 8
comptime CMSGHDR_LEVEL_OFFSET: Int = 4 if CompilationTarget.is_macos() else 8
comptime CMSGHDR_TYPE_OFFSET: Int = 8 if CompilationTarget.is_macos() else 12
comptime CMSGHDR_HEADER_BYTES: Int = 12 if CompilationTarget.is_macos() else 16
comptime CMSGHDR_LEN_ONE: Int = 16 if CompilationTarget.is_macos() else 20
comptime CMSGHDR_SPACE_ONE: Int = 16 if CompilationTarget.is_macos() else 24


struct msghdr:
    """One message for `sendmsg`, holding the address it goes to and the
    pieces it is made of, which are not all in one place.

    The two platforms agree on the first three members and then not on
    the widths. Darwin's `msg_iovlen` is an `int` and its
    `msg_controllen` a `socklen_t`, four bytes each, so its struct is 48
    bytes and `msg_flags` sits at 44. glibc makes both of them eight
    bytes, its struct is 56, and `msg_flags` is at 48. Held in slots and
    read and written at the offset and width that fit, which is why the
    members come from methods. 56 covers both.

    The offsets are named above and the widths are on the lines that use
    them, so the one member that moves — `msg_flags`, from the high half
    of the `msg_controllen` word on Darwin to a word of its own on glibc —
    is a constant rather than a shift written out three times.
    """

    var _slots: Array[UInt64, MSGHDR_SLOTS]

    def __init__(out self):
        """Zeroes the message, which is what `memset` would leave."""
        self._slots = Array[UInt64, MSGHDR_SLOTS](fill=0)

    def _at(self, off: Int) -> UInt64:
        """The eight bytes at an eight-aligned `off`."""
        return self._slots[off // 8]

    def _u32(self, off: Int) -> UInt64:
        """The four bytes at a four-aligned `off`, little-endian."""
        return (self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFFFFFFFF

    def _set_at(mut self, off: Int, value: UInt64) -> None:
        """Writes the eight bytes at an eight-aligned `off`."""
        self._slots[off // 8] = value

    def _set_u32(mut self, off: Int, value: UInt64) -> None:
        """Writes the four bytes at a four-aligned `off`, leaving the rest."""
        var slot = off // 8
        var shift = UInt64((off % 8) * 8)
        var keep = ~(UInt64(0xFFFFFFFF) << shift)
        self._slots[slot] = (self._slots[slot] & keep) | (
            (value & 0xFFFFFFFF) << shift
        )

    def msg_name(self) -> c_ptr[UInt8]:
        """Where the address goes, or null for a connected socket."""
        return c_ptr[UInt8](
            unsafe_from_address=Int(self._at(MSGHDR_NAME_OFFSET))
        )

    def set_msg_name(mut self, value: c_ptr[UInt8]) -> None:
        """Sets where the address comes from."""
        self._set_at(MSGHDR_NAME_OFFSET, UInt64(Int(value)))

    def msg_namelen(self) -> UInt32:
        """How long the address is, a `socklen_t` on both platforms."""
        return UInt32(self._u32(MSGHDR_NAMELEN_OFFSET))

    def set_msg_namelen(mut self, value: UInt32) -> None:
        """Sets how long the address is."""
        self._set_u32(MSGHDR_NAMELEN_OFFSET, UInt64(value))

    def msg_iov(self) -> c_ptr[iovec]:
        """The scatter/gather array of pieces the message is made of."""
        return c_ptr[iovec](
            unsafe_from_address=Int(self._at(MSGHDR_IOV_OFFSET))
        )

    def set_msg_iov(mut self, value: c_ptr[iovec]) -> None:
        """Sets the array of pieces."""
        self._set_at(MSGHDR_IOV_OFFSET, UInt64(Int(value)))

    def msg_iovlen(self) -> UInt64:
        """How many pieces the array holds, an `int` on Darwin."""
        comptime if CompilationTarget.is_macos():
            return self._u32(MSGHDR_IOVLEN_OFFSET)
        else:
            return self._at(MSGHDR_IOVLEN_OFFSET)

    def set_msg_iovlen(mut self, value: UInt64) -> None:
        """Sets how many pieces there are."""
        comptime if CompilationTarget.is_macos():
            self._set_u32(MSGHDR_IOVLEN_OFFSET, value)
        else:
            self._set_at(MSGHDR_IOVLEN_OFFSET, value)

    def msg_control(self) -> c_ptr[UInt8]:
        """The ancillary data, or null when there is none."""
        return c_ptr[UInt8](
            unsafe_from_address=Int(self._at(MSGHDR_CONTROL_OFFSET))
        )

    def set_msg_control(mut self, value: c_ptr[UInt8]) -> None:
        """Sets the ancillary data."""
        self._set_at(MSGHDR_CONTROL_OFFSET, UInt64(Int(value)))

    def msg_controllen(self) -> UInt64:
        """How much ancillary data there is."""
        comptime if CompilationTarget.is_macos():
            return self._u32(MSGHDR_CONTROLLEN_OFFSET)
        else:
            return self._at(MSGHDR_CONTROLLEN_OFFSET)

    def set_msg_controllen(mut self, value: UInt64) -> None:
        """Sets how much ancillary data there is.

        On Darwin that is four bytes with `msg_flags` in the four above
        it, so only the low half is written.
        """
        comptime if CompilationTarget.is_macos():
            self._set_u32(MSGHDR_CONTROLLEN_OFFSET, value)
        else:
            self._set_at(MSGHDR_CONTROLLEN_OFFSET, value)

    def msg_flags(self) -> Int32:
        """The flags on a message that was received."""
        return Int32(self._u32(MSGHDR_FLAGS_OFFSET))

    def set_msg_flags(mut self, value: Int32) -> None:
        """Sets the flags."""
        self._set_u32(MSGHDR_FLAGS_OFFSET, UInt64(value))


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


def recvmsg(sockfd: Int32, msg: c_ptr[msghdr], flags: Int32) -> Int64:
    """Libc POSIX `recvmsg` function.

    Reference: https://man7.org/linux/man-pages/man3/recvmsg.3p.html
    Fn signature: ssize_t recvmsg(int sockfd, struct msghdr *msg, int flags)

    Args:
        sockfd: Which socket to read from.
        msg: The message to fill in: where the pieces of it go, and room
            for the address and the ancillary data if either is wanted.
            It is written, not read, apart from those three pointers.
        flags: `MSG_*` flags for this one call, or 0 for none.

    Returns:
        How many bytes arrived, which can be fewer than there was room
        for, 0 at the end of a stream, or -1 with `errno` set.

    Notes:
        The other half of `sendmsg`, and the reason both exist: a message
        that arrives in pieces can be put into pieces, with one call and
        one return value rather than one per piece.

        `msg_flags` says what was true of the message that arrived —
        `MSG_TRUNC` when it did not fit, for instance — and on glibc it
        starts from zero, so the flags this was called with are not in
        it. XNU starts it from them instead: `recvit` is handed a
        `msg_flags` already set to the third argument and only adds to
        it, so a `MSG_PEEK` read on Darwin comes back reporting
        `MSG_PEEK` in a field that reads like an answer. Nothing is
        wrong with the bytes; it is the same word being used for two
        things on one platform.

        `MSG_PEEK` is what makes the returned count worth reading twice:
        the bytes are put into the pieces and left in the socket, so the
        next call sees the same ones.
    """
    return external_call["recvmsg", Int64, Int32, c_ptr[msghdr], Int32](
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


def sockatmark(sockfd: Int32) -> Int32:
    """Libc POSIX `sockatmark` function.

    Reference: https://man7.org/linux/man-pages/man3/sockatmark.3p.html
    Fn signature: `int sockatmark(int sockfd)`

    Args:
        sockfd: Which socket to ask.

    Returns:
        1 where the next thing to be read is the out-of-band mark,
        0 where it is not, or -1 with `errno` set where `sockfd` is
        not a socket that can be asked.

    Notes:
        This is the question the `SIOCATMARK` request asks, spelled
        as a function: it says whether the read pointer has reached
        the place in the stream where a byte sent out of band went,
        which is how a receiver finds the urgent byte without reading
        past it. What reading the urgent byte does to the mark is the
        platforms' own answer: Linux keeps it where it was until
        ordinary reading moves past that place, and Darwin drops it as
        the urgent byte is read.
    """
    return external_call["sockatmark", Int32, Int32](sockfd)
