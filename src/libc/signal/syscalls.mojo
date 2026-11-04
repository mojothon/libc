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
comptime SIGWINCH: Int32 = 28

# What a signal is answered with, and how a mask is asked for. In C these
# three are function pointers and these three are plain numbers, and all six
# are the same on both platforms.
comptime SIG_DFL: Int32 = 0
comptime SIG_IGN: Int32 = 1
comptime SIG_ERR: Int32 = -1
comptime SIG_BLOCK: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime SIG_UNBLOCK: Int32 = 2 if CompilationTarget.is_macos() else 1
comptime SIG_SETMASK: Int32 = 3 if CompilationTarget.is_macos() else 2

# The one flag an action can carry that both platforms have and that changes
# nothing about how this suite runs: a call that was interrupted is restarted
# rather than answered with -1 and `EINTR`. glibc keeps it at 0x10000000 and
# XNU at 0x2, which is why it is here twice.
comptime SA_RESTART: Int32 = 2 if CompilationTarget.is_macos() else 0x10000000

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


def sigaction(
    sig: Int32, act: c_ptr[sigaction_t], oldact: c_ptr[sigaction_t]
) -> Int32:
    """C library <signal.h> function `sigaction`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigaction.3.html

    Prototype:
        int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact)

    Description:
        The sigaction() function sets the action for the signal specified by signum.
        If the action is SIG_IGN, the signal is ignored.
        If the action is SIG_DFL, the default action for the signal is used.
        Otherwise, the action is a handler, which is the part still out of
        reach: a handler is a C function pointer, and there is no way to hand
        C a Mojo function as one. The rest is not: `sigaction_t` is that
        struct, with its first word kept as a number, which is exactly what
        `SIG_DFL` (0) and `SIG_IGN` (1) are. So a signal can be told to be
        ignored here, asked what it is doing, and put back.

        `oldact` is how it is asked: the same call with `act` left NULL
        writes the current action where `oldact` points and changes nothing.

    Arguments:
        sig: The signal, as a number: see `kill`.
        act: The new action, or NULL, which is `null_ptr[sigaction_t]()`,
            to leave the signal answering as it did.
        oldact: Where the action in force is written, or NULL if it is
            not wanted.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call[
        "sigaction", Int32, Int32, c_ptr[sigaction_t], c_ptr[sigaction_t]
    ](sig, act, oldact)


def sigaltstack(ss: c_ptr[stack_t], oss: c_ptr[stack_t]) -> Int32:
    """C library <signal.h> function `sigaltstack`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigaltstack.2.html

    Prototype:
        int sigaltstack(const stack_t *ss, stack_t *oss)

    Description:
        The sigaltstack() function sets the alternate signal stack, which is
        the stack a signal handler runs on when its action asked to be run
        there. Nothing here asks for that, so a stack can be installed, asked
        for and taken away again without a signal ever being delivered on it.

        `stack_t` is here. What it wants of the size is at least `SIGSTKSZ`,
        and the members are in a different order on each platform, which is
        why the offsets above are two numbers rather than one.

        As with `sigaction`, calling it with NULL where the new stack would go
        writes the stack in force where `oss` points and changes nothing.

    Arguments:
        ss: The stack to use, or NULL to leave the signal answering as it
            did.
        oss: Where the stack in force is written, or NULL if it is not
            wanted.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error.
    """
    return external_call["sigaltstack", Int32, c_ptr[stack_t], c_ptr[stack_t]](
        ss, oss
    )


def sigaddset(set: c_ptr[UInt8], signo: Int32) -> Int32:
    """C library <signal.h> function `sigaddset`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigdelset.3.html

    Prototype:
        int sigaddset(sigset_t *set, int signo)

    Description:
        The sigaddset() function adds the specified signal to the set. The set
        is not a `sigset_t` here but bytes, sixty-four bytes on Darwin and a
        hundred and twenty-eight on Linux, and an allocator asked for the
        larger gives a set both are happy with: the bit for a signal lives in
        the low bytes either way. Zero the block and it is an empty set, then
        add to it with this.

    Arguments:
        set: The set to add to, as bytes.
        signo: The signal to add, as a number. Anything outside the signals
            this platform has is refused rather than added somewhere wrong.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error. EINVAL means the number was not a
        signal this platform knows.
    """
    return external_call["sigaddset", Int32, c_ptr[UInt8], Int32](set, signo)


def sigismember(set: c_ptr[UInt8], signo: Int32) -> Int32:
    """C library <signal.h> function `sigismember`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigismember.3.html

    Prototype:
        int sigismember(const sigset_t *set, int signo)

    Description:
        The sigismember() function tests whether the given signal is in the
        set, which is the question to ask a set that `sigaddset` and
        `sigdelset` have been editing.

    Arguments:
        set: The set to ask about, as bytes. It is read and not written.
        signo: The signal to ask about, as a number.

    Return Value:
        1 if the signal is in the set, 0 if it is not, and -1 on error with
        errno set: whether something is a member and whether asking worked
        are different answers, so this is not a boolean even though it looks
        like one. Comparing it against 1 rather than testing it for truth is
        what tells EINVAL apart from a set a signal was never added to.
    """
    return external_call["sigismember", Int32, c_ptr[UInt8], Int32](set, signo)


def sigpending(set: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigpending`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigpending.2.html

    Prototype:
        int sigpending(sigset_t *set)

    Description:
        The sigpending() function writes the signals that are waiting to be
        delivered into the set, those being the ones blocked and having
        arrived, which is everything about the state of signals that can be
        asked without stopping to wait for one. A way for a program that
        blocks signals for a while to find out what it missed.

    Arguments:
        set: Where the waiting signals are written, as bytes, overwriting
            whatever was there. Test membership in it with `sigismember`.

    Return Value:
        On success, 0 is returned. On error, -1 is returned, and errno
        is set to indicate the error. The set is only meaningful when this
        returned 0.
    """
    return external_call["sigpending", Int32, c_ptr[UInt8]](set)


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


