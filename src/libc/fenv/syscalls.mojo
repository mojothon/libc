# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call



# ------------------------------------------------
# Floating-point environment
# ------------------------------------------------
fn fegetround():
    pass 


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