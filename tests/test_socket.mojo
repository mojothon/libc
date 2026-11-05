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

from libc.errno import get_errno
from libc.constant import (
    AF_INET,
    AF_UNIX,
    MSG_OOB,
    MSG_PEEK,
    MSG_TRUNC,
    SCM_RIGHTS,
    SHUT_RDWR,
    SOCK_DGRAM,
    SOCK_STREAM,
    SOL_SOCKET,
    SO_RCVTIMEO,
    SO_TYPE,
    c_ulong,
)
from libc.sys.socket import (
    accept,
    accept4,
    bind,
    connect,
    getpeername,
    getsockname,
    getsockopt,
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
    sockatmark,
    socket,
    socketaddr,
    socketpair,
    setsockopt,
)
from libc.poll import poll, pollfd
from libc.sys.stat import timeval
from libc.unistd import close
from libc.utils import null_ptr

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


def give_a_receive_timeout(fd: Int32) raises:
    """A second in which to answer, so a call that reads where it was
    asked to write comes back refused instead of holding the suite until
    the harness gives up on it.
    """
    var wait = unsafe_alloc[timeval](1)
    wait.unsafe_offset(0)[].tv_sec = 1
    wait.unsafe_offset(0)[].tv_usec = 0
    assert_equal(
        Int(
            setsockopt(
                fd, SOL_SOCKET, SO_RCVTIMEO, wait.unsafe_bitcast[NoneType](), 16
            )
        ),
        0,
        "a receive timeout is set",
    )
    wait.unsafe_free()


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
    give_a_receive_timeout(client)
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

    give_a_receive_timeout(left)
    var going = unsafe_alloc[UInt8](1)
    going.unsafe_offset(0)[] = 0x37
    assert_equal(send(left, going, 1, 0), 1, "one byte goes into the left")
    var coming = unsafe_alloc[UInt8](1)
    assert_equal(recv(right, coming, 1, 0), 1, "and out of the right")
    assert_equal(Int(coming.unsafe_load()), 0x37, "unchanged")

    # `AF_UNIX` is 1 and `SOCK_STREAM` is 1, so the first two arguments are
    # the same number and a binding handing them over the other way round is
    # asked exactly what it was already asked. A datagram pair is type 2: the
    # numbers differ there, and the socket can be asked which kind it is.
    var datagrams = unsafe_alloc[Int32](2)
    assert_equal(
        socketpair(AF_UNIX, SOCK_DGRAM, 0, datagrams),
        0,
        "a datagram pair is made the same way",
    )
    var kind = unsafe_alloc[Int32](1)
    kind[] = 0
    var width = unsafe_alloc[UInt32](1)
    width[] = 4
    assert_equal(
        Int(
            getsockopt(
                datagrams.unsafe_load(0),
                SOL_SOCKET,
                SO_TYPE,
                kind.unsafe_bitcast[NoneType](),
                width,
            )
        ),
        0,
        "and one end can be asked what it is",
    )
    assert_equal(
        kind[], SOCK_DGRAM, "a datagram, rather than the 1 that was asked for"
    )

    kind.unsafe_free()
    width.unsafe_free()
    _ = close(datagrams.unsafe_load(0))
    _ = close(datagrams.unsafe_load(1))
    datagrams.unsafe_free()
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

    give_a_receive_timeout(left)
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
    give_a_receive_timeout(left)
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


