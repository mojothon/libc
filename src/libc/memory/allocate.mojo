from sys import external_call
from memory import UnsafePointer
from libc.constant import *


@always_inline("nodebug")
fn malloc[T: AnyType](size: c_size_t) -> UnsafePointer[T]:
    return external_call["malloc", UnsafePointer[T]](size)


@always_inline("nodebug")
fn free(pointer: UnsafePointer):
    external_call["free", NoneType](pointer)


@always_inline("nodebug")
fn realloc[T: AnyType](pointer: UnsafePointer, size: c_size_t) -> UnsafePointer[T]:
    return external_call["realloc", UnsafePointer[T]](pointer, size)


@always_inline("nodebug")
fn reallocarray[T: AnyType](
    pointer: UnsafePointer, nmemb: c_size_t, size: c_size_t
) -> UnsafePointer[T]:
    return external_call["reallocarray", UnsafePointer[T]](pointer, nmemb, size)


@always_inline("nodebug")
fn calloc[T: AnyType](nmemb: c_size_t, size: c_size_t) -> UnsafePointer[T]:
    return external_call["calloc", UnsafePointer[T]](nmemb, size)


@always_inline("nodebug")
fn aligned_alloc[T: AnyType](alignment: c_size_t, size: c_size_t) -> UnsafePointer[T]:
    return external_call["aligned_alloc", UnsafePointer[T]](alignment, size)


@always_inline("nodebug")
fn memalign[T: AnyType](boundary: c_size_t, size: c_size_t) -> UnsafePointer[T]:
    return external_call["memalign", UnsafePointer[T]](boundary, size)


# @always_inline("nodebug")
# fn posix_memalign(
#     memptr: UnsafePointer[UnsafePointer[NoneType]],
#     alignment: c_size_t,
#     size: c_size_t,
# ) -> c_int:
#     return external_call["posix_memalign", c_int](memptr, alignment, size)


@always_inline("nodebug")
fn valloc[T: AnyType](size: c_size_t) -> UnsafePointer[T]:
    return external_call["valloc", UnsafePointer[T]](size)


@always_inline("nodebug")
fn mallopt(param: c_int, value: c_int) -> c_int:
    return external_call["mallopt", c_int](param, value)


@always_inline("nodebug")
fn mcheck(abortfn: UnsafePointer) -> c_int:
    return external_call["mcheck", c_int](abortfn)

# @always_inline("nodebug")
# fn memprobe(pointer: UnsafePointer, size: c_size_t) -> c_int:
#     return external_call["memprobe", c_int](pointer, size)

# @always_inline("nodebug")
# fn mallinfo():
#     return external_call["mallinfo", NoneType]()