def sigblock(mask: Int32) -> Int32:
    """C library <signal.h> function `sigblock`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigsetmask.3.html

    Prototype:
        int sigblock(int mask)

    Description:
        Adds signals to the blocked set, and answers with the set that
        was there before. The set is one machine word rather than the
        bytes `sigprocmask` takes: bit `signal - 1` for each signal
        blocked, so signal 1 is bit 0 and signal 31 is bit 30.

    Args:
        mask: The signals to add, as a word of bits.

    Returns:
        The blocked set as it was before the call, as a word of bits, or
        -1 on failure with `errno` set.

    Notes:
        This is the shape the blocked set had before `sigprocmask`, kept
        for the code that still calls it: the two are one mask, said as a
        word and as bytes, and a bit here is the same signal as a bit
        there.

        Only the first thirty-two signals fit in a word, which is the one
        thing `sigprocmask` can do that this cannot.

        Reading the set without changing it is `sigblock(0)`: adding
        nothing answers with the set and leaves it as it was.
    """
    return external_call["sigblock", Int32, Int32](mask)


def sigsetmask(mask: Int32) -> Int32:
    """C library <signal.h> function `sigsetmask`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigsetmask.3.html

    Prototype:
        int sigsetmask(int mask)

    Description:
        Replaces the blocked set with `mask`, and answers with the set it
        replaced.

    Args:
        mask: The set to leave in place, as a word of bits.

    Returns:
        The blocked set as it was before the call, as a word of bits, or
        -1 on failure with `errno` set.

    Notes:
        `sigblock` beside it only adds; this is the one that can take a
        signal out of the set as well, and putting back the word that
        `sigblock(0)` answered with is how a caller undoes it.

        A signal taken out of the set that arrived while it was still
        blocked is delivered before this returns, which is what
        `sigprocmask` does too, and the reason to put a set back rather
        than leave it empty.
    """
    return external_call["sigsetmask", Int32, Int32](mask)


