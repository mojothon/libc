from libc.memory.allocate import *
from libc import *


@always_inline("nodebug")
fn test_malloc_free():
    var ptr = malloc[Int](10)
    free(ptr)


@always_inline("nodebug")
fn test_malloc_realloc_free():
    var ptr = malloc[Int](10)
    ptr = realloc[Int](ptr, 20)
    free(ptr)


@always_inline("nodebug")
fn test_malloc_reallocarray_free():
    var ptr = malloc[Int](10)
    ptr = reallocarray[Int](ptr, 10, 2)
    free(ptr)


@always_inline("nodebug")
fn test_calloc_free():
    var ptr = calloc[Int](10, 2)
    free(ptr)


@always_inline("nodebug")
fn test_aligned_alloc_free():
    var ptr = aligned_alloc[Int](16, 10)
    free(ptr)


@always_inline("nodebug")
fn test_memalign_free():
    var ptr = memalign[Int](16, 10)
    free(ptr)


@always_inline("nodebug")
fn test_valloc_free():
    var ptr = valloc[Int](10)
    free(ptr)


@always_inline("nodebug")
fn test_mallopt():
    var result = mallopt(1, 1)
    print(result)


@always_inline("nodebug")
fn test_mcheck():
    var result = mcheck(UnsafePointer[NoneType]())
    print(result)


fn main():
    test_malloc_free()
    test_malloc_realloc_free()
    test_malloc_reallocarray_free()
    test_calloc_free()
    test_aligned_alloc_free()
    test_memalign_free()
    test_valloc_free()
    test_mallopt()
    test_mcheck()