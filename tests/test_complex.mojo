from std.testing import assert_equal, assert_true

from libc.complex import (
    cabs,
    cabsf,
    cacos,
    cacosh,
    carg,
    cargf,
    casin,
    casinh,
    catan,
    catanh,
    ccos,
    ccosh,
    cdouble,
    cexp,
    cexpf,
    cfloat,
    cimag,
    cimagf,
    clog,
    conj,
    conjf,
    cpow,
    cproj,
    cprojf,
    creal,
    crealf,
    csin,
    csinf,
    csinh,
    csqrt,
    csqrtf,
    ctan,
    ctanh,
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


def main() raises:
    test_components()
    test_magnitude_and_phase()
    test_conjugate_and_projection()
    test_roots_and_exponentials()
    test_trigonometric()
    test_hyperbolic()
    print("test_complex: ok")
