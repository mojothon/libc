# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import (
    AI_ADDRCONFIG,
    AI_ALL,
    AI_CANONNAME,
    AI_NUMERICHOST,
    AI_PASSIVE,
    AI_V4MAPPED,
    c_ptr,
    c_size_t,
    c_ushort,
)
from libc.network import htons, ntohs
from libc.utils import char_ptr_to_string, is_null, null_ptr


# What `getaddrinfo` is asked to prefer. The first three are the same on
# both platforms and the other four are not: glibc numbers them from 1 in
# bit order, XNU in an order of its own, so `AI_NUMERICSERV` is 1024 here
# and 4096 there.
comptime AI_NUMERICSERV: Int32 = 4096 if CompilationTarget.is_macos() else 1024


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
        `getprotoent` reading the rows and `endprotoent` the other end.
        Asking after one protocol by name or by number opens and shuts
        the database on its own, so this is only for where the whole of
        it is wanted.
    """
    external_call["setprotoent", NoneType, Int32](stayopen)


def getprotoent() -> c_ptr[protoent]:
    """Libc POSIX `getprotoent` function.

    Description:
        Reads the next row of the protocol database, which is the walk
        `setprotoent` opens and `endprotoent` closes.

    Returns:
        The next row, or a null pointer at the end of it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getprotoent.3.html).
        Fn signature: `struct protoent *getprotoent(void)`.

        Every row is read into the same storage, so the pointer is the
        position in the walk rather than a copy of the row: read what
        is wanted out of it before asking for the next one, and copy
        anything that has to outlive the call.

        `/etc/protocols` is not on every machine. Where it is not, the
        first call answers null, which is what the end of the database
        answers too — libc does not tell the two apart, so neither does
        this.
    """
    return external_call["getprotoent", c_ptr[protoent]]()


def endprotoent() -> None:
    """Libc POSIX `endprotoent` function.

    Description:
        Shuts the protocol database.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getprotoent.3.html).
        Fn signature: `void endprotoent(void)`.

        What this gives back is whatever was opened to read the
        database, and after it the next call starts from the top
        again. The walk `setprotoent` starts ends here: a caller that
        reads to the end of the database gets the same effect from the
        null `getprotoent` answers, but one that stops early has to say
        so, and this is how.
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
        `getservent` reading the rows and `endservent` the other end.
        Asking after one service by name or by port opens and shuts
        the database on its own, so this is only for where the whole
        of it is wanted.
    """
    external_call["setservent", NoneType, Int32](stayopen)


def getservent() -> c_ptr[servent]:
    """Libc POSIX `getservent` function.

    Description:
        Reads the next row of the service database, which is the walk
        `setservent` opens and `endservent` closes.

    Returns:
        The next row, or a null pointer at the end of it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getservent.3.html).
        Fn signature: `struct servent *getservent(void)`.

        Every row is read into the same storage, so the pointer is the
        position in the walk rather than a copy of the row: read what
        is wanted out of it before asking for the next one, and copy
        anything that has to outlive the call.

        `/etc/services` is on every machine that has ever had a socket,
        so unlike the protocol database this one has rows to walk.
    """
    return external_call["getservent", c_ptr[servent]]()


def endservent() -> None:
    """Libc POSIX `endservent` function.

    Description:
        Shuts the service database.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getservent.3.html).
        Fn signature: `void endservent(void)`.

        What this gives back is whatever was opened to read the
        database, and after it the next call starts from the top
        again. The walk `setservent` starts ends here: a caller that
        reads to the end of the database gets the same effect from the
        null `getservent` answers, but one that stops early has to say
        so, and this is how.
    """
    external_call["endservent", NoneType]()


struct hostent:
    """A C `struct hostent`: one row of the host database.

    Five members — a name, a list of aliases, which kind of address it
    is, how long one is, and the addresses themselves — at 0, 8, 16,
    20 and 24 on glibc and on Darwin both, thirty-two bytes and
    eight-aligned either way.

    libc owns the object this points at, and may hand every caller the
    same one: two calls overwrite each other's answer, and nothing here
    frees it. The two lists are `char **` the same allocator owns, each
    ended by a null, and they come with the row.

    `h_addr_list` is not a list of strings but a list of addresses:
    what each entry points at is `h_length` raw bytes, which is four
    for `AF_INET` and sixteen for `AF_INET6`, in network order. It is
    what `gethostbyaddr` is handed back.
    """

    var h_name: c_ptr[UInt8]
    var h_aliases: c_ptr[c_ptr[UInt8]]
    var h_addrtype: Int32
    var h_length: Int32
    var h_addr_list: c_ptr[c_ptr[UInt8]]

    def __init__(out self):
        """Zeroes every member, which is the state of one nothing has filled."""
        self.h_name = null_ptr[UInt8]()
        self.h_aliases = null_ptr[c_ptr[UInt8]]()
        self.h_addrtype = 0
        self.h_length = 0
        self.h_addr_list = null_ptr[c_ptr[UInt8]]()

    def first_address(self) -> c_ptr[UInt8]:
        """The first address in the list, `h_length` raw bytes of it.

        Notes:
            What `h_addr_list` points at, which is the one address
            nearly every caller wants. It is in network order, and it
            is not a string: `inet_ntop` is what makes it printable.
            NULL where the row has no address in it.
        """
        return self.h_addr_list.unsafe_offset(0)[]


def sethostent(stayopen: Int32) -> None:
    """Libc POSIX `sethostent` function.

    Description:
        Opens the host database, or winds it back to the top where it
        is already open.

    Args:
        stayopen: Non-zero to keep it open between calls rather than
            shutting it after each one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getipnodebyname.3.html).
        Fn signature: `void sethostent(int stayopen)`.

        This is the one end of the walk over every host in the
        database, `gethostent` being the middle and `endhostent` the
        other end. The database is the one kept in `hosts` and read
        from `/etc/hosts`, which is where `localhost` comes from on a
        machine that has been told no other names.
    """
    external_call["sethostent", NoneType, Int32](stayopen)


def gethostent() -> c_ptr[hostent]:
    """Libc POSIX `gethostent` function.

    Description:
        Reads the next row of the host database, which is to say the
        first where none has been read yet.

    Returns:
        The next row, or a null pointer at the end of the database.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getipnodebyname.3.html).
        Fn signature: `struct hostent *gethostent(void)`.

        `sethostent` winds this back to the top and `endhostent` shuts
        the database, and it is the first of those that a caller who
        wants the whole of it begins with. What comes back points into
        storage libc keeps, and every caller is handed the same one:
        two calls overwrite each other's answer.
    """
    return external_call["gethostent", c_ptr[hostent]]()


def endhostent() -> None:
    """Libc POSIX `endhostent` function.

    Description:
        Shuts the host database.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getipnodebyname.3.html).
        Fn signature: `void endhostent(void)`.

        What this gives back is whatever was opened to read the
        database, and after it the next read starts from the top
        again. It is the other end of the walk `sethostent` began.
    """
    external_call["endhostent", NoneType]()


def gethostbyname(name: c_ptr[UInt8]) -> c_ptr[hostent]:
    """Libc POSIX `gethostbyname` function.

    Description:
        Looks a host up by its name, asking the name service, which
        reads `hosts` — and so `/etc/hosts` — before it asks anyone
        further away.

    Args:
        name: The name to look for, or a null pointer for this machine.

    Returns:
        The row for that host, or a null pointer where no such name is
        known.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/gethostbyname.3.html).
        Fn signature: `struct hostent *gethostbyname(const char *name)`.

        This is the one of the family that every machine has, but it
        is not the one to reach for now: it speaks only `AF_INET`, and
        `getaddrinfo` is what speaks both that and `AF_INET6` and is
        what new code is written with. `gethostbyname2` is this with
        the address family asked for.

        What comes back points into storage libc keeps, and every
        caller is handed the same one. Which kind of address the row
        carries is libc's own to say, and it is `h_addrtype` and
        `h_length` that say it, not the caller's asking.
    """
    return external_call["gethostbyname", c_ptr[hostent], c_ptr[UInt8]](name)


def gethostbyname2(name: c_ptr[UInt8], af: Int32) -> c_ptr[hostent]:
    """Libc BSD `gethostbyname2` function.

    Description:
        Looks a host up by its name, asking for addresses of one kind.

    Args:
        name: The name to look for.
        af: Which kind of address to come back with, `AF_INET` or
            `AF_INET6`.

    Returns:
        The row for that host, or a null pointer where no such name is
        known under that kind.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/gethostbyname.3.html).
        Fn signature: `struct hostent *gethostbyname2(const char *name,
            int af)`.

        This is `gethostbyname` that is told which kind of address it
        wants, which is the one thing `gethostbyname` decides for
        itself. Asking for `AF_INET` and being given a row whose
        `h_addrtype` is anything else is a call that has not done
        what it was asked, and `h_length` says four when it has.

        It is on both platforms, though not in POSIX: `getaddrinfo` is
        the portable way to ask the same thing.
    """
    return external_call["gethostbyname2", c_ptr[hostent], c_ptr[UInt8], Int32](
        name, af
    )


def gethostbyaddr(
    addr: c_ptr[UInt8], length: c_size_t, kind: Int32
) -> c_ptr[hostent]:
    """Libc POSIX `gethostbyaddr` function.

    Description:
        Looks a host up by its address, asking the name service the
        other way round from `gethostbyname`.

    Args:
        addr: The address itself, raw bytes in network order and not a
            string, `length` of them.
        length: How long one address is, which is four for `AF_INET`
            and sixteen for `AF_INET6`.
        kind: Which kind of address it is, `AF_INET` or `AF_INET6`.

    Returns:
        The row for that host, or a null pointer where no name is
        known for that address.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/gethostbyname.3.html).
        Fn signature: `struct hostent *gethostbyaddr(const void *addr,
            socklen_t len, int type)`.

        This is the one that goes backwards: `gethostbyname` is given
        a name and answers with addresses, this is given an address
        and answers with a name. What is handed in is the same raw
        bytes the other one handed back, which is what
        `hostent`'s `first_address` is.

        Whether a machine knows a name for an address is its own to
        say, and a good many addresses have none, so a null pointer
        here is an answer and not a failure.
    """
    return external_call[
        "gethostbyaddr", c_ptr[hostent], c_ptr[UInt8], c_size_t, Int32
    ](addr, length, kind)


def hstrerror(err: Int32) -> c_ptr[UInt8]:
    """Libc BSD `hstrerror` function.

    Description:
        Says in words what a number the resolver answered with means.

    Args:
        err: The number, which is one the resolver handed back rather
            than one in `errno`.

    Returns:
        The words, as a string libc owns, which is not freed and is
        overwritten by the next call.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/hstrerror.3.html).
        Fn signature: `const char *hstrerror(int err)`.

        `herror` is the same words written to standard error, and this
        is the one for a caller that wants them for itself. The
        numbers are not `errno` numbers and are not bound here: which
        number means what is the resolver's own to say, and the two
        platforms do not number them alike, so a caller that has one
        is a caller that was handed it.

        What comes back is never empty, even for a number that means
        nothing: there are words for that too.
    """
    return external_call["hstrerror", c_ptr[UInt8], Int32](err)


def herror(text: c_ptr[UInt8]) -> None:
    """Libc BSD `herror` function.

    Description:
        Writes what the resolver last said went wrong to standard
        error, under a line of the caller's own.

    Args:
        text: What to write in front of it, which is what the caller
            was doing when it went wrong.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/hstrerror.3.html).
        Fn signature: `void herror(const char *s)`.

        This writes and says nothing back, so a caller cannot ask what
        went wrong and cannot tell whether anything did: `hstrerror`
        is the same words handed back rather than written, and
        `getaddrinfo` is what answers with a number a caller can act
        on. Nothing here reads `errno`, which is untouched by the
        resolver and so says nothing about this.
    """
    external_call["herror", NoneType, c_ptr[UInt8]](text)


struct netent:
    """A C `struct netent`: one row of the network database.

    Four members -- a name, a list of aliases, the address family, and the
    network number -- at 0, 8, 16 and 20 on glibc and on Darwin both,
    twenty-four bytes and eight-aligned either way. This is the third row
    in `netdb.h` the two platforms agree about all the way through, after
    `protoent` and `servent`.

    libc owns the object this points at, and may hand every caller the
    same one: two calls overwrite each other's answer, and nothing here
    frees it. `n_aliases` is a `char **` the same allocator owns, a list
    of other names ended by a null, and it comes with the row.

    `n_net` is in the order this machine counts in, which is the order
    `getnetbyaddr` is asked by and not the wire order a port is in: the
    row for the loopback network comes back as 127, not as the 127 that
    a byte-reversal would make of it. `n_addrtype` says which family
    that number is in, and every row `/etc/networks` holds is `AF_INET`.
    """

    var n_name: c_ptr[UInt8]
    var n_aliases: c_ptr[c_ptr[UInt8]]
    var n_addrtype: Int32
    var n_net: UInt32

    def __init__(out self):
        """Zeroes every member, which is the state of one nothing has filled."""
        self.n_name = null_ptr[UInt8]()
        self.n_aliases = null_ptr[c_ptr[UInt8]]()
        self.n_addrtype = 0
        self.n_net = 0

    def aliased_as(self) raises -> String:
        """The first other name the network goes by.

        Notes:
            The first entry of `n_aliases`, read as a string. A network
            with no other name has an empty list, and what comes back
            then is the empty string.
        """
        var first = self.n_aliases.unsafe_offset(0)[]
        if is_null(first):
            return String("")
        return char_ptr_to_string(first)


def setnetent(stayopen: Int32) -> None:
    """Libc POSIX `setnetent` function.

    Description:
        Opens the network database, or winds it back to the top where it
        is already open.

    Args:
        stayopen: Non-zero to keep it open between calls rather than
            shutting it after each one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getnetent.3.html).
        Fn signature: `void setnetent(int stayopen)`.

        This is the one end of the walk over every network there is,
        `getnetent` reading the rows and `endnetent` the other end. It
        is also the only way back to the top: a walk that has run out
        stays run out until this is asked again, which is what the
        finding calls below rely on rather than a rule of their own.

        The database is `/etc/networks`, which not every machine has;
        where it is not there the walk answers null at once, and that
        is an answer rather than a failure.
    """
    external_call["setnetent", NoneType, Int32](stayopen)


def endnetent() -> None:
    """Libc POSIX `endnetent` function.

    Description:
        Closes the network database, which is the walk `setnetent`
        opens and `getnetent` reads.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getnetent.3.html).
        Fn signature: `void endnetent(void)`.

        Nothing is said back, and nothing has to be: a walk that is
        never closed is closed by the process ending, so the only thing
        this buys is not holding the file open. Asking for a row after
        it opens the database again from the top.
    """
    external_call["endnetent", NoneType]()


def getnetent() -> c_ptr[netent]:
    """Libc POSIX `getnetent` function.

    Description:
        Reads the next row of the network database, which is the walk
        `setnetent` opens and `endnetent` closes.

    Returns:
        The next row, or a null pointer at the end of it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getnetent.3.html).
        Fn signature: `struct netent *getnetent(void)`.

        Every row is read into the same storage, so the pointer is the
        position in the walk rather than a copy of the row: read what
        is wanted out of it before asking for the next one, and copy
        anything that has to outlive the call.

        Asking here is the only way to see every row: the two lookups
        below find one row by what it is called or by its number, and
        neither can say what else is in the file.
    """
    return external_call["getnetent", c_ptr[netent]]()


def getnetbyname(name: c_ptr[UInt8]) -> c_ptr[netent]:
    """Libc POSIX `getnetbyname` function.

    Description:
        Looks a network up by the name it goes by.

    Args:
        name: The name to look for, as bytes with a nil on the end.

    Returns:
        The row for that network, or a null pointer where there is no
        such name.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getnetbyname.3.html).
        Fn signature: `struct netent *getnetbyname(const char *name)`.

        What comes back is the same row `getnetent` walks, in the same
        storage, so a lookup between two reads of the walk loses the
        walk's place in that storage even though the walk itself
        carries on from where it was.
    """
    return external_call["getnetbyname", c_ptr[netent], c_ptr[UInt8]](name)


def getnetbyaddr(net: UInt32, addrtype: Int32) -> c_ptr[netent]:
    """Libc POSIX `getnetbyaddr` function.

    Description:
        Looks a network up by its number, in a family of addresses.

    Args:
        net: The network number, in the order this machine counts in.
        addrtype: The family the number is in, which is `AF_INET` for
            every row `/etc/networks` holds.

    Returns:
        The row for that network, or a null pointer where there is no
        such number in that family.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getnetbyaddr.3.html).
        Fn signature: `struct netent *getnetbyaddr(uint32_t net, int type)`.

        The number is the one `n_net` carries, not one in wire order:
        passing it back as it came out of a row is what finds that row
        again, and `htonl` would not.

        The family is asked for as well as the number because a number
        means nothing without one; `AF_INET` is the only family the
        file has rows in.
    """
    return external_call["getnetbyaddr", c_ptr[netent], UInt32, Int32](
        net, addrtype
    )


struct rpcent:
    """A C `struct rpcent`: one row of the RPC program database.

    Three members -- a name, a list of aliases, and the program number --
    at 0, 8 and 16 on glibc and on Darwin both, twenty-four bytes and
    eight-aligned either way. The row needed no branch: the number is an
    `int` on both, even though the argument `getrpcbynumber` takes is a
    `long` on a 32-bit Darwin build and an `int` everywhere else.

    libc owns the object this points at, and may hand every caller the
    same one: two calls overwrite each other's answer, and nothing here
    frees it. `r_aliases` is a `char **` the same allocator owns, a list
    of other names ended by a null, and it comes with the row.

    The number is an RPC program number and not a port. Ports are what a
    portmapper turns these into, which is the whole of what the database
    is for: 100000 is the portmapper itself, and a caller that reads the
    number as a port will look for a server that is not there.
    """

    var r_name: c_ptr[UInt8]
    var r_aliases: c_ptr[c_ptr[UInt8]]
    var r_number: Int32
    var _pad: Int32

    def __init__(out self):
        """Zeroes every member, which is the state of one nothing has filled."""
        self.r_name = null_ptr[UInt8]()
        self.r_aliases = null_ptr[c_ptr[UInt8]]()
        self.r_number = 0
        self._pad = 0

    def aliased_as(self) raises -> String:
        """The first other name the program goes by.

        Notes:
            The first entry of `r_aliases`, read as a string. A program
            with no other name has an empty list, and what comes back
            then is the empty string.
        """
        var first = self.r_aliases.unsafe_offset(0)[]
        if is_null(first):
            return String("")
        return char_ptr_to_string(first)


def setrpcent(stayopen: Int32) -> None:
    """Libc BSD `setrpcent` function.

    Description:
        Opens the RPC program database, or winds it back to the top where
        it is already open.

    Args:
        stayopen: Non-zero to keep it open between calls rather than
            shutting it after each one.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getrpcent.3.html).
        Fn signature: `void setrpcent(int stayopen)`.

        This is the one end of the walk over every RPC program there is,
        `getrpcent` reading the rows and `endrpcent` the other end, and
        it is the only way back to the top: a walk that has run out stays
        run out until this is asked again.

        The database is `/etc/rpc`, which is not on every machine and is
        empty on many that have it; where there is nothing the walk
        answers null at once, and that is an answer rather than a
        failure.
    """
    external_call["setrpcent", NoneType, Int32](stayopen)


def endrpcent() -> None:
    """Libc BSD `endrpcent` function.

    Description:
        Closes the RPC program database, which is the walk `setrpcent`
        opens and `getrpcent` reads.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getrpcent.3.html).
        Fn signature: `void endrpcent(void)`.

        Nothing is said back, and nothing has to be: a walk that is never
        closed is closed by the process ending, so the only thing this
        buys is not holding the file open. Asking for a row after it
        opens the database again from the top.
    """
    external_call["endrpcent", NoneType]()


def getrpcent() -> c_ptr[rpcent]:
    """Libc BSD `getrpcent` function.

    Description:
        Reads the next row of the RPC program database, which is the walk
        `setrpcent` opens and `endrpcent` closes.

    Returns:
        The next row, or a null pointer at the end of it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getrpcent.3.html).
        Fn signature: `struct rpcent *getrpcent(void)`.

        Every row is read into the same storage, so the pointer is the
        position in the walk rather than a copy of the row: read what is
        wanted out of it before asking for the next one.

        This is the only way to see every row: the two lookups below find
        one row by what it is called or by its number, and neither can
        say what else is in the file.
    """
    return external_call["getrpcent", c_ptr[rpcent]]()


def getrpcbyname(name: c_ptr[UInt8]) -> c_ptr[rpcent]:
    """Libc BSD `getrpcbyname` function.

    Description:
        Looks an RPC program up by the name it goes by.

    Args:
        name: The name to look for, as bytes with a nil on the end.

    Returns:
        The row for that program, or a null pointer where there is no
        such name.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getrpcbyname.3.html).
        Fn signature: `struct rpcent *getrpcbyname(const char *name)`.

        What comes back is the same row `getrpcent` walks, in the same
        storage, so a lookup between two reads of the walk loses the
        walk's place in that storage even though the walk itself carries
        on from where it was.

        A name here is a program name and not a host: nothing is
        resolved, and no name service is consulted.
    """
    return external_call["getrpcbyname", c_ptr[rpcent], c_ptr[UInt8]](name)


def getrpcbynumber(number: Int32) -> c_ptr[rpcent]:
    """Libc BSD `getrpcbynumber` function.

    Description:
        Looks an RPC program up by its program number.

    Args:
        number: The program number to look for, which is 100000 for the
            portmapper.

    Returns:
        The row for that program, or a null pointer where there is no
        such number.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getrpcbynumber.3.html).
        Fn signature: `struct rpcent *getrpcbynumber(int number)`.

        The number is an RPC program number and not a port, which is the
        mistake the name invites: a portmapper is what turns one into the
        other, and this database is what tells the portmapper what the
        numbers are called.

        Darwin writes the argument down as a `long` on a 32-bit build and
        as an `int` on a 64-bit one, and every machine this is built for
        is a 64-bit one, so the `int` is the only signature there is.
    """
    return external_call["getrpcbynumber", c_ptr[rpcent], Int32](number)


def setnetgrent(group: c_ptr[UInt8]) -> None:
    """Libc BSD `setnetgrent` function.

    Description:
        Points the netgroup walk at one group.

    Args:
        group: The netgroup to walk, as bytes with a nil on the end.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/setnetgrent.3.html).
        Fn signature: `void setnetgrent(const char *netgroup)`.

        glibc says this answers with an `int` -- 0 where the group could
        not be opened -- and Darwin says it answers with nothing at all.
        Each is right about its own C, and there is one signature here,
        so the `int` is dropped rather than read on one platform and
        invented on the other. Nothing is lost: a group that could not
        be opened is a group whose walk answers nothing, which is what
        `getnetgrent` says anyway.

        The database is `/etc/netgroup`, which is on very few machines;
        where it is not there, every group is one that cannot be opened.
    """
    external_call["setnetgrent", NoneType, c_ptr[UInt8]](group)


def getnetgrent(
    host: c_ptr[c_ptr[UInt8]],
    user: c_ptr[c_ptr[UInt8]],
    domain: c_ptr[c_ptr[UInt8]],
) -> Int32:
    """Libc BSD `getnetgrent` function.

    Description:
        Reads the next triple out of the group `setnetgrent` opened.

    Args:
        host: Where to put the host of the triple, which may be a null
            in the group for "any host".
        user: Where to put the user, on the same terms.
        domain: Where to put the domain, on the same terms.

    Returns:
        1 where there was another triple, 0 at the end of the group.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/getnetgrent.3.html).
        Fn signature: `int getnetgrent(char **host, char **user, char **domain)`.

        All three arguments are written through rather than answered,
        so each is the address of a `char *` the caller owns. A null is
        stored on the end of a group as well as at it, so a caller that
        reads them only after the 1 has to check each one.

        The strings are libc's and the next call overwrites them; copy
        anything that has to outlive the walk. The end of the group and
        a group that could not be opened answer the same 0, which is the
        same thing libc says about the other database walks.
    """
    return external_call[
        "getnetgrent",
        Int32,
        c_ptr[c_ptr[UInt8]],
        c_ptr[c_ptr[UInt8]],
        c_ptr[c_ptr[UInt8]],
    ](host, user, domain)


def endnetgrent() -> None:
    """Libc BSD `endnetgrent` function.

    Description:
        Ends the walk `setnetgrent` opened, releasing what it held.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/setnetgrent.3.html).
        Fn signature: `void endnetgrent(void)`.

        Unlike the database walks, this one is worth calling: the group
        is held open in memory between calls rather than read a line at
        a time off a file, and nothing else closes it.
    """
    external_call["endnetgrent", NoneType]()


def innetgr(
    group: c_ptr[UInt8],
    host: c_ptr[UInt8],
    user: c_ptr[UInt8],
    domain: c_ptr[UInt8],
) -> Int32:
    """Libc BSD `innetgr` function.

    Description:
        Asks whether a triple is a member of a group, without walking it.

    Args:
        group: The group to ask about, as bytes with a nil on the end.
        host: The host to look for, or a null pointer for any host.
        user: The user to look for, or a null pointer for any user.
        domain: The domain to look for, or a null pointer for any domain.

    Returns:
        1 where the triple is a member, 0 where it is not.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/innetgr.3.html).
        Fn signature: `int innetgr(const char *netgroup, const char *host,
        const char *user, const char *domain)`.

        A null for any of the three says "any", which is not the same as
        the empty string: asked about no host at all, the question is
        whether the group has a triple whose host is anything.

        This does not disturb a walk in progress and does not need
        `setnetgrent` first, which is the whole of why it is here beside
        the walk rather than instead of it.
    """
    return external_call[
        "innetgr",
        Int32,
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[UInt8],
    ](group, host, user, domain)
