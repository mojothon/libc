# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr, c_ushort
from libc.network import htons, ntohs
from libc.utils import char_ptr_to_string, is_null, null_ptr


# What `getaddrinfo` is asked to prefer. The first three are the same on
# both platforms and the other four are not: glibc numbers them from 1 in
# bit order, XNU in an order of its own, so `AI_NUMERICSERV` is 1024 here
# and 4096 there.
comptime AI_PASSIVE: Int32 = 1
comptime AI_CANONNAME: Int32 = 2
comptime AI_NUMERICHOST: Int32 = 4
comptime AI_NUMERICSERV: Int32 = 4096 if CompilationTarget.is_macos() else 1024
comptime AI_ALL: Int32 = 256 if CompilationTarget.is_macos() else 16
comptime AI_ADDRCONFIG: Int32 = 1024 if CompilationTarget.is_macos() else 32
comptime AI_V4MAPPED: Int32 = 2048 if CompilationTarget.is_macos() else 8


# What went wrong when `getaddrinfo` answered something other than 0. The
# sign is the thing to notice: glibc's are all negative and XNU's are all
# positive, and the two lists are numbered differently besides, so not one
# of these agrees across the platforms — not even `EAI_SYSTEM`, which is
# -11 here and 11 there. A test that wrote the numbers down would pass on
# one and fail on the other, so they are named.
comptime EAI_BADFLAGS: Int32 = 3 if CompilationTarget.is_macos() else -1
comptime EAI_NONAME: Int32 = 8 if CompilationTarget.is_macos() else -2
comptime EAI_AGAIN: Int32 = 2 if CompilationTarget.is_macos() else -3
comptime EAI_FAIL: Int32 = 4 if CompilationTarget.is_macos() else -4
comptime EAI_FAMILY: Int32 = 5 if CompilationTarget.is_macos() else -6
comptime EAI_SOCKTYPE: Int32 = 10 if CompilationTarget.is_macos() else -7
comptime EAI_SERVICE: Int32 = 9 if CompilationTarget.is_macos() else -8
comptime EAI_MEMORY: Int32 = 6 if CompilationTarget.is_macos() else -10
comptime EAI_SYSTEM: Int32 = 11 if CompilationTarget.is_macos() else -11
comptime EAI_OVERFLOW: Int32 = 14 if CompilationTarget.is_macos() else -12


# What `getnameinfo` is asked to do with the answer. `NI_DGRAM` is 16 on
# both sides by luck and the two limits agree, but the other four are
# numbered the opposite way round: glibc's `NI_NUMERICHOST` is 1 and
# XNU's is 2, and so on down the list.
comptime NI_NOFQDN: Int32 = 1 if CompilationTarget.is_macos() else 4
comptime NI_NUMERICHOST: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime NI_NAMEREQD: Int32 = 4 if CompilationTarget.is_macos() else 8
comptime NI_NUMERICSERV: Int32 = 8 if CompilationTarget.is_macos() else 2
comptime NI_DGRAM: Int32 = 16
# How long a buffer `getnameinfo` can fill. Both platforms say the same.
comptime NI_MAXHOST: Int32 = 1025
comptime NI_MAXSERV: Int32 = 32


