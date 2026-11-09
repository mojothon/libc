# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <utmpx.h>, the login records.
#
# One record is one session: who, on which terminal, since when, and
# whether it is still open. `getutxent` walks the records one at a time in
# the order the file holds them, `getutxline` asks for the one on a given
# terminal, `getutxid` for the one with a given identifier, and
# `pututxline` writes one back. `utmpxname` is what says which file all of
# that is about — normally `/var/run/utmpx`, which is why these are
# testable at all without being root: point the walk at a file of your own
# and the four calls above it read and write that one instead.
#
# The two platforms do not agree on the shape of a record. glibc's is 384
# bytes and starts with the type; XNU's is 640 and starts with the login
# name, with 64 bytes of reserved space at the end. Not one member is in
# the same place — the terminal and the login name are the first two in
# one and the third and first in the other — and neither is a prefix of
# the other, so the record is held as bytes and each member is read at the
# offset that fits, the way `Stat` and `dirent` do it.
#
# The record is not the same width on the two either, so the size here is
# the platform's own rather than the larger of them: a record written out
# with this struct has to be exactly as long as C's, or the file it goes
# into is not one libc can walk.
#
# On XNU that is not enough by itself. A file there opens with a signature
# record in the 32-bit shape — the one a 32-bit process wrote — and every
# record after it is in that shape too, converted on the way in and out.
# So the file is libc's to make: `pututxline` into a file of your own is
# how one gets written, and bytes copied into it at this struct's offsets
# are not bytes XNU reads.
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_char, c_int, c_ptr


# The ARM ABI pads `ut_tv` to an eight-byte boundary where x86-64 packs the
# long members without one, so the record is 16 bytes longer there -- found
# by `check-layouts` reading the struct on the third machine.
comptime UTMPX_BYTES: Int = 640 if CompilationTarget.is_macos() else (
    400 if (
        CompilationTarget.is_linux() and CompilationTarget.is_arm()
    ) else 384
)
comptime UTMPX_SLOTS: Int = UTMPX_BYTES // 8

# Where each member sits, in bytes from the start of the record.
#
#                 glibc                       XNU
#   ut_user       44, 32 long                  0, 256 long
#   ut_id         40, 4 long                 256, 4 long
#   ut_line        8, 32 long                260, 32 long
#   ut_pid         4                         292
#   ut_type        0                         296
#   ut_tv        340                          304
#   ut_host       76, 256 long               320, 256 long
#   ut_pad        --                          576, 64 long
comptime UT_TYPE_OFFSET: Int = 296 if CompilationTarget.is_macos() else 0
comptime UT_PID_OFFSET: Int = 292 if CompilationTarget.is_macos() else 4
comptime UT_LINE_OFFSET: Int = 260 if CompilationTarget.is_macos() else 8
comptime UT_ID_OFFSET: Int = 256 if CompilationTarget.is_macos() else 40
comptime UT_USER_OFFSET: Int = 0 if CompilationTarget.is_macos() else 44
comptime UT_HOST_OFFSET: Int = 320 if CompilationTarget.is_macos() else 76

# How much room each of the four strings has, NUL included. Only the
# login name differs, XNU keeping 256 bytes of it where glibc keeps 32, so
# XNU names fit in the field that glibc would cut them in.
comptime UT_LINE_ROOM: Int = 32
comptime UT_ID_ROOM: Int = 4
comptime UT_USER_ROOM: Int = 256 if CompilationTarget.is_macos() else 32
comptime UT_HOST_ROOM: Int = 256


# What a record is about. The two number the first six the same way and
# then disagree: glibc calls 3 `NEW_TIME` and 4 `OLD_TIME`, XNU the other
# way round. XNU has three more that glibc does not have at all —
# `ACCOUNTING`, `SIGNATURE` and `SHUTDOWN_TIME` — and they are not here,
# because a name that is bound on one platform and missing on the other
# is a name a program cannot use.
comptime EMPTY: c_int = 0
comptime RUN_LVL: c_int = 1
comptime BOOT_TIME: c_int = 2
comptime OLD_TIME: c_int = 3 if CompilationTarget.is_macos() else 4
comptime NEW_TIME: c_int = 4 if CompilationTarget.is_macos() else 3
comptime INIT_PROCESS: c_int = 5
comptime LOGIN_PROCESS: c_int = 6
comptime USER_PROCESS: c_int = 7
comptime DEAD_PROCESS: c_int = 8


