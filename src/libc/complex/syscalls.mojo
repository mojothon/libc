# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_double, c_float


# C has no Mojo equivalent for a complex number, so a complex value is modelled
# as the struct the ABI actually passes: two components, laid out
# real-then-imaginary, exactly like `double complex`. The FFI hands such a
# struct to C in the same registers a complex number would use.
#
# `RegisterPassable` is required: `external_call` only accepts register
# passable types as its return type, and every function that returns a complex
# number needs `cdouble`/`cfloat` back.
struct cdouble(RegisterPassable):
    """A C `double complex`: two `Float64` components, real first."""

    var re: c_double
    var im: c_double

    def __init__(out self, re: c_double, im: c_double):
        """Builds `re + im * i`.

        Args:
            re: The real component.
            im: The imaginary component.
        """
        self.re = re
        self.im = im


struct cfloat(RegisterPassable):
    """A C `float complex`: two `Float32` components, real first."""

    var re: c_float
    var im: c_float

    def __init__(out self, re: c_float, im: c_float):
        """Builds `re + im * i`.

        Args:
            re: The real component.
            im: The imaginary component.
        """
        self.re = re
        self.im = im


# `long double complex` is deliberately absent, for the same reason libc.float
# has no `LDBL_*`: this ABI's `long double` is the 80-bit x87 format, which
# Mojo cannot express.


def creal(z: cdouble) -> c_double:
    """Libc C99 `creal` function.

    Args:
        z: A complex number.

    Returns:
        The real component of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/creal).
        Fn signature: `double creal(double complex z)`.
    """
    return external_call["creal", c_double, cdouble](z)


def crealf(z: cfloat) -> c_float:
    """Libc C99 `crealf` function.

    Args:
        z: A complex number.

    Returns:
        The real component of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/creal).
        Fn signature: `float crealf(float complex z)`.
    """
    return external_call["crealf", c_float, cfloat](z)


def cimag(z: cdouble) -> c_double:
    """Libc C99 `cimag` function.

    Args:
        z: A complex number.

    Returns:
        The imaginary component of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cimag).
        Fn signature: `double cimag(double complex z)`.
    """
    return external_call["cimag", c_double, cdouble](z)


def cimagf(z: cfloat) -> c_float:
    """Libc C99 `cimagf` function.

    Args:
        z: A complex number.

    Returns:
        The imaginary component of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cimag).
        Fn signature: `float cimagf(float complex z)`.
    """
    return external_call["cimagf", c_float, cfloat](z)


def cabs(z: cdouble) -> c_double:
    """Libc C99 `cabs` function.

    Args:
        z: A complex number.

    Returns:
        The magnitude (absolute value) of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cabs).
        Fn signature: `double cabs(double complex z)`.
    """
    return external_call["cabs", c_double, cdouble](z)


def cabsf(z: cfloat) -> c_float:
    """Libc C99 `cabsf` function.

    Args:
        z: A complex number.

    Returns:
        The magnitude (absolute value) of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cabs).
        Fn signature: `float cabsf(float complex z)`.
    """
    return external_call["cabsf", c_float, cfloat](z)


def carg(z: cdouble) -> c_double:
    """Libc C99 `carg` function.

    Args:
        z: A complex number.

    Returns:
        The phase angle of z in radians, in (-pi, pi].

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/carg).
        Fn signature: `double carg(double complex z)`.
    """
    return external_call["carg", c_double, cdouble](z)


def cargf(z: cfloat) -> c_float:
    """Libc C99 `cargf` function.

    Args:
        z: A complex number.

    Returns:
        The phase angle of z in radians, in (-pi, pi].

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/carg).
        Fn signature: `float cargf(float complex z)`.
    """
    return external_call["cargf", c_float, cfloat](z)


def conj(z: cdouble) -> cdouble:
    """Libc C99 `conj` function.

    Args:
        z: A complex number.

    Returns:
        The complex conjugate of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/conj).
        Fn signature: `double complex conj(double complex z)`.
    """
    return external_call["conj", cdouble, cdouble](z)


def conjf(z: cfloat) -> cfloat:
    """Libc C99 `conjf` function.

    Args:
        z: A complex number.

    Returns:
        The complex conjugate of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/conj).
        Fn signature: `float complex conjf(float complex z)`.
    """
    return external_call["conjf", cfloat, cfloat](z)


def cproj(z: cdouble) -> cdouble:
    """Libc C99 `cproj` function.

    Args:
        z: A complex number.

    Returns:
        The projection of z onto the Riemann sphere, which maps every
        infinity to a finite one.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cproj).
        Fn signature: `double complex cproj(double complex z)`.
    """
    return external_call["cproj", cdouble, cdouble](z)


