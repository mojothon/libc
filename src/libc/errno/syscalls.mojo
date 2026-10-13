# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import unsafe_stack_allocation
from std.sys import CompilationTarget

from libc.constant import *
from libc.constant import c_ptr
from libc.string import strerror
from libc.utils import char_ptr_to_string


def set_errno(value: Int32) raises:
    """Set the value of the `errno` global variable for the current thread.

    Args:
        value: The value to set `errno` to.

    Notes:
        `errno` is a macro in C, so this writes through `__errno_location()` on
        glibc and `__error()` on Darwin, the two symbols `get_errno` reads.
        Nothing in libc clears it, which is the usual reason to want this.
    """
    comptime if CompilationTarget.is_macos():
        external_call["__error", c_ptr[Int32]]()[] = value
    else:
        external_call["__errno_location", c_ptr[Int32]]()[] = value


def get_errno() -> Int32:
    """Get a copy of the current value of the `errno` global variable for the
    current thread.

    Returns:
        A copy of the current value of `errno` for the current thread.
    """

    comptime if CompilationTarget.is_macos():
        # macOS exports `__error()` instead of the glibc `__errno_location()`.
        return external_call["__error", c_ptr[Int32]]()[]
    else:
        return external_call["__errno_location", c_ptr[Int32]]()[]


