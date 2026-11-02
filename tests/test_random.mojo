"""Tests for `libc.sys.random`, the two calls that ask for bytes.

The kernel is asked for bytes nobody can guess, which is what reading
`/dev/urandom` gives and what the C library's own `rand` does not.

`getrandom` is Linux's and is answered on one platform only;
`getentropy` is the one both platforms agreed on, so it is the one that
is asked here for something besides bytes — that asking for more than
its limit is refused rather than truncated. A call that wrote half of
what was asked and said nothing would leave a caller with a buffer that
looks filled and is not.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.sys.random import getentropy, getrandom


def test_getrandom_fills_what_it_is_given() raises:
    """`getrandom` hands back how many bytes it wrote, and eight is
    well inside what it gives without being asked to wait.

    What is asked of the bytes themselves is only that they are not
    the zeroes that were there before. Bytes nobody can guess cannot
    be told apart from any other eight bytes, so there is nothing
    else that would be worth asking.

    Darwin has no `getrandom` to call, and the binding answers -1
    there rather than inventing one, so nothing is asked of it on
    that side.
    """
    comptime if CompilationTarget.is_macos():
        return
    var buf = unsafe_alloc[UInt8](8)
    for i in range(8):
        buf.unsafe_store(i, 0)

    assert_equal(
        getrandom(buf, 8, 0), 8, "getrandom answers with how much it wrote"
    )

    var not_zeroes = 0
    for i in range(8):
        if Int(buf.unsafe_load(i)) != 0:
            not_zeroes += 1
    assert_true(
        not_zeroes > 0, "and what it wrote is not the zeroes that were there"
    )

    buf.unsafe_free()


def test_getentropy_fills_and_refuses_what_it_cannot() raises:
    """`getentropy` on both platforms, and the limit it shares with the
    other one: 256 bytes is a whole call, and 257 is an error rather than
    a short answer.

    The refusal is the half worth having. Bytes cannot be told apart from
    other bytes, so the only thing a test can say about them is that they
    stopped being zeroes — but a call that quietly fills the first 256 of
    what it was given leaves a caller writing those 256 somewhere they
    believe are 257, and that is the bug this asks about.
    """
    comptime SIZE = 16

    var buf = unsafe_alloc[UInt8](SIZE)
    for i in range(SIZE):
        buf.unsafe_store(i, 0)

    assert_equal(
        getentropy(buf, SIZE), 0, "getentropy answers zero, not a count"
    )

    var not_zeroes = 0
    for i in range(SIZE):
        if Int(buf.unsafe_load(i)) != 0:
            not_zeroes += 1
    assert_true(
        not_zeroes > 0, "and what it wrote is not the zeroes that were there"
    )

    assert_equal(
        getentropy(buf, 257),
        -1,
        "257 bytes is more than a call carries, and is refused rather than cut",
    )

    buf.unsafe_free()


def main() raises:
    test_getrandom_fills_what_it_is_given()
    test_getentropy_fills_and_refuses_what_it_cannot()
    print("test_random: ok")
