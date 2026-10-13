# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from libc.constant import *


def openlog(ident: c_ptr[c_char], logopt: c_int, facility: c_int) -> c_void:
    """Libc POSIX `openlog` function.

    Args:
        ident: A name to put in front of every message. What is kept is the
            pointer and not a copy, so it has to stay where it is for as
            long as messages are being sent.
        logopt: Options or'd together: `LOG_PID` to put the process id in,
            `LOG_CONS` to write to the console when the log cannot be
            reached, `LOG_NDELAY` to open it now rather than at the first
            message, and `LOG_ODELAY` for the other way round.
        facility: Which kind of program is sending these, as one of the
            `LOG_*` facilities. It goes out with every message and is what
            the log is sorted by on the far end.

    Returns:
        Nothing: C declares this one `void`.

    Notes:
        This one does not have to be called: the first `syslog` opens the
        log on its own, which is the same as calling this with no options.

        [Reference](https://man7.org/linux/man-pages/man3/closelog.3p.html).
        Fn signature: `void openlog(const char *ident, int logopt,
            int facility)`.
    """
    return external_call["openlog", c_void, c_ptr[c_char], c_int, c_int](
        ident, logopt, facility
    )


def syslog(priority: c_int, message: c_ptr[c_char]) -> c_void:
    """Libc POSIX `syslog` function.

    Args:
        priority: A level and a facility or'd together, as in
            `LOG_ERR | LOG_USER`. The level is how bad it is and the
            facility is who is saying it.
        message: The message, which C reads as a format string.

    Returns:
        Nothing: C declares this one `void`.

    Notes:
        C takes arguments after the message to fill in any `%s` and its
        like, and this binding passes none, so a message written with one
        in it comes out with the conversion in place and nothing put
        there. Say what has to be said in the message itself, or build it
        first and hand over the whole of it.

        Where this goes depends on the level: `LOG_EMERG` and worse are
        written to every terminal that is logged in, and `LOG_DEBUG` is
        thrown away by most setups.

        [Reference](https://man7.org/linux/man-pages/man3/closelog.3p.html).
        Fn signature: `void syslog(int priority, const char *message,
            ... /* arguments */)`.
    """
    return external_call["syslog", c_void, c_int, c_ptr[c_char]](
        priority, message
    )


def setlogmask(maskpri: c_int) -> c_int:
    """Libc POSIX `setlogmask` function.

    Args:
        maskpri: A bit for each level that should be let through.
            `LOG_MASK(level)` is one of them and `LOG_UPTO(level)` is that
            one and every one below it, which is what is usually meant.

    Returns:
        The mask that was in place before this one, which is the only way
        to get it back: there is no call that asks what it is.

    Notes:
        What is masked out is dropped before it goes anywhere, so a level
        that is not in the mask costs nothing to send.

        [Reference](https://man7.org/linux/man-pages/man3/setlogmask.3p.html).
        Fn signature: `int setlogmask(int maskpri)`.
    """
    return external_call["setlogmask", c_int, c_int](maskpri)


def closelog():
    """Libc POSIX `closelog` function.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/closelog.3p.html).
        Fn signature: `void closelog(void)`.
    """
    _ = external_call["closelog", c_void]()


def LOG_UPTO(pri: c_int) -> c_int:
    """Libc POSIX `LOG_UPTO` function.

    A mask of every priority up to and including `pri`, for `setlogmask`.

    C gives this as a macro, which is why it is a function here rather
    than a constant: it is worked out rather than looked up, and there is
    nothing for the two platforms to disagree over.

    Args:
        pri: The highest priority to let through.

    Returns:
        The mask, holding a bit for this priority and every lower one.
    """
    return c_int((1 << (pri + 1)) - 1)

