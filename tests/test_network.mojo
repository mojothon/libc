from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, AF_INET6, c_size_t
from libc.network import htonl, htons, inet_ntop, inet_pton, ntohl, ntohs
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


def main() raises:
    test_htonl()
    test_htons()
    test_ntohl()
    test_ntohs()
    test_inet_pton_round_trips_an_ipv4()
    test_inet_pton_refuses_what_is_not_an_address()
    test_inet_pton_round_trips_an_ipv6()
    print("test_network: ok")
