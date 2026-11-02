# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
"""`sys/sem.h`: the counters the kernel keeps, and the two calls that move them.

The third of the System V objects, and the one that puts the other two
to work. A message queue can be filled and emptied, a segment can be
written and read, and neither says a word about who is doing it and when
it is safe. A semaphore set is a small array of counters the kernel
holds, and `semop` is the one operation on them — it is atomic, it can
subtract more than is there only by waiting, and that is enough to build
a lock or a queue of waiting processes on top of memory that has none.

Each counter starts at zero and can only be moved by `semop`. There is
no call here to give one a starting value: `semctl` with `SETVAL` wants
a fourth argument this binding cannot give it (see below), so a set is
brought up by adding to it, which is what a semaphore used as a lock
needs anyway.

The fourth argument is why `semctl` is only half here. C declares it as
`...`, whose meaning depends on the command — a number for `SETVAL`, a
pointer to an array for `GETALL`, a pointer to a struct for `IPC_STAT`.
A binding has to choose one before the caller does, and choosing the
number would be wrong for the rest while being untestable on the one
platform whose variadic arguments Mojo cannot place. So the commands
that take no fourth argument are the ones bound: read the counters,
remove the set, ask who touched it. `SETVAL` and `GETALL` are not.
"""

from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr, c_size_t
from libc.sys.ipc import key_t

# The two commands whose fourth argument is never read, out of the seven
# `semctl` has. `GETVAL` is one of the numbers that is numbered
# differently on the two platforms — 12 here and 5 there — while
# `SEM_UNDO`, the flag `semop` can be given, is 010000 on both.
comptime GETVAL: Int32 = 5 if CompilationTarget.is_macos() else 12
comptime SEM_UNDO: Int32 = 4096


struct sembuf:
    """A C `struct sembuf`: one thing to do to one counter.

    Which counter, how much to move it by, and what to do if it cannot be
    moved. `sem_op` is a `short` and signed because the whole point is
    that it is either an add or a subtract: a negative number waits for
    the counter to be that large before taking it away.

    Six bytes on both platforms, and the same three fields in the same
    order, which is rare enough among these structs to be worth saying:
    nothing here has to be asked which platform it is on.
    """

    # Which of the set's counters, counting from zero.
    var sem_num: UInt16
    # How much to add — or, when it is negative, how much to take away.
    var sem_op: Int16
    # `SEM_UNDO` to put the move back if the process exits, and nothing
    # at all. `IPC_NOWAIT` is refused here rather than waited for.
    var sem_flg: Int16


def semget(key: key_t, count: c_int, flags: c_int) -> Int32:
    """Libc POSIX `semget` function.

    Description:
        Turns a key into the identifier of a set of counters, making the
        set if it is not there and the flags say to.

    Args:
        key: The key the set is named by, `IPC_PRIVATE` for one that
            nobody else can find.
        count: How many counters the set is to have, when it is being
            made. Every one of them starts at zero.
        flags: `IPC_CREAT` to make the set where it does not exist,
            `IPC_EXCL` to fail instead of returning one that does, and
            the permission bits to give a set being made.

    Returns:
        The identifier, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/semget.2.html).
        Fn signature: `int semget(key_t key, int nsems, int semflg)`.

        `count` is looked at only when the set is being made. Asking
        again for a key that is already there gets that set back with
        however many counters it has, and `semop` on a counter past the
        end of it is an error rather than a new counter — which is why a
        caller that did not make the set should agree with whoever did
        about how many there are.
    """
    return external_call["semget", Int32, key_t, c_int, c_int](
        key, count, flags
    )


def semop(semid: c_int, ops: c_ptr[sembuf], count: c_size_t) -> Int32:
    """Libc POSIX `semop` function.

    Description:
        Moves the counters a set of operations asks for, all of them or
        none of them, waiting where one of them cannot be done yet.

    Args:
        semid: The identifier `semget` handed back.
        ops: The operations, `count` of them, in the order they are to be
            tried. Each names a counter and how much to move it by.
        count: How many operations there are. One is the usual number;
            more than one is how a caller takes two counters at once
            without the risk of holding one and waiting for the other.

    Returns:
        0, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/semop.2.html).
        Fn signature: `int semop(int semid, struct sembuf *sops, size_t nsops)`.

        A negative `sem_op` larger than the counter waits — that is the
        whole mechanism, a process asleep until somebody adds enough.
        `IPC_NOWAIT` in `sem_flg` turns the wait into `EAGAIN` instead,
        which is the only way to ask a question here without the risk of
        never being answered.

        `SEM_UNDO` in `sem_flg` records the move so that it is put back
        when the process exits, however it exits. It is what keeps a lock
        held by a process that died from taking the lock with it, and it
        is the one thing here that survives the caller.
    """
    return external_call["semop", Int32, c_int, c_ptr[sembuf], c_size_t](
        semid, ops, count
    )


def semctl(semid: c_int, number: c_int, command: c_int) -> Int32:
    """Libc POSIX `semctl` function, for the commands with nothing to pass.

    Description:
        Asks a set about itself, or removes it. The value of one counter
        is what `GETVAL` answers with; there is no way here to set one.

    Args:
        semid: The identifier `semget` handed back.
        number: Which counter the command is about, counting from zero.
            `IPC_RMID` ignores it.
        command: `GETVAL` for the value of that counter, `IPC_RMID` to
            remove the whole set, and `IPC_STAT` for a struct this
            binding cannot supply room for.

    Returns:
        What the command answers — the counter's value for `GETVAL`, and
        0 for the rest — or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/semctl.2.html).
        Fn signature: `int semctl(int semid, int semnum, int cmd, ...)`.

        The `...` is the reason for the shape of this: it is a union
        whose member depends on the command, so a binding must pick one
        before the caller has said which. `SETVAL`, `GETALL`, `SETALL`
        and `IPC_SET` all want something here and are therefore not
        offered; a set is brought up by `semop` adding to it instead.

        `IPC_RMID` removes the set whether or not anything is waiting on
        it, and wakes whatever is. Nothing else in the header removes
        one, and a set left behind stays until the machine goes down.
    """
    return external_call["semctl", Int32, c_int, c_int, c_int](
        semid, number, command
    )
