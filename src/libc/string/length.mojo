from sys import external_call
from libc.constant import *


@always_inline("nodebug")
fn strlen(s: UnsafePointer[c_char]) -> c_size_t:
    return external_call["strlen", c_size_t](s)


@always_inline("nodebug")
fn strnlen(s: UnsafePointer[c_char], maxlen: c_size_t) -> c_size_t:
    return external_call["strnlen", c_size_t](s, maxlen)
