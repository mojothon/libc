from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.utils import string_to_char_ptr
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
    atan2f,
    atanf,
    atanh,
    atanhf,
    cbrt,
    cbrtf,
    ceil,
    ceilf,
    copysign,
    copysignf,
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
    fabsf,
    fabs,
    fdim,
    fdimf,
    floor,
    floorf,
    fma,
    fmaf,
    fmax,
    fmaxf,
    fmin,
    fminf,
    fmod,
    fmodf,
    frexp,
    frexpf,
    gamma,
    gammaf,
    hypot,
    hypotf,
    ilogb,
    ilogbf,
    labs,
    ldexp,
    ldexpf,
    ldiv,
    lgamma,
    lgamma_r,
    lgammaf,
    lgammaf_r,
    llabs,
    lldiv,
    log,
    log10,
    log10f,
    log1p,
    log1pf,
    log2,
    log2f,
    logb,
    logbf,
    logf,
    modf,
    modff,
    nan,
    nanf,
    nearbyint,
    nearbyintf,
    nextafter,
    nextafterf,
    pow,
    powf,
    remainderf,
    remquo,
    remquof,
    rintf,
    roundf,
    scalbln,
    scalblnf,
    scalbn,
    scalbnf,
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
    tgamma,
    tgammaf,
    trunc,
    truncf,
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


def test_rounding_and_remainders() raises:
    """These answer with a number near the one they were given, and what
    sets them apart is which way they go when the number is between two:
    up, down, towards nothing, or to the nearest. `copysignf` is here
    because it is the one that takes the size from the first of its two
    and the sign from the second, which is the whole of what it does.
    """
    assert_true(fabs(Float64(ceilf(2.3)) - 3.0) < 1e-6)
    assert_true(fabs(Float64(floorf(2.7)) - 2.0) < 1e-6)
    assert_true(fabs(Float64(roundf(2.5)) - 3.0) < 1e-6)
    assert_true(fabs(Float64(truncf(2.7)) - 2.0) < 1e-6)
    assert_true(fabs(nearbyint(2.4) - 2.0) < 1e-12)
    assert_true(fabs(Float64(nearbyintf(2.6)) - 3.0) < 1e-6)
    assert_true(fabs(Float64(rintf(2.6)) - 3.0) < 1e-6)

    assert_true(fabs(Float64(fabsf(-3.0)) - 3.0) < 1e-6)
    assert_true(fabs(fmax(1.0, 2.0) - 2.0) < 1e-12)
    assert_true(fabs(Float64(fmaxf(1.0, 2.0)) - 2.0) < 1e-6)
    assert_true(fabs(fmin(1.0, 2.0) - 1.0) < 1e-12)
    assert_true(fabs(Float64(fminf(1.0, 2.0)) - 1.0) < 1e-6)

    assert_true(fabs(Float64(copysignf(3.0, -1.0)) + 3.0) < 1e-6)
    assert_true(fabs(Float64(copysignf(-3.0, 1.0)) - 3.0) < 1e-6)


def test_scaling_and_exponents() raises:
    """`ldexp` takes the number and then the power of two, `frexp` writes
    the power of two where it is told to rather than handing it back,
    and `logb` is the one that says which power of two a number is.
    """
    assert_true(fabs(ldexp(3.0, 2) - 12.0) < 1e-12)
    assert_true(fabs(Float64(ldexpf(3.0, 2)) - 12.0) < 1e-6)
    assert_true(fabs(scalbn(3.0, 2) - 12.0) < 1e-12)
    assert_true(fabs(Float64(scalbnf(3.0, 2)) - 12.0) < 1e-6)
    assert_true(fabs(scalbln(3.0, 2) - 12.0) < 1e-12)
    assert_true(fabs(Float64(scalblnf(3.0, 2)) - 12.0) < 1e-6)

    var power = unsafe_alloc[Int32](1)
    assert_true(fabs(frexp(8.0, power) - 0.5) < 1e-12)
    assert_equal(
        power.unsafe_offset(0)[], 4, "frexp writes the two where it was told"
    )
    assert_true(fabs(Float64(frexpf(8.0, power)) - 0.5) < 1e-6)
    assert_equal(power.unsafe_offset(0)[], 4, "and so does frexpf")
    power.unsafe_free()

    var whole = unsafe_alloc[Float64](1)
    assert_true(fabs(modf(2.75, whole) - 0.75) < 1e-12)
    assert_true(fabs(whole.unsafe_offset(0)[] - 2.0) < 1e-12)
    whole.unsafe_free()

    var whole_f = unsafe_alloc[Float32](1)
    assert_true(fabs(Float64(modff(2.75, whole_f)) - 0.75) < 1e-6)
    assert_true(fabs(Float64(whole_f.unsafe_offset(0)[]) - 2.0) < 1e-6)
    whole_f.unsafe_free()

    assert_equal(Int(ilogb(8.0)), 3, "ilogb says which power of two")
    assert_equal(Int(ilogbf(8.0)), 3, "and so does ilogbf")
    assert_true(fabs(logb(8.0) - 3.0) < 1e-12)
    assert_true(fabs(Float64(logbf(8.0)) - 3.0) < 1e-6)


