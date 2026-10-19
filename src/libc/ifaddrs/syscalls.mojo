# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr
from libc.sys.socket import socketaddr
from libc.utils import char_ptr_to_string


# The five `IFF_*` flags both platforms give the same number, which is
# the low five of the set: `IFF_UP`, `IFF_BROADCAST`, `IFF_LOOPBACK`,
# `IFF_POINTOPOINT` and `IFF_RUNNING` at 0x1, 0x2, 0x8, 0x10 and 0x40
# either way. `IFF_MULTICAST` is 0x1000 on glibc and 0x8000 on Darwin,
# and `IFF_LOWER_UP` and `IFF_DORMANT` are Linux only; none of the three
# is here.
comptime IFF_UP = 1
comptime IFF_BROADCAST = 2
comptime IFF_LOOPBACK = 8
comptime IFF_POINTOPOINT = 16
comptime IFF_RUNNING = 64


struct ifaddrs:
    """A C `struct ifaddrs`: one network interface's worth of addresses.

    Seven members, all in the same place on glibc and on Darwin: `ifa_next`,
    `ifa_name`, `ifa_flags`, `ifa_addr`, `ifa_netmask`, `ifa_dstaddr` and
    `ifa_data` at 0, 8, 16, 24, 32, 40 and 48, fifty-six bytes and
    eight-aligned either way. `ifa_flags` is a `u32` whose other four
    bytes are padding; `ifa_dstaddr` is a union with `ifa_broadaddr` on
    glibc and a flat pointer on Darwin, but it is the same slot. The
    whole struct is a linked list threaded by `ifa_next` — read it
    until it reads null.

    The object this points at belongs to libc; `freeifaddrs` is the only
    way out, and only on the head.
    """

    var _bytes: Array[UInt64, 7]

    def __init__(out self):
        """Zeroes the block, which is the state of one nothing has filled."""
        self._bytes = Array[UInt64, 7](fill=0)

    def _member(self, offset: Int) -> UInt64:
        """The eight bytes at `offset`, where each of these members begins."""
        return self._bytes[offset // 8]

    def ifa_next(self) -> c_ptr[ifaddrs]:
        """The next entry of the linked list, or null when this is the
        last one. Walking the list with this is the only way to see them
        all; `getifaddrs` gives the head, `freeifaddrs` is the only
        release and it takes the head too.
        """
        return c_ptr[ifaddrs](unsafe_from_address=Int(self._member(0)))

    def ifa_name(self) raises -> String:
        """The name of the interface, as in `lo0` on Darwin or `lo` on
        glibc. Every entry is named, even the half a half.
        """
        var held = self._member(8)
        if held == 0:
            return String("")
        return char_ptr_to_string(c_ptr[UInt8](unsafe_from_address=Int(held)))

    def ifa_flags(self) -> UInt32:
        """The bits from `SIOCGIFFLAGS`, which is what `ifconfig` shows
        the first column for. `IFF_UP` and `IFF_LOOPBACK` are the two
        every loopback has set, and `IFF_RUNNING` is the one a working
        interface carries.
        """
        return UInt32(self._member(16) & 0xFFFFFFFF)

    def ifa_addr(self) -> c_ptr[socketaddr]:
        """The address the interface answers at, which is what
        `bind(2)` would take and what `getnameinfo` would translate back
        to a hostname. Null for entries that have no address — most often
        the second one for the loopback, the IPv6 one. Read the family
        with `family` on `socketaddr`.
        """
        return c_ptr[socketaddr](unsafe_from_address=Int(self._member(24)))

    def ifa_netmask(self) -> c_ptr[socketaddr]:
        """The netmask for the address, in the same family. Null when
        there is no address, the loopback's IPv6 one for instance.
        """
        return c_ptr[socketaddr](unsafe_from_address=Int(self._member(32)))

    def ifa_dstaddr(self) -> c_ptr[socketaddr]:
        """The destination for a point-to-point link, the broadcast
        address for a broadcast link: the same slot on both, and the
        header's macros make them two names for one. Null for any
        interface that is neither.
        """
        return c_ptr[socketaddr](unsafe_from_address=Int(self._member(40)))

    def ifa_data(self) -> c_ptr[UInt8]:
        """Address-specific data, mostly for `AF_LINK` on Darwin and
        seldom useful from the outside. Null on most entries.
        """
        return c_ptr[UInt8](unsafe_from_address=Int(self._member(48)))


def getifaddrs(ifap: c_ptr[c_ptr[ifaddrs]]) -> Int32:
    """C library <ifaddrs.h> function `getifaddrs`.

    Reference:
        https://man7.org/linux/man-pages/man3/getifaddrs.3.html

    Description:
        Walks every network interface the kernel knows about and hands
        back a linked list, one node per `(interface, family)` pair: the
        loopback gets one for `AF_INET` and another for `AF_INET6`,
        every other interface as many times as it answers in different
        families. The list is linked by `ifa_next` and the head is what
        `freeifaddrs` is handed.

    Args:
        ifap: Where the head pointer is written. The caller zeroes it
            first, the way `errno` is zeroed, and reads it once
            `getifaddrs` has come back.

    Returns:
        0 on success, or -1 with `errno` set: `EAGAIN` for a transient
        allocation problem, `EAFNOSUPPORT` for an address family the
        kernel did not hand back, and `ENOMEM` for nothing else.

    Notes:
        Fn signature:
        `int getifaddrs(struct ifaddrs **ifap)`.
    """
    return external_call["getifaddrs", Int32, c_ptr[c_ptr[ifaddrs]]](ifap)


def freeifaddrs(ifa: c_ptr[ifaddrs]) -> None:
    """C library <ifaddrs.h> function `freeifaddrs`.

    Reference:
        https://man7.org/linux/man-pages/man3/getifaddrs.3.html

    Args:
        ifa: The head of the list `getifaddrs` gave back. Nothing else
            releases these bytes: walking the list does not free it,
            `free` on the head is the wrong call, and reading past
            `freeifaddrs` is reading freed memory.
    """
    external_call["freeifaddrs", NoneType, c_ptr[ifaddrs]](ifa)
