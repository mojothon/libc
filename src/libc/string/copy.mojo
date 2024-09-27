
from sys import external_call
from memory import UnsafePointer
from libc.constant import *


@always_inline("nodebug")
fn memcpy(
    dest: UnsafePointer[NoneType], src: UnsafePointer[NoneType], n: c_size_t
) -> UnsafePointer[NoneType]:
    return external_call["memcpy", UnsafePointer[NoneType]](dest, src, n)


@always_inline("nodebug")
fn mempcopy(
    dest: UnsafePointer[NoneType], src: UnsafePointer[NoneType], n: c_size_t
) -> UnsafePointer[NoneType]:
    return external_call["mempcopy", UnsafePointer[NoneType]](dest, src, n)


@always_inline("nodebug")
fn memmove(
    dest: UnsafePointer[NoneType], src: UnsafePointer[NoneType], n: c_size_t
) -> UnsafePointer[NoneType]:
    return external_call["memmove", UnsafePointer[NoneType]](dest, src, n)


@always_inline("nodebug")
fn memset(
    s: UnsafePointer[NoneType], c: c_int, n: c_size_t
) -> UnsafePointer[NoneType]:
    return external_call["memset", UnsafePointer[NoneType]](s, c, n)


@always_inline("nodebug")
fn strcopy(
    dest: UnsafePointer[c_char], src: UnsafePointer[c_char]
) -> UnsafePointer[c_char]:
    return external_call["strcpy", UnsafePointer[c_char]](dest, src)


@always_inline("nodebug")
fn strncopy(
    dest: UnsafePointer[c_char], src: UnsafePointer[c_char], n: c_size_t
) -> UnsafePointer[c_char]:
    return external_call["strncpy", UnsafePointer[c_char]](dest, src, n)


@always_inline("nodebug")
fn strdup(s: UnsafePointer[c_char]) -> UnsafePointer[c_char]:
    return external_call["strdup", UnsafePointer[c_char]](s)


@always_inline("nodebug")
fn strndup(s: UnsafePointer[c_char], n: c_size_t) -> UnsafePointer[c_char]:
    return external_call["strndup", UnsafePointer[c_char]](s, n)