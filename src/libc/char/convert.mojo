from sys import external_call
from libc.constant import *


@always_inline("nodebug")
fn tolower(c: c_int) -> c_int:
    return external_call["tolower", c_int](c)

@always_inline("nodebug")
fn toupper(c: c_int) -> c_int:
    return external_call["toupper", c_int](c)

@always_inline("nodebug")
fn toascii(c: c_int) -> c_int:
    return external_call["toascii", c_int](c)