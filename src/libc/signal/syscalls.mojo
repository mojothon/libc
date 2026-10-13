# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from std.memory import Pointer
from libc.constant import c_ptr


# The signal numbers, which is how `kill` and `craise` are told which one.
# Linux and Darwin agree as far as SIGTRAP and part company after it: SIGBUS
# is 7 here and 10 there, SIGUSR1 10 and 30, SIGCHLD 17 and 20, so they are
# set per platform. The Linux values were read out of <signal.h> and the
# Darwin ones are what Apple's has.
comptime SIGHUP: Int32 = 1
comptime SIGINT: Int32 = 2
comptime SIGQUIT: Int32 = 3
comptime SIGILL: Int32 = 4
comptime SIGTRAP: Int32 = 5
comptime SIGABRT: Int32 = 6
comptime SIGBUS: Int32 = 10 if CompilationTarget.is_macos() else 7
comptime SIGFPE: Int32 = 8
comptime SIGKILL: Int32 = 9
comptime SIGUSR1: Int32 = 30 if CompilationTarget.is_macos() else 10
comptime SIGSEGV: Int32 = 11
comptime SIGUSR2: Int32 = 31 if CompilationTarget.is_macos() else 12
comptime SIGPIPE: Int32 = 13
comptime SIGALRM: Int32 = 14
comptime SIGTERM: Int32 = 15
comptime SIGCHLD: Int32 = 20 if CompilationTarget.is_macos() else 17
comptime SIGCONT: Int32 = 19 if CompilationTarget.is_macos() else 18
comptime SIGSTOP: Int32 = 17 if CompilationTarget.is_macos() else 19
comptime SIGTSTP: Int32 = 18 if CompilationTarget.is_macos() else 20

# What a signal is answered with, and how a mask is asked for. In C these
# three are function pointers and these three are plain numbers, and all six
# are the same on both platforms.
comptime SIG_DFL: Int32 = 0
comptime SIG_IGN: Int32 = 1
comptime SIG_ERR: Int32 = -1
comptime SIG_BLOCK: Int32 = 0
comptime SIG_UNBLOCK: Int32 = 1
comptime SIG_SETMASK: Int32 = 2

# The least an alternate signal stack wants, which is what `sigaltstack`
# asks of its size: 131072 there and 8192 here.
comptime SIGSTKSZ: Int32 = 131072 if CompilationTarget.is_macos() else 8192


def kill(pid: Int32, sig: Int32) -> Int32:
    """C library <signal.h> function `kill`.

    Reference:
        https://man7.org/linux/man-pages/man2/kill.2.html

    Prototype:
        int kill(pid_t pid, int sig)

    Description:
        The kill() function sends a signal to the process specified by pid.
        The signal sent is specified by sig. If sig is 0, no signal is sent, but error checking is still performed.
        If sig is SIGKILL or SIGSTOP, the process is killed or stopped, respectively.
        If sig is SIGSEGV, the program is terminated with a segmentation fault.
        If sig is SIGFPE, the program is terminated with a floating-point exception.
        If sig is SIGILL, the program is terminated with an illegal instruction.
        If sig is SIGBUS, the program is terminated with a bus error.
        None of those names are bound here: sig is a number, and on Linux
        `SIGHUP` is 1, `SIGINT` 2, `SIGQUIT` 3, `SIGKILL` 9, `SIGUSR1` 10,
        `SIGSEGV` 11, `SIGUSR2` 12, `SIGPIPE` 13, `SIGALRM` 14, `SIGTERM`
        15 and `SIGCHLD` 17.

    Arguments:
        pid: Whom to send it to. A process id, or 0 for every process
            in the caller's group, or -1 for every one it is allowed
            to send to, or a negative number for the group whose id
            is that number made positive.
        sig: The signal, as a number. 0 sends nothing at all and is
            still checked, which is how a process asks whether one is
            still there.

    Return Value:
        On success, kill() returns 0. On error, -1 is returned, and errno is set to indicate the error.
    """
    return external_call["kill", Int32, Int32, Int32](pid, sig)


def craise(sig: Int32) -> Int32:
    """C library <signal.h> function `raise`.

    Reference:
        https://man7.org/linux/man-pages/man3/raise.3.html

    Prototype:
        int raise(int sig)

    Description:
        The raise() function causes the signal sig to be sent to the calling process.
        It is called `craise` here because `raise` is a Mojo keyword; what is
        called is C's `raise`.
        If sig is 0, no signal is sent, but error checking is still performed.
        If sig is SIGKILL or SIGSTOP, the process is killed or stopped, respectively.
        If sig is SIGSEGV, the program is terminated with a segmentation fault.
        If sig is SIGFPE, the program is terminated with a floating-point exception.
        If sig is SIGILL, the program is terminated with an illegal instruction.
        If sig is SIGBUS, the program is terminated with a bus error.

    Arguments:
        sig: The signal, as a number: see `kill`.

    Return Value:
        On success, 0 is returned. On failure a nonzero value comes
        back, which is not the -1 and errno that `kill` gives.
    """
    return external_call["raise", Int32, Int32](sig)


