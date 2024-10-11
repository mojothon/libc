# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call
from memory import UnsafePointer
from libc.constant import *


@always_inline("nodebug")
fn mtrace() -> NoneType:
    return external_call["mtrace", NoneType]()

@always_inline("nodebug")
fn muntrace() -> NoneType:
    return external_call["muntrace", NoneType]()