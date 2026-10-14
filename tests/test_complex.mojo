from std.testing import assert_equal, assert_true

from libc.complex import (
    cabs,
    cabsf,
    cacos,
    cacosf,
    cacosh,
    cacoshf,
    carg,
    cargf,
    casin,
    casinf,
    casinh,
    casinhf,
    catan,
    catanf,
    catanh,
    catanhf,
    ccos,
    ccosf,
    ccosh,
    ccoshf,
    cdouble,
    cexp,
    cexpf,
    cfloat,
    cimag,
    cimagf,
    clog,
    clogf,
    conj,
    conjf,
    cpow,
    cpowf,
    cproj,
    cprojf,
    creal,
    crealf,
    csin,
    csinf,
    csinh,
    csinhf,
    csqrt,
    csqrtf,
    ctan,
    ctanf,
    ctanh,
    ctanhf,
)


comptime EPS_D = 1e-9
comptime EPS_F = 1e-5


def assert_cdouble(got: cdouble, re: Float64, im: Float64) raises:
    assert_true(abs(got.re - re) < EPS_D, "real component")
    assert_true(abs(got.im - im) < EPS_D, "imaginary component")


def assert_cfloat(got: cfloat, re: Float64, im: Float64) raises:
    assert_true(abs(Float64(got.re) - re) < EPS_F, "real component")
    assert_true(abs(Float64(got.im) - im) < EPS_F, "imaginary component")


def test_components() raises:
    var z = cdouble(2.0, 3.0)
    assert_equal(creal(z), 2.0)
    assert_equal(cimag(z), 3.0)

    var zf = cfloat(2.0, 3.0)
    assert_equal(crealf(zf), 2.0)
    assert_equal(cimagf(zf), 3.0)


def test_magnitude_and_phase() raises:
    assert_equal(cabs(cdouble(3.0, 4.0)), 5.0)
    assert_equal(cabsf(cfloat(3.0, 4.0)), 5.0)

    # atan2(1, 1) == pi / 4.
    assert_true(abs(carg(cdouble(1.0, 1.0)) - 0.7853981633974483) < EPS_D)
    assert_true(
        abs(Float64(cargf(cfloat(1.0, 1.0))) - 0.7853981633974483) < EPS_F
    )


def test_conjugate_and_projection() raises:
    assert_cdouble(conj(cdouble(3.0, 4.0)), 3.0, -4.0)
    assert_cdouble(cproj(cdouble(3.0, 4.0)), 3.0, 4.0)

    assert_cfloat(conjf(cfloat(3.0, 4.0)), 3.0, -4.0)
    assert_cfloat(cprojf(cfloat(3.0, 4.0)), 3.0, 4.0)


def test_roots_and_exponentials() raises:
    assert_cdouble(csqrt(cdouble(-1.0, 0.0)), 0.0, 1.0)
    assert_cfloat(csqrtf(cfloat(-1.0, 0.0)), 0.0, 1.0)

    assert_cdouble(cexp(cdouble(0.0, 0.0)), 1.0, 0.0)
    assert_cdouble(clog(cdouble(1.0, 0.0)), 0.0, 0.0)

    assert_cfloat(cexpf(cfloat(0.0, 0.0)), 1.0, 0.0)

    # i ** 2 == -1, up to the usual rounding of the complex exponential.
    assert_cdouble(cpow(cdouble(0.0, 1.0), cdouble(2.0, 0.0)), -1.0, 0.0)


def test_trigonometric() raises:
    assert_cdouble(csin(cdouble(0.0, 0.0)), 0.0, 0.0)
    assert_cdouble(ccos(cdouble(0.0, 0.0)), 1.0, 0.0)
    assert_cdouble(ctan(cdouble(0.0, 0.0)), 0.0, 0.0)

    assert_cdouble(casin(cdouble(0.0, 0.0)), 0.0, 0.0)
    assert_true(abs(cacos(cdouble(0.0, 0.0)).re - 1.5707963267948966) < EPS_D)
    assert_cdouble(catan(cdouble(0.0, 0.0)), 0.0, 0.0)


def test_hyperbolic() raises:
    assert_cdouble(csinh(cdouble(0.0, 0.0)), 0.0, 0.0)
    assert_cdouble(ccosh(cdouble(0.0, 0.0)), 1.0, 0.0)
    assert_cdouble(ctanh(cdouble(0.0, 0.0)), 0.0, 0.0)

    assert_cdouble(casinh(cdouble(0.0, 0.0)), 0.0, 0.0)
    assert_cdouble(cacosh(cdouble(1.0, 0.0)), 0.0, 0.0)
    assert_cdouble(catanh(cdouble(0.0, 0.0)), 0.0, 0.0)


def test_float_variants() raises:
    """Thirteen of these had never been called, each of them the same
    call as one already asked about here with an `f` put on the end, and
    the `f` is the whole of the difference: a `cfloat` is two `Float32`
    where a `cdouble` is two `Float64`, and the two are not the same
    type and cannot be told apart by anything else.
    """
    assert_cfloat(ccosf(cfloat(0.0, 0.0)), 1.0, 0.0)
    assert_cfloat(ctanf(cfloat(0.0, 0.0)), 0.0, 0.0)
    assert_cfloat(casinf(cfloat(0.0, 0.0)), 0.0, 0.0)
    assert_true(
        abs(Float64(cacosf(cfloat(0.0, 0.0)).re) - 1.5707963267948966) < EPS_F,
        "cacosf of nothing is a quarter turn",
    )
    assert_cfloat(catanf(cfloat(0.0, 0.0)), 0.0, 0.0)

    assert_cfloat(ccoshf(cfloat(0.0, 0.0)), 1.0, 0.0)
    assert_cfloat(csinhf(cfloat(0.0, 0.0)), 0.0, 0.0)
    assert_cfloat(ctanhf(cfloat(0.0, 0.0)), 0.0, 0.0)
    assert_cfloat(casinhf(cfloat(0.0, 0.0)), 0.0, 0.0)
    assert_cfloat(cacoshf(cfloat(1.0, 0.0)), 0.0, 0.0)
    assert_cfloat(catanhf(cfloat(0.0, 0.0)), 0.0, 0.0)

    assert_cfloat(clogf(cfloat(1.0, 0.0)), 0.0, 0.0)

    # `cpowf` takes the base and then the power, and both are one type,
    # so two to the three: eight, and not the nine it would be were the
    # two of them the other way round.
    assert_cfloat(cpowf(cfloat(2.0, 0.0), cfloat(3.0, 0.0)), 8.0, 0.0)


def main() raises:
    test_components()
    test_magnitude_and_phase()
    test_conjugate_and_projection()
    test_roots_and_exponentials()
    test_trigonometric()
    test_hyperbolic()
    test_float_variants()
    print("test_complex: ok")
