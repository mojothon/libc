# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import (
    SPLICE_F_NONBLOCK,
    open as open_with_mode,
    splice,
    tee,
    vmsplice,
)
from libc.errno import EAGAIN, get_errno
from libc.stdio import remove
from libc.stdlib import mkstemp
from libc.sys.socket import iovec
from libc.unistd import close, lseek, pipe, read
from libc.utils import null_ptr
from libc.utils import string_to_char_ptr


def test_the_pages_become_the_pipes_and_the_files() raises:
    """`vmsplice` and `splice` together: the pages the caller holds
    are handed to the pipe, and the pipe hands them to a file --
    and no copy of the bytes is ever the caller's to make.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/libc_splice_XXXXXX")
        _ = remove(path)
        var fd = mkstemp(path)
        assert_true(fd >= 0, "the file the bytes land in is made")

        var ends = unsafe_alloc[Int32](2)
        assert_equal(Int(pipe(ends)), 0, "a pipe is made")
        var read_end = ends.unsafe_offset(0)[]
        var write_end = ends.unsafe_offset(1)[]

        var text = unsafe_alloc[UInt8](11)
        text.unsafe_store(0, 104)
        text.unsafe_store(1, 101)
        text.unsafe_store(2, 108)
        text.unsafe_store(3, 108)
        text.unsafe_store(4, 111)
        text.unsafe_store(5, 44)
        text.unsafe_store(6, 32)
        text.unsafe_store(7, 112)
        text.unsafe_store(8, 105)
        text.unsafe_store(9, 112)
        text.unsafe_store(10, 101)

        var pieces = unsafe_alloc[iovec](1)
        pieces.unsafe_offset(0)[] = iovec(text, UInt64(11))
        assert_equal(
            Int(vmsplice(write_end, pieces, 1, 0)),
            11,
            "the caller's pages are put in the pipe",
        )

        var moved = splice(
            read_end,
            null_ptr[Int64](),
            fd,
            null_ptr[Int64](),
            UInt64(64),
            UInt32(SPLICE_F_NONBLOCK),
        )
        assert_equal(Int(moved), 11, "the pipe hands the bytes to the file")

        assert_equal(Int(lseek(fd, 0, 0)), 0, "the file is read from the start")
        var buf = unsafe_alloc[UInt8](64)
        assert_equal(
            Int(read(fd, buf, UInt32(64))), 11, "the bytes come back out of it"
        )
        assert_true(
            buf.unsafe_offset(0)[] == 104 and buf.unsafe_offset(7)[] == 112,
            "and they are the ones the caller held",
        )
        buf.unsafe_free()
        text.unsafe_free()
        pieces.unsafe_free()

        _ = close(read_end)
        _ = close(write_end)
        _ = close(fd)
        _ = remove(path)
        path.unsafe_free()


def test_a_pipe_that_gives_and_keeps() raises:
    """`tee` and the keeping that is the whole of it: the bytes are
    copied to a second pipe and the first pipe still has them --
    two readers of one source, the caller never holding the bytes.
    """
    comptime if not CompilationTarget.is_macos():
        var ends_a = unsafe_alloc[Int32](2)
        var ends_b = unsafe_alloc[Int32](2)
        assert_equal(Int(pipe(ends_a)), 0, "the first pipe is made")
        assert_equal(Int(pipe(ends_b)), 0, "and the second")
        var read_a = ends_a.unsafe_offset(0)[]
        var write_a = ends_a.unsafe_offset(1)[]
        var read_b = ends_b.unsafe_offset(0)[]
        var write_b = ends_b.unsafe_offset(1)[]

        var text = unsafe_alloc[UInt8](5)
        text.unsafe_store(0, 97)
        text.unsafe_store(1, 98)
        text.unsafe_store(2, 99)
        text.unsafe_store(3, 100)
        text.unsafe_store(4, 101)
        var pieces = unsafe_alloc[iovec](1)
        pieces.unsafe_offset(0)[] = iovec(text, UInt64(5))
        assert_equal(
            Int(vmsplice(write_a, pieces, 1, 0)), 5, "the source is filled"
        )

        assert_equal(
            Int(tee(read_a, write_b, UInt64(5), UInt32(SPLICE_F_NONBLOCK))),
            5,
            "five bytes are copied across",
        )

        var buf = unsafe_alloc[UInt8](8)
        assert_equal(
            Int(read(read_b, buf, UInt32(8))), 5, "the second pipe has them"
        )
        assert_true(
            buf.unsafe_offset(0)[] == 97 and buf.unsafe_offset(4)[] == 101,
            "and they are the source's",
        )
        assert_equal(
            Int(read(read_a, buf, UInt32(8))),
            5,
            "and the first pipe kept its own",
        )
        assert_true(
            buf.unsafe_offset(0)[] == 97 and buf.unsafe_offset(4)[] == 101,
            "and they are the same bytes",
        )
        buf.unsafe_free()
        text.unsafe_free()
        pieces.unsafe_free()

        _ = close(read_a)
        _ = close(write_a)
        _ = close(read_b)
        _ = close(write_b)


def test_the_empty_pipe_and_the_pipe_at_its_end() raises:
    """`splice` and the two zeros the pipe can give: an empty pipe
    whose writer still lives refuses with `EAGAIN` rather than
    waiting -- it might be filled the moment after -- and a pipe
    whose writer is gone answers zero, because nothing will ever
    fill it again. The zero is not a failure; it is the end.
    """
    comptime if not CompilationTarget.is_macos():
        var ends = unsafe_alloc[Int32](2)
        assert_equal(Int(pipe(ends)), 0, "a pipe is made")
        var read_end = ends.unsafe_offset(0)[]
        var write_end = ends.unsafe_offset(1)[]

        var path = string_to_char_ptr("/tmp/libc_splice_n_XXXXXX")
        _ = remove(path)
        var fd = mkstemp(path)
        assert_true(fd >= 0, "the file is made")

        assert_equal(
            Int(
                splice(
                    read_end,
                    null_ptr[Int64](),
                    fd,
                    null_ptr[Int64](),
                    UInt64(64),
                    UInt32(SPLICE_F_NONBLOCK),
                )
            ),
            -1,
            "an empty pipe that might be filled refuses",
        )
        assert_equal(Int(get_errno()), Int(EAGAIN), "and the refusal is EAGAIN")

        assert_equal(Int(close(write_end)), 0, "the writer is gone")
        assert_equal(
            Int(
                splice(
                    read_end,
                    null_ptr[Int64](),
                    fd,
                    null_ptr[Int64](),
                    UInt64(64),
                    UInt32(SPLICE_F_NONBLOCK),
                )
            ),
            0,
            "and the pipe at its end answers zero",
        )

        _ = close(read_end)
        _ = close(fd)
        _ = remove(path)
        path.unsafe_free()


def main() raises:
    test_the_pages_become_the_pipes_and_the_files()
    test_a_pipe_that_gives_and_keeps()
    test_the_empty_pipe_and_the_pipe_at_its_end()
    print("test_splice: ok")
