# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <sys/un.h> addresses.
#
# An `AF_UNIX` address is a path rather than a machine and a port, which
# is why it cannot live in `socketaddr`: sixteen bytes is enough for a
# family, a port and four bytes of address, and a path is longer than the
# whole of that. C gives it a struct of its own, and the two platforms
# size theirs differently -- 110 bytes here, a two-byte family and a
# 108-byte path, and 106 there, where a one-byte `sun_len` comes first and
# leaves 104 for the path. The path starts at the same offset on both,
# because Darwin's two leading bytes fill the pair glibc spends on a
# family alone, which is the same coincidence `sockaddr` relies on. Both
# sizes and that offset are asked of C's `sizeof` and `offsetof` by
# `scripts/check-layouts.py`.
#
# What is not bound is Linux's abstract namespace, where a path that
# starts with a NUL byte names no file at all and lives only as long as
# the socket does. It is one convention away from what is here -- a path
# whose first byte is zero -- and it has no counterpart on Darwin, so a
# caller wanting it writes that byte itself rather than being told a
# portable name for a thing only one platform has.
from std.sys import CompilationTarget

from libc.constant import AF_UNIX, c_ptr
from libc.sys.socket import socketaddr
from libc.utils import char_ptr_to_string, string_to_char_ptr


# How many bytes the struct is, and how many of them the path may use.
# The path is NUL-terminated, so the last byte is never part of it: 107
# characters here and 103 there is the longest name a socket may have.
comptime SOCKADDR_UN_BYTES: Int = 106 if CompilationTarget.is_macos() else 110
comptime SOCKADDR_UN_PATH_OFFSET: Int = 2
comptime SOCKADDR_UN_PATH_BYTES: Int = 104 if CompilationTarget.is_macos() else 108


struct sockaddr_un:
    """A C `struct sockaddr_un`: an `AF_UNIX` address, which is a path.

    The struct is a family and a path and nothing else, so the bytes are
    held as C expects them and the path is written and read by method. On
    Darwin the first byte is `sun_len`, which is filled in with the size
    of the whole struct -- the number a C program passes as
    `sizeof(struct sockaddr_un)` -- and on glibc the family is there
    instead.

    The bytes are not owned: the struct is a view of a block the caller
    allocates, because that block is what `bind` and `connect` are handed
    a pointer to and a copy inside would be a second address that the
    call never sees. So the block outlives the struct, and freeing it is
    the caller's -- the same arrangement as every other buffer in this
    package.

    A path is a file, and the file is what `bind` creates: it stays after
    the socket is closed, and the next `bind` to the same name is refused
    until it is `unlink`ed. That is the one thing a caller has to do that
    a TCP port does not ask for.
    """

    var _bytes: c_ptr[UInt8]

    def __init__(out self, block: c_ptr[UInt8]):
        """Takes the block as the address and fills in its family.

        The path field is cleared, so a block that has been used before
        starts empty rather than carrying the name that was in it.

        Args:
            block: The caller's buffer, at least `SOCKADDR_UN_BYTES` long.
                It is not owned by the struct and not freed with it.
        """
        self._bytes = block
        # Every byte, not just the path: the family is two bytes on glibc
        # and the second of them has to be zero, or the kernel reads a
        # family of 0x2001 and answers `EINVAL`. The block comes from the
        # caller and is not assumed to be zeroed.
        for i in range(SOCKADDR_UN_BYTES):
            self._bytes.unsafe_offset(i)[] = 0
        comptime if CompilationTarget.is_macos():
            self._bytes.unsafe_offset(0)[] = UInt8(SOCKADDR_UN_BYTES)
            self._bytes.unsafe_offset(1)[] = UInt8(AF_UNIX)
        else:
            self._bytes.unsafe_offset(0)[] = UInt8(AF_UNIX)

    def byte(self, off: Int) -> UInt8:
        """The byte at `off` of the struct, which is what the platforms
        differ about and what there is to check the layout against.

        Args:
            off: Which byte, from 0 to one less than the struct's size.

        Returns:
            The byte.
        """
        return self._bytes.unsafe_offset(off)[]

    def set_path(mut self, path: String) raises -> None:
        """Writes the path, NUL-terminated, over the rest of the struct.

        The field is cleared first, so a shorter path written over a
        longer one ends where it ends rather than where the one before it
        did.

        Args:
            path: The path a socket is to be bound to, or the path a
                socket is to connect to. The last byte of the field is
                left for the NUL, so it may be at most one byte shorter
                than the field.

        Raises:
            Error: If the path does not fit in the field, which is 107
                bytes here and 103 there. It is raised here rather than
                truncated, because a truncated path is a different path:
                the socket would be bound somewhere no caller asked for,
                and the failure would arrive later as a client that
                cannot find the server.
        """
        if path.byte_length() > SOCKADDR_UN_PATH_BYTES - 1:
            raise Error(
                "a socket path is at most "
                + String(Int(SOCKADDR_UN_PATH_BYTES - 1))
                + " bytes, and this one is "
                + String(Int(path.byte_length()))
            )
        for i in range(SOCKADDR_UN_PATH_BYTES):
            self._bytes.unsafe_offset(SOCKADDR_UN_PATH_OFFSET + i)[] = 0
        var text = string_to_char_ptr(path)
        for i in range(path.byte_length()):
            self._bytes.unsafe_offset(
                SOCKADDR_UN_PATH_OFFSET + i
            )[] = text.unsafe_offset(i)[]

    def path(self) -> String:
        """The path, read up to the NUL that ends it.

        Returns:
            The path, which is empty for an address that names none --
            an `accept`ed socket whose caller never bound a name of its
            own, which is what most callers are.
        """
        return char_ptr_to_string(
            self._bytes.unsafe_offset(SOCKADDR_UN_PATH_OFFSET)
        )

    def length(self) -> UInt32:
        """How many bytes of this are the address, for the call's
        `address_len`: the whole struct, as C's `sizeof` would say.

        Returns:
            The size of the struct on this platform.
        """
        return UInt32(SOCKADDR_UN_BYTES)

    def as_socketaddr(mut self) -> c_ptr[socketaddr]:
        """The same bytes, as the `struct sockaddr` the calls take.

        The calls that write an address of their own into a buffer --
        `accept`, `getsockname` -- write through this pointer as well, so
        it is as writable as the block it points at, and `take_from` is
        how what they wrote is read back as an address.

        Returns:
            A pointer to the bytes, whatever family they are taken for.
        """
        return self._bytes.unsafe_bitcast[socketaddr]()

    def take_from(mut self, block: c_ptr[UInt8]) -> None:
        """Copies another block's bytes in over this one.

        A call that writes an address into a buffer it was handed leaves
        the answer there, and this puts it where the accessors can read
        it. The bytes are copied rather than pointed at, so `block` may
        be given back afterwards.

        Args:
            block: A buffer holding at least as many bytes as the struct
                is, as one of the calls left them.
        """
        for i in range(SOCKADDR_UN_BYTES):
            self._bytes.unsafe_offset(i)[] = block.unsafe_offset(i)[]
