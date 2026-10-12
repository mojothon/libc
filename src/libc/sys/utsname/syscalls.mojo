# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr


struct Utsname:
    """A C `struct utsname`, which `uname` fills in.

    The two platforms do not agree here at all: glibc's is six arrays of 65
    bytes, 390 in total, while Darwin's is five of 256, 1280 in total. This
    holds the larger and reads each name at the offset that fits, which is why
    the names come from methods rather than fields.
    """

    var _bytes: Array[UInt8, 1280]

    def __init__(out self):
        """Zeroes the struct, which is what `memset` would leave behind."""
        self._bytes = Array[UInt8, 1280](fill=0)

    def sysname(self) raises -> String:
        """The operating system name, `Linux` or `Darwin`."""
        return self._at(0)

    def nodename(self) raises -> String:
        """The name this machine has on the network."""
        comptime if CompilationTarget.is_macos():
            return self._at(256)
        else:
            return self._at(65)

    def release(self) raises -> String:
        """The operating system release, as in `uname -r`."""
        comptime if CompilationTarget.is_macos():
            return self._at(512)
        else:
            return self._at(130)

    def version(self) raises -> String:
        """The operating system version, as in `uname -v`."""
        comptime if CompilationTarget.is_macos():
            return self._at(768)
        else:
            return self._at(195)

    def machine(self) raises -> String:
        """The hardware type, `x86_64` or `arm64`."""
        comptime if CompilationTarget.is_macos():
            return self._at(1024)
        else:
            return self._at(260)

    def domainname(self) raises -> String:
        """The NIS domain name.

        Linux only. Darwin's struct stops at `machine` and has no such member,
        so this is the empty string there rather than a guess.
        """
        comptime if CompilationTarget.is_macos():
            return String("")
        else:
            return self._at(325)

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
