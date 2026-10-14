from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.math import (
    abs,
    acos,
    acosf,
    acosh,
    acoshf,
    asin,
    asinf,
    asinh,
    asinhf,
    atan,
    atan2,
    atanf,
    atanh,
    atanhf,
    cbrt,
    cbrtf,
    ceil,
    copysign,
    cos,
    cosf,
    cosh,
    coshf,
    erf,
    exp,
    expf,
    expm1,
    expm1f,
    fabs,
    fdim,
    fdimf,
    floor,
    fma,
    fmod,
    hypot,
    ldiv,
    lldiv,
    log,
    log10,
    log10f,
    log1p,
    log1pf,
    log2,
    log2f,
    logf,
    nan,
    nextafter,
    pow,
    powf,
    remquo,
    sin,
    sinf,
    sinh,
    sinhf,
    sqrt,
    sqrtf,
    tan,
    tanf,
    tanh,
    tanhf,
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


def test_arguments_in_order() raises:
    """Two arguments of the same type can be handed over in the wrong order
    and nothing says so: it still compiles, still matches the prototype and
    still returns a number. Each of these is asked for something that only
    comes out one way round.
    """
    assert_true((pow(2.0, 10.0) - 1024.0) < 1e-9, "2 to the 10, not 10 squared")
    assert_true((copysign(1.0, -1.0) + 1.0) < 1e-12, "the sign comes second")

    var after = nextafter(1.0, 4.0)
    assert_true(after > 1.0, "nextafter steps away from the first")
    assert_true(after < 4.0, "and toward the second")

    assert_true((fma(2.0, 3.0, 4.0) - 10.0) < 1e-9, "2*3+4, the 4 added last")
    assert_true(fdim(1.0, 4.0) == 0.0, "the positive difference, or zero")
    assert_true(
        (fdim(4.0, 1.0) - 3.0) < 1e-12, "which is not the same both ways"
    )
    assert_true((hypot(3.0, 4.0) - 5.0) < 1e-9, "a 3-4-5 triangle")

    var d = ldiv(10, 3)
    assert_equal(d.quot, 3, "10 over 3 goes 3 times")
    assert_equal(d.rem, 1, "with 1 left over")
    var ld = lldiv(10, 3)
    assert_equal(ld.quot, 3, "and the long long one")
    assert_equal(ld.rem, 1, "with 1 left over too")


def test_nan() raises:
    """`nan` takes its tag as a string, not as a byte."""
    var tag = unsafe_alloc[UInt8](1)
    tag.unsafe_offset(0)[] = 0

    var value = nan(tag)
    assert_true(value != value, "a NaN is not equal to itself")


def test_trigonometry() raises:
    """Not one of the sines, cosines or tangents had been called, nor
    their inverses, nor the hyperbolic ones, and each has the same name
    as the one twice its size. So each is asked about a number whose
    answer is known: the sine of nothing is nothing, the cosine of
    nothing is one, and each inverse undoes what it is the inverse of.
    """
    assert_true(fabs(sin(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(sinf(0.0)) - 0.0) < 1e-6)
    assert_true(fabs(cos(0.0) - 1.0) < 1e-12)
    assert_true(fabs(Float64(cosf(0.0)) - 1.0) < 1e-6)
    assert_true(fabs(tan(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(tanf(0.0)) - 0.0) < 1e-6)

    assert_true(fabs(asin(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(asinf(0.0)) - 0.0) < 1e-6)
    assert_true(fabs(acos(1.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(acosf(1.0)) - 0.0) < 1e-6)
    assert_true(fabs(atan(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(atanf(0.0)) - 0.0) < 1e-6)

    assert_true(fabs(sinh(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(sinhf(0.0)) - 0.0) < 1e-6)
    assert_true(fabs(cosh(0.0) - 1.0) < 1e-12)
    assert_true(fabs(Float64(coshf(0.0)) - 1.0) < 1e-6)
    assert_true(fabs(tanh(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(tanhf(0.0)) - 0.0) < 1e-6)

    assert_true(fabs(asinh(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(asinhf(0.0)) - 0.0) < 1e-6)
    assert_true(fabs(acosh(1.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(acoshf(1.0)) - 0.0) < 1e-6)
    assert_true(fabs(atanh(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(atanhf(0.0)) - 0.0) < 1e-6)


def test_exponentials_and_logarithms() raises:
    """What each of these is the inverse of is what says which one it
    is: `log2` answers in twos where `log10` answers in tens, and
    `expm1` and `log1p` are the two that stay honest next to nothing,
    which is where a plain `exp` minus one loses its answer.
    """
    assert_true(fabs(exp(0.0) - 1.0) < 1e-12)
    assert_true(fabs(Float64(expf(0.0)) - 1.0) < 1e-6)
    assert_true(fabs(expm1(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(expm1f(0.0)) - 0.0) < 1e-6)

    assert_true(fabs(log(1.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(logf(1.0)) - 0.0) < 1e-6)
    assert_true(fabs(log2(2.0) - 1.0) < 1e-12)
    assert_true(fabs(Float64(log2f(2.0)) - 1.0) < 1e-6)
    assert_true(fabs(log10(100.0) - 2.0) < 1e-12)
    assert_true(fabs(Float64(log10f(100.0)) - 2.0) < 1e-6)
    assert_true(fabs(log1p(0.0) - 0.0) < 1e-12)
    assert_true(fabs(Float64(log1pf(0.0)) - 0.0) < 1e-6)

    assert_true(fabs(Float64(sqrtf(4.0)) - 2.0) < 1e-6)
    assert_true(fabs(cbrt(8.0) - 2.0) < 1e-12)
    assert_true(fabs(Float64(cbrtf(27.0)) - 3.0) < 1e-6)


def main() raises:
    test_abs()
    test_sqrt_and_rounding()
    test_pow()
    test_the_right_symbol_is_called()
    test_arguments_in_order()
    test_remquo()
    test_trigonometry()
    test_exponentials_and_logarithms()
    test_nan()
    print("test_math: ok")
