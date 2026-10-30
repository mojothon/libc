from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, AF_INET6, c_size_t
from libc.network import (
    htonl,
    htons,
    in_addr,
    inet_addr,
    inet_aton,
    inet_lnaof,
    inet_makeaddr,
    inet_netof,
    inet_network,
    inet_ntoa,
    inet_ntop,
    inet_pton,
    ntohl,
    ntohs,
)
from libc.utils import char_ptr_to_string, string_to_char_ptr


def test_htonl() raises:
    assert_equal(htonl(0x12345678), 0x78563412)


def test_htons() raises:
    assert_equal(htons(0x1234), 0x3412)


def test_ntohl() raises:
    assert_equal(ntohl(0x78563412), 0x12345678)


def test_ntohs() raises:
    assert_equal(ntohs(0x3412), 0x1234)


def test_inet_pton_round_trips_an_ipv4() raises:
    """A dotted quad in, the four bytes `socketaddr` carries, and back.

    The point of the round trip rather than the one-way conversion is
    that it does not need the byte order spelled out: 1.2.3.4 is
    01 02 03 04 in the buffer whichever way round the machine keeps its
    integers, so an implementation that got the order wrong would come
    back as something else and fail here.
    """
    var text = string_to_char_ptr("1.2.3.4")
    var bin = unsafe_alloc[UInt8](4)
    for i in range(4):
        bin.unsafe_store(i, 0)

    assert_equal(
        inet_pton(AF_INET, text, bin),
        1,
        "1.2.3.4 is an address in the AF_INET family",
    )
    assert_equal(bin.unsafe_load(0), 1, "and the first byte is 1")
    assert_equal(bin.unsafe_load(1), 2, "the second is 2")
    assert_equal(bin.unsafe_load(2), 3, "the third is 3")
    assert_equal(bin.unsafe_load(3), 4, "the fourth is 4")

    # And back the other way, into a buffer big enough for the longest
    # IPv4 form plus its terminator.
    var out = unsafe_alloc[UInt8](16)
    for i in range(16):
        out.unsafe_store(i, 0)
    assert_true(
        Int(inet_ntop(AF_INET, bin, out, c_size_t(16))) != 0,
        "and it converts back",
    )
    assert_equal(
        char_ptr_to_string(out),
        "1.2.3.4",
        "to the same dotted quad it started as",
    )

    text.unsafe_free()
    bin.unsafe_free()
    out.unsafe_free()


def test_inet_pton_refuses_what_is_not_an_address() raises:
    """A string that is not an address answers 0, and not -1: the family
    was fine, the text was not.
    """
    var text = string_to_char_ptr("not an address")
    var bin = unsafe_alloc[UInt8](4)
    assert_equal(
        inet_pton(AF_INET, text, bin), 0, "and not an address is not one"
    )
    assert_equal(
        inet_pton(999, text, bin), -1, "a family nobody has answers -1"
    )
    text.unsafe_free()
    bin.unsafe_free()


def test_inet_pton_round_trips_an_ipv6() raises:
    """The same round trip at sixteen bytes, which is where the family
    number matters: `AF_INET6` is 10 on Linux and 30 on Darwin, so a test
    that wrote the number down would convert on one and fail on the other.
    """
    var text = string_to_char_ptr("::1")
    var bin = unsafe_alloc[UInt8](16)
    for i in range(16):
        bin.unsafe_store(i, 0)

    assert_equal(
        inet_pton(AF_INET6, text, bin),
        1,
        "::1 is an address in the AF_INET6 family",
    )
    # ::1 is fifteen zero bytes and a one, so all of it but the last is 0.
    for i in range(15):
        assert_equal(bin.unsafe_load(i), 0, "and it starts with fifteen zeroes")
    assert_equal(bin.unsafe_load(15), 1, "and ends with a one")

    var out = unsafe_alloc[UInt8](46)
    for i in range(46):
        out.unsafe_store(i, 0)
    assert_true(
        Int(inet_ntop(AF_INET6, bin, out, c_size_t(46))) != 0,
        "and it converts back",
    )
    assert_equal(char_ptr_to_string(out), "::1", "to the same short form")

    text.unsafe_free()
    bin.unsafe_free()
    out.unsafe_free()