struct addrinfo:
    """A C `struct addrinfo`: one answer to `getaddrinfo`.

    The first five members are forty-eight bytes' worth of ints and sit at
    the same offsets on both platforms, so they are fields and can be
    written straight into a hint. The last three are pointers, and here
    the two platforms part company: POSIX puts `ai_addr` before
    `ai_canonname`, glibc follows it, and Darwin does not — its
    `netdb.h` has the canonical name at 24 and the address at 32, where
    glibc has them the other way round. Forty-eight bytes and
    eight-aligned either way, so the size says nothing about it; the two
    that move are read by method, at the offset of whoever is compiling.

    `getaddrinfo` hands back the head of a linked list of these, and
    `ai_next` walks it. libc owns the whole list; `freeaddrinfo` is what
    releases it, and nothing here frees anything on its own.
    """

    var ai_flags: Int32
    var ai_family: Int32
    var ai_socktype: Int32
    var ai_protocol: Int32
    var ai_addrlen: UInt32
    var _ptrs: Array[UInt64, 3]

    def __init__(out self):
        """Zeroes every member, which is what a hint with no preferences is."""
        self.ai_flags = 0
        self.ai_family = 0
        self.ai_socktype = 0
        self.ai_protocol = 0
        self.ai_addrlen = 0
        self._ptrs = Array[UInt64, 3](fill=0)

    def _ptr_at(self, offset: Int) -> c_ptr[UInt8]:
        """The `void *` held at byte `offset`, which is one of the three."""
        return c_ptr[UInt8](
            unsafe_from_address=Int(self._ptrs[(offset - 24) // 8])
        )

    def ai_canonname(self) -> c_ptr[UInt8]:
        """The canonical name of the host, when `AI_CANONNAME` asked for one.

        Notes:
            Twenty-four bytes in on Darwin and thirty-two on Linux, the
            one member of these three the two do not agree about. It is
            NULL unless the flag was set. Read it with
            `char_ptr_to_string`.
        """
        return self._ptr_at(24 if CompilationTarget.is_macos() else 32)

    def ai_addr(self) -> c_ptr[UInt8]:
        """The socket address itself, `ai_addrlen` bytes of it.

        Notes:
            Thirty-two bytes in on Darwin and twenty-four on Linux. It
            points at a `struct sockaddr`, whose head the two platforms
            also lay out differently — Darwin keeps a length in front of
            the family — so read past the first four bytes rather than
            through `libc.sys.socket`.
        """
        return self._ptr_at(32 if CompilationTarget.is_macos() else 24)

    def ai_next(self) -> c_ptr[addrinfo]:
        """The next answer in the list, or NULL at the end of it.

        Notes:
            Forty bytes in on both, the one of the three they agree on.
        """
        return c_ptr[addrinfo](unsafe_from_address=Int(self._ptrs[2]))


def getaddrinfo(
    node: c_ptr[UInt8],
    service: c_ptr[UInt8],
    hints: c_ptr[addrinfo],
    res: c_ptr[c_ptr[addrinfo]],
) -> Int32:
    """C library <netdb.h> function `getaddrinfo`.

    Reference:
        https://man7.org/linux/man-pages/man3/getaddrinfo.3.html

    Description:
        Turns a host and a service into the list of addresses a `socket`
        could be pointed at, which is the one call that does the name
        lookup and the port number in the same place. It is what replaces
        `gethostbyname`, and unlike that one it answers for IPv6 as
        readily as IPv4 and takes the family as a hint rather than
        deciding it.

    Args:
        node: The host to look up, as a name or a numeric address, or
            NULL for the loopback or the wildcard address depending on
            `AI_PASSIVE`.
        service: The service, as a name from the services database or a
            decimal port number, or NULL for any port.
        hints: What to prefer, as an `addrinfo` above, or NULL for the
            defaults. Only the flags, family, socktype and protocol are
            read; the rest is filled in.
        res: Where the head of the answer list is written. libc owns the
            list from here until `freeaddrinfo` takes it.

    Returns:
        0 on success, or one of the `EAI_*` above on failure — and not
        -1, which is what makes this different from most of the calls in
        this package.

    Notes:
        Fn signature:
        `int getaddrinfo(const char *restrict node, const char *restrict service, const struct addrinfo *restrict hints, struct addrinfo **restrict res)`.

        `EAI_SYSTEM` means the failure is in `errno` rather than here, so
        ask `get_errno` for the real reason when it comes back.

        The whole list is freed with `freeaddrinfo`, not member by member,
        and not with anything this package's allocator knows about.
    """
    return external_call[
        "getaddrinfo",
        Int32,
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[addrinfo],
        c_ptr[c_ptr[addrinfo]],
    ](node, service, hints, res)


def freeaddrinfo(res: c_ptr[addrinfo]) -> None:
    """C library <netdb.h> function `freeaddrinfo`.

    Reference:
        https://man7.org/linux/man-pages/man3/getaddrinfo.3.html

    Args:
        res: The head of a list `getaddrinfo` wrote, or a member of it
            that the list was walked to. The whole list is released, not
            just that member.
    """
    external_call["freeaddrinfo", NoneType, c_ptr[addrinfo]](res)


def getnameinfo(
    sa: c_ptr[UInt8],
    salen: UInt32,
    host: c_ptr[UInt8],
    hostlen: UInt32,
    serv: c_ptr[UInt8],
    servlen: UInt32,
    flags: Int32,
) -> Int32:
    """C library <netdb.h> function `getnameinfo`.

    Reference:
        https://man7.org/linux/man-pages/man3/getnameinfo.3.html

    Description:
        The other direction from `getaddrinfo`: given a socket address,
        it says which host and which service that is. What it answers
        depends on the flags — a name where it can find one, or the
        numbers, which is what `NI_NUMERICHOST` and `NI_NUMERICSERV`
        ask for and what needs no lookup at all.

    Args:
        sa: The socket address to describe, `salen` bytes of it, as
            `addrinfo.ai_addr` hands it out.
        salen: How many bytes `sa` is, which is `addrinfo.ai_addrlen`.
        host: Where the host name is written, a buffer of `NI_MAXHOST`.
        hostlen: How many bytes `host` has.
        serv: Where the service is written, a buffer of `NI_MAXSERV`.
        servlen: How many bytes `serv` has.
        flags: What to prefer, as the `NI_*` above, or 0 for the
            defaults.

    Returns:
        0 on success, or one of the `EAI_*` on failure — the same list
        `getaddrinfo` answers with, and not -1.

    Notes:
        Fn signature:
        `int getnameinfo(const struct sockaddr *restrict sa, socklen_t salen, char *restrict host, socklen_t hostlen, char *restrict serv, socklen_t servlen, int flags)`.

        `sa` is taken as bytes rather than as a `socketaddr`, because the
        address may be a `sockaddr_in6` or anything else and it is the
        family in its first bytes that says which; `ai_addr` is the
        pointer to hand it.

        The buffers are C strings when this returns 0, so read them with
        `char_ptr_to_string` and give them `NI_MAXHOST` and `NI_MAXSERV`
        to be sure there is room.
    """
    return external_call[
        "getnameinfo",
        Int32,
        c_ptr[UInt8],
        UInt32,
        c_ptr[UInt8],
        UInt32,
        c_ptr[UInt8],
        UInt32,
        Int32,
    ](sa, salen, host, hostlen, serv, servlen, flags)


def gai_strerror(ecode: Int32) -> c_ptr[UInt8]:
    """C library <netdb.h> function `gai_strerror`.

    Reference:
        https://man7.org/linux/man-pages/man3/gai_strerror.3.html

    Args:
        ecode: One of the `EAI_*` above, as `getaddrinfo` answered it.

    Returns:
        A pointer to a static string describing the error. libc owns it,
        so it is good until the next call and no longer; copy it out with
        `char_ptr_to_string` if it has to outlive that.

    Notes:
        Fn signature: `const char *gai_strerror(int ecode)`.
    """
    return external_call["gai_strerror", c_ptr[UInt8], Int32](ecode)


struct protoent:
    """A C `struct protoent`: one row of the protocol database.

    Three members — a name, a list of aliases, and the number the
    protocol is known by — at 0, 8 and 16 on glibc and on Darwin both,
    twenty-four bytes and eight-aligned either way. This is one of the
    few rows in `netdb.h` the two agree about all the way through.

    libc owns the object this points at, and may hand every caller the
    same one: two calls overwrite each other's answer, and nothing here
    frees it. `p_aliases` is a `char **` the same allocator owns, a list
    of other names ended by a null, and it comes with the row.

    The number is the one that goes in an IP header, which is to say
    the one `getprotobynumber` is asked by and the one `IPPROTO_TCP`
    and its like are: 6 for TCP, 17 for UDP.
    """

    var p_name: c_ptr[UInt8]
    var p_aliases: c_ptr[c_ptr[UInt8]]
    var p_proto: Int32
    var _pad: Int32

    def __init__(out self):
        """Zeroes every member, which is the state of one nothing has filled."""
        self.p_name = null_ptr[UInt8]()
        self.p_aliases = null_ptr[c_ptr[UInt8]]()
        self.p_proto = 0
        self._pad = 0

    def aliased_as(self) raises -> String:
        """The first other name the protocol goes by.

        Notes:
            The first entry of `p_aliases`, read as a string. A
            protocol with no other name has an empty list, and what
            comes back then is the empty string.
        """
        var first = self.p_aliases.unsafe_offset(0)[]
        if is_null(first):
            return String("")
        return char_ptr_to_string(first)


struct servent:
    """A C `struct servent`: one row of the service database.

    Four members — a name, a list of aliases, the port, and which
    protocol the port is for — at 0, 8, 16 and 24 on glibc and on
    Darwin both, thirty-two bytes and eight-aligned either way.

    libc owns the object this points at, and may hand every caller the
    same one: two calls overwrite each other's answer, and nothing here
    frees it. `s_aliases` is a `char **` the same allocator owns, and
    `s_proto` points into storage held the same way.

    `s_port` is in network order, which is the order it goes on the
    wire in and not the order this machine counts in: `ntohs` is what
    makes it into a number worth reading, and `htons` what makes a
    number into one worth asking `getservbyport` by.
    """

    var s_name: c_ptr[UInt8]
    var s_aliases: c_ptr[c_ptr[UInt8]]
    var s_port: Int32
    var s_proto: c_ptr[UInt8]

    def __init__(out self):
        """Zeroes every member, which is the state of one nothing has filled."""
        self.s_name = null_ptr[UInt8]()
        self.s_aliases = null_ptr[c_ptr[UInt8]]()
        self.s_port = 0
        self.s_proto = null_ptr[UInt8]()

    def port(self) -> Int32:
        """The port in the order this machine counts in.

        Notes:
            `s_port` with `ntohs` over it. This is the number 80 and
            not the number 20480 that 80 looks like on the wire.
        """
        return Int32(ntohs(c_ushort(self.s_port)))


def getprotobyname(name: c_ptr[UInt8]) -> c_ptr[protoent]:
    """Libc POSIX `getprotobyname` function.

    Description:
        Looks a protocol up by its name in the protocol database, the
        one kept in `protocols` and read from `/etc/protocols`.

    Args:
        name: The name to look for, which is `tcp` and `udp` and the
            rest of them.

    Returns:
        The row for that protocol, or a null pointer where there is no
        such name.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getprotobyname.3.html).
        Fn signature: `struct protoent *getprotobyname(const char *name)`.

        What comes back points into storage libc keeps, and every
        caller is handed the same one: two calls overwrite each
        other's answer. `getprotobynumber` is the same row by number
        rather than by name, and `endprotoent` shuts the database.

        Which protocols are in it is the machine's own to say. TCP and
        UDP are in every one of them, which is what makes them the two
        worth asking after.
    """
    return external_call["getprotobyname", c_ptr[protoent], c_ptr[UInt8]](name)


def getprotobynumber(proto: Int32) -> c_ptr[protoent]:
    """Libc POSIX `getprotobynumber` function.

    Description:
        Looks a protocol up by its number in the protocol database.

    Args:
        proto: The number to look for, which is 6 for TCP and 17 for
            UDP.

    Returns:
        The row for that protocol, or a null pointer where there is no
        such number.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getprotobynumber.3.html).
        Fn signature: `struct protoent *getprotobynumber(int proto)`.

        This is `getprotobyname` asking by number rather than by name,
        and what comes back is the same row in the same storage. The
        number is the one that goes in an IP header, which is the one
        `getaddrinfo` hands back in `ai_protocol` too.
    """
    return external_call["getprotobynumber", c_ptr[protoent], Int32](proto)


def setprotoent(stayopen: Int32) -> None:
    """Libc POSIX `setprotoent` function.

    Description:
        Opens the protocol database, or winds it back to the top where
        it is already open.

    Args:
        stayopen: Non-zero to keep it open between calls rather than
            shutting it after each one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getprotoent.3.html).
        Fn signature: `void setprotoent(int stayopen)`.

        This is the one end of the walk over every protocol there is,
        `getprotoent` being the middle and `endprotoent` the other
        end. Asking after one protocol by name or by number opens and
        shuts the database on its own, so this is only for where the
        whole of it is wanted.
    """
    external_call["setprotoent", NoneType, Int32](stayopen)


def endprotoent() -> None:
    """Libc POSIX `endprotoent` function.

    Description:
        Shuts the protocol database.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getprotoent.3.html).
        Fn signature: `void endprotoent(void)`.

        What this gives back is whatever was opened to read the
        database, and after it the next call starts from the top
        again. Asking after one protocol by name or by number shuts
        the database on its own, so this is called not because it is
        wanted but because it is there.
    """
    external_call["endprotoent", NoneType]()


def getservbyname(name: c_ptr[UInt8], proto: c_ptr[UInt8]) -> c_ptr[servent]:
    """Libc POSIX `getservbyname` function.

    Description:
        Looks a service up by its name in the service database, the
        one read from `/etc/services`.

    Args:
        name: The name to look for, which is `http` and `ssh` and the
            rest of them.
        proto: Which protocol the port has to be for, `tcp` or `udp`,
            or a null pointer where any will do.

    Returns:
        The row for that service, or a null pointer where there is no
        such name under that protocol.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getservbyname.3.html).
        Fn signature: `struct servent *getservbyname(const char *name,
            const char *proto)`.

        What comes back points into storage libc keeps, and every
        caller is handed the same one: two calls overwrite each
        other's answer. The port in the row is in network order, and
        `servent`'s `port` is what says what it is in this machine's.

        Which services are in it is the machine's own to say, and a
        port may be given more than one name. Passing a null `proto`
        is how any protocol is allowed, and hands back the first row
        by that name, whichever it is.
    """
    return external_call[
        "getservbyname", c_ptr[servent], c_ptr[UInt8], c_ptr[UInt8]
    ](name, proto)


def getservbyport(port: Int32, proto: c_ptr[UInt8]) -> c_ptr[servent]:
    """Libc POSIX `getservbyport` function.

    Description:
        Looks a service up by its port in the service database.

    Args:
        port: The port to look for, in network order — `htons` is what
            makes a number into one of these.
        proto: Which protocol the port has to be for, `tcp` or `udp`,
            or a null pointer where any will do.

    Returns:
        The row for that service, or a null pointer where there is no
        such port under that protocol.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getservbyport.3.html).
        Fn signature: `struct servent *getservbyport(int port,
            const char *proto)`.

        The port is not the number 80 but the 80 that has been
        through `htons`, which is the order the port goes on the wire
        in. This is the one place in `netdb.h` where what is handed in
        is not what a caller would plainly write down, and it is the
        same order the row hands back: `servent`'s `port` undoes it.
    """
    return external_call["getservbyport", c_ptr[servent], Int32, c_ptr[UInt8]](
        port, proto
    )


def setservent(stayopen: Int32) -> None:
    """Libc POSIX `setservent` function.

    Description:
        Opens the service database, or winds it back to the top where
        it is already open.

    Args:
        stayopen: Non-zero to keep it open between calls rather than
            shutting it after each one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getservent.3.html).
        Fn signature: `void setservent(int stayopen)`.

        This is the one end of the walk over every service there is,
        `getservent` being the middle and `endservent` the other end.
        Asking after one service by name or by port opens and shuts
        the database on its own, so this is only for where the whole
        of it is wanted.
    """
    external_call["setservent", NoneType, Int32](stayopen)


def endservent() -> None:
    """Libc POSIX `endservent` function.

    Description:
        Shuts the service database.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getservent.3.html).
        Fn signature: `void endservent(void)`.

        What this gives back is whatever was opened to read the
        database, and after it the next call starts from the top
        again. Asking after one service by name or by port shuts the
        database on its own, so this is called not because it is
        wanted but because it is there.
    """
    external_call["endservent", NoneType]()
