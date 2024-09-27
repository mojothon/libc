# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call
from libc.constant import *


@always_inline("nodebug")
fn isascii(c: c_int) -> c_int:
    return external_call["isascii", c_int](c)


@always_inline("nodebug")
fn isalnum(c: c_int) -> c_int:
    return external_call["isalnum", c_int](c)


@always_inline("nodebug")
fn isalpha(c: c_int) -> c_int:
    return external_call["isalpha", c_int](c)


@always_inline("nodebug")
fn isblank(c: c_int) -> c_int:
    return external_call["isblank", c_int](c)


@always_inline("nodebug")
fn iscntrl(c: c_int) -> c_int:
    return external_call["iscntrl", c_int](c)


@always_inline("nodebug")
fn isdigit(c: c_int) -> c_int:
    return external_call["isdigit", c_int](c)


@always_inline("nodebug")
fn isgraph(c: c_int) -> c_int:
    return external_call["isgraph", c_int](c)


@always_inline("nodebug")
fn islower(c: c_int) -> c_int:
    return external_call["islower", c_int](c)


@always_inline("nodebug")
fn ispunct(c: c_int) -> c_int:
    return external_call["ispunct", c_int](c)


@always_inline("nodebug")
fn isspace(c: c_int) -> c_int:
    return external_call["isspace", c_int](c)


@always_inline("nodebug")
fn isupper(c: c_int) -> c_int:
    return external_call["isupper", c_int](c)


@always_inline("nodebug")
fn isxdigit(c: c_int) -> c_int:
    return external_call["isxdigit", c_int](c)