def cprojf(z: cfloat) -> cfloat:
    """Libc C99 `cprojf` function.

    Args:
        z: A complex number.

    Returns:
        The projection of z onto the Riemann sphere, which maps every
        infinity to a finite one.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cproj).
        Fn signature: `float complex cprojf(float complex z)`.
    """
    return external_call["cprojf", cfloat, cfloat](z)


def csqrt(z: cdouble) -> cdouble:
    """Libc C99 `csqrt` function.

    Args:
        z: A complex number.

    Returns:
        The square root of z, with a branch cut along the negative real axis.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/csqrt).
        Fn signature: `double complex csqrt(double complex z)`.
    """
    return external_call["csqrt", cdouble, cdouble](z)


def csqrtf(z: cfloat) -> cfloat:
    """Libc C99 `csqrtf` function.

    Args:
        z: A complex number.

    Returns:
        The square root of z, with a branch cut along the negative real axis.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/csqrt).
        Fn signature: `float complex csqrtf(float complex z)`.
    """
    return external_call["csqrtf", cfloat, cfloat](z)


def cexp(z: cdouble) -> cdouble:
    """Libc C99 `cexp` function.

    Args:
        z: A complex number.

    Returns:
        The value of e raised to z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cexp).
        Fn signature: `double complex cexp(double complex z)`.
    """
    return external_call["cexp", cdouble, cdouble](z)


def cexpf(z: cfloat) -> cfloat:
    """Libc C99 `cexpf` function.

    Args:
        z: A complex number.

    Returns:
        The value of e raised to z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cexp).
        Fn signature: `float complex cexpf(float complex z)`.
    """
    return external_call["cexpf", cfloat, cfloat](z)


def clog(z: cdouble) -> cdouble:
    """Libc C99 `clog` function.

    Args:
        z: A complex number.

    Returns:
        The natural logarithm of z, with a branch cut along the negative
        real axis.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/clog).
        Fn signature: `double complex clog(double complex z)`.
    """
    return external_call["clog", cdouble, cdouble](z)


def clogf(z: cfloat) -> cfloat:
    """Libc C99 `clogf` function.

    Args:
        z: A complex number.

    Returns:
        The natural logarithm of z, with a branch cut along the negative
        real axis.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/clog).
        Fn signature: `float complex clogf(float complex z)`.
    """
    return external_call["clogf", cfloat, cfloat](z)


def cpow(z: cdouble, w: cdouble) -> cdouble:
    """Libc C99 `cpow` function.

    Args:
        z: The base.
        w: The exponent.

    Returns:
        The value of z raised to w, with a branch cut along the
        negative real axis.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cpow).
        Fn signature: `double complex cpow(double complex z, double complex w)`.
    """
    return external_call["cpow", cdouble, cdouble, cdouble](z, w)


def cpowf(z: cfloat, w: cfloat) -> cfloat:
    """Libc C99 `cpowf` function.

    Args:
        z: The base.
        w: The exponent.

    Returns:
        The value of z raised to w, with a branch cut along the
        negative real axis.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cpow).
        Fn signature: `float complex cpowf(float complex z, float complex w)`.
    """
    return external_call["cpowf", cfloat, cfloat, cfloat](z, w)


def csin(z: cdouble) -> cdouble:
    """Libc C99 `csin` function.

    Args:
        z: A complex number.

    Returns:
        The complex sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/csin).
        Fn signature: `double complex csin(double complex z)`.
    """
    return external_call["csin", cdouble, cdouble](z)


def csinf(z: cfloat) -> cfloat:
    """Libc C99 `csinf` function.

    Args:
        z: A complex number.

    Returns:
        The complex sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/csin).
        Fn signature: `float complex csinf(float complex z)`.
    """
    return external_call["csinf", cfloat, cfloat](z)


def ccos(z: cdouble) -> cdouble:
    """Libc C99 `ccos` function.

    Args:
        z: A complex number.

    Returns:
        The complex cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ccos).
        Fn signature: `double complex ccos(double complex z)`.
    """
    return external_call["ccos", cdouble, cdouble](z)


def ccosf(z: cfloat) -> cfloat:
    """Libc C99 `ccosf` function.

    Args:
        z: A complex number.

    Returns:
        The complex cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ccos).
        Fn signature: `float complex ccosf(float complex z)`.
    """
    return external_call["ccosf", cfloat, cfloat](z)


def ctan(z: cdouble) -> cdouble:
    """Libc C99 `ctan` function.

    Args:
        z: A complex number.

    Returns:
        The complex tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ctan).
        Fn signature: `double complex ctan(double complex z)`.
    """
    return external_call["ctan", cdouble, cdouble](z)


def ctanf(z: cfloat) -> cfloat:
    """Libc C99 `ctanf` function.

    Args:
        z: A complex number.

    Returns:
        The complex tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ctan).
        Fn signature: `float complex ctanf(float complex z)`.
    """
    return external_call["ctanf", cfloat, cfloat](z)


