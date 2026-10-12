from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
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


def probe() raises:
    # Temporary: ask Darwin what its macros are instead of guessing.
    # Unrolled on purpose, and every call takes a different argument:
    # in a loop the compiler hoists these calls out and folds the
    # second `rint` into the first, which is what made the last two
    # attempts print the same number eight times.
    print("probe initial round", fegetround())
    var rc0 = fesetround(Int32(0))
    print(
        "probe v 0 rc",
        rc0,
        "rint",
        rint(strtod(string_to_char_ptr("0.5"))),
        rint(strtod(string_to_char_ptr("1.5"))),
        rint(strtod(string_to_char_ptr("-0.5"))),
    )
    var rc1 = fesetround(Int32(1))
    print(
        "probe v 1 rc",
        rc1,
        "rint",
        rint(strtod(string_to_char_ptr("0.50"))),
        rint(strtod(string_to_char_ptr("1.50"))),
        rint(strtod(string_to_char_ptr("-0.50"))),
    )
    var rc2 = fesetround(Int32(2))
    print(
        "probe v 2 rc",
        rc2,
        "rint",
        rint(strtod(string_to_char_ptr("0.500"))),
        rint(strtod(string_to_char_ptr("1.500"))),
        rint(strtod(string_to_char_ptr("-0.500"))),
    )
    var rc3 = fesetround(Int32(3))
    print(
        "probe v 3 rc",
        rc3,
        "rint",
        rint(strtod(string_to_char_ptr("0.5000"))),
        rint(strtod(string_to_char_ptr("1.5000"))),
        rint(strtod(string_to_char_ptr("-0.5000"))),
    )
    var rc4 = fesetround(Int32(4))
    print(
        "probe v 4 rc",
        rc4,
        "rint",
        rint(strtod(string_to_char_ptr("0.50000"))),
        rint(strtod(string_to_char_ptr("1.50000"))),
        rint(strtod(string_to_char_ptr("-0.50000"))),
    )
    var rc5 = fesetround(Int32(5))
    print(
        "probe v 5 rc",
        rc5,
        "rint",
        rint(strtod(string_to_char_ptr("0.500000"))),
        rint(strtod(string_to_char_ptr("1.500000"))),
        rint(strtod(string_to_char_ptr("-0.500000"))),
    )
    var rc6 = fesetround(Int32(6))
    print(
        "probe v 6 rc",
        rc6,
        "rint",
        rint(strtod(string_to_char_ptr("0.5000000"))),
        rint(strtod(string_to_char_ptr("1.5000000"))),
        rint(strtod(string_to_char_ptr("-0.5000000"))),
    )
    var rc7 = fesetround(Int32(7))
    print(
        "probe v 7 rc",
        rc7,
        "rint",
        rint(strtod(string_to_char_ptr("0.50000000"))),
        rint(strtod(string_to_char_ptr("1.50000000"))),
        rint(strtod(string_to_char_ptr("-0.50000000"))),
    )
    var c0 = feclearexcept(Int32(0x1F))
    var r0 = feraiseexcept(Int32(1 << 0))
    print(
        "probe bit 0 clear",
        c0,
        "raise",
        r0,
        "seen",
        fetestexcept(Int32(0x1F) | Int32(1 << 5)),
    )
    var c1 = feclearexcept(Int32(0x1F))
    var r1 = feraiseexcept(Int32(1 << 1))
    print(
        "probe bit 1 clear",
        c1,
        "raise",
        r1,
        "seen",
        fetestexcept(Int32(0x1F) | Int32(1 << 6)),
    )
    var c2 = feclearexcept(Int32(0x1F))
    var r2 = feraiseexcept(Int32(1 << 2))
    print(
        "probe bit 2 clear",
        c2,
        "raise",
        r2,
        "seen",
        fetestexcept(Int32(0x1F) | Int32(1 << 7)),
    )
    var c3 = feclearexcept(Int32(0x1F))
    var r3 = feraiseexcept(Int32(1 << 3))
    print(
        "probe bit 3 clear",
        c3,
        "raise",
        r3,
        "seen",
        fetestexcept(Int32(0x1F) | Int32(1 << 8)),
    )
    var c4 = feclearexcept(Int32(0x1F))
    var r4 = feraiseexcept(Int32(1 << 4))
    print(
        "probe bit 4 clear",
        c4,
        "raise",
        r4,
        "seen",
        fetestexcept(Int32(0x1F) | Int32(1 << 9)),
    )
    var c5 = feclearexcept(Int32(0x1F))
    var r5 = feraiseexcept(Int32(1 << 5))
    print(
        "probe bit 5 clear",
        c5,
        "raise",
        r5,
        "seen",
        fetestexcept(Int32(0x1F) | Int32(1 << 10)),
    )
    _ = feclearexcept(Int32(0x1F))
    _ = fesetround(Int32(0))


def main() raises:
    comptime if CompilationTarget.is_macos():
        probe()
        print("test_fenv: ok")
    else:
        test_rounding_modes()
        test_exception_flags()
        test_exceptflag_round_trip()
        test_environment_round_trip()
        print("test_fenv: ok")