def test_the_mark_that_out_of_band_data_leaves() raises:
    """`sockatmark` says whether the next read is at the mark a byte
    sent out of band leaves in the stream. Three bytes go over the
    loopback — two ordinary ones, then the marked one, then one more
    ordinary — and the mark sits between the second and the last, so
    the answer is 0 until both ordinary bytes are read and 1 from then
    on.

    Reading the marked byte is the one place the platforms part ways:
    Linux keeps the mark where it was until ordinary reading moves past
    that place, and Darwin drops it as the marked byte is read. Both
    are a reading of the same rule — the mark is a place in the stream
    rather than the byte at it — so what each platform answers there is
    asked for by name.
    """
    var server = socket(AF_INET, SOCK_STREAM, 0)
    var unspecified = unsafe_alloc[socketaddr](1)
    loopback(unspecified.unsafe_offset(0)[], 0)
    assert_equal(bind(server, unspecified, ADDRESS_SIZE), 0, "bound")
    assert_equal(listen(server, 1), 0, "listening")
    var port = ask_the_port(server)

    var client = socket(AF_INET, SOCK_STREAM, 0)
    var there = unsafe_alloc[socketaddr](1)
    loopback(there.unsafe_offset(0)[], port)
    assert_equal(connect(client, there, ADDRESS_SIZE), 0, "connected")
    var taken = accept(server, null_ptr[socketaddr](), null_ptr[UInt32]())
    assert_true(taken >= 0, "the connection is taken")

    assert_equal(sockatmark(taken), 0, "no mark where none was made")

    give_a_receive_timeout(client)
    var going = unsafe_alloc[UInt8](2)
    going.unsafe_offset(0)[] = 97  # a
    going.unsafe_offset(1)[] = 98  # b
    assert_equal(send(client, going, 2, 0), 2, "two ordinary bytes go")
    var urgent = unsafe_alloc[UInt8](1)
    urgent.unsafe_offset(0)[] = 99  # c
    assert_equal(
        send(client, urgent, 1, MSG_OOB), 1, "and the marked one after them"
    )
    var after = unsafe_alloc[UInt8](1)
    after.unsafe_offset(0)[] = 100  # d
    assert_equal(send(client, after, 1, 0), 1, "and an ordinary one last")

    var coming = unsafe_alloc[UInt8](1)
    assert_equal(recv(taken, coming, 1, 0), 1, "the first byte is read")
    assert_equal(Int(coming.unsafe_load()), 97, "and it is the first one")
    assert_equal(sockatmark(taken), 0, "the mark is not reached yet")

    assert_equal(recv(taken, coming, 1, 0), 1, "the second byte is read")
    assert_equal(Int(coming.unsafe_load()), 98, "and it is the second one")

    # The mark is a place in the stream, and it is a place only once the marked
    # byte has arrived: three `send`s are three segments and the receiver is
    # told about them one at a time, so on Darwin the two ordinary bytes were
    # read before the marked one was there and the mark was still nowhere.
    # `POLLPRI` is not the answer to that on Darwin -- it reported nothing for
    # two seconds while the byte was arriving -- so what is waited for is the
    # mark itself, a millisecond at a time, with `poll` on no descriptors as
    # the sleep.
    var mark = sockatmark(taken)
    var waited = 0
    while mark == 0 and waited < 2000:
        _ = poll(null_ptr[pollfd](), c_ulong(0), 1)
        mark = sockatmark(taken)
        waited += 1
    assert_equal(mark, 1, "and the read is at the mark")

    assert_equal(
        recv(taken, coming, 1, MSG_OOB), 1, "the marked byte is read at it"
    )
    assert_equal(Int(coming.unsafe_load()), 99, "and it is the marked one")
    comptime MARK_AFTER_ITS_BYTE: Int32 = 0 if CompilationTarget.is_macos() else 1
    assert_equal(
        sockatmark(taken),
        MARK_AFTER_ITS_BYTE,
        "reading the marked byte is where the platforms part ways",
    )

    assert_equal(recv(taken, coming, 1, 0), 1, "the last byte is read")
    assert_equal(Int(coming.unsafe_load()), 100, "and it is the last one")
    assert_equal(sockatmark(taken), 0, "and the mark is behind the read now")

    assert_equal(close(taken), 0, "the taken socket is closed")
    assert_equal(close(client), 0, "the client is closed")
    assert_equal(close(server), 0, "the server is closed")
    going.unsafe_free()
    urgent.unsafe_free()
    after.unsafe_free()
    coming.unsafe_free()
    there.unsafe_free()
    unspecified.unsafe_free()


