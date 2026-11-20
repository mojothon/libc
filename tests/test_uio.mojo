# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.errno import ESRCH, get_errno
from libc.constant import (
    MAP_ANONYMOUS,
    MAP_PRIVATE,
    MAP_SHARED,
    PROT_READ,
    PROT_WRITE,
)
from libc.sys.mman import mmap, munmap
from libc.sys.socket import iovec
from libc.sys.uio import process_vm_readv, process_vm_writev
from libc.stdlib import exit as exit_with
from libc.sys.wait import WIFEXITED, waitpid
from libc.unistd import close, fork, getpid, pipe, read, write
from libc.utils import null_ptr, string_to_char_ptr


comptime RW: Int32 = PROT_READ | PROT_WRITE
comptime PAGE: Int64 = 4096


def test_the_childs_memory_is_read_where_it_lies() raises:
    """`process_vm_readv` and a child that shares a page with the
    caller: the child writes into the page, the caller reads from
    the child by the address the page sits at -- the same address
    in both spaces, which is what a shared mapping makes of one
    page -- and what comes back is what the child put there.

    What makes the reading worth trusting is that the caller
    never wrote those bytes: they came into the page from the
    other side of the process boundary, and the call carried
    them across by naming where they lie.
    """
    comptime if not CompilationTarget.is_macos():
        var page = mmap(
            null_ptr[UInt8](), PAGE, RW, MAP_SHARED | MAP_ANONYMOUS, -1, 0
        )
        assert_true(Int(UInt(page)) > 0, "a page both processes will see")

        var ends = unsafe_alloc[Int32](2)
        assert_equal(Int(pipe(ends)), 0, "a pipe to say the child is in place")
        var read_end = ends.unsafe_offset(0)[]
        var write_end = ends.unsafe_offset(1)[]

        var child = fork()
        assert_true(child >= 0, "a child is made")
        if child == 0:
            page.unsafe_store(0, UInt8(104))
            page.unsafe_store(1, UInt8(105))
            page.unsafe_store(2, UInt8(33))
            _ = write(write_end, string_to_char_ptr("x"), 1)
            _ = read(read_end, null_ptr[UInt8](), 1)
            _ = exit_with(0)

        _ = close(write_end)
        var one = unsafe_alloc[UInt8](1)
        assert_equal(
            Int(read(read_end, one, UInt32(1))),
            1,
            "the child says it has written",
        )

        # The local side is two pieces where the remote side is one,
        # and the two counts are two different numbers on purpose: a
        # binding that swapped them would still be answered, by a
        # call that filled from the wrong side's table, and a test
        # where both counts are one would have nothing to say
        # about which was which.
        var local = unsafe_alloc[UInt8](8)
        var local_iov = unsafe_alloc[iovec](2)
        local_iov.unsafe_offset(0)[] = iovec(local, UInt64(2))
        local_iov.unsafe_offset(1)[] = iovec(local.unsafe_offset(2), UInt64(1))
        var remote_iov = unsafe_alloc[iovec](1)
        remote_iov.unsafe_offset(0)[] = iovec(page, UInt64(3))

        assert_equal(
            Int(
                process_vm_readv(
                    child, local_iov, UInt64(2), remote_iov, UInt64(1), 0
                )
            ),
            3,
            "three bytes are read out of the child, over two local pieces",
        )
        assert_true(
            local.unsafe_offset(2)[] == 33,
            "and the third landed in the second piece, where it was sent",
        )
        assert_true(
            local.unsafe_offset(0)[] == 104 and local.unsafe_offset(1)[] == 105,
            "and the first two landed in the first piece",
        )

        _ = write(write_end, string_to_char_ptr("x"), 1)
        var status = unsafe_alloc[Int32](1)
        assert_equal(
            waitpid(child, status, 0), child, "the child is waited for"
        )
        assert_true(WIFEXITED(status.unsafe_load()), "and it left on its own")

        local.unsafe_free()
        local_iov.unsafe_free()
        remote_iov.unsafe_free()
        one.unsafe_free()
        status.unsafe_free()
        ends.unsafe_free()
        _ = close(read_end)
        _ = munmap(page, PAGE)


