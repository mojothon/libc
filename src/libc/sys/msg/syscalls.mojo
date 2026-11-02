# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
"""The four calls of `<sys/msg.h>`: a queue of typed messages.

A message queue is a numbered object the kernel keeps, holding a list of
messages that any process holding the number can add to and take from.
Each message is a type and a body, the type being a `long` that goes
first in the buffer, and a reader can ask for the first message of a
given type rather than the first message outright. That one feature is
what a pipe cannot do, and it is the reason the type is in the message
rather than in the call.

The queue is found by a `key_t` and then by a number: `msgget` turns the
key into an identifier, and everything after that uses the identifier.
An identifier is not a descriptor — it is not inherited by a child across
`exec`, it is not a file, and it outlives the process that made it until
somebody removes it with `msgctl` and `IPC_RMID`. A program that forgets
that last call leaves the queue behind for as long as the machine is up.
"""

from std.ffi import external_call

from libc.constant import c_int, c_long, c_ptr, c_size_t, c_ssize_t
from libc.sys.ipc import key_t

# 010000 on both platforms, and the only one of the reader's flags that
# both of them have: what Linux calls `MSG_EXCEPT` Darwin has no number
# for, so there is nothing here to bind it to.
comptime MSG_NOERROR: Int32 = 4096


struct msqid_ds:
    """A C `struct msqid_ds`: what a queue says about itself.

    glibc's is 120 bytes and Darwin's is a different set of members in a
    different order, so this holds 128 and the callers pass it by
    pointer. Nothing here reads a member: the numbers in it are counts
    and times of an arrangement the kernel is keeping, and a binding that
    exposed them at offsets would be exposing one platform's layout as
    though it were both.

    Only `msgctl` with `IPC_STAT` writes into it and only `IPC_SET` reads
    from it, so a caller that is only removing a queue hands null and
    never needs an object at all.
    """

    # Held in 64-bit words rather than bytes so that this lands where C
    # wants it: a block of single bytes asks for one-byte alignment, and
    # the struct is eight-aligned on both platforms.
    var _opaque: Array[UInt64, 16]

    def __init__(out self):
        """Zeroes the object, which is what no queue looks like."""
        self._opaque = Array[UInt64, 16](fill=0)


def msgget(key: key_t, flags: c_int) -> Int32:
    """Libc POSIX `msgget` function.

    Description:
        Turns a key into the identifier of a queue, making the queue if
        it is not there and the flags say to.

    Args:
        key: The key the queue is named by, `IPC_PRIVATE` for one that
            nobody else can find.
        flags: `IPC_CREAT` to make the queue where it does not exist,
            `IPC_EXCL` to fail instead of returning one that does, and
            the permission bits to give a queue being made.

    Returns:
        The identifier, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/msgget.2.html).
        Fn signature: `int msgget(key_t key, int msgflg)`.

        `IPC_PRIVATE` is not a flag and cannot be combined with anything:
        it is the key zero, and a key of zero always means a queue of its
        own. The identifier it hands back is the only way to that queue,
        so it has to be told to whoever else is to use it.

        `IPC_EXCL` without `IPC_CREAT` does nothing. Asking for both is
        the way to make a queue and be sure it was not already there: the
        call then fails with `EEXIST` rather than returning somebody
        else's queue.
    """
    return external_call["msgget", Int32, key_t, c_int](key, flags)


def msgsnd(
    msqid: c_int, message: c_ptr[UInt8], size: c_size_t, flags: c_int
) -> Int32:
    """Libc POSIX `msgsnd` function.

    Description:
        Puts a message on the end of a queue, waiting if the queue is
        full.

    Args:
        msqid: The identifier `msgget` handed back.
        message: The message: a `long` type followed by the body, as
            bytes with the type at offset 0.
        size: How many bytes the body is, not counting the type.
        flags: `IPC_NOWAIT` to fail with `EAGAIN` rather than wait for
            room, and nothing at all to wait.

    Returns:
        0 where the message was put on, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/msgsnd.2.html).
        Fn signature: `int msgsnd(int msqid, const void *msgp, size_t msgsz, int msgflg)`.

        The type is not optional and has to be positive: it is what a
        reader asks for, and zero or a negative number is a message
        nobody can ask for. It is a `long`, which is eight bytes on both
        platforms here, so the body starts at offset 8.

        The buffer is read for the type and `size` bytes after it, and
        not one byte more. What is past that is not looked at, which is
        why a struct of type plus text can be handed over as it stands.
    """
    return external_call["msgsnd", Int32, c_int, c_ptr[UInt8], c_size_t, c_int](
        msqid, message, size, flags
    )


def msgrcv(
    msqid: c_int,
    message: c_ptr[UInt8],
    size: c_size_t,
    kind: c_long,
    flags: c_int,
) -> c_ssize_t:
    """Libc POSIX `msgrcv` function.

    Description:
        Takes a message off a queue, the oldest one of the type asked
        for, and copies it out as the type followed by the body.

    Args:
        msqid: The identifier `msgget` handed back.
        message: Where to put the message, the type going at offset 0.
            It has to have room for the type and `size` bytes after it.
        size: The most body bytes that will be taken; a longer message
            is an error rather than being cut short.
        kind: Which message to take: 0 for the oldest whatever its type,
            a positive number for the oldest of that type, and a
            negative number for the oldest of the lowest type at or below
            its size.
        flags: `IPC_NOWAIT` to fail rather than wait, and `MSG_NOERROR`
            to cut a too-long message short instead of failing.

    Returns:
        How many body bytes were copied out, not counting the type, or
        -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/msgrcv.2.html).
        Fn signature: `ssize_t msgrcv(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg)`.

        The type is written back over whatever was in the front of the
        buffer, so a caller that wants the body at a known place should
        still leave the first eight bytes alone.

        A negative `kind` is not a type. It is a ceiling: take the oldest
        message whose type is at or below the absolute value, lowest type
        first. That is how a reader with several kinds of work and one
        queue can serve the most important kind first.
    """
    return external_call[
        "msgrcv", c_ssize_t, c_int, c_ptr[UInt8], c_size_t, c_long, c_int
    ](msqid, message, size, kind, flags)


def msgctl(msqid: c_int, command: c_int, buffer: c_ptr[msqid_ds]) -> Int32:
    """Libc POSIX `msgctl` function.

    Description:
        Asks a queue about itself, tells it something, or removes it.

    Args:
        msqid: The identifier `msgget` handed back.
        command: `IPC_STAT` to fill `buffer` in, `IPC_SET` to take the
            permissions and the byte limit from it, or `IPC_RMID` to
            remove the queue.
        buffer: The `msqid_ds` to fill in or read from, or null when the
            command is `IPC_RMID` and there is nothing to say.

    Returns:
        0 where the command was carried out, or -1 with `errno` saying
        why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/msgctl.2.html).
        Fn signature: `int msgctl(int msqid, int cmd, struct msqid_ds *buf)`.

        `IPC_RMID` wakes every process waiting on the queue: a reader
        waiting for a message is told `EIDRM` and a writer waiting for
        room the same. Nothing else in the header removes a queue, so a
        program that does not call this leaves one behind.

        `IPC_SET` honours three things only — the owner, the group and
        the permission bits — and the rest of the struct is ignored
        whatever is written into it.
    """
    return external_call["msgctl", Int32, c_int, c_int, c_ptr[msqid_ds]](
        msqid, command, buffer
    )
