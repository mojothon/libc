# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <semaphore.h>.
#
# Half of this header is here and half of it is left out on purpose, and
# the reason is not taste: the two platforms disagree about which half
# exists. A named semaphore -- one opened by a name, as `sem_open` does --
# is implemented on both. An unnamed one is not: Darwin declares
# `sem_init`, `sem_destroy` and `sem_getvalue`, marks them deprecated, and
# answers `sem_init` with -1 and `errno` set to `ENOSYS`, because Apple
# never implemented unnamed POSIX semaphores at all; the struct it puts
# behind `sem_t` is an `int`, and the semaphore itself only ever lives in
# the kernel where a name can find it. `sem_timedwait` Darwin does not
# even declare, and `sem_clockwait` is glibc's alone.
#
# So what is bound here is the half that keeps its promise on both, which
# is also the half that a program able to give the semaphore a name wants:
# a counter that several processes can share, opened by name, counted down
# by wait, counted up by post.
# -----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_uint


struct Semaphore:
    """An opaque C `sem_t`, which is to say the thing a `sem_t *` points
    at.

    Empty on purpose, and only ever handled by address. What is behind it
    is not the same arrangement on the two platforms: glibc's `sem_t` is
    thirty-two bytes of a counter and a futex word that the process can
    read and write itself, while Darwin's is four bytes of an `int` that
    names a semaphore the kernel holds. Neither is anything this package
    has business walking through, and nothing here allocates one — the
    only way to get a semaphore is `sem_open`, which hands back the
    address of one libc already owns — so the difference in size never
    has to be written down anywhere.
    """

    pass


def sem_open(
    name: c_ptr[UInt8], oflag: c_int, mode: c_uint, value: c_uint
) -> c_ptr[Semaphore]:
    """C library <semaphore.h> function `sem_open`.

    Reference:
        https://man7.org/linux/man-pages/man3/sem_open.3.html

    Description:
        Opens a semaphore by name, making it first where it is not there
        yet. The name is not a path, though it looks like one: it has to
        begin with a slash and hold no other slash, and where the object
        that answers to it actually lives is the library's business —
        glibc keeps a file per name under `/dev/shm`, XNU asks the kernel
        for a slot — so two programs on one machine, or two processes of
        one program, that ask for the same name get the same counter.

        That sharing is the whole point of the name: a semaphore opened
        this way is visible to every process that can spell the name, not
        just to the one that made it, and it stays visible — and stays
        counted — until `sem_unlink` takes the name away.

    Args:
        name: The name, beginning with a slash and with no other slash in
            it, NUL terminated.
        oflag: `O_CREAT` to make the semaphore where the name is not in
            use yet, `O_EXCL` with it to refuse rather than open one that
            is, and `O_RDWR`, which POSIX asks for and neither platform
            looks at.
        mode: The permissions of the thing the name is to be made as,
            which is read only where `O_CREAT` says something is to be
            made. C's prototype is variadic — this is the third argument
            of it — because a call without `O_CREAT` has no use for it.
        value: The count the semaphore starts at, read only where
            `O_CREAT` says something is to be made, and ignored where the
            semaphore was already there: an existing count is never
            reset by opening it again.

    Returns:
        The address of a semaphore libc owns, or `SEM_FAILED`, with
        `errno` saying why.

    Notes:
        `SEM_FAILED` is two different addresses, which is the one trap in
        this header worth knowing before it is stepped in: the two
        headers define it differently. glibc's is the null pointer —
        `((sem_t *) 0)` — and Darwin's is the all-ones one,
        `((sem_t *) -1)`, which is what POSIX writes down and glibc does
        not follow. So the check a portable caller writes is both of
        them, `is_null(sem) or Int(UInt(sem)) == -1`, and a caller who
        checks only for null reads Darwin's failure as an address.

        Two calls that return, one after the other, without an
        intervening `sem_unlink` and with the same name, are two handles
        on one semaphore and one count: what one takes, the other finds
        gone. They are not promised to be the same address, and libc is
        free to keep track of how many handles are open and hand the same
        one back or not.

        Nothing is thrown away by closing: a named semaphore outlives
        every process that opened it, count and all, until `sem_unlink`
        is called — which is a reason to unlink one that will not be
        wanted again, since a name left behind is a name the next run
        finds already in use.
    """
    return external_call[
        "sem_open", c_ptr[Semaphore], c_ptr[UInt8], c_int, c_uint, c_uint
    ](name, oflag, mode, value)


def sem_close(semaphore: c_ptr[Semaphore]) -> c_int:
    """C library <semaphore.h> function `sem_close`.

    Reference:
        https://man7.org/linux/man-pages/man3/sem_close.3.html

    Description:
        Gives one handle on a semaphore back, and with it the descriptor
        or the mapping the open took. The semaphore itself is not
        touched: its count stays where it was, and every other handle on
        it — in this process or in another one — goes on counting.

    Args:
        semaphore: A handle from `sem_open`.

    Returns:
        Zero where the handle was given back, or -1 with `errno` set to
        `EINVAL` where what was handed over was not one.

    Notes:
        The handle is not usable afterwards, and nothing here says
        whether it was: a count that went down before the close went down
        for good, which is why the close is not a way to undo a wait.

        This is not `sem_unlink`, and a program that means "throw the
        semaphore away" has to call both — unlink for the name, close for
        the handle — and in that order if it means to leave nothing
        behind.
    """
    return external_call["sem_close", c_int, c_ptr[Semaphore]](semaphore)


