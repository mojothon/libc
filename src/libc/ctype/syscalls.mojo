# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from libc.constant import *
from libc.locale import locale_t


@inline(.nodebug)
def islower(c: Int32) -> Int32:
    return external_call["islower", Int32](c)


@inline(.nodebug)
def islower_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["islower_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isupper(c: Int32) -> Int32:
    return external_call["isupper", Int32](c)


@inline(.nodebug)
def isupper_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isupper_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isalpha(c: Int32) -> Int32:
    return external_call["isalpha", Int32](c)


@inline(.nodebug)
def isdigit(c: Int32) -> Int32:
    return external_call["isdigit", Int32](c)


@inline(.nodebug)
def isdigit_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isdigit_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isalnum(c: Int32) -> Int32:
    return external_call["isalnum", Int32](c)


@inline(.nodebug)
def isalnum_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isalnum_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isxdigit(c: Int32) -> Int32:
    return external_call["isxdigit", Int32](c)


@inline(.nodebug)
def isxdigit_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isxdigit_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isspace(c: Int32) -> Int32:
    return external_call["isspace", Int32](c)


@inline(.nodebug)
def isblank(c: Int32) -> Int32:
    return external_call["isblank", Int32](c)


@inline(.nodebug)
def isblank_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isblank_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def iscntrl(c: Int32) -> Int32:
    return external_call["iscntrl", Int32](c)


@inline(.nodebug)
def iscntrl_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["iscntrl_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isgraph(c: Int32) -> Int32:
    return external_call["isgraph", Int32](c)


@inline(.nodebug)
def isgraph_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isgraph_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isascii(c: Int32) -> Int32:
    return external_call["isascii", Int32](c)


@inline(.nodebug)
def isascii_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isascii_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def isprint(c: Int32) -> Int32:
    return external_call["isprint", Int32](c)


@inline(.nodebug)
def isprint_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["isprint_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def ispunct(c: Int32) -> Int32:
    return external_call["ispunct", Int32](c)


@inline(.nodebug)
def ispunct_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["ispunct_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def tolower(c: Int32) -> Int32:
    return external_call["tolower", Int32](c)


@inline(.nodebug)
def tolower_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["tolower_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def toupper(c: Int32) -> Int32:
    return external_call["toupper", Int32](c)


@inline(.nodebug)
def toupper_l(c: Int32, loc: locale_t) -> Int32:
    return external_call["toupper_l", Int32, Int32, locale_t](c, loc)


@inline(.nodebug)
def toascii(c: Int32) -> Int32:
    return external_call["toascii", Int32](c)
