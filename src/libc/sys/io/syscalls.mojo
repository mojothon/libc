from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ulong


def ioperm(from_port: c_ulong, num: c_ulong, turn_on: c_int) -> c_int:
    """C library <sys/io.h> function `ioperm`.

    Reference:
        https://man7.org/linux/man-pages/man2/ioperm.2.html

    Description:
        The word for the ports of the machine: the asking says
        whether the process may read from and write to the
        input and output ports from one number on for as many
        as are said, which is the thing a process that talks
        to the machine's own devices asks for, and the thing a
        process that is not allowed to ask is refused.

    Args:
        from_port: The first port the word is about.
        num: The count of the ports the word is about.
        turn_on: Whether the ports are to be the process's to
            read and write, or not.

    Returns:
        0 on success, -1 with `errno` saying why on a failure.

    Notes:
        The wrapper has been in the C library since 2.2.5, and
        it is the kernel's own word and not POSIX's: what
        POSIX says of the process is its files, and the ports
        are the machine's own ground, said by a process that
        is allowed to say it. A process that is not allowed is
        refused with `EPERM` when it asks to have the ports,
        and the asking to not have them -- the asking that
        gives up what the process never had -- is answered
        with nothing done, there being nothing to give up.
        Darwin's libSystem has no such call to say, so the
        word for the ports is had where the machine has ports.
    """
    return external_call["ioperm", c_int, c_ulong, c_ulong, c_int](
        from_port, num, turn_on
    )


def iopl(level: c_int) -> c_int:
    """C library <sys/io.h> function `iopl`.

    Reference:
        https://man7.org/linux/man-pages/man2/iopl.2.html

    Description:
        The word for all the ports of the machine at once: the
        saying of a level of none is the giving up of what the
        process has of the ports, and the saying of more is
        the asking to have them all, which a process that is
        not allowed to ask is refused.

    Args:
        level: The level of the word -- none to give the ports
            up, or three to have them all.

    Returns:
        0 on success, -1 with `errno` saying why on a failure.

    Notes:
        The wrapper has been in the C library since 2.2.5, and
        it is the whole word where `ioperm` is the word for
        some: the asking of a level of none is answered with
        nothing done whether the process has ports or not,
        there being nothing said of the ones it does not have,
        and the asking of more than the process is allowed is
        refused with `EPERM`. Darwin's libSystem has no such
        call to say, so the whole word is had where the
        machine has ports.
    """
    return external_call["iopl", c_int, c_int](level)
