"""Tests for the `libc.ifaddrs` bindings.

The list of network interfaces is read, not written to, and no socket
is opened: `getifaddrs` asks the kernel what it already knows. What the
tests do not assume is what the interfaces are *called* — `lo` on glibc
and `lo0` on Darwin — so nothing here matches a name against a string.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, AF_INET6, c_ptr
from libc.sys.socket import socketaddr
from libc.ifaddrs import (
    IFF_BROADCAST,
    IFF_LOOPBACK,
    IFF_POINTOPOINT,
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


def test_the_loopback_mask_is_an_eight_and_the_broadcasts_do_the_math() raises:
    """`ifa_netmask` is the mask that goes with the address and
    `ifa_dstaddr` is the far end or the broadcast, and the three of them
    — address, mask, far end — have to agree with each other, which is
    the one thing a getter reading some other member could not fake.

    Every IPv4 entry carries a mask in its own family whose bytes only
    go down: a run of 255s and then a run of 0s, and never a 1 after a
    0. The loopback's is an eight — 255.0.0.0, the answer both platforms
    give for it. An interface that broadcasts names the broadcast
    address in `ifa_dstaddr`, and that address is the interface's own
    address with the mask turned inside out, byte by byte. glibc also
    hands entries that do not broadcast a far end — the loopback gets
    its own address there — and whatever it hands is in the family of
    the address, which is the only claim the empty side of it carries.
    """
    var list = unsafe_alloc[c_ptr[ifaddrs]](1)
    list.unsafe_offset(0)[] = null_ptr[ifaddrs]()

    var got = getifaddrs(list)
    assert_equal(got, 0, "the list of interfaces comes back")

    var head = list[]
    var node = head
    var loopback_masked = False
    var broadcast_math = False
    var seen = 0
    while seen < MOST_WE_WILL_WALK and not is_null(node):
        var flags = Int(node[].ifa_flags())
        var addr = node[].ifa_addr()
        if not is_null(addr) and Int(addr[].family()) == AF_INET:
            var mask = node[].ifa_netmask()
            assert_true(
                not is_null(mask),
                "an IPv4 entry with no mask where one belongs",
            )
            assert_equal(
                Int(mask[].family()),
                AF_INET,
                "the mask is in the family of the address",
            )
            var going_down = True
            var last = 255
            for place in range(4):
                var piece = Int(mask[].byte(4 + place))
                going_down = going_down and piece <= last
                last = piece
            assert_true(
                going_down,
                "the mask only ever goes down: 255s and then 0s",
            )

            if (flags & IFF_LOOPBACK) != 0:
                assert_equal(
                    Int(mask[].byte(4)),
                    255,
                    "the loopback mask is an eight: 255",
                )
                assert_equal(
                    Int(mask[].byte(5))
                    + Int(mask[].byte(6))
                    + Int(mask[].byte(7)),
                    0,
                    "and then three zeros",
                )
                loopback_masked = True

            # An interface that broadcasts names its broadcast, and the
            # broadcast is the address with the mask turned inside out.
            # glibc even hands entries that do not broadcast a far end —
            # the loopback gets its own address there — and whatever it
            # hands, it hands in the family of the address.
            var far = node[].ifa_dstaddr()
            if (flags & IFF_BROADCAST) != 0:
                assert_true(
                    not is_null(far),
                    "an interface that broadcasts names the broadcast",
                )
                assert_equal(
                    Int(far[].family()),
                    AF_INET,
                    "and the broadcast is in the same family",
                )
                var matches = True
                for place in range(4):
                    var own = Int(addr[].byte(4 + place))
                    var coverage = Int(mask[].byte(4 + place))
                    var said = Int(far[].byte(4 + place))
                    matches = matches and said == own | (255 - coverage)
                assert_true(
                    matches,
                    "and the broadcast is the address with the mask "
                    + "turned inside out",
                )
                broadcast_math = True
            elif not is_null(far):
                assert_equal(
                    Int(far[].family()),
                    AF_INET,
                    "whatever names a far end names it in the "
                    + "address's family",
                )

        node = node[].ifa_next()
        seen += 1

    assert_true(loopback_masked, "there is a loopback in IPv4 to ask about")
    assert_true(
        broadcast_math,
        "and there is a broadcast interface to do the math with",
    )

    freeifaddrs(head)
    list.unsafe_free()


def test_the_packet_entries_carry_data_and_no_mask() raises:
    """`ifa_data` is the address family's own block, which the packet
    and link families fill and nobody else does — and those same
    entries carry no mask, which is what says the entry is one of them
    and not an IPv4 one whose getter read some other member's pointer.

    Every interface gets one of these entries: one per interface rather
    than one per address, so the machine has several, and the signature
    is an address that is in neither Internet family, a mask that is
    empty, and data that is not.
    """
    var list = unsafe_alloc[c_ptr[ifaddrs]](1)
    list.unsafe_offset(0)[] = null_ptr[ifaddrs]()

    var got = getifaddrs(list)
    assert_equal(got, 0, "the list of interfaces comes back")

    var head = list[]
    var node = head
    var carries_data = False
    var seen = 0
    while seen < MOST_WE_WILL_WALK and not is_null(node):
        var addr = node[].ifa_addr()
        var data = node[].ifa_data()
        if not is_null(data) and not is_null(addr):
            var of = Int(addr[].family())
            if of != Int(AF_INET) and of != Int(AF_INET6):
                assert_true(
                    is_null(node[].ifa_netmask()),
                    "a packet entry names no mask",
                )
                carries_data = True
        node = node[].ifa_next()
        seen += 1

    assert_true(
        carries_data,
        "there is a packet or link entry with its own block of data",
    )

    freeifaddrs(head)
    list.unsafe_free()


def main() raises:
    test_every_interface_in_the_list_is_named()
    test_the_loopback_is_up_and_answers_in_ipv4()
    test_the_loopback_mask_is_an_eight_and_the_broadcasts_do_the_math()
    test_the_packet_entries_carry_data_and_no_mask()
    print("test_ifaddrs: ok")
