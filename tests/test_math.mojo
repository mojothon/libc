from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.math import (
    abs,
    atan2,
    ceil,
    erf,
    fabs,
    fdimf,
    floor,
    fmod,
    nan,
    powf,
    remquo,
    sqrt,
)


def test_abs() raises:
    assert_equal(abs(-42), 42)
    assert_equal(abs(42), 42)


def test_sqrt_and_rounding() raises:
    assert_true((sqrt(16.0) - 4.0) < 1e-12)
    assert_true((fabs(-2.5) - 2.5) < 1e-12)
    assert_true((ceil(2.1) - 3.0) < 1e-12)
    assert_true((floor(2.9) - 2.0) < 1e-12)


def test_pow() raises:
    assert_true((powf(2.0, 10.0) - 1024.0) < 1e-6)


def test_the_right_symbol_is_called() raises:
    # `fabs` used to call `fabsl`, `fmod` called `fmodl`, `fdimf` called `fdim`
    # and `erf` called `erff`: one letter apart, and `erf(1.0)` came back as 1.0
    # instead of 0.8427. `atan2` was declared with a single argument.
    assert_equal(fabs(-3.5), 3.5, "fabs is fabs")
    assert_equal(fmod(10.5, 3.0), 1.5, "fmod is fmod")
    assert_equal(fdimf(5.0, 2.0), 3.0, "fdimf is fdimf")
    assert_true(erf(1.0) > 0.84 and erf(1.0) < 0.85, "erf(1) is about 0.8427")
    assert_true(
        atan2(1.0, 1.0) > 0.785398 and atan2(1.0, 1.0) < 0.785399,
        "atan2(1, 1) is a quarter of pi",
    )


def test_remquo() raises:
    """`remquo` takes a pointer to write the quotient into."""
    var quo = unsafe_alloc[Int32](1)
    quo.unsafe_offset(0)[] = 0

    var remainder = remquo(3.0, 2.0, quo)

    # 3 / 2 is 2 to the nearest, with -1 left over. What matters here is
    # that the quotient comes back through the pointer, which it cannot do
    # while the binding declares it as an `Int32`.
    assert_equal(quo.unsafe_offset(0)[], 2, "the quotient is written out")
    assert_true(
        remainder == 1.0 or remainder == -1.0, "the remainder is 3 - 2 * 2"
    )


def test_nan() raises:
    """`nan` takes its tag as a string, not as a byte."""
    var tag = unsafe_alloc[UInt8](1)
    tag.unsafe_offset(0)[] = 0

    var value = nan(tag)
    assert_true(value != value, "a NaN is not equal to itself")


def main() raises:
    test_abs()
    test_sqrt_and_rounding()
    test_pow()
    test_the_right_symbol_is_called()
    test_remquo()
    test_nan()
    print("test_math: ok")
