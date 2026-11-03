# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <termios.h>.
#
# How a terminal is set: whether the line discipline is to be
# remembered, what the interrupt character is, how fast the line runs.
# Every function here takes or fills a `struct termios`, which is why
# the layout below matters more than it looks — a binding that hands C
# a block of its own shape and lets it write is not a binding that can
# be checked by calling it.
#
# The two libcs do not lay this struct out the same way. Darwin's
# `tcflag_t` and `speed_t` are both `unsigned long`, so its four flag
# words are eight bytes each and `struct termios` comes to 72 bytes;
# glibc's are `unsigned int`, so its four are four bytes each and the
# struct comes to 60. glibc keeps a `c_line` member that Darwin has
# none of, which is what moves `c_cc` from 17 to 32. The bytes are
# held whole and each member is read at the offset that fits.
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr, c_uint


# `struct termios` is 72 bytes on Darwin and 60 on glibc, so nine
# eight-byte slots is the smaller of the two that holds both. The
# alignment is eight, which is Darwin's, and the stricter of the two.
comptime TERMIOS_SLOTS: Int = 9

comptime TERMIOS_IFLAG_OFFSET: Int = 0
comptime TERMIOS_OFLAG_OFFSET: Int = 8 if CompilationTarget.is_macos() else 4
comptime TERMIOS_CFLAG_OFFSET: Int = 16 if CompilationTarget.is_macos() else 8
comptime TERMIOS_LFLAG_OFFSET: Int = 24 if CompilationTarget.is_macos() else 12
comptime TERMIOS_CC_OFFSET: Int = 32 if CompilationTarget.is_macos() else 17
comptime TERMIOS_ISPEED_OFFSET: Int = 56 if CompilationTarget.is_macos() else 52
comptime TERMIOS_OSPEED_OFFSET: Int = 64 if CompilationTarget.is_macos() else 56

# How wide a flag word is, which is how much of the slot is one.
comptime TERMIOS_FLAG_BYTES: Int = 8 if CompilationTarget.is_macos() else 4
comptime TERMIOS_SPEED_BYTES: Int = 8 if CompilationTarget.is_macos() else 4


# `struct termios` is sized by the platform and not by us, which is
# what makes the four below worth having: a caller building one up
# from nothing has to know how far to go.
comptime NCCS: Int = 20 if CompilationTarget.is_macos() else 32

# What `tcsetattr` is to wait for before it changes anything. These
# three are 0, 1 and 2 on both platforms.
comptime TCSANOW: c_int = 0
comptime TCSADRAIN: c_int = 1
comptime TCSAFLUSH: c_int = 2

# What `tcflush` is to throw away. Darwin numbers these from 1 and
# glibc from 0, so the same integer means a different direction on
# each: 0 is "flush what came in" on glibc and nothing at all here.
comptime TCIFLUSH: c_int = 1 if CompilationTarget.is_macos() else 0
comptime TCOFLUSH: c_int = 2 if CompilationTarget.is_macos() else 1
comptime TCIOFLUSH: c_int = 3 if CompilationTarget.is_macos() else 2

# What `tcflow` is to stop or start. The same one-apart difference:
# Darwin numbers from 1, glibc from 0, and 0 means "suspend output"
# on glibc where it is not one of these at all.
comptime TCOOFF: c_int = 1 if CompilationTarget.is_macos() else 0
comptime TCOON: c_int = 2 if CompilationTarget.is_macos() else 1
comptime TCIOFF: c_int = 3 if CompilationTarget.is_macos() else 2
comptime TCION: c_int = 4 if CompilationTarget.is_macos() else 3