def sigsuspend(mask: c_ptr[UInt8]) -> Int32:
    """C library <signal.h> function `sigsuspend`.

    Reference:
        https://man7.org/linux/man-pages/man2/sigsuspend.2.html

    Prototype:
        int sigsuspend(const sigset_t *mask)

    Description:
        The sigsuspend() function swaps the blocked signals for `mask` and
        then waits, swapping back and returning once a signal has been
        handled. It exists because the two operations done separately leave a
        gap: a signal that arrives after the mask is changed but before the
        wait begins is neither blocked nor awaited, and so is missed. This is
        the one call that does both without the gap.

    Arguments:
        mask: The signals to block while waiting, as bytes. Anything not in
            it may be delivered, which is the point: leave one unblocked and
            its handler is what wakes the wait.

    Return Value:
        Always -1, and always with errno set to EINTR, whether anything went
        wrong or not: there is no other way back. Coming here for a success
        code is looking for something this does not give out, and every
        worthwhile error looks exactly like returning normally, so what it
        tells you is only that it has stopped waiting.
    """
    return external_call["sigsuspend", Int32, c_ptr[UInt8]](mask)


def sigwait(set: c_ptr[UInt8], signo: c_ptr[Int32]) -> Int32:
    """C library <signal.h> function `sigwait`.

    Reference:
        https://man7.org/linux/man-pages/man3/sigwait.3.html

    Prototype:
        int sigwait(const sigset_t *set, int *signo)

    Description:
        The sigwait() function blocks until one of the signals in the set
        arrives, then writes which one into `signo`, taking it rather than
        running any handler for it. Signals here are asked for and received
        by a thread sitting waiting, which is a plainer way to take them than
        arranging for a handler to leave a note somewhere.

    Arguments:
        set: The signals being waited for, as bytes. They should be blocked
            first with `sigprocmask`: one that is not blocked is delivered
            and handled before this gets a look at it.
        signo: Where the number of the signal that arrived is written.

    Return Value:
        0 on success, having written the signal's number. On failure it
        hands back the error code itself rather than -1, and leaves errno
        alone, which is the opposite of what every other call here does:
        EINVAL out of this is a positive number, and checking against -1
        — or asking errno for what went wrong — finds nothing.
    """
    return external_call["sigwait", Int32, c_ptr[UInt8], c_ptr[Int32]](
        set, signo
    )


def killpg(pgrp: Int32, sig: Int32) -> Int32:
    """Libc POSIX `killpg` function.

    Description:
        Sends a signal to every process in a process group.

    Args:
        pgrp: The group to send it to, which is 0 for this process's
            own group.
        sig: Which signal to send, or 0 to send none and only ask
            whether the group is there.

    Returns:
        0 where it was sent, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/killpg.3.html).
        Fn signature: `int killpg(pid_t pgrp, int sig)`.

        This is `kill` with the number negated — `killpg(p, s)` being
        `kill(-p, s)` — which is the whole of what a negative pid has
        meant since forever. The two differ in that `killpg` will not
        take 0 to mean a group, and `kill` will not take -1 to mean
        one; `killpg` with -1 is a group that is not there.

        Signal 0 is the one that sends nothing. What it does instead
        is the check, which is what makes it the only signal worth
        sending in a test: whether the group exists is answered
        without disturbing anyone in it.
    """
    return external_call["killpg", Int32, Int32, Int32](pgrp, sig)


def psignal(sig: Int32, text: c_ptr[UInt8]) -> None:
    """Libc BSD `psignal` function.

    Description:
        Writes to standard error what a signal's number means, under a
        line of the caller's own.

    Args:
        sig: The signal whose name is wanted.
        text: What to write in front of it, which is what the caller
            was doing when the signal came.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/psignal.3.html).
        Fn signature: `void psignal(int sig, const char *s)`.

        This writes and says nothing back, so a caller cannot ask what
        a signal means, only have it written down. `strsignal` is the
        same words handed back rather than written, which is the one
        to call where anything is to be done with them.

        It is on both platforms, though not in POSIX. What it writes
        is not the same on the two of them — which words go with which
        number is each platform's own to say — so it is a thing to
        show a person and not a thing to test against.
    """
    external_call["psignal", NoneType, Int32, c_ptr[UInt8]](sig, text)


