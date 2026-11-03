"""Tests for the `libc.execinfo` bindings.

Three calls that read the stack the process is standing on: one that
collects the addresses, and two that turn them into text — one into an
array of strings, one straight down a descriptor.

The frame count is the interesting part, because it is a count of what the
unwinder could find and not of what is there. A frame that was inlined left
none behind; a frame with no unwind information may be stepped over; an
entry point has no return address and so ends the walk. That rules out
asserting a number, and what is asserted instead is what survives it: that
zero room records nothing, that room for one records one, that sixty-four
is a ceiling, that the frames the caller can prove are there are there, and
that the two textual forms agree with each other about how many frames they
are describing — which is the one assertion that holds both calls at once
and holds on both platforms without knowing what either of them writes.
"""

from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr, c_uint, c_void
from libc.execinfo import backtrace, backtrace_symbols, backtrace_symbols_fd
from libc.stdlib import free
from libc.unistd import close, pipe, read
from libc.utils import char_ptr_to_string, is_null


def test_the_stack_can_be_counted() raises:
    """`backtrace` records at most what it was given room for, and says
    how many it recorded.

    The two ends of that are what can be pinned down. Asked for room for
    nothing it records nothing, which is the ceiling at its smallest;
    asked for room for one it records one, because a call that returns
    somewhere has at least that one frame above it.

    What a deep stack gives is not asserted, because it is not a
    property of this call. Run through `mojo run`, the code is built
    just before it is run and the frames it makes are not ones the
    unwinder knows: the same call in the same three-deep nest answers 1
    here and 4 in a binary built ahead of time. That is the build rather
    than the stack, so the floor asserted is the one frame that is
    certain in either case.
    """
    var held = unsafe_alloc[c_ptr[c_void]](64)

    assert_equal(backtrace(held, 0), 0, "room for no frames records no frames")
    assert_equal(
        backtrace(held, 1),
        1,
        "room for one records one, there being always a caller to come back to",
    )
    assert_true(
        not is_null(held.unsafe_offset(0)[]),
        "and what it recorded is an address rather than an empty slot",
    )

    var got = backtrace(held, 64)
    assert_true(got <= 64, "sixty-four is a ceiling and not a request")
    assert_true(
        got >= 1, "and the frame it returns to is always there to be found"
    )

    held.unsafe_free()


def test_the_two_forms_describe_the_same_frames() raises:
    """`backtrace_symbols` and `backtrace_symbols_fd` are the same
    information twice: once as an array of strings, once as lines written
    down a descriptor.

    Neither the words nor their spelling is the same on both platforms —
    one names the object and an offset into it, the other may write an
    address — so what is compared is the count, which both of them have
    to get right, and which has to agree with what `backtrace` said. A
    count that only one of them got right would still be a count, so the
    two are compared to each other and to the third rather than to a
    number written into this test.

    Under `mojo run` there is one frame to describe and its line is a
    bare address, the code having been built into memory that belongs to
    no loaded image. That still exercises both forms; it exercises them
    once.

    The array is freed the way the call says to free it: once, at the
    array, with the strings inside it and not one call each.
    """
    var held = unsafe_alloc[c_ptr[c_void]](64)
    var got = backtrace(held, 64)
    assert_true(got >= 1, "there is a stack here to be described")

    var lines = backtrace_symbols(held, got)
    assert_true(not is_null(lines), "the array of strings is made")
    for frame in range(Int(got)):
        assert_true(
            not is_null(lines.unsafe_offset(frame)[]),
            "every recorded frame has a line",
        )
        assert_true(
            char_ptr_to_string(lines.unsafe_offset(frame)[]).byte_length() > 0,
            "and a line that says nothing would be a line that was not written",
        )
    _ = free(lines.unsafe_bitcast[c_void]())

    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "there is a pipe to write the other form down")
    var read_fd = fds.unsafe_offset(0)[]
    var write_fd = fds.unsafe_offset(1)[]

    backtrace_symbols_fd(held, got, write_fd)
    _ = close(write_fd)

    var chunk = unsafe_alloc[UInt8](512)
    var written = 0
    var lines_written = 0
    while True:
        var taken = read(read_fd, chunk.unsafe_bitcast[c_void](), c_uint(512))
        if taken <= 0:
            break
        for at in range(Int(taken)):
            if chunk.unsafe_offset(at)[] == UInt8(10):
                lines_written += 1
        written += Int(taken)
    chunk.unsafe_free()
    _ = close(read_fd)
    fds.unsafe_free()
    held.unsafe_free()

    assert_true(written > 0, "the descriptor was written to")
    assert_equal(
        lines_written,
        Int(got),
        "one line per frame, which is the number the other form answered with",
    )


def main() raises:
    test_the_stack_can_be_counted()
    test_the_two_forms_describe_the_same_frames()
    print("test_execinfo: ok")
