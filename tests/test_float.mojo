from std.testing import assert_equal, assert_true

from libc.float import (
    DBL_DIG,
    DBL_EPSILON,
    DBL_MANT_DIG,
    DBL_MAX,
    DBL_MAX_10_EXP,
    DBL_MIN,
    DBL_MIN_EXP,
    DECIMAL_DIG,
    FLT_DIG,
    FLT_EPSILON,
    FLT_MANT_DIG,
    FLT_MAX,
    FLT_RADIX,
    FLT_ROUNDS,
    LDBL_MANT_DIG,
)


def test_radix_and_precision() raises:
    assert_equal(FLT_RADIX, 2)
    assert_equal(FLT_MANT_DIG, 24)
    assert_equal(DBL_MANT_DIG, 53)
    assert_equal(FLT_DIG, 6)
    assert_equal(DBL_DIG, 15)
    # `long double` is the 80-bit x87 type on x86-64, IEEE quad on the
    # aarch64 machines, and plain `double` on Darwin, and the header
    # answers differently because of it. Asking which of the three it is
    # asks the same question as writing a number down would, without
    # writing a number twice that a platform can disprove.
    assert_true(
        LDBL_MANT_DIG == DBL_MANT_DIG
        or LDBL_MANT_DIG == 64
        or LDBL_MANT_DIG == 113
    )
    assert_true(DECIMAL_DIG == 17 or DECIMAL_DIG == 21 or DECIMAL_DIG == 36)
    assert_true(DECIMAL_DIG >= DBL_DIG)


def test_ranges() raises:
    assert_equal(FLT_ROUNDS, 1)
    assert_equal(DBL_MIN_EXP, -1021)
    assert_equal(DBL_MAX_10_EXP, 308)


def test_magnitudes() raises:
    assert_true(FLT_MAX > 0.0)
    assert_true(DBL_MAX > 0.0)
    assert_true(FLT_EPSILON > 0.0)
    assert_true(FLT_EPSILON < 1.0)
    assert_true(DBL_EPSILON > 0.0)
    assert_true(DBL_EPSILON < 1.0)
    assert_true(DBL_MIN > 0.0)
    assert_true(DBL_MIN < DBL_EPSILON)


def main() raises:
    test_radix_and_precision()
    test_ranges()
    test_magnitudes()
    print("test_float: ok")