def test_the_childs_memory_is_written_and_the_child_answers() raises:
    """`process_vm_writev` and the other direction: the caller puts
    bytes into the child's memory by the address they lie at, and
    the child reads them out of its own page and says what they
    were -- which is the carrying in the other direction, and the
    answer comes from the child's own reading of what landed.
    """
    comptime if not CompilationTarget.is_macos():
        var page = mmap(
            null_ptr[UInt8](), PAGE, RW, MAP_SHARED | MAP_ANONYMOUS, -1, 0
        )
        assert_true(Int(UInt(page)) > 0, "a page both processes will see")

        # Two pipes, and the reason there are two: the caller tells
        # the child to look through one and the child answers through
        # the other. One pipe for both is the shape that fails, and
        # it fails by the caller reading back the wake it sent -- the
        # caller that waits for an answer is waiting for bytes it
        # cannot tell from its own.
        var ends = unsafe_alloc[Int32](2)
        var backs = unsafe_alloc[Int32](2)
        assert_equal(Int(pipe(ends)), 0, "a pipe to wake the child through")
        assert_equal(Int(pipe(backs)), 0, "and a pipe for the child's answer")
        var read_end = ends.unsafe_offset(0)[]
        var write_end = ends.unsafe_offset(1)[]
        var answer_read = backs.unsafe_offset(0)[]
        var answer_write = backs.unsafe_offset(1)[]

        # The child's own buffers are made before the fork: what the
        # child does after it is forked is run with the runtime the
        # fork gave it, and asking that runtime for memory is asking
        # the allocator of a process that may have been holding its
        # own lock at the moment it was split. Everything the child
        # touches is touched before the fork or shared with it.
        var seen = unsafe_alloc[UInt8](3)
        var wake = unsafe_alloc[UInt8](1)
        var child = fork()
        assert_true(child >= 0, "a child is made")
        if child == 0:
            _ = close(answer_read)
            _ = read(read_end, wake, UInt32(1))
            seen.unsafe_offset(0)[] = page.unsafe_load(0)
            seen.unsafe_offset(1)[] = page.unsafe_load(1)
            seen.unsafe_offset(2)[] = page.unsafe_load(2)
            _ = write(answer_write, seen, 3)
            _ = exit_with(0)

        _ = close(answer_write)

        var sent = unsafe_alloc[UInt8](3)
        sent.unsafe_offset(0)[] = 115
        sent.unsafe_offset(1)[] = 101
        sent.unsafe_offset(2)[] = 110
        var local_iov = unsafe_alloc[iovec](2)
        local_iov.unsafe_offset(0)[] = iovec(sent, UInt64(2))
        local_iov.unsafe_offset(1)[] = iovec(sent.unsafe_offset(2), UInt64(1))
        var remote_iov = unsafe_alloc[iovec](1)
        remote_iov.unsafe_offset(0)[] = iovec(page, UInt64(3))

        assert_equal(
            Int(
                process_vm_writev(
                    child, local_iov, UInt64(2), remote_iov, UInt64(1), 0
                )
            ),
            3,
            (
                "three bytes are put into the child's memory, over two local"
                " pieces"
            ),
        )
        _ = write(write_end, string_to_char_ptr("x"), 1)

        var back = unsafe_alloc[UInt8](8)
        assert_equal(
            Int(read(answer_read, back, UInt32(8))),
            3,
            "the child reads its own page and answers",
        )
        assert_true(
            back.unsafe_offset(0)[] == 115 and back.unsafe_offset(2)[] == 110,
            "and what it read is what was put there",
        )

        var status = unsafe_alloc[Int32](1)
        assert_equal(
            waitpid(child, status, 0), child, "the child is waited for"
        )
        assert_true(WIFEXITED(status.unsafe_load()), "and it left on its own")

        sent.unsafe_free()
        back.unsafe_free()
        local_iov.unsafe_free()
        remote_iov.unsafe_free()
        status.unsafe_free()
        seen.unsafe_free()
        wake.unsafe_free()
        ends.unsafe_free()
        backs.unsafe_free()
        _ = munmap(page, PAGE)


def test_a_process_that_is_not_there_is_refused() raises:
    """`process_vm_readv` and a pid nobody holds: the call is
    refused, and the refusal is `ESRCH` -- there is no such
    process -- which is the answer that says the permission was
    not the problem but the process was.
    """
    comptime if not CompilationTarget.is_macos():
        var local = unsafe_alloc[UInt8](8)
        var local_iov = unsafe_alloc[iovec](1)
        local_iov.unsafe_offset(0)[] = iovec(local, UInt64(8))
        var remote_iov = unsafe_alloc[iovec](1)
        remote_iov.unsafe_offset(0)[] = iovec(local, UInt64(8))

        assert_equal(
            Int(
                process_vm_readv(
                    Int32(999999),
                    local_iov,
                    UInt64(1),
                    remote_iov,
                    UInt64(1),
                    0,
                )
            ),
            -1,
            "a process nobody holds is refused",
        )
        assert_equal(
            Int(get_errno()), Int(ESRCH), "and the refusal names the absence"
        )

        local.unsafe_free()
        local_iov.unsafe_free()
        remote_iov.unsafe_free()


def main() raises:
    test_the_childs_memory_is_read_where_it_lies()
    test_the_childs_memory_is_written_and_the_child_answers()
    test_a_process_that_is_not_there_is_refused()
    print("test_uio: ok")