def test_an_address_written_down_and_read_back() raises:
    """`inet_addr` makes a printable address into the four bytes that
    go on the wire, and `inet_ntoa` makes them printable again.

    The round trip is the strong part of this, and it is what says the
    two of them agree: an address made printable and read back again
    is the address it was. It asks nothing about which way round the
    bytes are, which the next test does.

    `inet_aton` is the same four bytes put where the caller says
    rather than handed back, and it is asked for the same address:
    what it puts down has to be what `inet_addr` handed back.

    All three are asked for 127.0.0.1, which is an address with no
    name service and no network behind it.
    """
    var written = string_to_char_ptr("127.0.0.1")

    var as_bytes = inet_addr(written)
    var address = in_addr()
    address.s_addr = as_bytes

    assert_equal(
        char_ptr_to_string(inet_ntoa(address)),
        "127.0.0.1",
        "an address written down and read back is the address it was",
    )

    var put = unsafe_alloc[in_addr](1)
    assert_true(inet_aton(written, put) != 0, "and it was read, putting down")
    assert_equal(
        put.unsafe_offset(0)[].s_addr,
        as_bytes,
        "the same four bytes inet_addr handed back",
    )

    written.unsafe_free()
    put.unsafe_free()


def test_the_bytes_go_on_the_wire_one_way_and_are_counted_the_other() raises:
    """`inet_addr` and `inet_network` make the same address into two
    numbers that are the same four bytes the two ways round.

    127.0.0.1 is 16777343 by one and 2130706433 by the other, and
    which is which is the whole of what they are for: one is the
    bytes to hand to a socket, and one is a number to count with. A
    call that handed back the wrong one would say the other's number,
    which is why both are written down here rather than one.

    This is the one place in the package where what is held to is a
    machine's own byte order — these are small-endian numbers, and a
    big-endian machine would read both the other way round.
    """
    var written = string_to_char_ptr("127.0.0.1")

    assert_equal(
        inet_addr(written),
        16777343,
        "127.0.0.1 as it goes on the wire is 16777343",
    )
    assert_equal(
        inet_network(written),
        2130706433,
        "and as this machine counts it is 2130706433",
    )

    written.unsafe_free()


def test_an_address_taken_apart_and_put_back_together() raises:
    """`inet_netof` and `inet_lnaof` take an address apart into a
    network number and a host number, and `inet_makeaddr` puts the
    two back together.

    What is asked is the round trip, which asks nothing about which
    bits are which: an address taken apart and put back is the address
    it was. That is as well, because how much of an address is network
    and how much is host is told by its own first bits — 127.0.0.1 is
    of class A, which gives up eight — so what these answer for one
    address says nothing about what they answer for another.
    """
    var written = string_to_char_ptr("127.0.0.1")

    var address = in_addr()
    address.s_addr = inet_addr(written)

    var net = inet_netof(address)
    var host = inet_lnaof(address)

    var together = inet_makeaddr(net, host)
    assert_equal(
        together.s_addr,
        address.s_addr,
        "an address taken apart and put back together is itself",
    )
    assert_true(net != host, "and the two parts of it are not the same number")

    written.unsafe_free()


def main() raises:
    test_htonl()
    test_htons()
    test_ntohl()
    test_ntohs()
    test_inet_pton_round_trips_an_ipv4()
    test_inet_pton_refuses_what_is_not_an_address()
    test_inet_pton_round_trips_an_ipv6()
    test_an_address_written_down_and_read_back()
    test_the_bytes_go_on_the_wire_one_way_and_are_counted_the_other()
    test_an_address_taken_apart_and_put_back_together()
    print("test_network: ok")
