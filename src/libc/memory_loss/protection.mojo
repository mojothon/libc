# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call
from memory import UnsafePointer
from libc.constant import *


@always_inline("nodebug")
fn mprotect(addr: UnsafePointer[NoneType], len: c_size_t, prot: c_int) -> c_int:
    return external_call["mprotect", c_int](addr, len, prot)


@always_inline("nodebug")
fn pkey_alloc(flags: c_uint, access_rights: c_uint) -> c_int:
    return external_call["pkey_alloc", c_int](flags, access_rights)


@always_inline("nodebug")
fn pkey_free(key: c_int) -> c_int:
    return external_call["pkey_free", c_int](key)


@always_inline("nodebug")
fn pkey_mprotect(
    addr: UnsafePointer[NoneType],
    len: c_size_t,
    prot: c_int,
    pkey: c_int,
) -> c_int:
    return external_call["pkey_mprotect", c_int](addr, len, prot, pkey)


@always_inline("nodebug")
fn pkey_set(key: c_int, access_rights: c_uint) -> c_int:
    return external_call["pkey_set", c_int](key, access_rights)


@always_inline("nodebug")
fn pkey_get(key: c_int) -> c_uint:
    return external_call["pkey_get", c_uint](key)


@always_inline("nodebug")
fn mlock(addr: UnsafePointer[NoneType], len: c_size_t) -> c_int:
    return external_call["mlock", c_int](addr, len)


@always_inline("nodebug")
fn mlock2(
    addr: UnsafePointer[NoneType],
    len: c_size_t,
    flags: c_int,
) -> c_int:
    return external_call["mlock2", c_int](addr, len, flags)


@always_inline("nodebug")
fn munlock(addr: UnsafePointer[NoneType], len: c_size_t) -> c_int:
    return external_call["munlock", c_int](addr, len)


@always_inline("nodebug")
fn mlockall(flags: c_int) -> c_int:
    return external_call["mlockall", c_int](flags)


@always_inline("nodebug")
fn munlockall() -> c_int:
    return external_call["munlockall", c_int]()