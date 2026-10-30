# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from libc.constant import *


def htonl(hostlong: c_uint) -> c_uint:
    """Libc POSIX `htonl` function.

    Reference: https://man7.org/linux/man-pages/man3/htonl.3p.html
    Fn signature: uint32_t htonl(uint32_t hostlong)

    Args: hostlong: A 32-bit unsigned integer in host byte order.
    Returns: A 32-bit unsigned integer in network byte order."""
    return external_call["htonl", c_uint, c_uint](hostlong)


def htons(hostshort: c_ushort) -> c_ushort:
    """Libc POSIX `htons` function.

    Reference: https://man7.org/linux/man-pages/man3/htonl.3p.html
    Fn signature: uint16_t htons(uint16_t hostshort)

    Args:
        hostshort: A 16-bit unsigned integer in host byte order.
    Returns: A 16-bit unsigned integer in network byte order.
    """
    return external_call["htons", c_ushort, c_ushort](hostshort)


def ntohl(netlong: c_uint) -> c_uint:
    """Libc POSIX `ntohl` function.

    Reference: https://man7.org/linux/man-pages/man3/htonl.3p.html
    Fn signature: uint32_t ntohl(uint32_t netlong)

    Args:
        netlong: A 32-bit unsigned integer in network byte order.
    Returns: A 32-bit unsigned integer in host byte order.
    """
    return external_call["ntohl", c_uint, c_uint](netlong)


def ntohs(netshort: c_ushort) -> c_ushort:
    """Libc POSIX `ntohs` function.

    Reference: https://man7.org/linux/man-pages/man3/htonl.3p.html
    Fn signature: uint16_t ntohs(uint16_t netshort)

    Args:
        netshort: A 16-bit unsigned integer in network byte order.
    Returns: A 16-bit unsigned integer in host byte order.
    """
    return external_call["ntohs", c_ushort, c_ushort](netshort)


