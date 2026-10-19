# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr, c_uint
from libc.utils import char_ptr_to_string


# Sixteen on both, and the longest name an interface may have.
comptime IF_NAMESIZE = 16


struct IfNameindex:
    """A C `struct if_nameindex`: one interface's number and its name.

    Spelled without the underscore because `if_nameindex` the function
    takes the name the C struct would have had; the two cannot share one
    here the way `struct` lets them share one in C.

    Two members and both in the same place on glibc and on Darwin: an
    `unsigned int` index at 0 and a `char *` name at 8, sixteen bytes
    and eight-aligned either way. `if_nameindex` hands back an array of
    these with a last one whose index is 0 and whose name is null, and
    that pair is how the end is known — there is no count to go with it.

    The names are the kernel's own, `lo0` on Darwin and `lo` on glibc,
    `en0` against `eth0`, so nothing here is portable to write down.
    """

    var _bytes: Array[UInt64, 2]

    def __init__(out self):
        """Zeroes the block, which is the pair that ends the array."""
        self._bytes = Array[UInt64, 2](fill=0)

    def if_index(self) -> UInt32:
        """The number the kernel knows the interface by, counting from 1.
        Zero means the entry is the one that ends the array and not an
        interface at all.
        """
        return UInt32(self._bytes[0] & 0xFFFFFFFF)

    def if_name(self) raises -> String:
        """The name of that interface. Null on the entry that ends the
        array, where the name is read as an empty string.
        """
        var held = self._bytes[1]
        if held == 0:
            return String("")
        return char_ptr_to_string(c_ptr[UInt8](unsafe_from_address=Int(held)))


def if_nametoindex(ifname: c_ptr[UInt8]) -> c_uint:
    """C library POSIX function `if_nametoindex`.

    Reference:
        https://man7.org/linux/man-pages/man3/if_nametoindex.3.html

    Description:
        Asks for the number the kernel has given the interface called
        `ifname`. The names are the kernel's own, so this is the only
        way to ask without knowing what they are called here.

    Args:
        ifname: The name of an interface, as `if_nameindex` hands them
            out or as `getifaddrs` names them.

    Returns:
        The number of the interface, or 0 when no interface is called
        that — `errno` is `ENXIO` for the second, and never set for
        the first.
    """
    return external_call["if_nametoindex", c_uint, c_ptr[UInt8]](ifname)


def if_indextoname(ifindex: c_uint, ifname: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library POSIX function `if_indextoname`.

    Reference:
        https://man7.org/linux/man-pages/man3/if_indextoname.3.html

    Args:
        ifindex: The number of an interface, one `if_nametoindex` or
            `if_nameindex` has given and not a number made up here.
        ifname: Where the name is written, which wants room for
            `IF_NAMESIZE`: sixteen, the longest name there is.

    Returns:
        `ifname` itself — the same pointer — with the name in it, or
        null when no interface has that number, `errno` set to `ENXIO`.

    Notes:
        Fn signature:
        `char *if_indextoname(unsigned int ifindex, char *ifname)`.

        The buffer is a C string when this comes back, so read it with
        `char_ptr_to_string`. Give it `IF_NAMESIZE` and no less, or a
        long name is cut off rather than refused.
    """
    return external_call["if_indextoname", c_ptr[UInt8], c_uint, c_ptr[UInt8]](
        ifindex, ifname
    )


def if_nameindex() -> c_ptr[IfNameindex]:
    """C library POSIX function `if_nameindex`.

    Reference:
        https://man7.org/linux/man-pages/man3/if_nameindex.3.html

    Description:
        Every interface the kernel has, as an array of `if_nameindex`:
        a number and a name each, in the kernel's own order. The one
        that ends the array has 0 for its number and a null for its
        name, and that is the only end there is — no count comes with
        it. The array is one allocation and `if_freenameindex` is the
        only thing that releases it.

    Returns:
        The array of every interface, or null with `errno` set when it
        could not be had.

    Notes:
        Fn signature: `struct if_nameindex *if_nameindex(void)`.
    """
    return external_call["if_nameindex", c_ptr[IfNameindex]]()


def if_freenameindex(ptr: c_ptr[IfNameindex]) -> None:
    """C library POSIX function `if_freenameindex`.

    Reference:
        https://man7.org/linux/man-pages/man3/if_nameindex.3.html

    Args:
        ptr: The array `if_nameindex` gave back. The whole array is one
            allocation, so this takes the first of it and nothing else
            releases these bytes — not `free`, and not once per entry.
    """
    external_call["if_freenameindex", NoneType, c_ptr[IfNameindex]](ptr)
