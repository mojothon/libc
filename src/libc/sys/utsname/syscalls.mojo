# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


# Where each name starts. glibc lays six arrays of 65 bytes end to end, XNU
# five of 256 — no padding between them, since a name is a byte array and
# needs no alignment, so the offsets are the lengths added up and nothing
# else. Both are NUL terminated inside their own array, which is what makes
# this readable at all: a name ends before the next one begins even when it
# fills its array.
#
# Numbers from `bits/utsname.h` and XNU `sys/utsname.h`, and five of the six
# are compared with C's `offsetof` on both platforms by
# `scripts/check-layouts.py`. The sixth, `domainname`, has no member to be
# compared with on Darwin, where the struct stops at `machine`; the script
# says that out loud instead of passing it.
comptime UTSNAME_SYSNAME_OFFSET: Int = 0
comptime UTSNAME_NODENAME_OFFSET: Int = 256 if CompilationTarget.is_macos() else 65
comptime UTSNAME_RELEASE_OFFSET: Int = 512 if CompilationTarget.is_macos() else 130
comptime UTSNAME_VERSION_OFFSET: Int = 768 if CompilationTarget.is_macos() else 195
comptime UTSNAME_MACHINE_OFFSET: Int = 1024 if CompilationTarget.is_macos() else 260
comptime UTSNAME_DOMAINNAME_OFFSET: Int = 325


struct Utsname:
    """A C `struct utsname`, which `uname` fills in.

    The two platforms do not agree here at all: glibc's is six arrays of 65
    bytes, 390 in total, while Darwin's is five of 256, 1280 in total. This
    holds the larger and reads each name at the offset that fits, which is why
    the names come from methods rather than fields.

    The offsets are named above, one per name, because they are the whole of
    the layout here: no member is wider than a byte, so the only thing that
    can be wrong about it is where a name starts.
    """

    var _bytes: Array[UInt8, 1280]

    def __init__(out self):
        """Zeroes the struct, which is what `memset` would leave behind."""
        self._bytes = Array[UInt8, 1280](fill=0)

    def sysname(self) raises -> String:
        """The operating system name, `Linux` or `Darwin`."""
        return self._at(UTSNAME_SYSNAME_OFFSET)

    def nodename(self) raises -> String:
        """The name this machine has on the network."""
        return self._at(UTSNAME_NODENAME_OFFSET)

    def release(self) raises -> String:
        """The operating system release, as in `uname -r`."""
        return self._at(UTSNAME_RELEASE_OFFSET)

    def version(self) raises -> String:
        """The operating system version, as in `uname -v`."""
        return self._at(UTSNAME_VERSION_OFFSET)

    def machine(self) raises -> String:
        """The hardware type, `x86_64` or `arm64`."""
        return self._at(UTSNAME_MACHINE_OFFSET)

    def domainname(self) raises -> String:
        """The NIS domain name.

        Linux only. Darwin's struct stops at `machine` and has no such member,
        so this is the empty string there rather than a guess.
        """
        comptime if CompilationTarget.is_macos():
            return String("")
        else:
            return self._at(UTSNAME_DOMAINNAME_OFFSET)

    def _at(self, offset: Int) raises -> String:
        """The NUL terminated string starting at `offset`."""
        var bytes = List[UInt8](capacity=256)
        var i = offset
        while i < 1280 and self._bytes[i] != 0:
            bytes.append(self._bytes[i])
            i += 1
        return String(unsafe_from_utf8=Span[UInt8](bytes))


def uname(buf: c_ptr[Utsname]) -> Int32:
    """Libc POSIX `uname`.

    Args:
        buf: Where to store the names describing this machine.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/uname.2.html).
        Fn signature: `int uname(struct utsname *buf)`.
    """
    return external_call["uname", Int32, c_ptr[Utsname]](buf)
