"""Tests for the `libc.sys.socket` bindings that had never been called.

`socket` itself had been; the fourteen that turn a socket into a
connection had not. They are tried here over the loopback address and
over a socket pair, neither of which leaves the machine, and every
port is left to the kernel to choose and then asked for, so nothing
here can collide with anything else that is running.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import (
    AF_INET,
    AF_UNIX,
    MSG_PEEK,
    SHUT_RDWR,
    SOCK_DGRAM,
    SOCK_STREAM,
)
from libc.sys.socket import (
    accept,
    accept4,
    bind,
    connect,
    getpeername,
    getsockname,
    iovec,
    listen,
    msghdr,
    recv,
    recvmsg,
    recvfrom,
    send,
    sendmsg,
    sendto,
    shutdown,
    socket,
    socketaddr,
    socketpair,
)
from libc.unistd import close

comptime ADDRESS_SIZE: UInt32 = 16


def loopback(mut addr: socketaddr, port: Int) -> None:
    """Fills in the loopback address on `port`.

    Both platforms put the port in the two bytes after the family —
    Darwin's `sa_len` and family take the same two between them — and
    the four bytes of the address after that, so one filling serves
    both. A port of 0 is left for the kernel to choose.

    Args:
        addr: The sixteen bytes to fill in.
        port: The port, or 0 to have the kernel choose one.
    """
    addr = socketaddr()
    addr.set_family(UInt16(AF_INET))
    addr.set_byte(2, UInt8((port >> 8) & 0xFF))
    addr.set_byte(3, UInt8(port & 0xFF))
    addr.set_byte(4, 127)
    addr.set_byte(5, 0)
    addr.set_byte(6, 0)
    addr.set_byte(7, 1)


def port_of(ref addr: socketaddr) -> Int:
    """The port, read back out of the two bytes it was written into."""
    return Int(addr.byte(2)) * 256 + Int(addr.byte(3))


def ask_the_port(of: Int32) raises -> Int:
    """Which port a bound socket was given, which is only known by asking.

    Args:
        of: The bound socket.

    Returns:
        The port.
    """
    var addr = unsafe_alloc[socketaddr](1)
    var length = unsafe_alloc[UInt32](1)
    length.unsafe_offset(0)[] = ADDRESS_SIZE
    assert_equal(getsockname(of, addr, length), 0, "getsockname answers")
    var port = port_of(addr.unsafe_offset(0)[])
    addr.unsafe_free()
    length.unsafe_free()
    return port


def test_a_connection_over_the_loopback() raises:
    """`bind` gives a socket an address, `listen` says it is willing to
    be connected to, `connect` asks, and `accept` takes what asked. The
    port is not chosen here: 0 is handed over and `getsockname` is then
    asked which one that turned out to be, there being no way of
    knowing beforehand and no way of colliding if there is.
    """
    var server = socket(AF_INET, SOCK_STREAM, 0)
    assert_true(server >= 0, "a socket to listen on")

    var unspecified = unsafe_alloc[socketaddr](1)
    loopback(unspecified.unsafe_offset(0)[], 0)
    assert_equal(
        bind(server, unspecified, ADDRESS_SIZE),
        0,
        "it is bound to the loopback",
    )
    assert_equal(listen(server, 1), 0, "and it is listening")

    var port = ask_the_port(server)
    assert_true(port > 0, "and the port it was given is not none")

    var client = socket(AF_INET, SOCK_STREAM, 0)
    assert_true(client >= 0, "a socket to connect with")
    var there = unsafe_alloc[socketaddr](1)
    loopback(there.unsafe_offset(0)[], port)
    assert_equal(
        connect(client, there, ADDRESS_SIZE),
        0,
        "and it connects to the listener",
    )

    var mine = ask_the_port(client)

    # `accept` writes the address of whoever asked into the buffer it
    # is given, which is why it gets one of its own and not the one
    # `connect` was pointed at.
    var caller = unsafe_alloc[socketaddr](1)
    var caller_length = unsafe_alloc[UInt32](1)
    caller_length.unsafe_offset(0)[] = ADDRESS_SIZE
    var taken = accept(server, caller, caller_length)
    assert_true(taken >= 0, "accept takes the connection")
    assert_equal(
        port_of(caller.unsafe_offset(0)[]),
        mine,
        "and it says who asked, port and all",
    )

    # Of the two ends, `getpeername` names the one that is not you.
    var peer = unsafe_alloc[socketaddr](1)
    var peer_length = unsafe_alloc[UInt32](1)
    peer_length.unsafe_offset(0)[] = ADDRESS_SIZE
    assert_equal(
        getpeername(taken, peer, peer_length), 0, "getpeername answers"
    )
    assert_equal(
        port_of(peer.unsafe_offset(0)[]),
        mine,
        "and the far end of the accepted socket is the client",
    )
    var going = unsafe_alloc[UInt8](1)
    going.unsafe_offset(0)[] = 0x5A
    assert_equal(
        send(client, going, 1, 0), 1, "send answers with how much went"
    )

    var coming = unsafe_alloc[UInt8](1)
    assert_equal(recv(taken, coming, 1, 0), 1, "and recv with how much came")
    assert_equal(
        Int(coming.unsafe_load()),
        0x5A,
        "the byte that went in is the byte that came out",
    )

    assert_equal(shutdown(taken, SHUT_RDWR), 0, "and the socket is shut down")

    going.unsafe_free()
    coming.unsafe_free()
    peer.unsafe_free()
    peer_length.unsafe_free()
    there.unsafe_free()
    caller.unsafe_free()
    caller_length.unsafe_free()
    unspecified.unsafe_free()
    _ = close(taken)
    _ = close(client)
    _ = close(server)


def test_accept4() raises:
    """`accept4` is `accept` with the flags decided at the same time
    rather than afterwards, so the socket comes back already as asked.
    Linux and Android have it; Darwin does not, and takes it out in
    `fcntl` instead.
    """
    comptime if not CompilationTarget.is_macos():
        var server = socket(AF_INET, SOCK_STREAM, 0)
        var unspecified = unsafe_alloc[socketaddr](1)
        loopback(unspecified.unsafe_offset(0)[], 0)
        assert_equal(bind(server, unspecified, ADDRESS_SIZE), 0, "bound")
        assert_equal(listen(server, 1), 0, "listening")

        var client = socket(AF_INET, SOCK_STREAM, 0)
        var there = unsafe_alloc[socketaddr](1)
        loopback(there.unsafe_offset(0)[], ask_the_port(server))
        assert_equal(connect(client, there, ADDRESS_SIZE), 0, "connected")

        var length = unsafe_alloc[UInt32](1)
        length.unsafe_offset(0)[] = ADDRESS_SIZE
        var taken = accept4(server, there, length, 0)
        assert_true(taken >= 0, "accept4 takes it, asking nothing of its own")

        there.unsafe_free()
        length.unsafe_free()
        unspecified.unsafe_free()
        _ = close(taken)
        _ = close(client)
        _ = close(server)


def test_socketpair() raises:
    """`socketpair` makes two ends of a connection without an address,
    a port, or anything else being agreed: what goes in one comes out
    the other and neither knows a thing about the network.
    """
    var ends = unsafe_alloc[Int32](2)
    assert_equal(
        socketpair(AF_UNIX, SOCK_STREAM, 0, ends),
        0,
        "socketpair makes two ends",
    )
    var left = ends.unsafe_load(0)
    var right = ends.unsafe_load(1)

    var going = unsafe_alloc[UInt8](1)
    going.unsafe_offset(0)[] = 0x37
    assert_equal(send(left, going, 1, 0), 1, "one byte goes into the left")
    var coming = unsafe_alloc[UInt8](1)
    assert_equal(recv(right, coming, 1, 0), 1, "and out of the right")
    assert_equal(Int(coming.unsafe_load()), 0x37, "unchanged")

    going.unsafe_free()
    coming.unsafe_free()
    ends.unsafe_free()
    _ = close(left)
    _ = close(right)


def test_sendto_and_recvfrom() raises:
    """A datagram is told where it is going every time, and the one
    that receives it is told where it came from, which is what
    `recvfrom` is for and what `recv` cannot say.
    """
    var here = socket(AF_INET, SOCK_DGRAM, 0)
    var there = socket(AF_INET, SOCK_DGRAM, 0)
    assert_true(here >= 0 and there >= 0, "two datagram sockets")

    var here_addr = unsafe_alloc[socketaddr](1)
    loopback(here_addr.unsafe_offset(0)[], 0)
    assert_equal(bind(here, here_addr, ADDRESS_SIZE), 0, "the first is bound")
    var there_addr = unsafe_alloc[socketaddr](1)
    loopback(there_addr.unsafe_offset(0)[], 0)
    assert_equal(
        bind(there, there_addr, ADDRESS_SIZE), 0, "and so is the second"
    )

    var here_port = ask_the_port(here)
    var there_port = ask_the_port(there)
    assert_true(here_port != there_port, "and they are not the same port")

    # What was bound was port 0, so the address still says 0 and has to
    # be filled in again now that the port is known.
    loopback(there_addr.unsafe_offset(0)[], there_port)

    var going = unsafe_alloc[UInt8](1)
    going.unsafe_offset(0)[] = 0x42
    assert_equal(
        sendto(here, going, 1, 0, there_addr, ADDRESS_SIZE),
        1,
        "sendto answers with how much went",
    )

    var whence = unsafe_alloc[socketaddr](1)
    var whence_length = unsafe_alloc[UInt32](1)
    whence_length.unsafe_offset(0)[] = ADDRESS_SIZE
    var coming = unsafe_alloc[UInt8](1)
    assert_equal(
        recvfrom(there, coming, 1, 0, whence, whence_length),
        1,
        "and recvfrom with how much came",
    )
    assert_equal(Int(coming.unsafe_load()), 0x42, "and it is the same byte")
    assert_equal(
        port_of(whence.unsafe_offset(0)[]),
        here_port,
        "and it says which port it came from",
    )

    going.unsafe_free()
    coming.unsafe_free()
    whence.unsafe_free()
    whence_length.unsafe_free()
    here_addr.unsafe_free()
    there_addr.unsafe_free()
    _ = close(here)
    _ = close(there)


def test_sendmsg() raises:
    """`sendmsg` is given the pieces of a message and not the message,
    each piece being somewhere else. A connected pair is used, so there
    is no address to give it and the pieces are all it is asked for.
    """
    var ends = unsafe_alloc[Int32](2)
    assert_equal(
        socketpair(AF_UNIX, SOCK_STREAM, 0, ends), 0, "a pair to send over"
    )
    var left = ends.unsafe_load(0)
    var right = ends.unsafe_load(1)

    var bytes = unsafe_alloc[UInt8](2)
    bytes.unsafe_offset(0)[] = 0x41
    bytes.unsafe_offset(1)[] = 0x42

    var pieces = unsafe_alloc[iovec](1)
    pieces.unsafe_offset(0)[] = iovec(bytes, 1)  # the first byte only
    var message = unsafe_alloc[msghdr](1)
    message.unsafe_offset(0)[] = msghdr()
    message.unsafe_offset(0)[].set_msg_iov(pieces)
    message.unsafe_offset(0)[].set_msg_iovlen(1)

    assert_equal(
        Int(sendmsg(left, message, 0)),
        1,
        "sendmsg sends the one piece it was given",
    )

    var coming = unsafe_alloc[UInt8](1)
    assert_equal(recv(right, coming, 1, 0), 1, "and it is received")
    assert_equal(
        Int(coming.unsafe_load()),
        0x41,
        "and it is the first byte and not the second",
    )

    bytes.unsafe_free()
    pieces.unsafe_free()
    message.unsafe_free()
    coming.unsafe_free()
    ends.unsafe_free()
    _ = close(left)
    _ = close(right)


def test_recvmsg_gathers_without_taking() raises:
    """`recvmsg` is handed pieces to fill rather than one buffer, and
    `MSG_PEEK` is what makes the count it returns worth reading twice.

    Five bytes go out over two pieces and come back into two pieces of a
    different split, so the boundary the sender used is not the boundary
    the receiver gets: anything that copied a buffer would put `abcde`
    into the first three bytes of one block, and this puts `ab` there and
    `cde` in the next piece.

    The peek is followed by a zeroing of both pieces and then a second
    read, because a peek that consumed would still hand the same bytes
    back to a test that never cleared them.

    `msg_flags` is read twice for the same kind of reason. Darwin starts
    it from the flags the call was made with, so the peek comes back
    carrying `MSG_PEEK` there and nothing on glibc; the second read is
    made with no flags at all and is zero on both, which is the part that
    says the field is still worth reading.
    """
    var ends = unsafe_alloc[Int32](2)
    assert_equal(
        socketpair(AF_UNIX, SOCK_STREAM, 0, ends), 0, "a pair to talk over"
    )
    var left = ends.unsafe_load(0)
    var right = ends.unsafe_load(1)

    var bytes = unsafe_alloc[UInt8](5)
    for i in range(5):
        bytes.unsafe_offset(i)[] = UInt8(97 + i)

    var sending = unsafe_alloc[iovec](2)
    sending.unsafe_offset(0)[] = iovec(bytes, 3)
    sending.unsafe_offset(1)[] = iovec(bytes.unsafe_offset(3), 2)
    var out = unsafe_alloc[msghdr](1)
    out.unsafe_offset(0)[] = msghdr()
    out.unsafe_offset(0)[].set_msg_iov(sending)
    out.unsafe_offset(0)[].set_msg_iovlen(2)
    assert_equal(
        Int(sendmsg(left, out, 0)), 5, "five bytes out over two pieces"
    )

    var first = unsafe_alloc[UInt8](3)
    var second = unsafe_alloc[UInt8](2)
    var pieces = unsafe_alloc[iovec](2)
    pieces.unsafe_offset(0)[] = iovec(first, 2)  # a split of its own
    pieces.unsafe_offset(1)[] = iovec(second, 3)
    var coming = unsafe_alloc[msghdr](1)
    coming.unsafe_offset(0)[] = msghdr()
    coming.unsafe_offset(0)[].set_msg_iov(pieces)
    coming.unsafe_offset(0)[].set_msg_iovlen(2)

    assert_equal(
        Int(recvmsg(right, coming, MSG_PEEK)), 5, "a peek sees all five bytes"
    )
    assert_equal(
        first.unsafe_offset(0)[],
        UInt8(97),
        "the first piece starts the message",
    )
    assert_equal(
        first.unsafe_offset(1)[],
        UInt8(98),
        "and stops at its own length rather than at the sender's",
    )
    assert_equal(
        second.unsafe_offset(0)[], UInt8(99), "so the rest goes to the second"
    )
    assert_equal(
        second.unsafe_offset(2)[], UInt8(101), "as far as the last byte"
    )
    # Darwin starts `msg_flags` from the flags the call was made with, and
    # glibc starts it from zero: the same peek reports `MSG_PEEK` on one and
    # nothing on the other. What both agree on is that nothing was truncated.
    comptime PEEKED: Int32 = MSG_PEEK if CompilationTarget.is_macos() else 0
    assert_equal(
        coming.unsafe_offset(0)[].msg_flags(),
        PEEKED,
        "no truncation, which is all msg_flags is for on glibc",
    )

    for i in range(3):
        first.unsafe_offset(i)[] = 0
    for i in range(2):
        second.unsafe_offset(i)[] = 0

    assert_equal(Int(recvmsg(right, coming, 0)), 5, "and the peek took nothing")
    assert_equal(
        first.unsafe_offset(0)[], UInt8(97), "the same five bytes are there"
    )
    assert_equal(second.unsafe_offset(2)[], UInt8(101), "to be taken this time")
    assert_equal(
        coming.unsafe_offset(0)[].msg_flags(),
        0,
        "and with no flags asked for, msg_flags is zero on both platforms",
    )

    bytes.unsafe_free()
    sending.unsafe_free()
    out.unsafe_free()
    pieces.unsafe_free()
    coming.unsafe_free()
    first.unsafe_free()
    second.unsafe_free()
    ends.unsafe_free()
    _ = close(left)
    _ = close(right)


def main() raises:
    test_a_connection_over_the_loopback()
    test_accept4()
    test_socketpair()
    test_sendto_and_recvfrom()
    test_sendmsg()
    test_recvmsg_gathers_without_taking()
    print("test_socket: ok")