def sigaction(sig: Int32, act: c_ptr[UInt8], oldact: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigaction`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigaction.3.html

    Prototype:
        int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact)

    Description:
        The sigaction() function sets the action for the signal specified by signum.
        If the action is SIG_IGN, the signal is ignored.
        If the action is SIG_DFL, the default action for the signal is used.
        Otherwise, the action is a handler, which is the part that is out of
        reach here: there is no `struct sigaction` in this package, so `act`
        is bytes, and a handler is a C function pointer, which Mojo cannot
        make one of, there being no way to hand C a Mojo function as one.
        Laying the structure out by hand is not enough, so what this binding
        can do is limited to what a `struct sigaction` with no handler in it
        would ask for.

    Arguments:
        sig: The signal, as a number: see `kill`.
        act: The new action, as bytes.
        oldact: Where the old one is written, as bytes, or NULL if it
            is not wanted, which is `null_ptr[UInt8]()`.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call["sigaction", Int32, Int32, c_ptr[UInt8], c_ptr[UInt8]](
        sig, act, oldact
    )


def sigaltstack(ss: c_ptr[UInt8], oss: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigaltstack`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigaltstack.2.html

    Prototype:
        int sigaltstack(const stack_t *ss, stack_t *oss)

    Description:
        The sigaltstack() function sets the alternate signal stack. There is no
        `stack_t` here either, so both arguments are bytes: what C wants at
        `ss` is a pointer, a set of flags and a size, and what it wants of the
        size is at least `SIGSTKSZ`, which is not bound here and differs
        between the platforms.

    Arguments:
        ss: The stack to use, as bytes, or NULL to leave it alone.
        oss: Where the old one is written, as bytes, or NULL if it is
            not wanted.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call["sigaltstack", Int32, c_ptr[UInt8], c_ptr[UInt8]](
        ss, oss
    )


def sigdelset(set: c_ptr[UInt8], signo: Int32) -> Int32:
    """C library <signal.h> function `sigdelset`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigdelset.3.html

    Prototype:
        int sigdelset(sigset_t *set, int signo)

    Description:
        The sigdelset() function deletes the specified signal from the set.
        The set is not a `sigset_t` here but bytes, and what C wants is a block
        of memory holding a bit per signal, which is 128 bytes on Linux: a set
        allocated and zeroed is an empty one, so this is the one of these that
        can be used as it stands.

    Arguments:
        set: The set to delete from, as bytes.
        signo: The signal to delete, as a number.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call["sigdelset", Int32, c_ptr[UInt8], Int32](set, signo)


def sigemptyset(set: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigemptyset`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigemptyset.3.html

    Prototype:
        int sigemptyset(sigset_t *set)

    Description:
        The sigemptyset() function clears the set, which is bytes here rather
        than a `sigset_t`: give it a block of 128 zeroed bytes, or one that
        has been through `sigfillset`, and it comes back empty.

    Arguments:
        set: The set to clear, as bytes.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call["sigemptyset", Int32, c_ptr[UInt8]](set)


def sigfillset(set: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigfillset`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigfillset.3.html

    Prototype:
        int sigfillset(sigset_t *set)

    Description:
        The sigfillset() function fills the set with all possible signals.
        The set is bytes here, and it wants room for every signal there is,
        which is 128 bytes on Linux.

    Arguments:
        set: The set to fill, as bytes.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call["sigfillset", Int32, c_ptr[UInt8]](set)


def signal(signum: Int32, handler: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <signal.h> function `signal`.

    Reference:
        https://man7.org/linux/man-pages/man3/signal.3.html

    Prototype:
        sighandler_t signal(int signum, sighandler_t handler)

    Description:
        The signal() function sets the action for the signal specified by signum.
        If the action is SIG_IGN, the signal is ignored.
        If the action is SIG_DFL, the default action for the signal is used.
        Otherwise, the action is specified by the handler argument.

        The handler can be SIG_DFL, SIG_IGN, or a pointer to a function that takes an int argument.

        The signal() function returns the old action for the signal.

        A handler is a C function pointer, and Mojo cannot make one: there is no
        way to hand C a Mojo function as one. So a handler of one's own is out
        of reach, and what is reachable is the two that are not functions —
        `SIG_DFL`, which is 0 on Linux, and `SIG_IGN`, which is 1 — neither of
        which is bound here.

        It is also not quite `sigaction`: on a System V platform the disposition
        is put back to the default once the signal is delivered, and while it is
        being handled the signal is blocked, which `sigaction` leaves to the
        caller to ask for.

    Arguments:
        signum: The signal, as a number: see `kill`.
        handler: The action, as bytes, which in practice means 0 for
            `SIG_DFL` or 1 for `SIG_IGN` written as a pointer-sized
            value, a handler of one's own being out of reach.

    Return Value:
        On success, the previous action is returned. On error,
        `SIG_ERR` is returned, which is -1, and errno is set to
        indicate the error.
    """

    return external_call["signal", c_ptr[UInt8], Int32, c_ptr[UInt8]](
        signum, handler
    )


def sigprocmask(how: Int32, set: c_ptr[UInt8], oldset: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigprocmask`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigprocmask.2.html

    Prototype:
        int sigprocmask(int how, const sigset_t *set, sigset_t *oldset)

    Description:
        The sigprocmask() function manipulates the set of blocked signals.
        The sets are bytes here rather than `sigset_t`, and `how` is a number:
        on Linux `SIG_BLOCK` is 0, `SIG_UNBLOCK` 1 and `SIG_SETMASK` 2, none
        of which is bound here.

    Arguments:
        how: What to do with the set, as a number.
        set: The set to do it with, as bytes, or NULL when `how` is
            `SIG_SETMASK` and the mask is only being read.
        oldset: Where the previous mask is written, as bytes, or NULL
            if it is not wanted.

    Return Value:
        On success, sigprocmask() returns 0. On error, -1 is returned, and errno is set to indicate the error.
    """
    return external_call[
        "sigprocmask", Int32, Int32, c_ptr[UInt8], c_ptr[UInt8]
    ](how, set, oldset)
