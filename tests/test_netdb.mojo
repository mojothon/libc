"""Tests for the `libc.netdb` bindings.

The address-arithmetic functions in `libc.network` turn a printable
address into bytes and back; this is the one that decides which address to
use, and the only one here that talks to the name service. Every question
asked below is a numeric one, so no resolver is consulted and nothing
waits on the network.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, AF_UNSPEC, SOCK_STREAM, c_ptr
from libc.netdb import (
    AI_NUMERICHOST,
    AI_NUMERICSERV,
    EAI_NONAME,
    addrinfo,
    freeaddrinfo,
    gai_strerror,
    getaddrinfo,
)
from libc.utils import char_ptr_to_string, string_to_char_ptr


def test_a_numeric_address_needs_no_name_service() raises:
    """`127.0.0.1` with `AI_NUMERICHOST` is a number and not a name, so
    the call cannot consult the resolver: it either converts it or refuses
    it.

    What is checked is that the call answers 0, that what it wrote is a
    real `addrinfo` with the family and the type that were asked for, and
    that the address inside it is the four bytes 127.0.0.1 is. The bytes
    are read at a fixed offset rather than through `ai_addr` as a
    `socketaddr`, because the two platforms disagree about what the first
    two bytes of a `struct sockaddr` are: Darwin puts a length in front of
    the family. Port and address sit at 2 and 4 either way.
    """
    var hints = unsafe_alloc[addrinfo](1)
    hints.unsafe_offset(0)[] = addrinfo()
    hints.unsafe_offset(0)[].ai_family = AF_UNSPEC
    hints.unsafe_offset(0)[].ai_socktype = SOCK_STREAM
    hints.unsafe_offset(0)[].ai_flags = AI_NUMERICHOST | AI_NUMERICSERV

    var res = unsafe_alloc[c_ptr[addrinfo]](1)
    var node = string_to_char_ptr("127.0.0.1")
    var service = string_to_char_ptr("80")

    assert_equal(
        getaddrinfo(node, service, hints, res),
        0,
        "a numeric address and a numeric port need no lookup",
    )

    var first = res[]
    assert_true(Int(first) != 0, "and it wrote a list to walk")
    var one = first.unsafe_offset(0)
    assert_equal(
        one[].ai_family, AF_INET, "which came back in the family asked for"
    )
    assert_equal(one[].ai_socktype, SOCK_STREAM, "and the type with it")
    assert_true(Int(one[].ai_addr()) != 0, "and there is an address in it")
    assert_true(Int(one[].ai_addrlen) >= 16, "and it is a whole socket address")

    var bytes = one[].ai_addr()
    assert_equal(Int(bytes.unsafe_offset(4)[]), 127, "127 first")
    assert_equal(Int(bytes.unsafe_offset(5)[]), 0, "then 0")
    assert_equal(Int(bytes.unsafe_offset(6)[]), 0, "then 0")
    assert_equal(Int(bytes.unsafe_offset(7)[]), 1, "then 1")
    assert_equal(
        Int(bytes.unsafe_offset(2)[]) * 256 + Int(bytes.unsafe_offset(3)[]),
        80,
        "and the port was 80",
    )

    freeaddrinfo(first)
    hints.unsafe_free()
    res.unsafe_free()
    node.unsafe_free()
    service.unsafe_free()


def test_a_name_that_is_not_a_number_is_refused() raises:
    """A host that is neither a name nor a number is refused, and the
    answer is one of the `EAI_*` rather than -1.

    `AI_NUMERICHOST` is what makes this answer without a resolver: it says
    the host has to be a number already, so any name is refused on the
    spot. Without it the call would ask the network for a name that does
    not exist, which is slow where there is a resolver and a different
    error where there is not.

    The value is named rather than written down: glibc's `EAI_NONAME` is
    -2 and XNU's is 8, so a number in this test would have passed on one
    platform and failed on the other.
    """
    var hints = unsafe_alloc[addrinfo](1)
    hints.unsafe_offset(0)[] = addrinfo()
    hints.unsafe_offset(0)[].ai_flags = AI_NUMERICHOST | AI_NUMERICSERV

    var res = unsafe_alloc[c_ptr[addrinfo]](1)
    var node = string_to_char_ptr("not-an-address")
    var service = string_to_char_ptr("80")

    var answered = getaddrinfo(node, service, hints, res)
    assert_equal(
        answered,
        EAI_NONAME,
        "and it says so with the name it could not resolve",
    )
    assert_true(
        char_ptr_to_string(gai_strerror(answered)).byte_length() > 0,
        "and there is a sentence to go with it",
    )

    hints.unsafe_free()
    res.unsafe_free()
    node.unsafe_free()
    service.unsafe_free()


def main() raises:
    test_a_numeric_address_needs_no_name_service()
    test_a_name_that_is_not_a_number_is_refused()
    print("test_netdb: ok")