def casin(z: cdouble) -> cdouble:
    """Libc C99 `casin` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/casin).
        Fn signature: `double complex casin(double complex z)`.
    """
    return external_call["casin", cdouble, cdouble](z)


def casinf(z: cfloat) -> cfloat:
    """Libc C99 `casinf` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/casin).
        Fn signature: `float complex casinf(float complex z)`.
    """
    return external_call["casinf", cfloat, cfloat](z)


def cacos(z: cdouble) -> cdouble:
    """Libc C99 `cacos` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cacos).
        Fn signature: `double complex cacos(double complex z)`.
    """
    return external_call["cacos", cdouble, cdouble](z)


def cacosf(z: cfloat) -> cfloat:
    """Libc C99 `cacosf` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cacos).
        Fn signature: `float complex cacosf(float complex z)`.
    """
    return external_call["cacosf", cfloat, cfloat](z)


def catan(z: cdouble) -> cdouble:
    """Libc C99 `catan` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/catan).
        Fn signature: `double complex catan(double complex z)`.
    """
    return external_call["catan", cdouble, cdouble](z)


def catanf(z: cfloat) -> cfloat:
    """Libc C99 `catanf` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/catan).
        Fn signature: `float complex catanf(float complex z)`.
    """
    return external_call["catanf", cfloat, cfloat](z)


def csinh(z: cdouble) -> cdouble:
    """Libc C99 `csinh` function.

    Args:
        z: A complex number.

    Returns:
        The complex hyperbolic sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/csinh).
        Fn signature: `double complex csinh(double complex z)`.
    """
    return external_call["csinh", cdouble, cdouble](z)


def csinhf(z: cfloat) -> cfloat:
    """Libc C99 `csinhf` function.

    Args:
        z: A complex number.

    Returns:
        The complex hyperbolic sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/csinh).
        Fn signature: `float complex csinhf(float complex z)`.
    """
    return external_call["csinhf", cfloat, cfloat](z)


def ccosh(z: cdouble) -> cdouble:
    """Libc C99 `ccosh` function.

    Args:
        z: A complex number.

    Returns:
        The complex hyperbolic cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ccosh).
        Fn signature: `double complex ccosh(double complex z)`.
    """
    return external_call["ccosh", cdouble, cdouble](z)


def ccoshf(z: cfloat) -> cfloat:
    """Libc C99 `ccoshf` function.

    Args:
        z: A complex number.

    Returns:
        The complex hyperbolic cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ccosh).
        Fn signature: `float complex ccoshf(float complex z)`.
    """
    return external_call["ccoshf", cfloat, cfloat](z)


def ctanh(z: cdouble) -> cdouble:
    """Libc C99 `ctanh` function.

    Args:
        z: A complex number.

    Returns:
        The complex hyperbolic tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ctanh).
        Fn signature: `double complex ctanh(double complex z)`.
    """
    return external_call["ctanh", cdouble, cdouble](z)


def ctanhf(z: cfloat) -> cfloat:
    """Libc C99 `ctanhf` function.

    Args:
        z: A complex number.

    Returns:
        The complex hyperbolic tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/ctanh).
        Fn signature: `float complex ctanhf(float complex z)`.
    """
    return external_call["ctanhf", cfloat, cfloat](z)


def casinh(z: cdouble) -> cdouble:
    """Libc C99 `casinh` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc hyperbolic sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/casinh).
        Fn signature: `double complex casinh(double complex z)`.
    """
    return external_call["casinh", cdouble, cdouble](z)


def casinhf(z: cfloat) -> cfloat:
    """Libc C99 `casinhf` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc hyperbolic sine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/casinh).
        Fn signature: `float complex casinhf(float complex z)`.
    """
    return external_call["casinhf", cfloat, cfloat](z)


def cacosh(z: cdouble) -> cdouble:
    """Libc C99 `cacosh` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc hyperbolic cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cacosh).
        Fn signature: `double complex cacosh(double complex z)`.
    """
    return external_call["cacosh", cdouble, cdouble](z)


def cacoshf(z: cfloat) -> cfloat:
    """Libc C99 `cacoshf` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc hyperbolic cosine of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/cacosh).
        Fn signature: `float complex cacoshf(float complex z)`.
    """
    return external_call["cacoshf", cfloat, cfloat](z)


def catanh(z: cdouble) -> cdouble:
    """Libc C99 `catanh` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc hyperbolic tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/catanh).
        Fn signature: `double complex catanh(double complex z)`.
    """
    return external_call["catanh", cdouble, cdouble](z)


def catanhf(z: cfloat) -> cfloat:
    """Libc C99 `catanhf` function.

    Args:
        z: A complex number.

    Returns:
        The complex arc hyperbolic tangent of z.

    Notes:
        [Reference](https://en.cppreference.com/w/c/numeric/complex/catanh).
        Fn signature: `float complex catanhf(float complex z)`.
    """
    return external_call["catanhf", cfloat, cfloat](z)
