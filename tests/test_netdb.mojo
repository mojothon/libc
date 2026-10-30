"""Tests for the `libc.netdb` bindings.

The address-arithmetic functions in `libc.network` turn a printable
address into bytes and back; this is the one that decides which address to
use, and the only one here that talks to the name service. Every question
asked below is a numeric one, so no resolver is consulted and nothing
waits on the network.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AF_INET, AF_UNSPEC, SOCK_STREAM, c_ptr, c_ushort
from libc.network import htons
from libc.netdb import (
    AI_NUMERICHOST,
    AI_NUMERICSERV,
    EAI_NONAME,
    NI_MAXHOST,
    NI_MAXSERV,
    NI_NUMERICHOST,
    NI_NUMERICSERV,
    addrinfo,
    endprotoent,
    endservent,
    freeaddrinfo,
    gai_strerror,
    getaddrinfo,
    getnameinfo,
    getprotobyname,
    getprotobynumber,
    getservbyname,
    getservbyport,
)
from libc.utils import char_ptr_to_string, is_null, string_to_char_ptr


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


def test_the_address_answers_with_the_host_it_came_from() raises:
    """`getnameinfo` is the way back: given the address `getaddrinfo`
    wrote, it says which host and which port that was.

    Both directions are asked for numbers only, so the two calls meet in
    the middle without a resolver in sight. The buffers are `NI_MAXHOST`
    and `NI_MAXSERV`, which is the most either platform can write.
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
        getaddrinfo(node, service, hints, res), 0, "the address comes first"
    )
    var one = res[].unsafe_offset(0)

    var host = unsafe_alloc[UInt8](Int(NI_MAXHOST))
    var serv = unsafe_alloc[UInt8](Int(NI_MAXSERV))
    host.unsafe_offset(0)[] = 0
    serv.unsafe_offset(0)[] = 0

    assert_equal(
        getnameinfo(
            one[].ai_addr(),
            one[].ai_addrlen,
            host,
            UInt32(NI_MAXHOST),
            serv,
            UInt32(NI_MAXSERV),
            NI_NUMERICHOST | NI_NUMERICSERV,
        ),
        0,
        "and it goes back to the host and the port it was made from",
    )
    assert_equal(char_ptr_to_string(host), "127.0.0.1", "the host again")
    assert_equal(char_ptr_to_string(serv), "80", "and the port again")

    freeaddrinfo(res[])
    hints.unsafe_free()
    res.unsafe_free()
    node.unsafe_free()
    service.unsafe_free()
    host.unsafe_free()
    serv.unsafe_free()


def test_the_protocol_database_by_name_and_by_number() raises:
    """`getprotobyname` and `getprotobynumber` look a protocol up in
    the protocol database, one by its name and one by its number.

    Both are asked for TCP, which is in every machine's database and
    is numbered 6 in every one of them. What is asked of them is that
    they answer each other: the row found by name carries the number,
    and the row found by that number carries the name back. A call
    that read the number out of the wrong place in the row would not
    say 6, and one that read the name out of it would not say tcp.

    `endprotoent` shuts the database, and is called because it is
    there rather than because it is wanted: the two that look one
    protocol up open and shut it on their own.
    """
    var tcp = string_to_char_ptr("tcp")

    var by_name = getprotobyname(tcp)
    assert_true(not is_null(by_name), "tcp is in the protocol database, and")
    assert_equal(
        Int(by_name.unsafe_offset(0)[].p_proto),
        6,
        "the row found by name carries the number for TCP",
    )

    var by_number = getprotobynumber(6)
    assert_true(not is_null(by_number), "and 6 is in it too, carrying")
    assert_equal(
        char_ptr_to_string(by_number.unsafe_offset(0)[].p_name),
        "tcp",
        "the name back again",
    )

    endprotoent()
    tcp.unsafe_free()


def test_the_service_database_by_name_and_by_port() raises:
    """`getservbyname` and `getservbyport` look a service up in the
    service database, one by its name and one by its port.

    Both are asked for HTTP over TCP, which is on port 80 in every
    machine's database. The port in the row is in network order, which
    is the order it goes on the wire in and not the order this machine
    counts in, so what is asked for is 80 after `ntohs` has been over
    it — and what is handed to `getservbyport` is 80 after `htons`
    has. A row read without undoing the order says 20480 instead.

    `endservent` shuts the database, called because it is there rather
    than because it is wanted.
    """
    var http = string_to_char_ptr("http")
    var tcp = string_to_char_ptr("tcp")

    var by_name = getservbyname(http, tcp)
    assert_true(not is_null(by_name), "http over tcp is in the database, and")
    assert_equal(
        Int(by_name.unsafe_offset(0)[].port()),
        80,
        "the row found by name carries port 80",
    )
    assert_equal(
        char_ptr_to_string(by_name.unsafe_offset(0)[].s_proto),
        "tcp",
        "and says which protocol the port is for",
    )

    var by_port = getservbyport(Int32(htons(c_ushort(80))), tcp)
    assert_true(not is_null(by_port), "and 80 is in it too, carrying")
    assert_equal(
        char_ptr_to_string(by_port.unsafe_offset(0)[].s_name),
        "http",
        "the name back again",
    )

    endservent()
    http.unsafe_free()
    tcp.unsafe_free()


def main() raises:
    test_a_numeric_address_needs_no_name_service()
    test_a_name_that_is_not_a_number_is_refused()
    test_the_address_answers_with_the_host_it_came_from()
    test_the_protocol_database_by_name_and_by_number()
    test_the_service_database_by_name_and_by_port()
    print("test_netdb: ok")