# Line speeds. glibc numbers these: twenty of them, 0 to 19 for the
# ones up to 38400 and then 4097 upward for the faster ones. Darwin
# names each one after the speed it is — `B9600` is 9600 — so the two
# schemes agree only at 0.
comptime B0: c_uint = 0
comptime B50: c_uint = 50 if CompilationTarget.is_macos() else 1
comptime B75: c_uint = 75 if CompilationTarget.is_macos() else 2
comptime B110: c_uint = 110 if CompilationTarget.is_macos() else 3
comptime B134: c_uint = 134 if CompilationTarget.is_macos() else 4
comptime B150: c_uint = 150 if CompilationTarget.is_macos() else 5
comptime B200: c_uint = 200 if CompilationTarget.is_macos() else 6
comptime B300: c_uint = 300 if CompilationTarget.is_macos() else 7
comptime B600: c_uint = 600 if CompilationTarget.is_macos() else 8
comptime B1200: c_uint = 1200 if CompilationTarget.is_macos() else 9
comptime B1800: c_uint = 1800 if CompilationTarget.is_macos() else 10
comptime B2400: c_uint = 2400 if CompilationTarget.is_macos() else 11
comptime B4800: c_uint = 4800 if CompilationTarget.is_macos() else 12
comptime B9600: c_uint = 9600 if CompilationTarget.is_macos() else 13
comptime B19200: c_uint = 19200 if CompilationTarget.is_macos() else 14
comptime B38400: c_uint = 38400 if CompilationTarget.is_macos() else 15
comptime B57600: c_uint = 57600 if CompilationTarget.is_macos() else 4097
comptime B115200: c_uint = 115200 if CompilationTarget.is_macos() else 4098
comptime B230400: c_uint = 230400 if CompilationTarget.is_macos() else 4099