def test_a_message_sent_to_a_name_and_answered_with_one() raises:
    """`sendmsg` reads the name `set_msg_name` put in, and `recvmsg` writes
    the one it came from where `msg_name` points.

    Two datagram sockets on the loopback, each bound and each given a
    port by the kernel. What goes out travels over two pieces and is
    addressed by the name, so the arrival on the other socket is the
    proof that C read the name the setter wrote; what comes back is
    answered with the sender's address, written by C into the sixteen
    bytes the setter pointed at — the family and the port of it are the
    part a getter reading some other member could not produce. C also
    writes how long the address is, that there was no ancillary data,
    and that the message arrived whole.

    The same message is then sent again and received into a room half
    its size, which is the one way C has of saying something through
    `msg_flags`: the flags say the message did not fit. `msg_flags` on a
    message being sent is C's to write and nothing of this package's, so
    the setter is asked as a pair, on a block never handed to the line.
    `msg_iov` and `msg_iovlen` are asked the same way, since no call
    writes either of them back.
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

    # What was bound was port 0, so the address still says 0 and is
    # filled in again now that the port is known.
    loopback(there_addr.unsafe_offset(0)[], there_port)
    give_a_receive_timeout(there)

    # Out: two pieces, and a name to send them to.
    var going = unsafe_alloc[UInt8](4)
    going.unsafe_offset(0)[] = 0x70
    going.unsafe_offset(1)[] = 0x69
    going.unsafe_offset(2)[] = 0x6E
    going.unsafe_offset(3)[] = 0x67
    var pieces = unsafe_alloc[iovec](2)
    pieces.unsafe_offset(0)[] = iovec(going, 2)
    pieces.unsafe_offset(1)[] = iovec(going.unsafe_offset(2), 2)
    var out = unsafe_alloc[msghdr](1)
    out.unsafe_offset(0)[] = msghdr()
    out.unsafe_offset(0)[].set_msg_name(there_addr.unsafe_bitcast[UInt8]())
    out.unsafe_offset(0)[].set_msg_namelen(ADDRESS_SIZE)
    out.unsafe_offset(0)[].set_msg_iov(pieces)
    out.unsafe_offset(0)[].set_msg_iovlen(2)
    out.unsafe_offset(0)[].set_msg_control(null_ptr[UInt8]())
    out.unsafe_offset(0)[].set_msg_controllen(0)
    assert_equal(
        Int(out.unsafe_offset(0)[].msg_iovlen()),
        2,
        "the piece count is read where it was written",
    )
    assert_equal(
        Int(out.unsafe_offset(0)[].msg_iov()),
        Int(pieces),
        "and the array is",
    )
    assert_equal(
        Int(sendmsg(here, out, 0)),
        4,
        "four bytes out over two pieces, to the name",
    )

    # In: one piece, and sixteen bytes of room for an answer about who
    # it was from.
    var coming = unsafe_alloc[UInt8](4)
    var one = unsafe_alloc[iovec](1)
    one.unsafe_offset(0)[] = iovec(coming, 4)
    var whence = unsafe_alloc[socketaddr](1)
    var in_msg = unsafe_alloc[msghdr](1)
    in_msg.unsafe_offset(0)[] = msghdr()
    in_msg.unsafe_offset(0)[].set_msg_iov(one)
    in_msg.unsafe_offset(0)[].set_msg_iovlen(1)
    in_msg.unsafe_offset(0)[].set_msg_name(whence.unsafe_bitcast[UInt8]())
    in_msg.unsafe_offset(0)[].set_msg_namelen(ADDRESS_SIZE)
    in_msg.unsafe_offset(0)[].set_msg_control(null_ptr[UInt8]())
    in_msg.unsafe_offset(0)[].set_msg_controllen(0)
    assert_equal(
        Int(recvmsg(there, in_msg, 0)), 4, "four bytes in, in one piece"
    )
    assert_equal(
        Int(coming.unsafe_offset(3)[]), 0x67, "and they are the bytes sent"
    )
    assert_equal(
        Int(in_msg.unsafe_offset(0)[].msg_namelen()),
        16,
        "C answers how long the address it wrote is",
    )
    # The answer is read through the getter itself. C wrote the address
    # into the bytes the setter pointed at, so what `msg_name` gives back
    # has to be those bytes; reading the pointer this test kept would ask
    # nothing of the getter at all.
    var answered = (
        in_msg.unsafe_offset(0)[].msg_name().unsafe_bitcast[socketaddr]()
    )
    assert_equal(
        Int(answered.unsafe_offset(0)[].family()),
        Int(AF_INET),
        "the address is the sender's family",
    )
    assert_equal(
        port_of(answered.unsafe_offset(0)[]),
        here_port,
        "and the sender's port, written where the name was pointed",
    )
    assert_equal(
        Int(in_msg.unsafe_offset(0)[].msg_controllen()),
        0,
        "there was no ancillary data, and C says so",
    )
    assert_equal(
        Int(in_msg.unsafe_offset(0)[].msg_flags()),
        0,
        "and nothing to say about the message",
    )

    # The same message again, into half the room: this time the flags are
    # C's own answer, and they are the one that says the message did not
    # fit.
    assert_equal(Int(sendmsg(here, out, 0)), 4, "the message is sent again")
    var small = unsafe_alloc[UInt8](2)
    one.unsafe_offset(0)[] = iovec(small, 2)
    assert_equal(Int(recvmsg(there, in_msg, 0)), 2, "two of the four are taken")
    assert_true(
        (in_msg.unsafe_offset(0)[].msg_flags() & MSG_TRUNC) != 0,
        "and the flags say the message was bigger than the room",
    )

    # And the setter of the flags, as a pair, on a block that is never
    # handed to the line.
    var scratch = unsafe_alloc[msghdr](1)
    scratch.unsafe_offset(0)[] = msghdr()
    scratch.unsafe_offset(0)[].set_msg_flags(0x1234)
    assert_equal(
        Int(scratch.unsafe_offset(0)[].msg_flags()),
        0x1234,
        "the flags are read where they were written",
    )

    scratch.unsafe_free()
    small.unsafe_free()
    coming.unsafe_free()
    one.unsafe_free()
    whence.unsafe_free()
    in_msg.unsafe_free()
    going.unsafe_free()
    pieces.unsafe_free()
    out.unsafe_free()
    here_addr.unsafe_free()
    there_addr.unsafe_free()
    _ = close(here)
    _ = close(there)


def test_a_descriptor_traveling_as_ancillary_data() raises:
    """`msg_control` is where the ancillary data is put and
    `msg_controllen` is how much room it has, and the descriptor that
    travels in it arrives through a pointer C followed and a length C
    wrote back.

    A descriptor goes out as one byte of payload beside the `SCM_RIGHTS`
    message, and comes back as a different number at the other end,
    still naming the same open line: what is sent through the received
    descriptor arrives on the end that stayed home. The length is asked
    of `msg_controllen` after the call, which is C's own answer rather
    than the number this test put there.

    The line it travels over is a stream pair, because Darwin refuses
    ancillary data on a datagram one outright — `sendmsg` answers -1
    there — and a stream pair carries it on both platforms.
    """
    var ends = unsafe_alloc[Int32](2)
    # A stream pair, because Darwin refuses ancillary data on a datagram
    # one: `sendmsg` answers -1 there, so the line the descriptor travels
    # over is the one kind both platforms carry it on.
    assert_equal(
        socketpair(AF_UNIX, SOCK_STREAM, 0, ends), 0, "a pair to send over"
    )
    var left = ends.unsafe_load(0)
    var right = ends.unsafe_load(1)
    var legs = unsafe_alloc[Int32](2)
    assert_equal(
        socketpair(AF_UNIX, SOCK_DGRAM, 0, legs),
        0,
        "and a second, whose end is the one that travels",
    )
    var leg_a = legs.unsafe_load(0)
    var leg_b = legs.unsafe_load(1)
    give_a_receive_timeout(right)

    # A `cmsghdr` is the length, the level, the type, and then the data,
    # which is one descriptor here: twenty bytes of message in
    # twenty-four of room, which is what C's `CMSG_SPACE` makes of it.
    var ancillary = unsafe_alloc[UInt64](4)
    ancillary.unsafe_offset(0)[] = 20
    ancillary.unsafe_offset(1)[] = UInt64(UInt32(SOL_SOCKET)) | (1 << 32)
    ancillary.unsafe_offset(2)[] = UInt64(Int(leg_a) & 0xFFFFFFFF)
    ancillary.unsafe_offset(3)[] = 0

    var letter = unsafe_alloc[UInt8](1)
    letter.unsafe_offset(0)[] = 0x66
    var pieces = unsafe_alloc[iovec](1)
    pieces.unsafe_offset(0)[] = iovec(letter, 1)
    var out = unsafe_alloc[msghdr](1)
    out.unsafe_offset(0)[] = msghdr()
    out.unsafe_offset(0)[].set_msg_iov(pieces)
    out.unsafe_offset(0)[].set_msg_iovlen(1)
    out.unsafe_offset(0)[].set_msg_name(null_ptr[UInt8]())
    out.unsafe_offset(0)[].set_msg_namelen(0)
    out.unsafe_offset(0)[].set_msg_control(ancillary.unsafe_bitcast[UInt8]())
    out.unsafe_offset(0)[].set_msg_controllen(24)
    give_a_receive_timeout(left)
    var went = sendmsg(left, out, 0)
    assert_true(
        went == 1,
        "the byte goes out, and the descriptor with it (errno "
        + String(Int(get_errno()))
        + ")",
    )

    var taken = unsafe_alloc[UInt8](1)
    var one = unsafe_alloc[iovec](1)
    one.unsafe_offset(0)[] = iovec(taken, 1)
    var arrived = unsafe_alloc[UInt64](16)
    var in_msg = unsafe_alloc[msghdr](1)
    in_msg.unsafe_offset(0)[] = msghdr()
    in_msg.unsafe_offset(0)[].set_msg_iov(one)
    in_msg.unsafe_offset(0)[].set_msg_iovlen(1)
    in_msg.unsafe_offset(0)[].set_msg_name(null_ptr[UInt8]())
    in_msg.unsafe_offset(0)[].set_msg_namelen(0)
    in_msg.unsafe_offset(0)[].set_msg_control(arrived.unsafe_bitcast[UInt8]())
    in_msg.unsafe_offset(0)[].set_msg_controllen(128)
    assert_equal(Int(recvmsg(right, in_msg, 0)), 1, "and the byte comes back")
    assert_equal(
        Int(taken.unsafe_load()), 0x66, "and it is the byte that was sent"
    )
    assert_true(
        in_msg.unsafe_offset(0)[].msg_controllen() >= 20,
        "C answers how much ancillary data it wrote",
    )
    var level = UInt32(arrived.unsafe_offset(1)[] & 0xFFFFFFFF)
    var kind = UInt32(arrived.unsafe_offset(1)[] >> 32)
    assert_equal(Int(level), Int(SOL_SOCKET), "the message is at this level")
    assert_equal(Int(kind), Int(SCM_RIGHTS), "and of the descriptor kind")
    var traveled = Int32(arrived.unsafe_offset(2)[] & 0xFFFFFFFF)
    assert_true(traveled >= 0, "and it names a descriptor")

    # What is sent through the descriptor that arrived comes out of the
    # end that stayed here, which is what says it is the same open line
    # and not a number that happens to name something.
    var carried = unsafe_alloc[UInt8](1)
    carried.unsafe_offset(0)[] = 0x7A
    assert_equal(
        Int(send(traveled, carried, 1, 0)), 1, "a byte through the arrival"
    )
    var home = unsafe_alloc[UInt8](1)
    assert_equal(Int(recv(leg_b, home, 1, 0)), 1, "and it comes out at home")
    assert_equal(Int(home.unsafe_load()), 0x7A, "and it is the byte sent")

    arrived.unsafe_free()
    in_msg.unsafe_free()
    one.unsafe_free()
    taken.unsafe_free()
    home.unsafe_free()
    carried.unsafe_free()
    out.unsafe_free()
    pieces.unsafe_free()
    letter.unsafe_free()
    ancillary.unsafe_free()
    legs.unsafe_free()
    ends.unsafe_free()
    _ = close(leg_a)
    _ = close(leg_b)
    _ = close(left)
    _ = close(right)


def main() raises:
    test_a_connection_over_the_loopback()
    test_accept4()
    test_socketpair()
    test_sendto_and_recvfrom()
    test_sendmsg()
    test_recvmsg_gathers_without_taking()
    test_the_mark_that_out_of_band_data_leaves()
    test_a_message_sent_to_a_name_and_answered_with_one()
    test_a_descriptor_traveling_as_ancillary_data()
    print("test_socket: ok")
