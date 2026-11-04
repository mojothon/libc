"""Tests for the `libc.aio` bindings.

`aio` hands a read or a write over to the library and comes back at
once, leaving a control block behind to be asked how it went. Two of
the eight calls are about the block rather than the I/O, and every
test here leans on both halves agreeing: `aio_error` says it
finished, `aio_return` says how much moved, and the file itself says
what moved. A block whose fields were written at the wrong offset
cannot make all three agree, which is the point — the members sit
somewhere different on each platform, and nothing else here would
notice.

Nothing is asserted about how long any of it takes. Whether an I/O
has finished is asked for, up to a number of times, and if it never
does the test says so rather than waiting.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.aio import (
    AIO_ALLDONE,
    AIO_CANCELED,
    AIO_NOTCANCELED,
    Aiocb,
    LIO_NOP,
    LIO_NOWAIT,
    LIO_READ,
    aio_cancel,
    aio_error,
    aio_fsync,
    aio_read,
    aio_return,
    aio_suspend,
    aio_write,
    lio_listio,
)
from libc.constant import EINPROGRESS, SEEK_SET, c_ptr
from libc.fcntl import O_SYNC
from libc.file import FILE, fclose
from libc.stdio import fileno, tmpfile
from libc.time import nanosleep, timespec
from libc.unistd import lseek, read, write
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def _a_file_holding(text: String) raises -> c_ptr[FILE]:
    """A temporary file with that in it, flushed out of the stream and
    into the file, ready to be read by descriptor.
    """
    var f = tmpfile()
    var fd = fileno(f)
    var msg = string_to_char_ptr(text)
    var n = text.byte_length()
    assert_equal(Int(write(fd, msg, UInt32(n))), n, "the file is written")
    assert_equal(Int(lseek(fd, 0, SEEK_SET)), 0, "and it starts at the start")
    msg.unsafe_free()
    return f


def _wait_for(cb: c_ptr[Aiocb]) raises -> Int:
    """Asks `aio_error` until it stops saying the I/O is under way,
    and hands back what it said instead.

    Bounded, because a test that waits for something that is never
    going to happen is a test that never finishes: a thousand asks
    is more than any I/O here needs, and the answer then is whatever
    it was always going to be.
    """
    var pause = unsafe_alloc[timespec](1)
    pause[] = timespec(0, 1_000_000)
    for _ in range(500):
        var state = Int(aio_error(cb))
        if state != Int(EINPROGRESS):
            return state
        _ = nanosleep(pause, null_ptr[timespec]())
    return Int(EINPROGRESS)


def test_a_read_that_finishes_and_says_so() raises:
    """The whole round trip on one block: handed over, asked about,
    and then read back out of the buffer it was aimed at.

    Three things have to agree — that the I/O finished, that five
    bytes moved, and that those five bytes are the ones in the file —
    and the block is asked what it is holding besides, which is the
    only check the getters get.
    """
    var f = _a_file_holding("hello world")
    var fd = fileno(f)

    var buf = unsafe_alloc[UInt8](16)
    for i in range(16):
        buf.unsafe_offset(i)[] = 0

    var cb = unsafe_alloc[Aiocb](1)
    cb[] = Aiocb()
    cb[].set_fildes(fd)
    cb[].set_offset(0)
    cb[].set_buf(buf)
    cb[].set_nbytes(5)

    # What went in is what the block says it is holding.
    assert_equal(Int(cb[].fildes()), Int(fd), "the file it was given")
    assert_equal(cb[].offset(), 0, "the place in it")
    assert_equal(cb[].nbytes(), 5, "and how much")
    assert_equal(Int(cb[].buf()), Int(buf), "the buffer it was aimed at")

    assert_equal(Int(aio_read(cb)), 0, "the read is taken")
    assert_equal(_wait_for(cb), 0, "and finishes without an error")

    # `aio_suspend` on one that has finished comes back at once.
    var list = unsafe_alloc[c_ptr[Aiocb]](1)
    list.unsafe_offset(0)[] = cb
    assert_equal(
        Int(aio_suspend(list, 1, null_ptr[timespec]())),
        0,
        "aio_suspend says it is done",
    )

    assert_equal(Int(aio_return(cb)), 5, "five bytes moved")
    assert_equal(
        char_ptr_to_string(buf), "hello", "and they are the first five"
    )

    assert_equal(Int(fclose(f)), 0, "the file closes")


def test_a_write_the_file_itself_answers_for() raises:
    """A write handed over is a write the file has afterwards, which
    is the part worth asking: `aio_return` saying five bytes moved
    would say the same whether they went into the file or nowhere.

    The file's own offset is not what the block reads from, so the
    reading back here goes by `lseek` and `read` rather than by
    whatever the stream thinks.
    """
    var f = tmpfile()
    var fd = fileno(f)

    var cb = unsafe_alloc[Aiocb](1)
    cb[] = Aiocb()
    cb[].set_fildes(fd)
    cb[].set_offset(0)
    cb[].set_buf(string_to_char_ptr("world"))
    cb[].set_nbytes(5)

    assert_equal(Int(aio_write(cb)), 0, "the write is taken")
    assert_equal(_wait_for(cb), 0, "and finishes")
    assert_equal(Int(aio_return(cb)), 5, "five bytes moved")

    var back = unsafe_alloc[UInt8](16)
    for i in range(16):
        back.unsafe_offset(i)[] = 0
    assert_equal(Int(lseek(fd, 0, SEEK_SET)), 0, "back to the start")
    assert_equal(Int(read(fd, back, 5)), 5, "and the file has them")
    assert_equal(char_ptr_to_string(back), "world", "the file says 'world'")

    assert_equal(Int(fclose(f)), 0, "the file closes")


def test_lio_listio_takes_a_list_at_a_time() raises:
    """Two blocks in one call, one of them a no-op, and the read is
    the one that happens: which operation a block is, is written in
    the block, and `lio_listio` is the only call that reads it.

    The pair matters because `LIO_NOP` is 0 on one platform and 2 on
    the other, and `LIO_READ` the other way about — a block given
    the wrong number is a block that does the wrong thing, or a list
    that is refused.
    """
    var f = _a_file_holding("hello world")
    var fd = fileno(f)

    var buf = unsafe_alloc[UInt8](16)
    for i in range(16):
        buf.unsafe_offset(i)[] = 0

    var skipped = unsafe_alloc[Aiocb](1)
    skipped[] = Aiocb()
    skipped[].set_fildes(fd)
    skipped[].set_offset(0)
    skipped[].set_buf(buf)
    skipped[].set_nbytes(5)
    skipped[].set_lio_opcode(LIO_NOP)

    var wanted = unsafe_alloc[Aiocb](1)
    wanted[] = Aiocb()
    wanted[].set_fildes(fd)
    wanted[].set_offset(0)
    wanted[].set_buf(buf)
    wanted[].set_nbytes(5)
    wanted[].set_lio_opcode(LIO_READ)

    assert_equal(Int(skipped[].lio_opcode()), Int(LIO_NOP), "one is a no-op")
    assert_equal(Int(wanted[].lio_opcode()), Int(LIO_READ), "and one is a read")

    var list = unsafe_alloc[c_ptr[Aiocb]](2)
    list.unsafe_offset(0)[] = skipped
    list.unsafe_offset(1)[] = wanted
    assert_equal(
        Int(lio_listio(LIO_NOWAIT, list, 2, null_ptr[UInt8]())),
        0,
        "the list is taken",
    )

    assert_equal(_wait_for(wanted), 0, "the read in it finishes")
    assert_equal(Int(aio_return(wanted)), 5, "five bytes moved")
    assert_equal(
        char_ptr_to_string(buf), "hello", "and they are the first five"
    )

    assert_equal(Int(fclose(f)), 0, "the file closes")


def test_cancel_and_sync_are_answered_about() raises:
    """The two that are about asking rather than doing.

    `aio_cancel` is asked about a block that has already finished,
    and answers one of the three it is allowed to answer — all done,
    cancelled, or not cancelled — which one being the platform's to
    choose, and -1 the only answer that means the block was not one
    anything had been handed.

    `aio_fsync` is asked to make a write reach the file, and what is
    asserted is that it is answered at all and that the block it was
    given settles: whether a platform has anything to synchronise is
    not something a test on one machine can say about the other.
    """
    var f = tmpfile()
    var fd = fileno(f)

    var cb = unsafe_alloc[Aiocb](1)
    cb[] = Aiocb()
    cb[].set_fildes(fd)
    cb[].set_offset(0)
    cb[].set_buf(string_to_char_ptr("again"))
    cb[].set_nbytes(5)

    assert_equal(Int(aio_write(cb)), 0, "a write is taken")
    assert_equal(_wait_for(cb), 0, "and finishes")

    var answer = Int(aio_cancel(fd, cb))
    assert_true(
        answer == Int(AIO_ALLDONE)
        or answer == Int(AIO_CANCELED)
        or answer == Int(AIO_NOTCANCELED),
        "aio_cancel answers with one of the three, and not with -1",
    )

    var sync = unsafe_alloc[Aiocb](1)
    sync[] = Aiocb()
    sync[].set_fildes(fd)
    sync[].set_offset(0)
    # And it is the sync that is asked for, which is what the answer says.
    # `aio_cancel` -- the call next to it, with the same two arguments --
    # answers 2 about the block the write left behind, because that block has
    # already finished; the sync of it is taken, and 0 is what taken is.
    assert_equal(
        Int(aio_fsync(O_SYNC, cb)), 0, "the sync of the finished block is taken"
    )
    var asked = Int(aio_fsync(O_SYNC, sync))
    assert_equal(asked, 0, "and so is a sync of a block of its own")
    assert_true(
        _wait_for(sync) != Int(EINPROGRESS),
        "and the block it was given is settled either way",
    )

    assert_equal(Int(fclose(f)), 0, "the file closes")


def main() raises:
    test_a_read_that_finishes_and_says_so()
    test_a_write_the_file_itself_answers_for()
    test_lio_listio_takes_a_list_at_a_time()
    test_cancel_and_sync_are_answered_about()
    print("test_aio: ok")