struct Termios:
    """A C `struct termios`: how one terminal line is set.

    Held as eight-byte slots and read a member at a time, because the
    two libcs lay it out differently. Darwin's four flag words are
    `unsigned long` and eight bytes apart; glibc's are `unsigned int`
    and four. glibc carries a `c_line` that Darwin does not, so its
    `c_cc` starts at 17 where Darwin's starts at 32, and it holds 32
    control characters where Darwin holds 20.

    Nothing here is read without saying which platform it is read for.
    A caller who wants the whole struct, to hand to `tcgetattr` and
    then back to `tcsetattr`, does not have to know any of this: the
    block is as big as either libc's and C writes it itself.
    """

    var _slots: Array[UInt64, TERMIOS_SLOTS]

    def __init__(out self):
        """Zeroes all 72 bytes, which is what `memset` would leave behind."""
        self._slots = Array[UInt64, TERMIOS_SLOTS](fill=0)

    def _byte(self, off: Int) -> UInt8:
        """The single byte at `off`, whichever slot holds it."""
        return UInt8((self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFF)

    def _u32(self, off: Int) -> UInt32:
        """Four little-endian bytes at `off`."""
        return (
            UInt32(self._byte(off))
            | (UInt32(self._byte(off + 1)) << 8)
            | (UInt32(self._byte(off + 2)) << 16)
            | (UInt32(self._byte(off + 3)) << 24)
        )

    def _u64(self, off: Int) -> UInt64:
        """Eight little-endian bytes at `off`."""
        var acc: UInt64 = 0
        for i in range(8):
            acc |= UInt64(self._byte(off + i)) << UInt64(i * 8)
        return acc

    def _flag(self, off: Int) -> UInt64:
        """The flag word at `off`, which is four bytes on glibc and eight here.
        """
        comptime if CompilationTarget.is_macos():
            return self._u64(off)
        else:
            return UInt64(self._u32(off))

    def _set_byte(mut self, off: Int, to: UInt8):
        """Puts the single byte at `off`, leaving the rest of its slot."""
        var slot = off // 8
        var shift = UInt64((off % 8) * 8)
        var mask: UInt64 = ~(UInt64(0xFF) << shift)
        self._slots[slot] = (self._slots[slot] & mask) | (UInt64(to) << shift)

    def _set_flag(mut self, off: Int, to: UInt64):
        """Puts the flag word at `off`, however wide one is here."""
        comptime if CompilationTarget.is_macos():
            for i in range(8):
                self._set_byte(off + i, UInt8((to >> UInt64(i * 8)) & 0xFF))
        else:
            for i in range(4):
                self._set_byte(off + i, UInt8((to >> UInt64(i * 8)) & 0xFF))

    def iflag(self) -> UInt64:
        """Input modes: what is done to what comes in before it is read."""
        return self._flag(TERMIOS_IFLAG_OFFSET)

    def oflag(self) -> UInt64:
        """Output modes: what is done to what goes out on its way there."""
        return self._flag(TERMIOS_OFLAG_OFFSET)

    def cflag(self) -> UInt64:
        """Control modes: the character size, the parity, the line speed."""
        return self._flag(TERMIOS_CFLAG_OFFSET)

    def lflag(self) -> UInt64:
        """Local modes: echoing, and whether the line is canonical."""
        return self._flag(TERMIOS_LFLAG_OFFSET)

    def ispeed(self) -> UInt64:
        """The input baud rate, as `speed_t` gives it back."""
        return self._flag(TERMIOS_ISPEED_OFFSET)

    def ospeed(self) -> UInt64:
        """The output baud rate, as `speed_t` gives it back."""
        return self._flag(TERMIOS_OSPEED_OFFSET)

    def set_iflag(mut self, to: UInt64):
        """Puts the input modes."""
        self._set_flag(TERMIOS_IFLAG_OFFSET, to)

    def set_oflag(mut self, to: UInt64):
        """Puts the output modes."""
        self._set_flag(TERMIOS_OFLAG_OFFSET, to)

    def set_cflag(mut self, to: UInt64):
        """Puts the control modes."""
        self._set_flag(TERMIOS_CFLAG_OFFSET, to)

    def set_lflag(mut self, to: UInt64):
        """Puts the local modes."""
        self._set_flag(TERMIOS_LFLAG_OFFSET, to)

    def set_ispeed(mut self, to: UInt64):
        """Puts the input baud rate, in the numbering this libc uses."""
        self._set_flag(TERMIOS_ISPEED_OFFSET, to)

    def set_ospeed(mut self, to: UInt64):
        """Puts the output baud rate, in the numbering this libc uses."""
        self._set_flag(TERMIOS_OSPEED_OFFSET, to)

    def cc(self, at: Int) -> UInt8:
        """The control character at subscript `at`, such as `VMIN`.

        Args:
            at: Which one. Fewer than `NCCS`, which is where the
                platforms differ: 20 here, 32 on glibc.

        Returns:
            The character, or 0 where it has been switched off with
            `_POSIX_VDISABLE`.
        """
        return self._byte(TERMIOS_CC_OFFSET + at)

    def set_cc(mut self, at: Int, to: UInt8):
        """Puts the control character at subscript `at`.

        Args:
            at: Which one, fewer than `NCCS`.
            to: The character.
        """
        self._set_byte(TERMIOS_CC_OFFSET + at, to)


def tcgetattr(fildes: c_int, termios_p: c_ptr[Termios]) -> c_int:
    """C library <termios.h> function `tcgetattr`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcgetattr.3p.html

    Prototype:
        int tcgetattr(int fildes, struct termios *termios_p)

    Description:
        Reads how the terminal behind `fildes` is set and writes it
        where `termios_p` points.

    Args:
        fildes: The terminal. Anything that is not one — a file, a
            pipe, a socket — leaves `errno` at `ENOTTY` and the answer
            at -1.
        termios_p: Where the settings are to be written.

    Returns:
        0 on success, or -1 with `errno` set.

    Notes:
        What comes back is the terminal as it is now, and it is the
        only way to find out: there is no other call that reads it.
        Change what you want in it and hand it back to `tcsetattr`.
    """
    return external_call["tcgetattr", c_int, c_int, c_ptr[Termios]](
        fildes, termios_p
    )


def tcsetattr(
    fildes: c_int, optional_actions: c_int, termios_p: c_ptr[Termios]
) -> c_int:
    """C library <termios.h> function `tcsetattr`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcgetattr.3p.html

    Prototype:
        int tcsetattr(int fildes, int optional_actions,
                      const struct termios *termios_p)

    Description:
        Sets the terminal behind `fildes` to what `termios_p` says.

    Args:
        fildes: The terminal.
        optional_actions: When to do it — `TCSANOW` at once,
            `TCSADRAIN` once what is queued to go out has gone,
            `TCSAFLUSH` once that and once what has come in has been
            thrown away.
        termios_p: The settings, which is what `tcgetattr` filled in.

    Returns:
        0 on success, or -1 with `errno` set.

    Notes:
        A change that cannot be carried out does not fail the whole
        call: the settings that can be are, and 0 comes back anyway.
        Read back with `tcgetattr` if you need to know what took.
    """
    return external_call["tcsetattr", c_int, c_int, c_int, c_ptr[Termios]](
        fildes, optional_actions, termios_p
    )


def tcsendbreak(fildes: c_int, duration: c_int) -> c_int:
    """C library <termios.h> function `tcsendbreak`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcsendbreak.3p.html

    Prototype:
        int tcsendbreak(int fildes, int duration)

    Description:
        Sends a break — zero bits for longer than a character takes —
        out on the line behind `fildes`.

    Args:
        fildes: The terminal.
        duration: How long. 0 means about a quarter of a second, which
            is what it always comes to; anything else is up to the
            driver.

    Returns:
        0 on success, or -1 with `errno` set.
    """
    return external_call["tcsendbreak", c_int, c_int, c_int](fildes, duration)


def tcdrain(fildes: c_int) -> c_int:
    """C library <termios.h> function `tcdrain`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcdrain.3p.html

    Prototype:
        int tcdrain(int fildes)

    Description:
        Waits until everything written to `fildes` has gone out.

    Args:
        fildes: The terminal.

    Returns:
        0 on success, or -1 with `errno` set.

    Notes:
        This waits. On a descriptor that is not a terminal it comes
        back at once with `ENOTTY` rather than hanging.
    """
    return external_call["tcdrain", c_int, c_int](fildes)


def tcflush(fildes: c_int, queue_selector: c_int) -> c_int:
    """C library <termios.h> function `tcflush`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcflush.3p.html

    Prototype:
        int tcflush(int fildes, int queue_selector)

    Description:
        Throws away whatever has come in or is waiting to go out on
        the line behind `fildes`.

    Args:
        fildes: The terminal.
        queue_selector: Which — `TCIFLUSH` for what came in,
            `TCOFLUSH` for what is waiting to go out, `TCIOFLUSH` for
            both. **These are not the same numbers on both
            platforms**: glibc counts from 0 and Darwin from 1, so the
            constants above, not bare integers, are what to pass.

    Returns:
        0 on success, or -1 with `errno` set.
    """
    return external_call["tcflush", c_int, c_int, c_int](fildes, queue_selector)


def tcflow(fildes: c_int, action: c_int) -> c_int:
    """C library <termios.h> function `tcflow`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcflow.3p.html

    Prototype:
        int tcflow(int fildes, int action)

    Description:
        Stops or starts the flow of data on the line behind `fildes`.

    Args:
        fildes: The terminal.
        action: What to do — `TCOOFF` to hold up what is going out,
            `TCOON` to let it go again, `TCIOFF`/`TCION` for what is
            coming in. **These are not the same numbers on both
            platforms**, one apart, so pass the constants above.

    Returns:
        0 on success, or -1 with `errno` set.
    """
    return external_call["tcflow", c_int, c_int, c_int](fildes, action)


def tcgetsid(fildes: c_int) -> c_int:
    """C library <termios.h> function `tcgetsid`.

    Reference:
        https://man7.org/linux/man-pages/man3/tcgetsid.3p.html

    Prototype:
        pid_t tcgetsid(int fildes)

    Description:
        Answers with the process group ID of the session that has
        `fildes` as its controlling terminal.

    Args:
        fildes: The terminal.

    Returns:
        The session leader's process group ID on success, or -1 with
        `errno` set.

    Notes:
        This is the one way to get from a terminal to the session
        behind it, which is what moving a terminal between sessions
        and job control turn on.
    """
    return external_call["tcgetsid", c_int, c_int](fildes)


def cfgetispeed(termios_p: c_ptr[Termios]) -> c_uint:
    """C library <termios.h> function `cfgetispeed`.

    Reference:
        https://man7.org/linux/man-pages/man3/cfgetispeed.3p.html

    Prototype:
        speed_t cfgetispeed(const struct termios *termios_p)

    Description:
        The input baud rate the settings ask for.

    Args:
        termios_p: The settings.

    Returns:
        The speed, in the numbering this libc uses for one — glibc's
        runs 0 to 19 and then 4097 upward, while here each is the
        rate itself. Compare against the `B*` constants above rather
        than against a number of your own.

    Notes:
        This reads a block of memory and nothing else, so it wants no
        terminal and cannot fail.
    """
    return external_call["cfgetispeed", c_uint, c_ptr[Termios]](termios_p)


def cfgetospeed(termios_p: c_ptr[Termios]) -> c_uint:
    """C library <termios.h> function `cfgetospeed`.

    Reference:
        https://man7.org/linux/man-pages/man3/cfgetospeed.3p.html

    Prototype:
        speed_t cfgetospeed(const struct termios *termios_p)

    Description:
        The output baud rate the settings ask for.

    Args:
        termios_p: The settings.

    Returns:
        The speed, numbered as this libc numbers one. Compare against
        the `B*` constants above.

    Notes:
        This reads a block of memory and nothing else, so it wants no
        terminal and cannot fail.
    """
    return external_call["cfgetospeed", c_uint, c_ptr[Termios]](termios_p)


def cfsetispeed(termios_p: c_ptr[Termios], speed: c_uint) -> c_int:
    """C library <termios.h> function `cfsetispeed`.

    Reference:
        https://man7.org/linux/man-pages/man3/cfsetispeed.3p.html

    Prototype:
        int cfsetispeed(struct termios *termios_p, speed_t speed)

    Description:
        Puts the input baud rate the settings are to ask for.

    Args:
        termios_p: The settings, which is what `tcgetattr` filled in.
        speed: The rate, from the `B*` constants above.

    Returns:
        0 on success, or -1 with `errno` set.

    Notes:
        This only writes into the block; it sets nothing on the
        terminal. Hand the settings to `tcsetattr` for that.
    """
    return external_call["cfsetispeed", c_int, c_ptr[Termios], c_uint](
        termios_p, speed
    )


def cfsetospeed(termios_p: c_ptr[Termios], speed: c_uint) -> c_int:
    """C library <termios.h> function `cfsetospeed`.

    Reference:
        https://man7.org/linux/man-pages/man3/cfsetospeed.3p.html

    Prototype:
        int cfsetospeed(struct termios *termios_p, speed_t speed)

    Description:
        Puts the output baud rate the settings are to ask for.

    Args:
        termios_p: The settings, which is what `tcgetattr` filled in.
        speed: The rate, from the `B*` constants above.

    Returns:
        0 on success, or -1 with `errno` set.

    Notes:
        This only writes into the block; it sets nothing on the
        terminal. Hand the settings to `tcsetattr` for that.
    """
    return external_call["cfsetospeed", c_int, c_ptr[Termios], c_uint](
        termios_p, speed
    )


def cfsetspeed(termios_p: c_ptr[Termios], speed: c_uint) -> c_int:
    """C library <termios.h> function `cfsetspeed`.

    Reference:
        https://man7.org/linux/man-pages/man3/cfsetspeed.3.html

    Prototype:
        int cfsetspeed(struct termios *termios_p, speed_t speed)

    Description:
        Puts the same baud rate in and out, which is what most callers
        want and what `cfsetispeed` and `cfsetospeed` together would
        otherwise take two calls to say.

    Args:
        termios_p: The settings, which is what `tcgetattr` filled in.
        speed: The rate, from the `B*` constants above.

    Returns:
        0 on success, or -1 with `errno` set.

    Notes:
        Not POSIX: it is the BSD spelling, and glibc carries it under
        `_DEFAULT_SOURCE`. Where it is missing, the two calls above
        say the same thing.
    """
    return external_call["cfsetspeed", c_int, c_ptr[Termios], c_uint](
        termios_p, speed
    )


def cfmakeraw(termios_p: c_ptr[Termios]):
    """C library <termios.h> function `cfmakeraw`.

    Reference:
        https://man7.org/linux/man-pages/man3/cfmakeraw.3.html

    Prototype:
        void cfmakeraw(struct termios *termios_p)

    Description:
        Sets the settings to raw mode: no echoing, no line
        discipline, no translating of characters on the way in or out,
        no flow control, and no signals from the keyboard.

    Args:
        termios_p: The settings, which is what `tcgetattr` filled in.

    Notes:
        Not POSIX either: the BSD spelling again, carried by glibc
        under `_DEFAULT_SOURCE`. It leaves the speed alone, so set
        that before or after and it stays.

        This only writes into the block; hand it to `tcsetattr` for
        the terminal to change.
    """
    external_call["cfmakeraw", NoneType, c_ptr[Termios]](termios_p)
