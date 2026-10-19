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
