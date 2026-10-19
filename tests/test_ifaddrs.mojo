"""Tests for the `libc.ifaddrs` bindings.

The list of network interfaces is read, not written to, and no socket
is opened: `getifaddrs` asks the kernel what it already knows. What the
tests do not assume is what the interfaces are *called* — `lo` on glibc
and `lo0` on Darwin — so nothing here matches a name against a string.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, c_ptr
from libc.ifaddrs import (
    IFF_LOOPBACK,
    IFF_UP,
    freeifaddrs,
    getifaddrs,
    ifaddrs,
)
from libc.utils import is_null, null_ptr

# No machine has sixty-four interfaces and a list with a loop in it
# would otherwise be walked forever.
comptime MOST_WE_WILL_WALK = 64


def test_every_interface_in_the_list_is_named() raises:
    """A linked list of every interface the kernel has, threaded by
    `ifa_next` and ended by a null. Each one is a whole interface with
    its own name, so the test walks to the end and reads the name of
    each, which is the one member every entry has.
    """
    var list = unsafe_alloc[c_ptr[ifaddrs]](1)
    list.unsafe_offset(0)[] = null_ptr[ifaddrs]()

    var got = getifaddrs(list)
    assert_equal(got, 0, "the list of interfaces comes back")

    var head = list[]
    var node = head
    var seen = 0
    while seen < MOST_WE_WILL_WALK and not is_null(node):
        assert_true(
            node[].ifa_name().byte_length() > 0, "and every entry is named"
        )
        node = node[].ifa_next()
        seen += 1
    assert_true(seen > 0, "there is at least one interface")
    assert_true(seen < MOST_WE_WILL_WALK, "and the list ends in a null")

    freeifaddrs(head)

    list.unsafe_free()


def test_the_loopback_is_up_and_answers_in_ipv4() raises:
    """Two things every machine has and neither names the same way. The
    loopback is up — `IFF_LOOPBACK` with `IFF_UP` — and it answers in
    `AF_INET`, which is the family `127.0.0.1` is in.

    The family is read out of the address `socketaddr` hands back, and
    that is where the two platforms differ: glibc puts a two-byte
    family first and Darwin a length byte in front of it, which is why
    `family` is a method there and not a field.
    """
    var list = unsafe_alloc[c_ptr[ifaddrs]](1)
    list.unsafe_offset(0)[] = null_ptr[ifaddrs]()

    var got = getifaddrs(list)
    assert_equal(got, 0, "the list of interfaces comes back")

    var head = list[]
    var node = head
    var up_loopback = False
    var answers_in_v4 = False
    var seen = 0
    while seen < MOST_WE_WILL_WALK and not is_null(node):
        var flags = Int(node[].ifa_flags())
        if (flags & IFF_LOOPBACK) != 0 and (flags & IFF_UP) != 0:
            up_loopback = True

        var addr = node[].ifa_addr()
        if not is_null(addr) and Int(addr[].family()) == AF_INET:
            answers_in_v4 = True

        node = node[].ifa_next()
        seen += 1

    assert_true(up_loopback, "the loopback is there and up")
    assert_true(answers_in_v4, "and it answers in AF_INET")

    freeifaddrs(head)

    list.unsafe_free()


def main() raises:
    test_every_interface_in_the_list_is_named()
    test_the_loopback_is_up_and_answers_in_ipv4()
    print("test_ifaddrs: ok")
