# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <aio.h>.
#
# I/O that is handed over rather than waited for. Each of the six that
# does something takes a control block saying what it is and comes
# straight back; whether it has happened since is what `aio_error`
# answers, and how much of it happened is what `aio_return` says.
# Those two are the ones every program using the other six ends up
# needing, and the only two here that take a block back out rather
# than in.
#
# The block is not the same shape on the two. Not only is every member
# somewhere else — the file offset is at 128 in glibc's and at 8 in
# XNU's — the two do not agree on what the operations are numbered:
# `LIO_READ` is 0 here and 1 there. Both are asked of the platform
# below rather than written down here.
# -----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_int, c_ptr, c_ssize_t
from libc.time import timespec


# Where each member of C's `struct aiocb` sits, and how much room one
# takes: 168 bytes on glibc and 80 on XNU, so 176 here, which is more
# than either and eight-aligned as both are. The order is the part
# that differs, not only the places: XNU puts the offset second and
# the opcode last, glibc puts the opcode second and the offset next to
# last, and neither is a prefix of the other.
comptime AIOCB_SLOTS: Int = 22
comptime AIOCB_FILDES: Int = 0
comptime AIOCB_LIO_OPCODE: Int = 72 if CompilationTarget.is_macos() else 4
comptime AIOCB_REQPRIO: Int = 32 if CompilationTarget.is_macos() else 8
comptime AIOCB_BUF: Int = 16
comptime AIOCB_NBYTES: Int = 24
comptime AIOCB_OFFSET: Int = 8 if CompilationTarget.is_macos() else 128


# What the operations are called, and what `aio_cancel` answers with:
# three numbers on each, and not one of the six is the same on the
# two. glibc numbers the read first and XNU numbers it second, after
# the no-op, and where one says 0, 1, 2 the other says 1, 2, 4 for
# the answers `aio_cancel` gives.
comptime LIO_READ: c_int = 1 if CompilationTarget.is_macos() else 0
comptime LIO_WRITE: c_int = 2 if CompilationTarget.is_macos() else 1
comptime LIO_NOP: c_int = 0 if CompilationTarget.is_macos() else 2
comptime LIO_WAIT: c_int = 2 if CompilationTarget.is_macos() else 0
comptime LIO_NOWAIT: c_int = 1
comptime AIO_CANCELED: c_int = 2 if CompilationTarget.is_macos() else 0
comptime AIO_NOTCANCELED: c_int = 4 if CompilationTarget.is_macos() else 1
comptime AIO_ALLDONE: c_int = 1 if CompilationTarget.is_macos() else 2