def errno_name(errnum: Int32) -> String:
    """The name `errno.h` gives a number, which C cannot be asked for.

    `errno` is a number at run time and a macro at compile time, and
    nothing joins the two: there is no `errno_name` in libc, so a program
    that prints one prints a number and its reader looks it up in a table.
    This is that table, and it is the one this package already uses, so it
    answers with the name for the platform it was built for — `EAGAIN` is
    11 here and 35 on Darwin, and either way this says `EAGAIN`.

    Args:
        errnum: An `errno` value, as `get_errno` answers with.

    Returns:
        The name, as `ENOENT`, or `errno N` for a number that has none,
        which is how an unknown one reads rather than looking like a name.
    """
    var e = Int(errnum)
    if e == 0:
        return "no error"
    if e == EPERM:
        return "EPERM"
    if e == ENOENT:
        return "ENOENT"
    if e == ESRCH:
        return "ESRCH"
    if e == EINTR:
        return "EINTR"
    if e == EIO:
        return "EIO"
    if e == ENXIO:
        return "ENXIO"
    if e == E2BIG:
        return "E2BIG"
    if e == ENOEXEC:
        return "ENOEXEC"
    if e == EBADF:
        return "EBADF"
    if e == ECHILD:
        return "ECHILD"
    if e == EDEADLK:
        return "EDEADLK"
    if e == ENOMEM:
        return "ENOMEM"
    if e == EACCES:
        return "EACCES"
    if e == EFAULT:
        return "EFAULT"
    if e == ENOTBLK:
        return "ENOTBLK"
    if e == EBUSY:
        return "EBUSY"
    if e == EEXIST:
        return "EEXIST"
    if e == EXDEV:
        return "EXDEV"
    if e == ENODEV:
        return "ENODEV"
    if e == ENOTDIR:
        return "ENOTDIR"
    if e == EISDIR:
        return "EISDIR"
    if e == EINVAL:
        return "EINVAL"
    if e == ENFILE:
        return "ENFILE"
    if e == EMFILE:
        return "EMFILE"
    if e == ENOTTY:
        return "ENOTTY"
    if e == ETXTBSY:
        return "ETXTBSY"
    if e == EFBIG:
        return "EFBIG"
    if e == ENOSPC:
        return "ENOSPC"
    if e == ESPIPE:
        return "ESPIPE"
    if e == EROFS:
        return "EROFS"
    if e == EMLINK:
        return "EMLINK"
    if e == EPIPE:
        return "EPIPE"
    if e == EDOM:
        return "EDOM"
    if e == ERANGE:
        return "ERANGE"
    if e == EAGAIN:
        return "EAGAIN"
    if e == EWOULDBLOCK:
        return "EWOULDBLOCK"
    if e == EDEADLOCK:
        return "EDEADLOCK"
    if e == EINPROGRESS:
        return "EINPROGRESS"
    if e == EALREADY:
        return "EALREADY"
    if e == ENOTSOCK:
        return "ENOTSOCK"
    if e == EDESTADDRREQ:
        return "EDESTADDRREQ"
    if e == EMSGSIZE:
        return "EMSGSIZE"
    if e == EPROTOTYPE:
        return "EPROTOTYPE"
    if e == ENOPROTOOPT:
        return "ENOPROTOOPT"
    if e == EPROTONOSUPPORT:
        return "EPROTONOSUPPORT"
    if e == ECHRNG:
        return "ECHRNG"
    if e == ESOCKTNOSUPPORT:
        return "ESOCKTNOSUPPORT"
    if e == EL2NSYNC:
        return "EL2NSYNC"
    if e == ENOTSUP:
        return "ENOTSUP"
    if e == EL3HLT:
        return "EL3HLT"
    if e == EPFNOSUPPORT:
        return "EPFNOSUPPORT"
    if e == EL3RST:
        return "EL3RST"
    if e == EAFNOSUPPORT:
        return "EAFNOSUPPORT"
    if e == ELNRNG:
        return "ELNRNG"
    if e == EADDRINUSE:
        return "EADDRINUSE"
    if e == EUNATCH:
        return "EUNATCH"
    if e == EADDRNOTAVAIL:
        return "EADDRNOTAVAIL"
    if e == ENOCSI:
        return "ENOCSI"
    if e == ENETDOWN:
        return "ENETDOWN"
    if e == EL2HLT:
        return "EL2HLT"
    if e == ENETUNREACH:
        return "ENETUNREACH"
    if e == EBADE:
        return "EBADE"
    if e == ENETRESET:
        return "ENETRESET"
    if e == EBADR:
        return "EBADR"
    if e == ECONNABORTED:
        return "ECONNABORTED"
    if e == EXFULL:
        return "EXFULL"
    if e == ECONNRESET:
        return "ECONNRESET"
    if e == ENOANO:
        return "ENOANO"
    if e == ENOBUFS:
        return "ENOBUFS"
    if e == EBADRQC:
        return "EBADRQC"
    if e == EISCONN:
        return "EISCONN"
    if e == EBADSLT:
        return "EBADSLT"
    if e == ENOTCONN:
        return "ENOTCONN"
    if e == ESHUTDOWN:
        return "ESHUTDOWN"
    if e == EBFONT:
        return "EBFONT"
    if e == ETOOMANYREFS:
        return "ETOOMANYREFS"
    if e == ETIMEDOUT:
        return "ETIMEDOUT"
    if e == ECONNREFUSED:
        return "ECONNREFUSED"
    if e == ELOOP:
        return "ELOOP"
    if e == ENAMETOOLONG:
        return "ENAMETOOLONG"
    if e == ENONET:
        return "ENONET"
    if e == EHOSTDOWN:
        return "EHOSTDOWN"
    if e == ENOPKG:
        return "ENOPKG"
    if e == EHOSTUNREACH:
        return "EHOSTUNREACH"
    if e == ENOTEMPTY:
        return "ENOTEMPTY"
    if e == EADV:
        return "EADV"
    if e == EUSERS:
        return "EUSERS"
    if e == ESRMNT:
        return "ESRMNT"
    if e == EDQUOT:
        return "EDQUOT"
    if e == ECOMM:
        return "ECOMM"
    if e == ESTALE:
        return "ESTALE"
    if e == EREMOTE:
        return "EREMOTE"
    if e == EDOTDOT:
        return "EDOTDOT"
    if e == ENOTUNIQ:
        return "ENOTUNIQ"
    if e == ENOLCK:
        return "ENOLCK"
    if e == EBADFD:
        return "EBADFD"
    if e == ENOSYS:
        return "ENOSYS"
    if e == EREMCHG:
        return "EREMCHG"
    if e == ELIBACC:
        return "ELIBACC"
    if e == ELIBBAD:
        return "ELIBBAD"
    if e == ELIBSCN:
        return "ELIBSCN"
    if e == ELIBMAX:
        return "ELIBMAX"
    if e == ELIBEXEC:
        return "ELIBEXEC"
    if e == EOVERFLOW:
        return "EOVERFLOW"
    if e == ERESTART:
        return "ERESTART"
    if e == ESTRPIPE:
        return "ESTRPIPE"
    if e == ECANCELED:
        return "ECANCELED"
    if e == EIDRM:
        return "EIDRM"
    if e == ENOMSG:
        return "ENOMSG"
    if e == EILSEQ:
        return "EILSEQ"
    if e == EBADMSG:
        return "EBADMSG"
    if e == EMULTIHOP:
        return "EMULTIHOP"
    if e == ENODATA:
        return "ENODATA"
    if e == ENOLINK:
        return "ENOLINK"
    if e == ENOSR:
        return "ENOSR"
    if e == ENOSTR:
        return "ENOSTR"
    if e == EPROTO:
        return "EPROTO"
    if e == ETIME:
        return "ETIME"
    if e == EOPNOTSUPP:
        return "EOPNOTSUPP"
    if e == ENOTRECOVERABLE:
        return "ENOTRECOVERABLE"
    if e == EOWNERDEAD:
        return "EOWNERDEAD"
    if e == EUCLEAN:
        return "EUCLEAN"
    if e == ENOTNAM:
        return "ENOTNAM"
    if e == ENAVAIL:
        return "ENAVAIL"
    if e == EISNAM:
        return "EISNAM"
    if e == EREMOTEIO:
        return "EREMOTEIO"
    if e == ENOMEDIUM:
        return "ENOMEDIUM"
    if e == EMEDIUMTYPE:
        return "EMEDIUMTYPE"
    if e == ENOKEY:
        return "ENOKEY"
    if e == EKEYEXPIRED:
        return "EKEYEXPIRED"
    if e == EKEYREVOKED:
        return "EKEYREVOKED"
    if e == EKEYREJECTED:
        return "EKEYREJECTED"
    if e == ERFKILL:
        return "ERFKILL"
    if e == EHWPOISON:
        return "EHWPOISON"
    return "errno " + String(e)


