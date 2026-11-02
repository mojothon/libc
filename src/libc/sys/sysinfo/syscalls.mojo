# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <sys/sysinfo.h>.
#
# Linux's and nobody else's. Darwin has no such header and no such
# calls, which is why this is a package of its own rather than four
# more functions in `libc.unistd`: the same reason `epoll` and
# `eventfd` sit where they sit. Nothing here is called where it does
# not exist, and the tests say so rather than quietly skipping.
#
# Two of these are about the machine and three of them are about the
# moment, and the difference is worth keeping straight: how much
# memory the machine has is a fact about it, and how much of it is
# free is an answer about right now.
# -----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_long, c_ptr


# Where each member of C's `struct sysinfo` sits, asked of C rather than
# remembered: `sizeof` is 112 and the alignment 8, and every member is a
# `long` but for `procs`, two bytes at 80, and `mem_unit`, four at 104.
# The loads are three `long`s in a row at 8.
comptime SYSINFO_UPTIME = 0
comptime SYSINFO_LOADS = 8
comptime SYSINFO_TOTALRAM = 32
comptime SYSINFO_FREERAM = 40
comptime SYSINFO_SHAREDRAM = 48
comptime SYSINFO_BUFFERRAM = 56
comptime SYSINFO_TOTALSWAP = 64
comptime SYSINFO_FREESWAP = 72
comptime SYSINFO_PROCS = 80
comptime SYSINFO_TOTALHIGH = 88
comptime SYSINFO_FREEHIGH = 96
comptime SYSINFO_MEM_UNIT = 104


