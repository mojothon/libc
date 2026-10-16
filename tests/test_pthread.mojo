"""Tests for the `libc.pthread` bindings, none of which had been called.

The module is the attribute object and nothing else: `pthread_create`
and the mutexes are not here yet.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.pthread import (
    pthread_attr_destroy,
    PTHREAD_CREATE_DETACHED,
    PTHREAD_CREATE_JOINABLE,
    pthread_attr_getdetachstate,
    pthread_attr_getguardsize,
    pthread_attr_getstack,
    pthread_attr_getstacksize,
    pthread_attr_init,
    pthread_attr_setdetachstate,
    pthread_attr_setguardsize,
    pthread_attr_setstack,
    pthread_attr_setstacksize,
    pthread_condattr_destroy,
    pthread_attr_t,
    pthread_condattr_t,
)
from libc.utils import null_ptr

# A megabyte of stack and one page in front of it: more than any of them
# ask for, which is what keeps the numbers from being the thing tested.
comptime STACK = 1 << 20
comptime GUARD = 4096


def test_the_attribute_object() raises:
    """`pthread_attr_init` fills an attribute object in, the ones ending
    in `set` write into it, the ones ending in `get` read out of it, and
    `pthread_attr_destroy` takes it away again.

    What is asked of every `set` is whether the `get` beside it reads
    back what was written, that being the whole of what they are for.
    It is also what catches `pthread_attr_setdetachstate`, which was
    handed the object by value rather than by address: C wrote into a
    copy, the caller's object never moved, and the call still said 0.
    """
    var attr = unsafe_alloc[pthread_attr_t](1)
    assert_equal(pthread_attr_init(attr), 0, "pthread_attr_init fills one in")

    var state = unsafe_alloc[Int32](1)
    assert_equal(pthread_attr_getdetachstate(attr, state), 0)
    # POSIX does not say what number either state is, so what is asked is
    # not which number detached is but whether what went in comes out.
    var got: Int32 = state.unsafe_load()
    var other: Int32 = (
        PTHREAD_CREATE_DETACHED if got
        == PTHREAD_CREATE_JOINABLE else PTHREAD_CREATE_JOINABLE
    )
    assert_equal(pthread_attr_setdetachstate(attr, other), 0)
    assert_equal(pthread_attr_getdetachstate(attr, state), 0)
    assert_equal(
        state.unsafe_load(), other, "and it reads back what was written"
    )

    var size = unsafe_alloc[Int](1)
    assert_equal(pthread_attr_setstacksize(attr, STACK), 0)
    assert_equal(pthread_attr_getstacksize(attr, size), 0)
    assert_equal(size.unsafe_load(), STACK, "the stack size likewise")

    var guard = unsafe_alloc[UInt64](1)
    assert_equal(pthread_attr_setguardsize(attr, GUARD), 0)
    assert_equal(pthread_attr_getguardsize(attr, guard), 0)
    # POSIX lets an implementation round a guard size up to whatever
    # granularity it keeps stacks on. glibc hands back what it was
    # given; Darwin answers in multiples of its 16 KiB page, so 4096
    # comes back as 16384 there. Asking for the number to have come
    # back unchanged would fail the side that is within its rights,
    # so what is asked is that it is at least what was asked for.
    assert_true(
        Int(guard.unsafe_load()) >= GUARD,
        "and a guard size no smaller than the one asked for",
    )

    var base = unsafe_alloc[c_ptr[UInt8]](1)
    assert_equal(
        pthread_attr_setstack(attr, null_ptr[UInt8](), STACK),
        0,
        "pthread_attr_setstack is given no address and told to find one",
    )
    assert_equal(pthread_attr_getstack(attr, base, size), 0)
    assert_true(
        size.unsafe_load() >= STACK,
        "and what it found is not less than was asked",
    )

    assert_equal(
        pthread_attr_destroy(attr), 0, "pthread_attr_destroy takes it back"
    )

    base.unsafe_free()
    size.unsafe_free()
    guard.unsafe_free()
    state.unsafe_free()
    attr.unsafe_free()


def test_the_one_that_is_left() raises:
    """`pthread_condattr_destroy` takes back a condition attribute
    object. One is filled with zeroes here rather than left as it was
    found, since what it does with a thing that was never initialised is
    nothing anyone should rely on.

    `pthread_atfork` is the one of the twelve not called at all: glibc
    exports it with no default version, so looking it up by name finds
    nothing and the call cannot be made from Mojo, however it is given
    its three function pointers. The binding says so.
    """
    var cond = unsafe_alloc[pthread_condattr_t](1)
    cond.unsafe_offset(0)[] = pthread_condattr_t()
    assert_equal(
        pthread_condattr_destroy(cond),
        0,
        "pthread_condattr_destroy takes it back",
    )
    cond.unsafe_free()


def main() raises:
    test_the_attribute_object()
    test_the_one_that_is_left()
    print("test_pthread: ok")
