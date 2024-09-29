# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call



# ------------------------------------------------
# Floating-point environment
# ------------------------------------------------
fn fegetround() -> Int32:
    """C library <fenv.h> function `fegetround`.

    Reference:
        https://man7.org/linux/man-pages/man3/fesetround.3.html

    Prototype:
        int fegetround(void)

    Description:
        Gets the current floating-point rounding mode.

    Return Value:
        Upon successful completion, fegetround returns the rounding mode as one of the floating-point rounding macro values. A negative value is returned if the current rounding mode cannot be determined.
    """
    return external_call["fegetround", Int32]()



fn fesetround():
    pass 


fn feclearexcept(excepts: Int32) -> Int32:
    """

    """
    return external_call["feclearexcept", Int32, Int32](excepts)


fn feraiseexcept():
    pass 


fn fetestexcept():
    pass 


fn fetestexceptflag():
    pass 


fn fegetenv():
    pass 


fn fesetenv():
    pass 


fn fegetexceptflag():
    pass 


fn fesetexcept():
    pass 


fn fesetexceptflag():
    pass 


fn feholdexcept():
    pass 


fn feupdateenv():
    pass 


fn feenableexcept():
    pass 


fn fedisableexcept():
    pass 


fn fegetexcept():
    pass 