struct Sysinfo:
    """A C `struct sysinfo`: the whole of what `sysinfo` writes down
    about the machine and the moment.

    Held as bytes and read by offset, because the arrangement is
    Linux's to change and the only thing a caller needs is the
    numbers. The offsets this reads at were printed by C: 112 bytes
    long, aligned to 8, `uptime` first, the three loads after it, then
    the six memory counts, then `procs`, the high-memory pair, and
    `mem_unit` last.

    `mem_unit` is the one that matters to reading the rest: every
    count of memory in here is a number of units, and a unit is that
    many bytes. glibc answers with 1, which is to say the counts are
    bytes, but the struct says units and a program that reads them is
    a program that should ask.
    """

    # Eight-byte slots rather than bytes: C says this one is 8-aligned,
    # and an `Array[UInt8]` would take its alignment down to 1.
    var _slots: Array[UInt64, 14]

    def __init__(out self):
        """Zeroes the whole thing."""
        self._slots = Array[UInt64, 14](fill=0)

    def _byte(self, off: Int) -> UInt8:
        """The single byte at `off`, whichever slot holds it."""
        return UInt8((self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFF)

    def _u16(self, off: Int) -> UInt16:
        """Two little-endian bytes at `off`."""
        return UInt16(self._byte(off)) | (UInt16(self._byte(off + 1)) << 8)

    def _u32(self, off: Int) -> UInt32:
        """Four little-endian bytes at `off`."""
        var acc: UInt32 = 0
        for i in range(4):
            acc |= UInt32(self._byte(off + i)) << UInt32(i * 8)
        return acc

    def _u64(self, off: Int) -> UInt64:
        """Eight little-endian bytes at `off`."""
        var acc: UInt64 = 0
        for i in range(8):
            acc |= UInt64(self._byte(off + i)) << UInt64(i * 8)
        return acc

    def uptime(self) -> Int:
        """Seconds since the machine was started."""
        return Int(self._u64(SYSINFO_UPTIME))

    def loads(self, which: Int) -> Int:
        """One of the three load averages, `which` being 0 for the last
        minute, 1 for five and 2 for fifteen.

        Scaled, and by a shift the kernel picks — sixteen in practice,
        so this over 65536 is the number `/proc/loadavg` shows with two
        decimals after it.
        """
        return Int(self._u64(SYSINFO_LOADS + which * 8))

    def totalram(self) -> Int:
        """All the memory there is, in `mem_unit` bytes."""
        return Int(self._u64(SYSINFO_TOTALRAM))

    def freeram(self) -> Int:
        """Memory going unused, in `mem_unit` bytes."""
        return Int(self._u64(SYSINFO_FREERAM))

    def sharedram(self) -> Int:
        """Memory holding things shared between processes, in
        `mem_unit` bytes.
        """
        return Int(self._u64(SYSINFO_SHAREDRAM))

    def bufferram(self) -> Int:
        """Memory holding buffers, in `mem_unit` bytes."""
        return Int(self._u64(SYSINFO_BUFFERRAM))

    def totalswap(self) -> Int:
        """All the swap there is, in `mem_unit` bytes."""
        return Int(self._u64(SYSINFO_TOTALSWAP))

    def freeswap(self) -> Int:
        """Swap going unused, in `mem_unit` bytes."""
        return Int(self._u64(SYSINFO_FREESWAP))

    def procs(self) -> Int:
        """How many processes there are."""
        return Int(self._u16(SYSINFO_PROCS))

    def totalhigh(self) -> Int:
        """High memory, in `mem_unit` bytes: memory the kernel cannot
        map directly, which on a 64-bit machine is none of it, and so
        this is 0 on every machine this is likely to run on.
        """
        return Int(self._u64(SYSINFO_TOTALHIGH))

    def freehigh(self) -> Int:
        """High memory going unused, in `mem_unit` bytes."""
        return Int(self._u64(SYSINFO_FREEHIGH))

    def mem_unit(self) -> Int:
        """How many bytes one unit of memory is, which every count in
        here is a number of.
        """
        return Int(self._u32(SYSINFO_MEM_UNIT))


def get_nprocs() -> c_int:
    """C library <sys/sysinfo.h> function `get_nprocs`.

    Reference:
        https://man7.org/linux/man-pages/man3/get_nprocs.3.html

    Description:
        How many processors are available to this process at this
        moment — the ones that are online, which is not always the ones
        the machine was built with: a processor can be taken offline,
        and `get_nprocs_conf` is the call that does not care whether it
        was.

    Returns:
        The number, which is at least 1.

    Notes:
        The same number `sysconf` answers with for
        `SC_NPROCESSORS_ONLN`, and the two are worth asking for
        together: this one is the convenience and that one is the
        standard, and a program that has both has no need to remember
        which is which.

        Available rather than installed, and so a number that can
        change between two calls. Threads are scheduled on these, and
        a program that starts one per processor is a program that
        should ask again rather than remember.
    """
    return external_call["get_nprocs", c_int]()


def get_nprocs_conf() -> c_int:
    """C library <sys/sysinfo.h> function `get_nprocs_conf`.

    Reference:
        https://man7.org/linux/man-pages/man3/get_nprocs.3.html

    Description:
        How many processors the machine is configured with, online or
        not. What `get_nprocs` reports is a number that can be smaller:
        it counts the ones that are up.

    Returns:
        The number, which is at least 1 and never less than what
        `get_nprocs` says.

    Notes:
        The same number `sysconf` answers with for
        `SC_NPROCESSORS_CONF`. Asked together with `get_nprocs`, the
        two say whether the machine has processors switched off, which
        is the only thing the difference between them can be.
    """
    return external_call["get_nprocs_conf", c_int]()


def get_phys_pages() -> c_long:
    """C library <sys/sysinfo.h> function `get_phys_pages`.

    Reference:
        https://man7.org/linux/man-pages/man3/get_phys_pages.3.html

    Description:
        All the memory the machine has, counted in pages — which is how
        C talks about memory in most of its other places, and the
        reason this is a number of pages rather than a number of
        bytes. `sysconf` with `SC_PHYS_PAGES` says the same thing, and
        `SC_PAGESIZE` says how big a page is.

    Returns:
        The number of pages, or -1 where it cannot be told.

    Notes:
        Total rather than free: the machine's memory, not what is left
        of it. `get_avphys_pages` is the call for what is left.

        Multiply by the page size and what comes out is
        `totalram` times `mem_unit` as `sysinfo` reports them — the
        same amount of memory arrived at two ways, which is the one
        check on this number that does not need a machine of a known
        size.
    """
    return external_call["get_phys_pages", c_long]()


def get_avphys_pages() -> c_long:
    """C library <sys/sysinfo.h> function `get_avphys_pages`.

    Reference:
        https://man7.org/linux/man-pages/man3/get_avphys_pages.3.html

    Description:
        Memory that can be had without swapping: what is free, plus
        what is only holding a cache the kernel is free to drop. It is
        the number to ask for before deciding how much to take, and it
        is never more than what `get_phys_pages` says there is.

    Returns:
        The number of pages, or -1 where it cannot be told.

    Notes:
        An answer about right now, and one that moves: a program that
        asks twice is asking about two different moments. Nothing here
        reserves anything — between this call and the next one another
        process may have taken the memory it counted.
    """
    return external_call["get_avphys_pages", c_long]()


def sysinfo(info: c_ptr[Sysinfo]) -> c_int:
    """C library <sys/sysinfo.h> function `sysinfo`.

    Reference:
        https://man7.org/linux/man-pages/man2/sysinfo.2.html

    Description:
        Writes down the whole of what the kernel keeps about the
        machine and the moment: how long it has been up, the three
        load averages, six counts of memory, and how many processes
        there are. Everything `get_nprocs` and `get_phys_pages` answer
        separately is in here, and then some.

    Args:
        info: Where to write it, 112 bytes of room, which is what a
            `Sysinfo` is.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        Every count of memory in here is a number of units, and
        `mem_unit` says how big a unit is. Reading `totalram` without
        reading `mem_unit` is reading a number whose size nobody said.

        The three loads are scaled, by sixteen bits as things stand,
        so `loads(0)` over 65536 is the one-minute average.

        `totalhigh` and `freehigh` are about memory the kernel cannot
        map directly, which on a 64-bit machine there is none of: both
        come back 0, and that is an answer rather than a failure.
    """
    return external_call["sysinfo", c_int, c_ptr[Sysinfo]](info)
