from sys import external_call
from memory import UnsafePointer
from libc.constant import * 


@register_passable("trivial")
struct FILE:
    pass


fn fflush(arg: UnsafePointer[FILE]) -> Int32:
    """

    """
    return external_call["fflush", Int32, UnsafePointer[FILE]](arg)



fn asserts(expression: Bool) -> c_void:
    """
    Asserts that the expression is True. If the expression is False,
    the program will terminate with an error message.
    """
    args = int(expression)
    return external_call["assert", c_void, c_int](args)