# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call


# ------------------------------------------------
# Floating-point environment
# ------------------------------------------------
def fegetround() -> Int32:
    """C library <fenv.h> function `fegetround`.

    Reference:
        https://man7.org/linux/man-pages/man3/fegetround.3.html

    Prototype:
        int fegetround(void)

    Description:
        Gets the current floating-point rounding mode.

    Return Value:
        Upon successful completion, fegetround returns the rounding mode as one of the floating-point rounding macro values. A negative value is returned if the current rounding mode cannot be determined.
    """
    return external_call["fegetround", Int32]()


def fesetround(round: Int32) -> Int32:
    """C library <fenv.h> function `fesetround`.

    Reference:
        https://man7.org/linux/man-pages/man3/fesetround.3.html

    Prototype:
        int fesetround(int round)

    Description:
        Sets the current floating-point rounding mode.

    Return Value:
        return a zero value if and only if the requested rounding direction was established.
    """
    return external_call["fesetround", Int32, Int32](round)


def feclearexcept(excepts: Int32) -> Int32:
    """C library <fenv.h> function `feclearexcept`.

    Reference:
        https://man7.org/linux/man-pages/man3/feclearexcept.3.html

    Prototype:
        int feclearexcept(int excepts)

    Description:
        The functionality described on this reference page is aligned
        with the ISO C standard. Any conflict between the requirements
        described here and the ISO C standard is unintentional. This
        volume of POSIX.1‐2017 defers to the ISO C standard.

    Return Value:
        If the argument is zero or if all the specified exceptions were
        successfully cleared, feclearexcept() shall return zero.
        Otherwise, it shall return a non-zero value.
    """
    return external_call["feclearexcept", Int32, Int32](excepts)


def feraiseexcept(excepts: Int32) -> Int32:
    """C library <fenv.h> function `feraiseexcept`.

    Reference:
        https://man7.org/linux/man-pages/man3/feraiseexcept.3.html

    Prototype:
        int feraiseexcept(int excepts)

    Description:
        The functionality described on this reference page is aligned
        with the ISO C standard. Any conflict between the requirements
        described here and the ISO C standard is unintentional. This
        volume of POSIX.1‐2017 defers to the ISO C standard.

    Return Value:
        If the argument is zero or if all the specified exceptions were
        successfully raised, feraiseexcept() shall return zero.
        Otherwise, it shall return a non-zero value.
    """
    return external_call["feraiseexcept", Int32, Int32](excepts)


def fetestexcept(excepts: Int32) -> Int32:
    """C library <fenv.h> function `fetestexcept`.

    Reference:
        https://man7.org/linux/man-pages/man3/fetestexcept.3.html

    Prototype:
        int fetestexcept(int excepts)

    Description:
        The functionality described on this reference page is aligned
       with the ISO C standard. Any conflict between the requirements
       described here and the ISO C standard is unintentional. This
       volume of POSIX.1‐2017 defers to the ISO C standard.

    Return Value:
        The fetestexcept() function shall return the value of the
       bitwise-inclusive OR of the floating-point exception macros
       corresponding to the currently set floating-point exceptions
       included in excepts.
    """
    return external_call["fetestexcept", Int32, Int32](excepts)


def fetestexceptflag():
    pass


def fegetenv():
    pass


def fesetenv():
    pass


def fegetexceptflag():
    pass


def fesetexcept():
    pass


def fesetexceptflag():
    pass


def feholdexcept():
    pass


def feupdateenv():
    pass


def feenableexcept():
    pass


def fedisableexcept():
    pass


def fegetexcept():
    pass
