# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


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
