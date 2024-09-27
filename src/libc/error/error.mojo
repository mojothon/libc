from sys import external_call
from libc.constant import *
from libc.utils import CString


@always_inline("nodebug")
fn strerror(errnum: c_int) -> CString:
    return external_call["strerror", UnsafePointer[c_char]](errnum)


@always_inline("nodebug")
fn strerror_l(errnum: c_int, locale: UnsafePointer) -> CString:
    return external_call["strerror_l", UnsafePointer[c_char]](errnum, locale)


@always_inline("nodebug")
fn strerror_r(errnum: c_int, buf: UnsafePointer[c_char], n: c_size_t) -> CString:
    return external_call["strerror_r", UnsafePointer[c_char]](errnum, buf, n)


@always_inline("nodebug")
fn perror(message: StringLiteral):
    external_call["perror", NoneType](message)


@always_inline("nodebug")
fn strerrorname_np(errnum: c_int) -> CString:
    return external_call["strerrorname_np", UnsafePointer[c_char]](errnum)


@always_inline("nodebug")
fn strerrordesc_np(errnum: c_int) -> CString:
    return external_call["strerrordesc_np", UnsafePointer[c_char]](errnum)


@always_inline("nodebug")
fn error(status: c_int, errnum: c_int, format: StringLiteral):
    external_call["error", NoneType](status, errnum, format)


@always_inline("nodebug")
fn error_at_line(status: c_int, errnum: c_int, fname: StringLiteral, lineno: c_uint, format: StringLiteral):
    external_call["error_at_line", NoneType](status, errnum, fname, lineno, format)


@always_inline("nodebug")
fn warn(format: StringLiteral):
    external_call["warn", NoneType](format)


@always_inline("nodebug")
fn warnx(format: StringLiteral):
    external_call["warnx", NoneType](format)


@always_inline("nodebug")
fn err(status: c_int, format: StringLiteral):
    external_call["err", NoneType](status, format)


@always_inline("nodebug")
fn errx(status: c_int, format: StringLiteral):
    external_call["errx", NoneType](status, format)