def sighold(sig: Int32) -> Int32:
    """Libc BSD `sighold` function.

    Reference:
        https://man7.org/linux/man-pages/man3/sighold.3.html

    Args:
        sig: The signal to add to the set this process holds back.

    Returns:
        0 where the signal is held, or -1 where it is not, with
        `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/sighold.3.html).
        Fn signature: `int sighold(int sig)`.

        This is `sigprocmask` with `SIG_BLOCK` and a set of one, said
        in one call. What it does not say is what the mask was before,
        which `sigprocmask` hands back and this does not -- putting the
        mask back is the caller's to arrange, and `sigrelse` is the
        one-way way out it was paired with.

        A signal that is held after having been raised is not gone: it
        waits in the pending set, and `sigpending` is the call that
        sees it there.
    """
    return external_call["sighold", Int32, Int32](sig)


def sigrelse(sig: Int32) -> Int32:
    """Libc BSD `sigrelse` function.

    Reference:
        https://man7.org/linux/man-pages/man3/sigrelse.3.html

    Args:
        sig: The signal to take out of the set this process holds
            back.

    Returns:
        0 where the signal is released, or -1 where it is not, with
        `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/sigrelse.3.html).
        Fn signature: `int sigrelse(int sig)`.

        This is `sigprocmask` with the signal taken out of the set,
        said in one call. A signal that was waiting in the pending set
        is delivered the moment it is out from behind the mask, which
        is the whole point of the pair: `sighold` to shut the door with
        the signal already inside, `sigrelse` to open it and let it
        come.
    """
    return external_call["sigrelse", Int32, Int32](sig)


def sigignore(sig: Int32) -> Int32:
    """Libc BSD `sigignore` function.

    Reference:
        https://man7.org/linux/man-pages/man3/sigignore.3.html

    Args:
        sig: The signal to be made nothing of.

    Returns:
        0 where the disposition was set, or -1 where it was not, with
        `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/sigignore.3.html).
        Fn signature: `int sigignore(int sig)`.

        This is `signal` with `SIG_IGN`, said in one call. It says
        nothing about the mask: a signal that is ignored and held is
        discarded rather than kept, which is the one way `sigignore`
        is not the same as `sighold` -- a held signal waits, an ignored
        one never arrives.
    """
    return external_call["sigignore", Int32, Int32](sig)


def sigpause(sig: Int32) -> Int32:
    """Libc BSD `sigpause` function.

    Reference:
        https://man7.org/linux/man-pages/man3/sigpause.3.html

    Args:
        sig: The signal to take out of the set this process holds
            back, and then wait on.

    Returns:
        -1, with `errno` set to `EINTR`, when a signal ends the wait.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/sigpause.3.html).
        Fn signature: `int sigpause(int sig)`.

        This is `sigrelse` and `sigsuspend` in one atomic step: the
        signal comes out from behind the mask and the process waits for
        one to arrive, and the atomicity is the reason it exists --
        between a `sigrelse` and a wait of one's own, the signal could
        arrive with nobody waiting for it.

        A signal that was waiting in the pending set is delivered the
        moment the mask lets it, so this call with one already waiting
        does not wait at all.
    """
    return external_call["sigpause", Int32, Int32](sig)


def siginterrupt(sig: Int32, interrupt: Int32) -> Int32:
    """Libc BSD `siginterrupt` function.

    Description:
        Says whether a slow call is to be woken up by this signal or
        to carry on after it.

    Args:
        sig: The signal being decided about.
        interrupt: Non-zero where the call is to be woken up and
            answer `EINTR`, zero where it is to carry on.

    Returns:
        0 where it was said, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/siginterrupt.3.html).
        Fn signature: `int siginterrupt(int sig, int flag)`.

        This is a way of setting, or clearing, the one flag in a
        signal's `sigaction` that says which of those happens, and
        `sigaction` is the one that says it now: it takes the whole
        of the flags at once, and is portable where this is not.

        It is on both platforms, though not in POSIX, and it is of the
        time before `sigaction`: what it does to a signal is done to
        whichever handler that signal has, so it is called after one
        is set and not before.
    """
    return external_call["siginterrupt", Int32, Int32, Int32](sig, interrupt)


