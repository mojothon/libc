from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.fenv import (
    FE_ALL_EXCEPT,
    FE_DOWNWARD,
    FE_INEXACT,
    FE_INVALID,
    FE_TONEAREST,
    FE_UPWARD,
    FE_TOWARDZERO,
    fenv_t,
    fexcept_t,
    feclearexcept,
    fegetenv,
    fegetexceptflag,
    fegetround,
    feholdexcept,
    feraiseexcept,
    fesetenv,
    fesetexceptflag,
    fesetround,
    fetestexcept,
    feupdateenv,
)
from libc.math import rint
from libc.stdlib import strtod
from libc.utils import string_to_char_ptr


def for_each_mode(mode: Int32) raises:
    assert_equal(fesetround(mode), 0, "setting mode " + String(mode))
    assert_equal(fegetround(), mode, "and reading it back")


def test_rounding_modes() raises:
    # The mode is a macro in C and a different number on arm64 than on x86, so
    # this is what catches a wrong one.
    assert_equal(fegetround(), FE_TONEAREST, "the default is round to nearest")

    for_each_mode(FE_UPWARD)
    for_each_mode(FE_DOWNWARD)
    for_each_mode(FE_TOWARDZERO)
    for_each_mode(FE_TONEAREST)

    # And from the arithmetic side, which is what tells two swapped constants
    # apart. The halves come out of `strtod` rather than a literal because the
    # compiler folds `rint(0.5)` to a constant under the default mode.
    var half = string_to_char_ptr("0.5")
    var minus_half = string_to_char_ptr("-0.5")

    assert_equal(fesetround(FE_UPWARD), 0, "rounding up was set")
    assert_equal(rint(strtod(half)), 1.0, "0.5 rounds up to 1")
    assert_equal(rint(strtod(minus_half)), 0.0, "-0.5 rounds up to 0")

    assert_equal(fesetround(FE_DOWNWARD), 0, "rounding down was set")
    assert_equal(rint(strtod(half)), 0.0, "0.5 rounds down to 0")
    assert_equal(rint(strtod(minus_half)), -1.0, "-0.5 rounds down to -1")

    half.unsafe_free()
    minus_half.unsafe_free()

    assert_equal(fesetround(FE_TONEAREST), 0, "the default is back")


def test_exception_flags() raises:
    assert_equal(
        feclearexcept(FE_ALL_EXCEPT), 0, "the flags start out clearable"
    )
    assert_equal(fetestexcept(FE_ALL_EXCEPT), 0, "and then are clear")

    assert_equal(feraiseexcept(FE_INEXACT), 0, "an exception was raised")
    assert_true(fetestexcept(FE_INEXACT) != 0, "and it shows up")
    assert_equal(
        fetestexcept(FE_INVALID), 0, "raising one does not raise the others"
    )

    assert_equal(feclearexcept(FE_ALL_EXCEPT), 0, "the flags were cleared")
    assert_equal(fetestexcept(FE_ALL_EXCEPT), 0, "and are clear again")


def test_exceptflag_round_trip() raises:
    var flags = unsafe_alloc[fexcept_t](1)
    flags[] = fexcept_t()

    assert_equal(feclearexcept(FE_ALL_EXCEPT), 0, "the flags start out clear")
    assert_equal(feraiseexcept(FE_INVALID), 0, "an exception was raised")
    assert_equal(
        fegetexceptflag(flags, FE_ALL_EXCEPT), 0, "the flags were saved"
    )

    assert_equal(feclearexcept(FE_ALL_EXCEPT), 0, "the flags were cleared")
    assert_equal(fetestexcept(FE_INVALID), 0, "and the exception is gone")

    assert_equal(
        fesetexceptflag(flags, FE_ALL_EXCEPT), 0, "the flags were restored"
    )
    assert_true(fetestexcept(FE_INVALID) != 0, "and the exception is back")

    assert_equal(feclearexcept(FE_ALL_EXCEPT), 0, "the flags were cleared")
    flags.unsafe_free()


def test_environment_round_trip() raises:
    var env = unsafe_alloc[fenv_t](1)
    env[] = fenv_t()

    assert_equal(fegetenv(env), 0, "the environment was saved")
    assert_equal(fesetround(FE_UPWARD), 0, "the mode was changed")
    assert_equal(fesetenv(env), 0, "the environment was restored")
    assert_equal(fegetround(), FE_TONEAREST, "and the default mode is back")

    # feholdexcept saves the environment and quiets the flags, and feupdateenv
    # puts the environment back while keeping whatever was raised meanwhile.
    assert_equal(feclearexcept(FE_ALL_EXCEPT), 0, "the flags start out clear")
    assert_equal(feholdexcept(env), 0, "the environment was saved and quieted")
    assert_equal(fesetround(FE_UPWARD), 0, "the mode was changed")
    assert_equal(feraiseexcept(FE_INEXACT), 0, "an exception was raised")
    assert_equal(feupdateenv(env), 0, "the environment was restored")
    assert_equal(fegetround(), FE_TONEAREST, "the default mode is back")
    assert_true(fetestexcept(FE_INEXACT) != 0, "and the exception survived")

    assert_equal(feclearexcept(FE_ALL_EXCEPT), 0, "the flags were cleared")
    env.unsafe_free()


def main() raises:
    test_rounding_modes()
    test_exception_flags()
    test_exceptflag_round_trip()
    test_environment_round_trip()
    print("test_fenv: ok")
