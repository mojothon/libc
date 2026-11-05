# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <pty.h>.
#
# A pseudo-terminal is a pair of descriptors that stand in for a
# terminal: one is the program's side, which reads and writes as if it
# were a terminal's cable, and the other is the terminal itself, with a
# line discipline, a size, and everything `isatty` looks for. A program
# that needs to drive something that only talks to a terminal -- and
# that would hold a pipe at arm's length -- asks for the pair here.
#
# Where the declarations live differs and the symbols do not: Linux
# keeps them in `<pty.h>` and Darwin in `<util.h>`, which is why nothing
# below is a header question. `forkpty` is `fork` and `openpty` and
# `login_tty` in one call, and its child has the terminal for all three
# of its standard descriptors.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_char, c_int, c_ptr
from libc.termios import Termios


struct Winsize(TrivialRegisterPassable):
    """A C `struct winsize`: the size of the terminal window.

    Four `unsigned short`s -- rows, columns, then the pixel sizes that
    most terminals leave at nothing -- and the same layout on both
    platforms, so unlike `struct termios` this one is written as the
    members it has rather than read out of slots.
    """

    var ws_row: UInt16
    var ws_col: UInt16
    var ws_xpixel: UInt16
    var ws_ypixel: UInt16

    def __init__(out self):
        """Zeroes the four sizes, which is a window of no size."""
        self.ws_row = 0
        self.ws_col = 0
        self.ws_xpixel = 0
        self.ws_ypixel = 0


def openpty(
    amaster: c_ptr[c_int],
    aslave: c_ptr[c_int],
    name: c_ptr[c_char],
    termp: c_ptr[Termios],
    winp: c_ptr[Winsize],
) -> c_int:
    """C library `openpty`, which takes a pseudo-terminal pair.

    Reference:
        https://man7.org/linux/man-pages/man3/openpty.3.html

    Args:
        amaster: Where the master descriptor is written.
        aslave: Where the slave descriptor is written.
        name: Where the slave's path is written, or a null pointer.
        termp: The settings to give the slave, or a null pointer for the
            ones a terminal starts with.
        winp: The size to give the slave, or a null pointer for none.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        Fn signature: `int openpty(int *amaster, int *aslave, char *name,
        const struct termios *termp, const struct winsize *winp)`.

        The master is not a terminal itself -- `isatty` says no -- and is
        what a program reads and writes; the slave is one, and is what
        the program under test gets. Both are closed with `close`.
    """
    return external_call[
        "openpty",
        c_int,
        c_ptr[c_int],
        c_ptr[c_int],
        c_ptr[c_char],
        c_ptr[Termios],
        c_ptr[Winsize],
    ](amaster, aslave, name, termp, winp)


def forkpty(
    amaster: c_ptr[c_int],
    name: c_ptr[c_char],
    termp: c_ptr[Termios],
    winp: c_ptr[Winsize],
) -> c_int:
    """C library `forkpty`, which forks with a pseudo-terminal as its child's.

    Reference:
        https://man7.org/linux/man-pages/man3/forkpty.3.html

    Args:
        amaster: Where the master descriptor is written, in the parent.
        name: Where the slave's path is written, or a null pointer.
        termp: The settings to give the slave, or a null pointer for the
            ones a terminal starts with.
        winp: The size to give the slave, or a null pointer for none.

    Returns:
        In the parent, the child's process id, or -1 with `errno` set; in
        the child, 0, with the slave on descriptors 0, 1 and 2.

    Notes:
        Fn signature: `pid_t forkpty(int *amaster, char *name,
        const struct termios *termp, const struct winsize *winp)`.

        What the child gets is `openpty`, `login_tty` and `fork` in that
        order, which is also the order a caller doing it by hand must
        use: the descriptors have to exist before the child is made, or
        the other side of the terminal is not there to be read.
    """
    return external_call[
        "forkpty",
        c_int,
        c_ptr[c_int],
        c_ptr[c_char],
        c_ptr[Termios],
        c_ptr[Winsize],
    ](amaster, name, termp, winp)


def login_tty(fd: c_int) -> c_int:
    """C library `login_tty`, which makes a descriptor the terminal.

    Reference:
        https://man7.org/linux/man-pages/man3/login_tty.3.html

    Args:
        fd: The descriptor to put on 0, 1 and 2.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        Fn signature: `int login_tty(int fd)`.

        It makes a new session, makes the descriptor the controlling
        terminal of it, and duplicates it onto the three standard
        descriptors. It is what a process that has just opened a
        terminal does before it starts the program that is to run on it.
    """
    return external_call["login_tty", c_int, c_int](fd)