struct utmpx:
    """A C `struct utmpx`: one entry in the login database.

    The members are in a different order on the two platforms — see the
    table above the offsets — so the record is kept as bytes and the
    accessors read and write them where C keeps them. `ut_line`, `ut_id`,
    `ut_user` and `ut_host` are fixed-size character arrays rather than
    pointers, which is the part that has to be held as bytes: modelling
    one as a pointer would read the characters as an address.

    A record is filled in here and handed to `pututxline`, which copies
    what it is given; nothing here keeps a pointer to it afterwards.
    """

    # Eight-byte slots rather than bytes: glibc says this record is
    # 4-aligned and XNU says 8, and an `Array[UInt8]` would take the
    # struct's alignment down to 1 rather than up to what C asks.
    var _slots: Array[UInt64, UTMPX_SLOTS]

    def __init__(out self):
        """Zeroes the whole record, which is what C leaves in one that
        has just been declared: type `EMPTY`, nothing in any of the
        strings.
        """
        self._slots = Array[UInt64, UTMPX_SLOTS](fill=0)

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

    def _set_byte(mut self, off: Int, to: UInt8):
        """Puts the single byte at `off`, leaving the rest of its slot."""
        var slot = off // 8
        var shift = UInt64((off % 8) * 8)
        var mask = ~(UInt64(0xFF) << shift)
        self._slots[slot] = (self._slots[slot] & mask) | (UInt64(to) << shift)

    def _set_u16(mut self, off: Int, to: UInt16):
        """Puts two little-endian bytes at `off`."""
        for i in range(2):
            self._set_byte(off + i, UInt8((to >> UInt16(i * 8)) & 0xFF))

    def _set_u32(mut self, off: Int, to: UInt32):
        """Puts four little-endian bytes at `off`."""
        for i in range(4):
            self._set_byte(off + i, UInt8((to >> UInt32(i * 8)) & 0xFF))

    def _string(self, off: Int, room: Int) -> String:
        """The NUL terminated text at `off`, given `room` bytes of it."""
        var bytes = List[UInt8]()
        for i in range(room):
            var byte = self._byte(off + i)
            if byte == 0:
                break
            bytes.append(byte)
        return String(unsafe_from_utf8=Span[UInt8](bytes))

    def _set_string(mut self, off: Int, room: Int, to: String):
        """Puts `to` at `off`, ending it with a NUL when there is room.

        Text too long for the field is cut rather than overrunning it, and
        a text that fills the field exactly leaves no NUL behind, which is
        what C's own records do: `ut_id` is four bytes and the four are
        the whole of it. A reader stops at the NUL or at the end of the
        field, whichever comes first, so both are read back whole.
        """
        var i = 0
        for byte in to.bytes():
            if i == room:
                break
            self._set_byte(off + i, byte)
            i += 1
        if i < room:
            self._set_byte(off + i, 0)

    def ut_type(self) -> Int16:
        """What the record is about: one of the constants above."""
        return Int16(self._u16(UT_TYPE_OFFSET))

    def set_ut_type(mut self, kind: Int16):
        """Sets what the record is about."""
        self._set_u16(UT_TYPE_OFFSET, UInt16(kind))

    def ut_pid(self) -> Int32:
        """The process the record belongs to."""
        return Int32(self._u32(UT_PID_OFFSET))

    def set_ut_pid(mut self, pid: Int32):
        """Sets the process the record belongs to."""
        self._set_u32(UT_PID_OFFSET, UInt32(pid))

    def ut_line(self) -> String:
        """The terminal the session is on, without the `/dev/`."""
        return self._string(UT_LINE_OFFSET, UT_LINE_ROOM)

    def set_ut_line(mut self, line: String):
        """Sets the terminal the session is on."""
        self._set_string(UT_LINE_OFFSET, UT_LINE_ROOM, line)

    def ut_id(self) -> String:
        """The identifier the record is filed under: four characters,
        which are the last four of the terminal's name when `pututxline`
        fills them in itself.
        """
        return self._string(UT_ID_OFFSET, UT_ID_ROOM)

    def set_ut_id(mut self, id: String):
        """Sets the identifier the record is filed under."""
        self._set_string(UT_ID_OFFSET, UT_ID_ROOM, id)

    def ut_user(self) -> String:
        """The name of whoever is logged in."""
        return self._string(UT_USER_OFFSET, UT_USER_ROOM)

    def set_ut_user(mut self, user: String):
        """Sets the name of whoever is logged in."""
        self._set_string(UT_USER_OFFSET, UT_USER_ROOM, user)

    def ut_host(self) -> String:
        """The machine the session came from, empty for a local one."""
        return self._string(UT_HOST_OFFSET, UT_HOST_ROOM)

    def set_ut_host(mut self, host: String):
        """Sets the machine the session came from."""
        self._set_string(UT_HOST_OFFSET, UT_HOST_ROOM, host)


def endutxent() -> None:
    """C library <utmpx.h> function `endutxent`.

    Reference:
        https://man7.org/linux/man-pages/man3/endutxent.3p.html

    Description:
        Ends the walk and releases whatever it was holding open. What
        `utmpxname` named is not forgotten: the next `setutxent` walks the
        same file again.

    Notes:
        Fn signature:
        `void endutxent(void)`.
    """
    external_call["endutxent", NoneType]()


def getutxent() -> c_ptr[utmpx]:
    """C library <utmpx.h> function `getutxent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getutxent.3p.html

    Description:
        The next record in the database, and the walk moved on by one.
        The first call after `setutxent` is the first record again.

    Returns:
        A pointer to libc's own record, which the next call overwrites —
        read what is wanted out of it before asking for the next one — or
        null when there are no more records, or the file could not be
        read.

    Notes:
        The end of the file and a file that could not be opened are both
        answered with null, so a walk that ends is not told apart from a
        walk that never started. That is C's arrangement, not this
        package's: `getutxent` has one return value for both.
    """
    return external_call["getutxent", c_ptr[utmpx]]()