def errno_message(errnum: Int32) -> String:
    """The name and what libc says about it, as `ENOENT: No such file or
    directory`.

    Two questions in one answer, which is what `perror` prints and what
    `strerror` alone does not: `strerror` on its own says "No such file or
    directory" without saying which number that was, and the name on its
    own says which without saying what went wrong.

    Args:
        errnum: An `errno` value, as `get_errno` answers with.

    Returns:
        The name, a colon, and the message.
    """
    return errno_name(errnum) + ": " + char_ptr_to_string(strerror(errnum))


def check(result: Int32) raises -> Int32:
    """Pass a result through, or raise with what went wrong.

    Most of libc says -1 when it fails and leaves the reason in `errno`,
    and every caller then writes the same two lines to look at it. This is
    those two lines, so:

        var fd = check(open(path, O_RDONLY))

    raises `ENOENT: No such file or directory` rather than answering -1
    and leaving `errno` for someone to remember to read. C has no such
    thing to offer, having no exceptions to raise; the nearest is a macro
    of one's own that calls `perror` and `exit`, which is not the same as
    being able to catch it.

    It is the -1 kind of failure this is for. The calls that answer with
    the `errno` value itself rather than with -1 — most of `pthread` —
    want a look at their own answer instead.

    Args:
        result: What a call answered, where less than 0 means it failed.

    Returns:
        The same number, when it is 0 or more.

    Raises:
        With `errno_message` for whatever `errno` held.
    """
    if result >= 0:
        return result
    raise Error(errno_message(get_errno()))
