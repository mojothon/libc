# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
"""The four calls of `<sys/shm.h>`: bytes the kernel keeps for you.

Shared memory is a message queue taken one step further down. Both are
objects the kernel holds under a key, both outlive the process that made
them, and both go on existing until somebody removes them by hand. The
difference is what is inside: a queue holds messages and hands them out
one at a time, while a segment holds bytes and nothing else. `shmget`
makes the bytes, `shmat` maps them into this process, and after that
there are no calls at all — the memory is read and written as memory.

Which is the whole of the appeal and the whole of the difficulty. Two
processes that attach the same segment are looking at the same bytes, so
nothing is copied on the way in or out, and nothing tells either of them
when the other has finished writing. There is no lock here: a segment
is a place to put data, not a way to agree about it.

The calls are the same four on both platforms, and the identifier works
the way a queue's does — `shmget` turns a key into a number, and the
number is what everything else uses. That one difference matters at the
end: `IPC_RMID` marks a segment for removal, and while it stops new
attachments it does not take the memory away from anybody already
attached. It stays mapped until the last `shmdt`.
"""

from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_size_t
from libc.sys.ipc import key_t

# What an attachment can be asked for. Both are the same number on the
# two platforms, which is worth saying because so little in System V IPC
# is: `SHM_RDONLY` is 010000 and `SHM_RND` 020000 on both.
comptime SHM_RDONLY: Int32 = 4096
comptime SHM_RND: Int32 = 8192


struct shmid_ds:
    """A C `struct shmid_ds`: what a segment says about itself.

    glibc's is 112 bytes and Darwin's is a different set of members in a
    different order, so this holds 128 and the callers pass it by
    pointer. Nothing here reads a member: the sizes and the times and the
    owner in it are of an arrangement the kernel is keeping, and a
    binding that exposed them at offsets would be exposing one platform's
    layout as though it were both.

    Only `shmctl` with `IPC_STAT` writes into it and only `IPC_SET` reads
    from it, so a caller that is only removing a segment hands null and
    never needs an object at all.
    """

    # Held in 64-bit words rather than bytes so that this lands where C
    # wants it: a block of single bytes asks for one-byte alignment, and
    # the struct is eight-aligned on both platforms.
    var _opaque: Array[UInt64, 16]

    def __init__(out self):
        """Zeroes the object, which is what no segment looks like."""
        self._opaque = Array[UInt64, 16](fill=0)


def shmget(key: key_t, size: c_size_t, flags: c_int) -> Int32:
    """Libc POSIX `shmget` function.

    Description:
        Turns a key into the identifier of a segment, making the segment
        if it is not there and the flags say to.

    Args:
        key: The key the segment is named by, `IPC_PRIVATE` for one that
            nobody else can find.
        size: How many bytes the segment is to be, when it is being made.
            A size is rounded up to a whole page, so asking for one byte
            takes four thousand and ninety-six.
        flags: `IPC_CREAT` to make the segment where it does not exist,
            `IPC_EXCL` to fail instead of returning one that does, and
            the permission bits to give a segment being made.

    Returns:
        The identifier, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/shmget.2.html).
        Fn signature: `int shmget(key_t key, size_t size, int shmflg)`.

        `size` is looked at only when the segment is being made. Asking
        again for a key that is already there gets that segment back
        whatever was asked for this time, and the size to use is the one
        the segment was made with rather than the one in the call — which
        is a way to write past the end of it, so a caller that did not
        make the segment should ask what it is with `shmctl` first, or
        trust the size to whoever did.

        A size of zero is an `EINVAL`, not an empty segment.
    """
    return external_call["shmget", Int32, key_t, c_size_t, c_int](
        key, size, flags
    )


def shmat(shmid: c_int, address: c_ptr[UInt8], flags: c_int) -> c_ptr[UInt8]:
    """Libc POSIX `shmat` function.

    Description:
        Maps a segment into this process's address space and hands back
        the address it landed at.

    Args:
        shmid: The identifier `shmget` handed back.
        address: Where to put it, or null to let the kernel choose, which
            is what almost everything does.
        flags: `SHM_RDONLY` to map it read-only, and nothing at all to
            map it both ways.

    Returns:
        The address, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/shmat.2.html).
        Fn signature: `void *shmat(int shmid, const void *shmaddr, int shmflg)`.

        What comes back is a pointer into this process, not into the
        segment: two processes that attach the same segment get two
        addresses, and what is the same about them is the bytes behind
        them. That is why an address cannot be sent to another process
        and used — send the identifier instead, and let it attach.

        Attaching the same segment twice in one process is allowed, and
        is how a test can tell a segment from ordinary memory: what is
        written through one address is readable through the other.

        `SHM_RND` is what an address means when one is given: without it
        the address has to be one the segment can be mapped at exactly,
        and with it C rounds down to the segment's own boundary. Null
        asks for neither and is what almost everything passes.
    """
    return external_call["shmat", c_ptr[UInt8], c_int, c_ptr[UInt8], c_int](
        shmid, address, flags
    )


def shmdt(address: c_ptr[UInt8]) -> Int32:
    """Libc POSIX `shmdt` function.

    Description:
        Unmaps a segment from this process, which is the address that
        `shmat` handed back and not the identifier.

    Args:
        address: The address the segment was mapped at.

    Returns:
        0, or -1 with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/shmdt.2.html).
        Fn signature: `int shmdt(const void *shmaddr)`.

        This is not `free` and does not give anything back to the kernel:
        the bytes are still there, still the segment's, and another
        attach finds them as they were left. What ends is only this
        process's use of them, so nothing that was written is lost.

        Touching the address afterwards is a fault — the mapping is gone,
        and the pages behind it belong to the segment rather than to this
        process. A segment removed with `IPC_RMID` while still attached
        stays usable until this call, and disappears when the last
        attachment goes.
    """
    return external_call["shmdt", Int32, c_ptr[UInt8]](address)


def shmctl(shmid: c_int, command: c_int, buffer: c_ptr[shmid_ds]) -> Int32:
    """Libc POSIX `shmctl` function.

    Description:
        Asks a segment about itself, tells it something, or marks it for
        removal.

    Args:
        shmid: The identifier `shmget` handed back.
        command: `IPC_STAT` to fill `buffer` in, `IPC_SET` to take the
            owner and the permissions from it, or `IPC_RMID` to remove
            the segment.
        buffer: The `shmid_ds` to fill in or read from, or null when the
            command is `IPC_RMID` and there is nothing to say.

    Returns:
        0 where the command was carried out, or -1 with `errno` saying
        why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/shmctl.2.html).
        Fn signature: `int shmctl(int shmid, int cmd, struct shmid_ds *buf)`.

        `IPC_RMID` is not immediate for anybody still attached. It stops
        the segment being found or attached again, and the memory goes
        when the last process that was already attached calls `shmdt`.
        A program that removes a segment and then exits without
        detaching leaves the kernel to do it, which it does — but a
        segment that is never removed at all stays until the machine goes
        down, exactly as a queue does.

        `IPC_SET` honours the owner and the permission bits and nothing
        else; the rest of the struct is ignored whatever is written into
        it.
    """
    return external_call["shmctl", Int32, c_int, c_int, c_ptr[shmid_ds]](
        shmid, command, buffer
    )