def sem_unlink(name: c_ptr[UInt8]) -> c_int:
    """C library <semaphore.h> function `sem_unlink`.

    Reference:
        https://man7.org/linux/man-pages/man3/sem_unlink.3.html

    Description:
        Takes a name away, so that no `sem_open` after this one can find
        what it was the name of. Nothing visible happens at once: the
        semaphore stays alive, count and all, for as long as any handle
        on it is open, and a program that has one goes on counting with
        it after the name is gone.

        What it buys is the name, and that is worth buying: the name is
        the whole of what makes the semaphore findable, so a name left in
        place outlives the process that made it — a run that dies before
        it unlinks leaves a name behind for the next run to trip over,
        and the next run's `O_CREAT | O_EXCL` is refused by a semaphore
        nobody is holding.

    Args:
        name: The name to take away, spelled as it was to `sem_open`,
            NUL terminated.

    Returns:
        Zero where the name was taken away, or -1 with `errno` set to
        `ENOENT` where no semaphore answers to it.

    Notes:
        Unlinking a name that a handle is still open on is not an error
        and not a leak: the semaphore is freed with the last `sem_close`.
    """
    return external_call["sem_unlink", c_int, c_ptr[UInt8]](name)


def sem_wait(semaphore: c_ptr[Semaphore]) -> c_int:
    """C library <semaphore.h> function `sem_wait`.

    Reference:
        https://man7.org/linux/man-pages/man3/sem_wait.3.html

    Description:
        Takes one from the count, and waits where there is none to take:
        the call does not return until some other process or thread has
        posted, or until a signal arrives to end the wait.

        The count never goes below zero, and a waiter is not a reader of
        it: what it means to be waiting is the library's to arrange, and
        fourteen processes waiting on a count of zero are woken one post
        at a time.

    Args:
        semaphore: A handle from `sem_open`.

    Returns:
        Zero where one was taken, or -1 with `errno` set to `EINTR` where
        a signal ended the wait before a post did, or to `EINVAL` where
        what was handed over was not a semaphore.

    Notes:
        `EINTR` is the answer that matters here: the count was not
        touched, and the call has to be made again by whoever wants the
        one it did not get. A loop around this that treats every -1 as a
        failure loses posts that were never taken.

        Blocking is the point rather than an accident, so this is the one
        call in this module a single-threaded program should not make on
        a count it knows to be zero: there is nothing in that program to
        post.
    """
    return external_call["sem_wait", c_int, c_ptr[Semaphore]](semaphore)


def sem_trywait(semaphore: c_ptr[Semaphore]) -> c_int:
    """C library <semaphore.h> function `sem_trywait`.

    Reference:
        https://man7.org/linux/man-pages/man3/sem_trywait.3.html

    Description:
        `sem_wait` with no waiting in it: takes one from the count where
        there is one, and says so where there is not.

    Args:
        semaphore: A handle from `sem_open`.

    Returns:
        Zero where one was taken, or -1 with `errno` set to `EAGAIN`
        where the count was zero — the failure that means "nothing to
        take right now" rather than "broken" — or to `EINVAL` where what
        was handed over was not a semaphore.

    Notes:
        `EAGAIN` is what a program polls on: with it, a count of zero is
        an answer and not an error, and the check is a `sem_trywait` that
        returns -1 rather than a read of the count, which no call in this
        header offers on both platforms.
    """
    return external_call["sem_trywait", c_int, c_ptr[Semaphore]](semaphore)


def sem_post(semaphore: c_ptr[Semaphore]) -> c_int:
    """C library <semaphore.h> function `sem_post`.

    Reference:
        https://man7.org/linux/man-pages/man3/sem_post.3.html

    Description:
        Puts one back into the count, waking a waiter where there is one.
        It is the only call that raises the count, and unlike `sem_wait`
        it never blocks: what a post does is done by the time it returns,
        which is what makes it safe to call from a signal handler.

    Args:
        semaphore: A handle from `sem_open`.

    Returns:
        Zero where one was put back, or -1 with `errno` set to
        `EOVERFLOW` where the count was already at its largest
        representable value, or to `EINVAL` where what was handed over
        was not a semaphore.

    Notes:
        POSIX makes this async-signal-safe, and it is one of very few
        calls in this package that are: a handler that posts is a handler
        that can wake a thread, which is how a wait gets out of the way
        of a signal that arrived.

        `EOVERFLOW` is not a number any program should be able to reach
        by accident: it takes a count that was never taken from.
    """
    return external_call["sem_post", c_int, c_ptr[Semaphore]](semaphore)