def test_the_two_that_are_not_symmetric() raises:
    """`atan2f` is given the y and then the x, which is not the order
    anybody writes them in; `nextafterf` goes from the first towards the
    second; `remainderf` is what is left of the first after the second;
    and `fmaf` multiplies the first two and adds the third.
    """
    assert_true(fabs(Float64(atan2f(1.0, 0.0)) - 1.5707963267948966) < 1e-6)
    assert_true(fabs(Float64(atan2f(0.0, 1.0)) - 0.0) < 1e-6)

    assert_true(
        Float64(nextafterf(1.0, 4.0)) > 1.0,
        "nextafterf goes towards the second",
    )
    assert_true(
        Float64(nextafterf(1.0, 0.0)) < 1.0, "and back down towards nothing"
    )

    assert_true(fabs(Float64(remainderf(7.0, 3.0)) - 1.0) < 1e-6)
    assert_true(fabs(Float64(fmodf(7.0, 3.0)) - 1.0) < 1e-6)
    assert_true(fabs(Float64(hypotf(3.0, 4.0)) - 5.0) < 1e-6)
    assert_true(fabs(Float64(fmaf(2.0, 3.0, 4.0)) - 10.0) < 1e-6)


def test_the_gamma_functions() raises:
    """`tgamma` is the factorial moved along by one and `lgamma` is its
    logarithm, which is the one that does not overflow. `gamma` is
    another name for `lgamma`, and the two ending in `_r` write the sign
    where they are told to rather than leaving it somewhere of libc's
    own choosing.
    """
    assert_true(fabs(tgamma(5.0) - 24.0) < 1e-12)
    assert_true(fabs(Float64(tgammaf(5.0)) - 24.0) < 1e-6)
    assert_true(fabs(lgamma(5.0) - 3.1780538303479458) < 1e-12)
    assert_true(fabs(Float64(lgammaf(5.0)) - 3.1780538303479458) < 1e-6)
    assert_true(fabs(gamma(5.0) - 3.1780538303479458) < 1e-12)
    assert_true(fabs(Float64(gammaf(5.0)) - 3.1780538303479458) < 1e-6)

    var sign = unsafe_alloc[Int32](1)
    assert_true(fabs(lgamma_r(5.0, sign) - 3.1780538303479458) < 1e-12)
    assert_equal(
        sign.unsafe_offset(0)[], 1, "lgamma_r writes the sign where it was told"
    )
    assert_true(fabs(Float64(lgammaf_r(5.0, sign)) - 3.1780538303479458) < 1e-6)
    assert_equal(sign.unsafe_offset(0)[], 1, "and so does lgammaf_r")
    sign.unsafe_free()


def test_nanf_and_the_absolute_values() raises:
    var tag = string_to_char_ptr("")
    var nothing = nanf(tag)
    assert_true(
        Float64(nothing) != Float64(nothing),
        "nanf hands back a thing that is not equal to itself",
    )
    tag.unsafe_free()

    assert_equal(Int(labs(-5)), 5, "labs takes the sign away")
    assert_equal(Int(llabs(-5)), 5, "and so does llabs")


def test_trunc_takes_the_fraction_towards_zero() raises:
    """`trunc` takes the fraction away and leaves the whole, and takes
    it towards zero, which is what sets it apart from `floor`: what
    `floor` makes of -2.7 is -3 and what `trunc` makes of it is -2.
    """
    assert_equal(trunc(2.7), 2.0, "trunc takes the fraction off 2.7")
    assert_equal(
        trunc(-2.7), -2.0, "and off -2.7, towards zero rather than downwards"
    )
    assert_equal(trunc(0.0), 0.0, "and leaves nothing as it found it")


def test_remquof_keeps_the_quotient() raises:
    """`remquof` is `remainderf` with the quotient kept as well and
    put where it is pointed. The quotient is not the whole of it — a
    few bits and the sign are all that is promised — but the two of
    them still have to come back to the number that went in, and that
    is what is asked of them here.
    """
    var quotient = unsafe_alloc[Int32](1)
    quotient.unsafe_offset(0)[] = 0
    var left = remquof(5.0, 3.0, quotient)

    assert_true(
        fabs(Float64(left) + Float64(Int(quotient.unsafe_load())) * 3.0 - 5.0)
        < 0.001,
        "the remainder and the quotient come back to five",
    )
    assert_true(
        fabs(Float64(left)) <= 1.5,
        "and the remainder is no more than half of three",
    )
    quotient.unsafe_free()


def main() raises:
    test_abs()
    test_sqrt_and_rounding()
    test_pow()
    test_the_right_symbol_is_called()
    test_arguments_in_order()
    test_remquo()
    test_trigonometry()
    test_exponentials_and_logarithms()
    test_rounding_and_remainders()
    test_scaling_and_exponents()
    test_the_two_that_are_not_symmetric()
    test_the_gamma_functions()
    test_nanf_and_the_absolute_values()
    test_nan()
    test_trunc_takes_the_fraction_towards_zero()
    test_remquof_keeps_the_quotient()
    print("test_math: ok")
