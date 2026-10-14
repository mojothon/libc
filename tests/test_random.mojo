"""Tests for `libc.sys.random`, of which `getrandom` is the whole of it.

It asks the kernel for bytes nobody can guess, which is what reading
`/dev/urandom` gives and what the C library's own `rand` does not.
It had never been called.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.sys.random import getrandom


def test_getrandom_fills_what_it_is_given() raises:
    """`getrandom` hands back how many bytes it wrote, and eight is
    well inside what it gives without being asked to wait.

    What is asked of the bytes themselves is only that they are not
    the zeroes that were there before. Bytes nobody can guess cannot
    be told apart from any other eight bytes, so there is nothing
    else that would be worth asking.
    """
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


def main() raises:
    test_getrandom_fills_what_it_is_given()
    print("test_random: ok")