# Where the members of C's `siginfo_t` that this reads sit. The first
# three agree on both platforms, and then the two layouts stop agreeing:
# `struct sigaction` is the other struct here whose layout the two platforms
# disagree about, and by more than a padding byte: glibc's is a handler, a
# 128-byte mask, four bytes of flags and a restorer, at 0, 8, 136 and 144 for
# 152 bytes in all; XNU's is a handler, a four-byte mask and four bytes of
# flags at 0, 8 and 12 for 16. So this block is sized per platform rather than
# generously as `siginfo_t` is: a `sigaction` is handed *to* libc, and the
# bytes after the end of Darwin's are memory this process did not own, which
# the kernel would not read and a longer mask would have overwritten.
#
# The mask is the member left out. It is the one part of the struct whose size
# is not a word, and nothing in this suite installs one; what is here is the
# union at the front and the flags behind it, which is what installing
# `SIG_IGN` and asking for it back needs.
comptime SIGACTION_HANDLER_OFFSET: Int = 0
comptime SIGACTION_FLAGS_OFFSET: Int = 12 if CompilationTarget.is_macos() else 136
comptime SIGACTION_SLOTS: Int = 2 if CompilationTarget.is_macos() else 19


# `stack_t` is the third struct on this page whose members the two platforms
# put in a different order, and the least obvious of the three: both are a
# pointer, a size and four bytes of flags, both are 24 bytes and 8-aligned, and
# the size and the flags are in each other's places. glibc has the flags at 8
# and XNU has the size at 8, so a struct laid out for one is a struct the other
# refuses -- the flags read 131072, which is not a flag, and the call answers
# `EINVAL`. Nothing about the two headers looks different until they are
# compared member by member, which is what `check-layouts` does with these.
comptime STACK_SP_OFFSET: Int = 0
comptime STACK_SIZE_OFFSET: Int = 8 if CompilationTarget.is_macos() else 16
comptime STACK_FLAGS_OFFSET: Int = 16 if CompilationTarget.is_macos() else 8


