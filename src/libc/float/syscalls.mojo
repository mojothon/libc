# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <float.h> limits.
#
# Every constant is a compile-time value for the x86_64 System V ABI
# (LP64, IEEE-754 binary32/binary64). `long double` on that ABI is the
# 80-bit x87 format, for which Mojo has no type, so the `LDBL_*`
# extremes that overflow a `Float64` are deliberately not defined.
# ----------------------------------
from libc.constant import c_double, c_float, c_int


# -------------------------------------------------------
#  rounding and evaluation
# -------------------------------------------------------
comptime FLT_ROUNDS: c_int = 1
"""The rounding mode for floating-point addition: round to nearest."""

comptime FLT_EVAL_METHOD: c_int = 0
"""0: operations are evaluated in the precision of their own type."""

comptime DECIMAL_DIG: c_int = 21
"""Number of decimal digits needed to round-trip the widest
floating-point type (`long double`) without loss."""


# -------------------------------------------------------
#  radix and mantissa
# -------------------------------------------------------
comptime FLT_RADIX: c_int = 2
"""The radix of the floating-point representation."""

comptime FLT_MANT_DIG: c_int = 24
"""Number of base-`FLT_RADIX` digits in a `float` significand."""

comptime DBL_MANT_DIG: c_int = 53
"""Number of base-`FLT_RADIX` digits in a `double` significand."""

comptime LDBL_MANT_DIG: c_int = 64
"""Number of base-`FLT_RADIX` digits in a `long double` significand."""

comptime FLT_DIG: c_int = 6
"""Decimal digits that survive a `float` round-trip."""

comptime DBL_DIG: c_int = 15
"""Decimal digits that survive a `double` round-trip."""

comptime LDBL_DIG: c_int = 18
"""Decimal digits that survive a `long double` round-trip."""


# -------------------------------------------------------
#  exponent range
# -------------------------------------------------------
comptime FLT_MIN_EXP: c_int = -125
"""Minimum negative integer such that `FLT_RADIX` raised to that power
minus 1 is a normalized `float`."""

comptime DBL_MIN_EXP: c_int = -1021
"""Minimum exponent of a normalized `double` (base `FLT_RADIX`)."""

comptime LDBL_MIN_EXP: c_int = -16381
"""Minimum exponent of a normalized `long double` (base `FLT_RADIX`)."""

comptime FLT_MIN_10_EXP: c_int = -37
"""Minimum negative integer such that 10 raised to that power is a
normalized `float`."""

comptime DBL_MIN_10_EXP: c_int = -307
"""Minimum negative integer such that 10 raised to that power is a
normalized `double`."""

comptime LDBL_MIN_10_EXP: c_int = -4931
"""Minimum negative integer such that 10 raised to that power is a
normalized `long double`."""

comptime FLT_MAX_EXP: c_int = 128
"""Maximum integer such that `FLT_RADIX` raised to that power minus 1
is a representable `float`."""

comptime DBL_MAX_EXP: c_int = 1024
"""Maximum exponent of a `double` (base `FLT_RADIX`)."""

comptime LDBL_MAX_EXP: c_int = 16384
"""Maximum exponent of a `long double` (base `FLT_RADIX`)."""

comptime FLT_MAX_10_EXP: c_int = 38
"""Maximum integer such that 10 raised to that power is a
representable `float`."""

comptime DBL_MAX_10_EXP: c_int = 308
"""Maximum integer such that 10 raised to that power is a
representable `double`."""

comptime LDBL_MAX_10_EXP: c_int = 4932
"""Maximum integer such that 10 raised to that power is a
representable `long double`."""


# -------------------------------------------------------
#  magnitudes
# -------------------------------------------------------
comptime FLT_MAX: c_float = 3.4028234663852886e38
"""Maximum representable finite `float`."""

comptime DBL_MAX: c_double = 1.7976931348623157e308
"""Maximum representable finite `double`."""

comptime FLT_MIN: c_float = 1.1754943508222875e-38
"""Minimum normalized positive `float`."""

comptime DBL_MIN: c_double = 2.2250738585072014e-308
"""Minimum normalized positive `double`."""

comptime FLT_EPSILON: c_float = 1.1920928955078125e-07
"""Difference between 1.0 and the next representable `float`."""

comptime DBL_EPSILON: c_double = 2.2204460492503131e-16
"""Difference between 1.0 and the next representable `double`."""

comptime LDBL_EPSILON: c_double = 1.0842021724855044e-19
"""Difference between 1.0 and the next representable `long double`.

The x87 80-bit value is 1.08420217248550443401e-19; this is the nearest
`Float64`, since Mojo has no 80-bit type.
"""

comptime FLT_TRUE_MIN: c_float = 1.4012984643248171e-45
"""Minimum positive subnormal `float`."""

# `DBL_TRUE_MIN` (4.9406564584124654e-324) is deliberately absent: Mojo
# folds that subnormal literal to 0.0, so exposing it would be a lie. Use
# `DBL_MIN` for the smallest normalized value.