struct Aiocb:
    """One asynchronous read or write, the whole of it: which file,
    where in it, where in memory, how much, and (for `lio_listio`)
    which of the three operations this one is.

    Kept as bytes and written and read by offset, because the members
    are in a different order on the two platforms and a caller wants
    the numbers, not the arrangement. `set_fildes`, `set_offset`,
    `set_buf` and `set_nbytes` are what a program using these calls
    reaches for; the rest are here so the block can be looked at
    afterwards.

    A block is given to one call and then left alone until that one
    is finished: the library keeps its own pointer to it, and moving
    it or giving it to a second call while the first is still going
    is not a thing either side promises to cope with.
    """

    # Eight-byte slots rather than bytes: C says this one is 8-aligned,
    # and an `Array[UInt8]` would take its alignment down to 1.
    var _slots: Array[UInt64, AIOCB_SLOTS]

    def __init__(out self):
        """Zeroes the whole block, which is what C leaves in one that
        has just been declared.
        """
        self._slots = Array[UInt64, AIOCB_SLOTS](fill=0)

    def _byte(self, off: Int) -> UInt8:
        """The single byte at `off`, whichever slot holds it."""
        return UInt8((self._slots[off // 8] >> UInt64((off % 8) * 8)) & 0xFF)

    def _u32(self, off: Int) -> UInt32:
        """Four little-endian bytes at `off`."""
        var acc = UInt32(0)
        for i in range(4):
            acc |= UInt32(self._byte(off + i)) << UInt32(i * 8)
        return acc

    def _u64(self, off: Int) -> UInt64:
        """Eight little-endian bytes at `off`."""
        var acc = UInt64(0)
        for i in range(8):
            acc |= UInt64(self._byte(off + i)) << UInt64(i * 8)
        return acc

    def _set_byte(mut self, off: Int, to: UInt8):
        """Puts the single byte at `off`, leaving the rest of its slot."""
        var slot = off // 8
        var shift = UInt64((off % 8) * 8)
        var mask = ~(UInt64(0xFF) << shift)
        self._slots[slot] = (self._slots[slot] & mask) | (UInt64(to) << shift)

    def _set_u32(mut self, off: Int, to: UInt32):
        """Puts four little-endian bytes at `off`."""
        for i in range(4):
            self._set_byte(off + i, UInt8((to >> UInt32(i * 8)) & 0xFF))

    def _set_u64(mut self, off: Int, to: UInt64):
        """Puts eight little-endian bytes at `off`."""
        for i in range(8):
            self._set_byte(off + i, UInt8((to >> UInt64(i * 8)) & 0xFF))

    def fildes(self) -> Int32:
        """Which file the I/O is on."""
        return Int32(self._u32(AIOCB_FILDES))

    def set_fildes(mut self, fd: Int32):
        """Sets which file the I/O is on."""
        self._set_u32(AIOCB_FILDES, UInt32(fd))

    def offset(self) -> Int:
        """Where in the file it starts."""
        return Int(self._u64(AIOCB_OFFSET))

    def set_offset(mut self, off: Int):
        """Sets where in the file it starts, which is where the I/O
        goes whether or not anything has moved the file's own offset
        since.
        """
        self._set_u64(AIOCB_OFFSET, UInt64(off))

    def buf(self) -> c_ptr[UInt8]:
        """Where in memory it goes to, or comes from."""
        return c_ptr[UInt8](unsafe_from_address=Int(self._u64(AIOCB_BUF)))

    def set_buf(mut self, buf: c_ptr[UInt8]):
        """Sets where in memory it goes to, or comes from. The bytes
        are the caller's and have to outlast the I/O.
        """
        self._set_u64(AIOCB_BUF, UInt64(Int(buf)))

    def nbytes(self) -> Int:
        """How many bytes are to move."""
        return Int(self._u64(AIOCB_NBYTES))

    def set_nbytes(mut self, n: Int):
        """Sets how many bytes are to move."""
        self._set_u64(AIOCB_NBYTES, UInt64(n))

    def reqprio(self) -> Int32:
        """By how much this one's priority is lowered."""
        return Int32(self._u32(AIOCB_REQPRIO))

    def set_reqprio(mut self, prio: Int32):
        """Sets by how much this one's priority is lowered, which is
        subtracted from the priority the call would otherwise have.
        """
        self._set_u32(AIOCB_REQPRIO, UInt32(prio))

    def lio_opcode(self) -> Int32:
        """Which operation this block is, as `lio_listio` reads it."""
        return Int32(self._u32(AIOCB_LIO_OPCODE))

    def set_lio_opcode(mut self, op: Int32):
        """Sets which operation this block is, one of `LIO_READ`,
        `LIO_WRITE` or `LIO_NOP`.
        """
        self._set_u32(AIOCB_LIO_OPCODE, UInt32(op))


def aio_read(cb: c_ptr[Aiocb]) -> c_int:
    """C library <aio.h> function `aio_read`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_read.3.html

    Prototype:
        int aio_read(struct aiocb *aiocbp)

    Description:
        Hands over a read: `nbytes` from the file at `offset` into
        `buf`, and comes back at once, the read having been started
        rather than finished. Nothing of it may have happened by the
        time this returns, and how much has is what `aio_error` and
        `aio_return` are for.

        Where in the file is read from the block, not from the file's
        own offset, so the two do not disturb each other: a read here
        does not move where a later `read` starts, and a `read` does
        not move where this one starts.

    Args:
        cb: The block, with the file, the offset, the buffer and how
            much, and those four filled in before the call.

    Returns:
        0 once the read is queued, or -1 with `errno` set when it is
        not.

    Notes:
        What is queued rather than what happened: 0 says the read was
        taken, and a read that fails once it is under way says so
        through `aio_error` instead, which is where the error number
        for the I/O itself comes from.

        The buffer and the block both have to stay where they are and
        stay the caller's until the read has finished, which is what
        `aio_error` stops reporting as in progress.
    """
    return external_call["aio_read", c_int, c_ptr[Aiocb]](cb)


def aio_write(cb: c_ptr[Aiocb]) -> c_int:
    """C library <aio.h> function `aio_write`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_write.3.html

    Prototype:
        int aio_write(struct aiocb *aiocbp)

    Description:
        Hands over a write: `nbytes` from `buf` into the file at
        `offset`, and comes back at once. Where in the file is taken
        from the block, so this does not move the file's own offset
        and is not moved by it.

    Args:
        cb: The block, with the file, the offset, the buffer and how
            much.

    Returns:
        0 once the write is queued, or -1 with `errno` set.

    Notes:
        Whether it has reached the file is not what 0 says — that is
        `aio_error`, and past that `aio_fsync`, which is the call for
        asking that it be made to reach the file rather than merely
        be on its way there.

        Nothing here waits for anything, and nothing here says the
        bytes are on the disk: the buffer has to stay put until the
        write is finished, and `fsync` is still the way to ask about
        the disk.
    """
    return external_call["aio_write", c_int, c_ptr[Aiocb]](cb)


def aio_fsync(op: c_int, cb: c_ptr[Aiocb]) -> c_int:
    """C library <aio.h> function `aio_fsync`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_fsync.3.html

    Prototype:
        int aio_fsync(int op, struct aiocb *aiocbp)

    Description:
        Hands over the `fsync` half of the job: everything already
        written to the file from this descriptor, and everything in
        the block that is still to be written, is asked to be made
        to reach the file before this one is said to be finished.
        Like the other five, it comes back at once.

    Args:
        op: What is to be made to reach the file: the data alone, or
            the data and what the file says about it besides, which
            is `O_DSYNC` and `O_SYNC` as `fcntl` spells them.
        cb: The block, which says which file, and which is then asked
            about with `aio_error` like any other.

    Returns:
        0 once it is queued, or -1 with `errno` set.

    Notes:
        Asynchronous only in the asking: nothing here says the file
        is on the disk when this returns, and `aio_error` on the
        block is what says so afterwards.

        A file that has never been written to has nothing to
        synchronise, and the answer to asking is not an error.
    """
    return external_call["aio_fsync", c_int, c_int, c_ptr[Aiocb]](op, cb)


def aio_error(cb: c_ptr[Aiocb]) -> c_int:
    """C library <aio.h> function `aio_error`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_error.3.html

    Prototype:
        int aio_error(const struct aiocb *aiocbp)

    Description:
        Where the I/O stands: 0 for finished, `EINPROGRESS` for not
        yet, and the error number itself for one that was taken and
        then failed, which is where the error number for the I/O
        comes from — the -1 the other six answer with is about the
        queueing, not about the reading or writing.

    Args:
        cb: The block the I/O was handed over with.

    Returns:
        0, or `EINPROGRESS`, or the error number, or -1 when the
        block is not one anything was handed.

    Notes:
        The one call here that has to be made after every other one:
        `aio_return` is only allowed once this has said 0, and a
        program that does not ask this first has no way of knowing
        whether what it reads back means anything.

        Asking again after it has said 0 is asking about a block the
        library has finished with, which is -1 rather than an answer.
    """
    return external_call["aio_error", c_int, c_ptr[Aiocb]](cb)


def aio_return(cb: c_ptr[Aiocb]) -> c_ssize_t:
    """C library <aio.h> function `aio_return`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_return.3.html

    Prototype:
        ssize_t aio_return(struct aiocb *aiocbp)

    Description:
        How much moved: the number of bytes the read read or the
        write wrote, which is what `read` and `write` would have
        handed back had they been waited for.

    Args:
        cb: The block the I/O was handed over with.

    Returns:
        The count, or -1 with `errno` set when the block is not
        finished or was never given anything.

    Notes:
        Once only: the library forgets the block when this is called,
        so a second call is -1 and the count has to be kept by
        whoever asked. Asking before `aio_error` has said 0 is
        asking about an I/O that has not finished, and the answer
        is -1 for that as well.

        A short count is not a failure — fewer bytes than asked for
        is what happens at the end of a file, and `aio_error` is
        what says whether anything went wrong.
    """
    return external_call["aio_return", c_ssize_t, c_ptr[Aiocb]](cb)


def aio_cancel(fd: c_int, cb: c_ptr[Aiocb]) -> c_int:
    """C library <aio.h> function `aio_cancel`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_cancel.3.html

    Prototype:
        int aio_cancel(int fd, struct aiocb *aiocbp)

    Description:
        Asks for one I/O, or for every I/O on a file, not to be
        finished: the block given, or every block on the file when
        the block is null. Whatever has already reached the file
        stays there, and how much that was is what `aio_return`
        says afterwards.

    Args:
        fd: The file the I/O is on.
        cb: The block to ask about, or null for all of them on `fd`.

    Returns:
        `AIO_CANCELED` for one that was stopped, `AIO_ALLDONE` for
        one that had finished before this was asked,
        `AIO_NOTCANCELED` for one that went on, or -1 with `errno`
        set when neither the file nor the block is one anything was
        handed.

    Notes:
        A request, not a command: `AIO_NOTCANCELED` is the answer
        for an I/O that was already too far along to stop, and a
        program that needs it stopped has to keep asking, or wait
        with `aio_suspend`.

        Cancelling does not undo what had been done, and the block
        is still finished off the same way — `aio_error` and then
        `aio_return`, which says how much of it had happened.
    """
    return external_call["aio_cancel", c_int, c_int, c_ptr[Aiocb]](fd, cb)


def aio_suspend(
    list: c_ptr[c_ptr[Aiocb]], nent: c_int, timeout: c_ptr[timespec]
) -> c_int:
    """C library <aio.h> function `aio_suspend`.

    Reference:
        https://man7.org/linux/man-pages/man3/aio_suspend.3.html

    Prototype:
        int aio_suspend(const struct aiocb *const list[], int nent,
            const struct timespec *timeout)

    Description:
        Waits for I/O: it comes back when at least one of the blocks
        in the list has finished, which is what a program that has
        handed work over and then needs it does instead of asking
        `aio_error` again and again.

    Args:
        list: The blocks to wait on, an array of pointers to them.
        nent: How many of them.
        timeout: How long to wait, or null to wait until one of them
            finishes however long that takes.

    Returns:
        0 when one of them has finished, or -1 with `errno` set,
        `EAGAIN` being what a timeout that ran out answers with.

    Notes:
        "At least one" and not "all": it says nothing about which,
        and a program waiting on four blocks has to ask `aio_error`
        about each to find out. Twenty blocks is the most the
        standard lets a program have going at once on either
        platform.

        A block that had already finished before this was called is
        a block this comes straight back for, and one that has had
        `aio_return` called on it is not one to wait on at all.
    """
    return external_call[
        "aio_suspend", c_int, c_ptr[c_ptr[Aiocb]], c_int, c_ptr[timespec]
    ](list, nent, timeout)


def lio_listio(
    mode: c_int, list: c_ptr[c_ptr[Aiocb]], nent: c_int, sig: c_ptr[UInt8]
) -> c_int:
    """C library <aio.h> function `lio_listio`.

    Reference:
        https://man7.org/linux/man-pages/man3/lio_listio.3.html

    Prototype:
        int lio_listio(int mode, struct aiocb *const list[], int nent,
            struct sigevent *sevp)

    Description:
        Hands over a whole list of reads and writes at once, each
        block saying which of the three it is by its own
        `set_lio_opcode`. One call for the lot rather than one per
        block, which is the point of it, and what comes back is
        about the handing over and not about any of them.

    Args:
        mode: `LIO_WAIT` to wait for the whole list before coming
            back, or `LIO_NOWAIT` to come back at once, which is the
            other reason to want this call.
        list: The blocks, an array of pointers to them, each with
            its operation, its file, its offset, its buffer and how
            much.
        nent: How many blocks are in the list, or 0 to hand over
            none of them and be told when the last one taken from
            the list has finished.
        sig: How the caller is to be told, or null for not at all,
            which is what this one is given here: a notification the
            caller cannot be handed is not one to ask for.

    Returns:
        0 when every block in the list was taken, or -1 with
        `errno` set when the list itself was refused.

    Notes:
        Per block and not per list: whether each one happened is
        `aio_error` on that block, and how much of it happened is
        `aio_return` on that block, the same as if it had been
        handed over on its own.

        A block whose operation is `LIO_NOP` is one that is skipped,
        which is how a list is made shorter without being rebuilt.
        With `LIO_WAIT` this waits for all of them, and the count it
        came back with says nothing about any of them having worked.
    """
    return external_call[
        "lio_listio",
        c_int,
        c_int,
        c_ptr[c_ptr[Aiocb]],
        c_int,
        c_ptr[UInt8],
    ](mode, list, nent, sig)