def getutxid(id: c_ptr[utmpx]) -> c_ptr[utmpx]:
    """C library <utmpx.h> function `getutxid`.

    Reference:
        https://man7.org/linux/man-pages/man3/getutxid.3p.html

    Description:
        The record whose identifier and type match the ones in `id`,
        searched for from wherever the walk has got to.

    Args:
        id: The record to match against. Only its `ut_id` and `ut_type`
            are looked at.

    Returns:
        A pointer to libc's own record, or null when there is none, which
        is also what the end of the file answers.

    Notes:
        Forward from the current position, like `getutxline`: `setutxent`
        is what makes a search cover the file rather than the rest of it.

        The type decides how much of the identifier is compared: a
        `USER_PROCESS` or `DEAD_PROCESS` record is matched on the
        identifier alone, everything else on the type as well. Asking for
        the wrong one of those two finds nothing rather than the nearest
        thing.
    """
    return external_call["getutxid", c_ptr[utmpx], c_ptr[utmpx]](id)


def getutxline(line: c_ptr[utmpx]) -> c_ptr[utmpx]:
    """C library <utmpx.h> function `getutxline`.

    Reference:
        https://man7.org/linux/man-pages/man3/getutxline.3p.html

    Description:
        The record for a given terminal, searched for from wherever the
        walk has got to.

    Args:
        line: The record to match against. Only its `ut_line` is looked
            at.

    Returns:
        A pointer to libc's own record, or null when no session on that
        terminal is found from here on.

    Notes:
        This carries on from the current position rather than starting at
        the top, so a search after a walk that has ended finds nothing at
        all. `setutxent` is what winds it back, and a caller that wants
        the whole file searched rather than the rest of it has to say so.

        The terminal name is compared as C's own field, so a record
        written with the name anywhere else is a record this does not
        find — which is what makes a test of it a test of the layout as
        well.
    """
    return external_call["getutxline", c_ptr[utmpx], c_ptr[utmpx]](line)


def pututxline(line: c_ptr[utmpx]) -> c_ptr[utmpx]:
    """C library <utmpx.h> function `pututxline`.

    Reference:
        https://man7.org/linux/man-pages/man3/pututxline.3p.html

    Description:
        Writes a record into the database: it replaces the one already
        there for the same terminal, or is appended when there is none.

    Args:
        line: The record to write, filled in by the caller.

    Returns:
        A pointer to libc's own copy of what was written, or null with
        `errno` set.

    Notes:
        Nothing is filled in on the way. A record whose `ut_pid` is zero
        is written with a zero in it, and a record with no `ut_id` is
        written with none — glibc does neither of the things a caller
        might expect it to, which was worth finding out with a record
        that had both left out: what came back had both still zero.

        Writing needs the file to be writable by the caller and libc to
        be able to open it for writing, which `utmpxname` having pointed
        at a file of the caller's own is what makes possible. Against the
        real database this is a privileged call and is not tested here.
    """
    return external_call["pututxline", c_ptr[utmpx], c_ptr[utmpx]](line)


def setutxent() -> None:
    """C library <utmpx.h> function `setutxent`.

    Reference:
        https://man7.org/linux/man-pages/man3/setutxent.3p.html

    Description:
        Winds the walk back to the top, so the next `getutxent` is the
        first record again. Also what opens the file, so this is the call
        that finds out whether the name `utmpxname` was given is there.

    Notes:
        Fn signature:
        `void setutxent(void)`.
    """
    external_call["setutxent", NoneType]()


def utmpxname(file: c_ptr[c_char]) -> c_int:
    """C library <utmpx.h> function `utmpxname`.

    Reference:
        https://man7.org/linux/man-pages/man3/utmpxname.3p.html

    Description:
        Says which file the four calls above are about. Normally the
        system's own `/var/run/utmpx`; a file of the caller's own is what
        makes the walk testable without privileges.

    Args:
        file: The path of the file to walk from now on.

    Returns:
        0 when the name was taken and -1 when it was not, on glibc. XNU
        answers 1 and 0 for those two, which is the opposite way round
        and is not a mistake here: its own implementation returns the
        boolean its internals use. A caller that compares the answer
        against 0 is therefore comparing against the wrong thing on one
        of the two platforms, and the one thing both agree on is that the
        name they took is the name used.

    Notes:
        The name is remembered, not opened: this says nothing about
        whether the file is there. A name that is not there is found out
        at `setutxent`, which is the call that opens it.

        XNU takes only a name that ends in `x` — its own are
        `/var/run/utmpx` and `/var/log/wtmpx` — and answers 0 for
        anything else without setting `errno` to say why. That is a
        corner of the platform a header does not mention and a test
        finds: a path of the caller's own that works on glibc is one XNU
        quietly ignores.
    """
    return external_call["utmpxname", c_int, c_ptr[c_char]](file)