def inet_pton(af: Int32, src: c_ptr[UInt8], dst: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `inet_pton` function.

    Reference:
        https://man7.org/linux/man-pages/man3/inet_pton.3.html

    Description:
        Converts a printable address into the binary form a `socketaddr`
        carries, which is the other half of the byte-order dance the four
        functions above only do half of: `htons` puts the port in network
        order, and this is what puts the address there.

    Args:
        af: The address family, `AF_INET` or `AF_INET6`.
        src: The printable form, NUL terminated.
        dst: Where the binary form goes. `AF_INET` writes 4 bytes and
            `AF_INET6` writes 16, so it has to be at least that big.

    Returns:
        1 when the address was valid, 0 when it was not, and -1 when `af`
        is not a family this knows about.

    Notes:
        Fn signature:
        `int inet_pton(int af, const char *restrict src, void *restrict dst)`.

        Unlike `inet_aton`, which it replaces, this refuses the sloppy
        forms — a leading zero is not octal and a bare number is not a
        packed address — so a string that reads back the same is the only
        kind that converts.
    """
    return external_call["inet_pton", Int32, Int32, c_ptr[UInt8], c_ptr[UInt8]](
        af, src, dst
    )


def inet_ntop(
    af: Int32, src: c_ptr[UInt8], dst: c_ptr[UInt8], size: c_size_t
) -> c_ptr[UInt8]:
    """Libc POSIX `inet_ntop` function.

    Reference:
        https://man7.org/linux/man-pages/man3/inet_ntop.3.html

    Description:
        Converts the binary form a `socketaddr` carries back into the
        printable one, the inverse of `inet_pton`.

    Args:
        af: The address family, `AF_INET` or `AF_INET6`.
        src: The binary form, 4 bytes for `AF_INET` and 16 for `AF_INET6`.
        dst: Where the printable form goes, NUL terminated.
        size: How many bytes `dst` holds.

    Returns:
        `dst`, or NULL when `size` was too small for the answer — in
        which case `errno` says `ENOSPC`. NULL here is `Int(p) == 0`,
        since `c_ptr` cannot itself be null.

    Notes:
        Fn signature:
        `const char *inet_ntop(int af, const void *restrict src, char *restrict dst, socklen_t size)`.

        Unlike `inet_ntoa`, which it replaces, this takes the family as an
        argument rather than assuming `AF_INET`, and a buffer rather than
        a single static one that every call would overwrite.
    """
    return external_call[
        "inet_ntop", c_ptr[UInt8], Int32, c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](af, src, dst, size)


struct in_addr(TrivialRegisterPassable):
    """A C `struct in_addr`: one IPv4 address, as it goes on the wire.

    One member and nothing to disagree about: a single four-byte
    `s_addr`, four bytes and four-aligned on glibc and on Darwin both.
    It is the whole of the struct, which is what makes it the one
    address in `netdb.h`'s world small enough to be handed about by
    value rather than pointed at.

    The bytes are in network order, which is the order they go on the
    wire in and not the order this machine counts in: 127.0.0.1 is
    `0x0100007f` here and not `0x7f000001`. `inet_addr` is what makes
    a printable address into one of these, and `inet_ntoa` what makes
    one printable again.
    """

    var s_addr: UInt32

    def __init__(out self):
        """Zeroes the address, which is the one written 0.0.0.0."""
        self.s_addr = 0


def inet_addr(cp: c_ptr[UInt8]) -> UInt32:
    """Libc POSIX `inet_addr` function.

    Description:
        Makes a printable IPv4 address into the four bytes that go on
        the wire.

    Args:
        cp: The address in numbers-and-dots, which is `127.0.0.1` and
            the rest of them.

    Returns:
        The address in network order, or the same number as the
        address 255.255.255.255 where it could not be read.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_addr.3.html).
        Fn signature: `in_addr_t inet_addr(const char *cp)`.

        The bytes come back in the order they go on the wire in, which
        is not the order this machine counts in: 127.0.0.1 is the
        number 16777343 here, and not the 2130706433 it is after
        `ntohl` has been over it. `inet_network` is the same address
        with the bytes the other way round, and having both is what
        tells the two orders apart.

        Where the address could not be read this hands back the same
        number as the address 255.255.255.255, which is to say a
        failure looks like an answer, and which is why `inet_aton` is
        the one to call: it says no in a number of its own.
    """
    return external_call["inet_addr", UInt32, c_ptr[UInt8]](cp)


def inet_network(cp: c_ptr[UInt8]) -> UInt32:
    """Libc BSD `inet_network` function.

    Description:
        Makes a printable IPv4 address into a number, with the bytes
        in the order this machine counts in.

    Args:
        cp: The address in numbers-and-dots.

    Returns:
        The address in host order, or -1 where it could not be read.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_network.3.html).
        Fn signature: `in_addr_t inet_network(const char *cp)`.

        This is `inet_addr` with the bytes the other way round: 127.0.0.1
        is the number 2130706433 here and the number 16777343 there.
        Which of the two a caller wants is which question it is
        asking — one wants the bytes to hand to a socket, which is
        `inet_addr`, and one wants a number to count with, which is
        this.

        It is on both platforms, though not in POSIX. Where the
        address could not be read this answers -1.
    """
    return external_call["inet_network", UInt32, c_ptr[UInt8]](cp)


def inet_aton(cp: c_ptr[UInt8], inp: c_ptr[in_addr]) -> Int32:
    """Libc BSD `inet_aton` function.

    Description:
        Makes a printable IPv4 address into the four bytes that go on
        the wire, putting them where the caller says.

    Args:
        cp: The address in numbers-and-dots.
        inp: Where to put the four bytes, which is written to.

    Returns:
        Non-zero where the address was read and zero where it could
        not be.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_addr.3.html).
        Fn signature: `int inet_aton(const char *cp, struct in_addr *inp)`.

        This is `inet_addr` that says no in a number of its own rather
        than in a number that is also an address, which is the fix
        for that one's trouble:
        it cannot hand back an answer that is also an address. The
        bytes it puts down are the same bytes, in the same order.

        `inet_pton` is what came after it and is what new code is
        written with, being the one that speaks `AF_INET6` as well.
        This one is asked for `AF_INET` only, and is on both platforms
        though not in POSIX.
    """
    return external_call["inet_aton", Int32, c_ptr[UInt8], c_ptr[in_addr]](
        cp, inp
    )


def inet_ntoa(address: in_addr) -> c_ptr[UInt8]:
    """Libc POSIX `inet_ntoa` function.

    Description:
        Makes the four bytes of an IPv4 address printable again.

    Args:
        address: The address itself, by value and not pointed at.

    Returns:
        The address in numbers-and-dots, in a string libc owns, which
        is not freed and is overwritten by the next call.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_addr.3.html).
        Fn signature: `char *inet_ntoa(struct in_addr in)`.

        This is `inet_addr` going the other way, and the round trip is
        what says the two of them agree: an address made printable and
        read back again is the address it was.

        What comes back is in storage libc holds, and every caller is
        handed the same place, so two answers cannot be held at once.
        `inet_ntop` is the one that takes a buffer of the caller's
        own, and is the one that speaks `AF_INET6` as well.
    """
    return external_call["inet_ntoa", c_ptr[UInt8], in_addr](address)


def inet_makeaddr(net: UInt32, host: UInt32) -> in_addr:
    """Libc BSD `inet_makeaddr` function.

    Description:
        Puts a network number and a host number together into one
        address, the old classful way.

    Args:
        net: The network part.
        host: The host part within it.

    Returns:
        The address, by value.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_netof.3.html).
        Fn signature: `struct in_addr inet_makeaddr(in_addr_t net,
            in_addr_t host)`.

        This is the other end of `inet_netof` and `inet_lnaof`, which
        take an address apart into the same two numbers it is made
        of: `inet_makeaddr` puts them back together. All three are of
        the classful network's own reckoning, where how much of an
        address is network and how much is host is told by its first
        bits rather than by a mask, and all three are on both
        platforms though not in POSIX.

        `inet_addr` is what makes an address out of the whole of it
        written down, which is the way addresses are written now.
    """
    return external_call["inet_makeaddr", in_addr, UInt32, UInt32](net, host)


def inet_netof(address: in_addr) -> UInt32:
    """Libc BSD `inet_netof` function.

    Description:
        Takes the network part out of an address, the old classful
        way.

    Args:
        address: The address itself, by value and not pointed at.

    Returns:
        The network part, in the order this machine counts in.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_netof.3.html).
        Fn signature: `in_addr_t inet_netof(struct in_addr in)`.

        `inet_lnaof` is the host part out of the same address and
        `inet_makeaddr` is the two parts put back together. Which
        bits are which is told by the address's own first bits —
        a class A address gives up eight, a class B sixteen, a class C
        twenty-four — which is why these are the classful network's
        own and not the way addresses are taken apart now.

        It is on both platforms, though not in POSIX.
    """
    return external_call["inet_netof", UInt32, in_addr](address)


def inet_lnaof(address: in_addr) -> UInt32:
    """Libc BSD `inet_lnaof` function.

    Description:
        Takes the host part out of an address, the old classful way.

    Args:
        address: The address itself, by value and not pointed at.

    Returns:
        The host part, in the order this machine counts in.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/inet_netof.3.html).
        Fn signature: `in_addr_t inet_lnaof(struct in_addr in)`.

        `inet_netof` is the network part out of the same address and
        `inet_makeaddr` is the two parts put back together, which is
        what makes these three a round trip: an address taken apart
        and put back is the address it was.

        Which bits are which is told by the address's own first bits,
        so what this answers for one address says nothing about what
        it answers for another. It is on both platforms, though not
        in POSIX.
    """
    return external_call["inet_lnaof", UInt32, in_addr](address)