struct stack_t:
    """A C `stack_t`: the alternate stack a signal handler may be run on.

    Three members and no union, so this one is written out rather than kept as
    a number the way `sigaction_t`'s handler is: `ss_sp` is an address, and it
    is kept as one, because nothing else can be.

    The two platforms disagree about the order. glibc has the pointer, four
    bytes of flags and the size; Darwin has the pointer, the size and the
    flags. Both are 24 bytes, so the size is the same number and the offsets
    are not, which is why each member here asks the platform where it is.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/sigaltstack.2.html).
    """

    # The `ss_size` member is a `size_t` and the pointer is a word: eight-byte
    # slots keep the alignment C gives it.
    var _slots: Array[UInt64, 3]

    def __init__(out self):
        """Zeroed, which is a process that has no alternate stack: `ss_sp` is
        NULL and `ss_flags` is 0, which is what `sigaltstack` refuses.
        """
        self._slots = Array[UInt64, 3](fill=0)

    def sp(self) -> UInt64:
        """The lowest address of the stack, which is zero when there is none."""
        return self._slots[STACK_SP_OFFSET // 8]

    def set_sp(mut self, value: UInt64):
        """Puts the stack at `value`."""
        self._slots[STACK_SP_OFFSET // 8] = value

    def flags(self) -> Int32:
        """The `SS_*` bits: `SS_DISABLE` and `SS_ONSTACK`.

        Returns:
            The four bytes beside the pointer, as the number C reads.
        """
        var shift = UInt64((STACK_FLAGS_OFFSET % 8) * 8)
        var word = self._slots[STACK_FLAGS_OFFSET // 8]
        return Int32(UInt32((word >> shift) & 0xFFFFFFFF))

    def set_flags(mut self, value: Int32):
        """Asks for `value` as the flags, leaving the pointer where it is."""
        var shift = UInt64((STACK_FLAGS_OFFSET % 8) * 8)
        var word = self._slots[STACK_FLAGS_OFFSET // 8]
        var bits = UInt64(UInt32(Int64(value) & 0xFFFFFFFF))
        self._slots[STACK_FLAGS_OFFSET // 8] = (
            word & ~(UInt64(0xFFFFFFFF) << shift)
        ) | (bits << shift)

    def size(self) -> UInt64:
        """How many bytes there are, which is what `SIGSTKSZ` is for."""
        return self._slots[STACK_SIZE_OFFSET // 8]

    def set_size(mut self, value: UInt64):
        """Makes the stack `value` bytes long."""
        self._slots[STACK_SIZE_OFFSET // 8] = value


struct sigaction_t:
    """A C `struct sigaction`: the action one signal is given.

    The first eight bytes are a union of `sa_handler` and the three-argument
    `sa_sigaction`, and they are kept as a number rather than as a pointer,
    which is what makes most of this struct usable from here: the two actions
    that are not addresses are `SIG_DFL`, which is 0, and `SIG_IGN`, which is
    1. Installing one of those and reading it back is the whole of what a
    handler of one's own would prove, apart from the handler.

    The mask between the handler and the flags is not offered: it is 128 bytes
    wide on glibc and 4 on Darwin, so a `sigset_t` in here would be either
    thirty-two times too wide on one of them or a method that knows which
    platform it is on, and nothing in this suite installs a mask.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/sigaction.2.html).
    """

    # Eight-byte slots, as for `siginfo_t`: this one is 8-aligned in C, and an
    # `Array[UInt8]` would take its alignment down to 1.
    var _slots: Array[UInt64, SIGACTION_SLOTS]

    def __init__(out self):
        """Zeroed, which is what C leaves in one just declared: the default
        action, no flags, and an empty mask.
        """
        self._slots = Array[UInt64, SIGACTION_SLOTS](fill=0)

    def handler(self) -> UInt64:
        """What the signal is answered with: `SIG_DFL`, `SIG_IGN`, or the
        address of a function, which is the union's first word.
        """
        return self._slots[SIGACTION_HANDLER_OFFSET // 8]

    def set_handler(mut self, value: UInt64):
        """Answers the signal with `value`: `UInt64(SIG_DFL)`,
        `UInt64(SIG_IGN)`, or a function's address if one could be had.
        """
        self._slots[SIGACTION_HANDLER_OFFSET // 8] = value

    def flags(self) -> Int32:
        """The `SA_*` bits asked for, `SA_RESTART` being the one this package
        names.
        """
        var shift = UInt64((SIGACTION_FLAGS_OFFSET % 8) * 8)
        var word = self._slots[SIGACTION_FLAGS_OFFSET // 8]
        return Int32(UInt32((word >> shift) & 0xFFFFFFFF))

    def set_flags(mut self, value: Int32):
        """Asks for `value` as the flags, leaving the handler where it is.

        The four bytes are written into the word they share with whatever sits
        beside them -- the mask's last word on Darwin, padding on glibc -- so
        the rest of the word is read back first.
        """
        var shift = UInt64((SIGACTION_FLAGS_OFFSET % 8) * 8)
        var word = self._slots[SIGACTION_FLAGS_OFFSET // 8]
        var bits = UInt64(UInt32(Int64(value) & 0xFFFFFFFF))
        self._slots[SIGACTION_FLAGS_OFFSET // 8] = (
            word & ~(UInt64(0xFFFFFFFF) << shift)
        ) | (bits << shift)


# glibc pads `si_code` out to 16 so that the members after it are all
# word-aligned inside a union of `_pad[SI_PAD_SIZE]`, while XNU packs
# `si_pid` straight in at 12 and needs no padding for a 64-bit `si_addr`
# at 24. That is why one struct is 128 bytes and the other 104.
#
# `si_status` and `si_value` are the interesting pair on Linux: both are at
# 24, because they are different members of one union — a child's status
# and a value sent with `sigqueue` cannot both be true of one signal. On
# Darwin they are not in a union and sit at 20 and 32.
#
# Numbers from glibc's `bits/types/siginfo_t.h` and XNU's `sys/signal.h`,
# and both are compared with C's `offsetof` on both platforms by
# `scripts/check-layouts.py`. That comparison is worth having here more
# than anywhere else in the package: glibc spells these as macros over
# `_sifields`, so the name in C and the number here are two different
# ways of saying where the member is, and nothing but `offsetof` ties the
# two together.
comptime SIGINFO_SIGNO_OFFSET: Int = 0
comptime SIGINFO_ERRNO_OFFSET: Int = 4
comptime SIGINFO_CODE_OFFSET: Int = 8
comptime SIGINFO_PID_OFFSET: Int = 12 if CompilationTarget.is_macos() else 16
comptime SIGINFO_UID_OFFSET: Int = 16 if CompilationTarget.is_macos() else 20
comptime SIGINFO_STATUS_OFFSET: Int = 20 if CompilationTarget.is_macos() else 24
comptime SIGINFO_VALUE_OFFSET: Int = 32 if CompilationTarget.is_macos() else 24


struct siginfo_t:
    """A C `siginfo_t`: what a signal, or a wait, says happened.

    Kept as bytes and read by offset, because the members sit at
    different offsets on the two platforms: `si_pid` is at 16 on Linux
    and 12 on Darwin, `si_uid` 20 and 16, `si_status` 24 and 20. The
    first three — `si_signo`, `si_errno` and `si_code` — are at 0, 4
    and 8 on both.

    Nothing here writes one: a `siginfo_t` is something the library
    fills in and the caller reads, and the seven below are the part of
    it that is worth reading. The block is 128 bytes, which is what
    glibc's is and more than the 104 Darwin asks for, so there is room
    either way.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/waitid.2.html).
    """

    # Eight-byte slots rather than bytes: C says this one is 8-aligned,
    # and an `Array[UInt8]` would take its alignment down to 1.
    var _slots: Array[UInt64, 16]

    def __init__(out self):
        """Zeroes the whole block, which is what C leaves in one that
        has just been declared.
        """
        self._slots = Array[UInt64, 16](fill=0)

    def _u32(self, off: Int) -> UInt32:
        """Four little-endian bytes at `off`, which every offset in
        here keeps inside one slot.
        """
        var slot = self._slots[off // 8]
        return UInt32((slot >> UInt64((off % 8) * 8)) & 0xFFFFFFFF)

    def _u64(self, off: Int) -> UInt64:
        """The whole slot at `off`, which every offset in here keeps
        inside one.
        """
        return self._slots[off // 8]

    def si_signo(self) -> Int32:
        """The signal number the call was about."""
        return Int32(self._u32(SIGINFO_SIGNO_OFFSET))

    def si_errno(self) -> Int32:
        """Whatever `errno` was when it happened, 0 where nothing went
        wrong.
        """
        return Int32(self._u32(SIGINFO_ERRNO_OFFSET))

    def si_code(self) -> Int32:
        """Why it happened, one of the `CLD_*` codes for a child."""
        return Int32(self._u32(SIGINFO_CODE_OFFSET))

    def si_pid(self) -> Int32:
        """The process it was about: the child, for a wait."""
        return Int32(self._u32(SIGINFO_PID_OFFSET))

    def si_uid(self) -> UInt32:
        """The real user id of whoever sent it, or of the child."""
        return self._u32(SIGINFO_UID_OFFSET)

    def si_status(self) -> Int32:
        """The number the child left with, or the signal it died of,
        whichever `si_code` says it was.
        """
        return Int32(self._u32(SIGINFO_STATUS_OFFSET))

    def si_value(self) -> Int32:
        """The number that was sent along with the signal, the
        `sival_int` half of the `sigval` union.

        Notes:
            Sits where `si_status` sits on Linux, the two being
            different members of one union there, and past the
            faulting address on Darwin, where they are not.

            Four bytes of the eight the union occupies: a number too
            big for an `Int32` is truncated here and whole in `si_ptr`,
            which is the same eight bytes read the other way.
        """
        return Int32(self._u32(SIGINFO_VALUE_OFFSET))

    def si_ptr(self) -> c_ptr[UInt8]:
        """What was sent along with the signal, read as the address it
        may be: the `sival_ptr` half of the `sigval` union.

        Returns:
            The eight bytes `si_value` takes four of, as a pointer.

        Notes:
            `sigqueue` takes one eight-byte value and the sender means
            either a number or an address by it; a number that fits in
            `Int32` comes back from here with its high half zero, and
            an address is whole. Nothing checks which was meant, and
            nothing here can: the union is eight bytes on both
            platforms and C does not say either.

            A pointer this package hands back as a pointer, for the
            reason the rest are: it is not this package's to read
            through, and `Int` of it is the number that was sent.
        """
        return c_ptr[UInt8](
            unsafe_from_address=Int(self._u64(SIGINFO_VALUE_OFFSET))
        )
