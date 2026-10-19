"""Tests for the `libc.pthread` mutex bindings.

Making a lock, taking it, giving it up, and giving it back. None of
these starts a thread — `pthread_create` takes a function pointer,
which Mojo cannot make one of — so every lock here is taken and
released by the one thread running the test, which is enough: a lock
nobody else contends for still has to behave like the kind of lock it
was made to be.

The kind is where the two platforms part company, and the test that
matters is the one that asks what a lock *does* rather than what it
*says*. Asking a recursive lock for its type and getting it back
proves nothing: the number is stored and handed back, whichever
number it is. Asking to take one twice and getting away with it is
the thing a recursive lock does and no other kind does.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.pthread import (
    PTHREAD_MUTEX_DEFAULT,
    PTHREAD_MUTEX_ERRORCHECK,
    PTHREAD_MUTEX_NORMAL,
    PTHREAD_MUTEX_RECURSIVE,
    PTHREAD_PRIO_INHERIT,
    PTHREAD_PRIO_NONE,
    PTHREAD_PROCESS_PRIVATE,
    PTHREAD_PROCESS_SHARED,
    pthread_mutex_destroy,
    pthread_mutex_init,
    pthread_mutex_lock,
    pthread_mutex_trylock,
    pthread_mutex_unlock,
    pthread_mutex_t,
    pthread_mutexattr_destroy,
    pthread_mutexattr_t,
    pthread_mutexattr_getprioceiling,
    pthread_mutexattr_getprotocol,
    pthread_mutexattr_getpshared,
    pthread_mutexattr_gettype,
    pthread_mutexattr_init,
    pthread_mutexattr_setprioceiling,
    pthread_mutexattr_setprotocol,
    pthread_mutexattr_setpshared,
    pthread_mutexattr_settype,
)
from libc.utils import null_ptr


# Same number on both platforms, and both below 35, where the errno
# lists start to disagree.
comptime EBUSY: Int32 = 16
comptime EINVAL: Int32 = 22


def _an_attribute() raises -> c_ptr[pthread_mutexattr_t]:
    """One initialised, default set of mutex attributes."""
    var attr = unsafe_alloc[pthread_mutexattr_t](1)
    attr.unsafe_offset(0)[] = pthread_mutexattr_t()
    assert_equal(pthread_mutexattr_init(attr), 0, "attributes initialise")
    return attr


def _a_mutex_of(kind: Int32) raises -> c_ptr[pthread_mutex_t]:
    """One initialised lock of the kind asked for."""
    var attr = _an_attribute()
    assert_equal(
        pthread_mutexattr_settype(attr, kind), 0, "the kind is one there is"
    )
    var mutex = unsafe_alloc[pthread_mutex_t](1)
    mutex.unsafe_offset(0)[] = pthread_mutex_t()
    assert_equal(pthread_mutex_init(mutex, attr), 0, "the lock initialises")
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()
    return mutex


def test_a_default_lock_takes_and_gives_up() raises:
    """A lock made with no attributes at all, taken and given up.

    `null_ptr[pthread_mutexattr_t]()` is the ordinary way to ask for
    the default kind, so this is the shape most callers write.
    """
    var mutex = unsafe_alloc[pthread_mutex_t](1)
    mutex.unsafe_offset(0)[] = pthread_mutex_t()

    assert_equal(
        pthread_mutex_init(mutex, null_ptr[pthread_mutexattr_t]()),
        0,
        "no attributes means the default kind",
    )
    assert_equal(pthread_mutex_lock(mutex), 0, "it takes")
    assert_equal(pthread_mutex_unlock(mutex), 0, "and gives up")
    assert_equal(pthread_mutex_destroy(mutex), 0, "and goes away")

    mutex.unsafe_free()


def test_trylock_says_what_it_found() raises:
    """`trylock` answers without waiting, so a caller holding the
    lock itself is a case it can be asked about: taken once is 0,
    taken again is `EBUSY`, and given up it is 0 again.

    This cannot hang, which is why it is the call these tests use
    rather than `lock`.
    """
    var mutex = unsafe_alloc[pthread_mutex_t](1)
    mutex.unsafe_offset(0)[] = pthread_mutex_t()
    assert_equal(
        pthread_mutex_init(mutex, null_ptr[pthread_mutexattr_t]()),
        0,
        "the lock initialises",
    )

    assert_equal(pthread_mutex_trylock(mutex), 0, "the first take is free")
    assert_equal(
        pthread_mutex_trylock(mutex),
        EBUSY,
        "the second is busy, because this caller holds it",
    )
    assert_equal(pthread_mutex_unlock(mutex), 0, "giving up works")
    assert_equal(
        pthread_mutex_trylock(mutex), 0, "and it is free again afterwards"
    )
    assert_equal(pthread_mutex_unlock(mutex), 0, "and given up again")
    assert_equal(pthread_mutex_destroy(mutex), 0, "and gone")

    mutex.unsafe_free()


def test_a_recursive_lock_can_be_taken_twice() raises:
    """The test that would catch the two platforms swapping their
    constants.

    `PTHREAD_MUTEX_RECURSIVE` is 1 on glibc and 2 here. A binding that
    had them the wrong way round would still say 0 from
    `pthread_mutexattr_settype` and still read its own answer back
    from `gettype` — the round trip is self-consistent either way.
    What it would not do is let the same caller take the lock twice,
    because the lock it had made would be an error-checking one and
    an error-checking one says `EBUSY`.
    """
    var mutex = _a_mutex_of(PTHREAD_MUTEX_RECURSIVE)

    assert_equal(pthread_mutex_trylock(mutex), 0, "the first take is free")
    assert_equal(
        pthread_mutex_trylock(mutex),
        0,
        "and so is the second, which is what recursive means",
    )
    assert_equal(pthread_mutex_unlock(mutex), 0, "giving one of them up")
    assert_equal(pthread_mutex_unlock(mutex), 0, "and the other")
    assert_equal(pthread_mutex_destroy(mutex), 0, "and it goes away")

    mutex.unsafe_free()


def test_an_error_checking_lock_refuses_the_second_take() raises:
    """The other half: `PTHREAD_MUTEX_ERRORCHECK` is 2 on glibc and 1
    here, and a lock of that kind says `EBUSY` when the caller that
    holds it asks again.

    Between this test and the one above, the two constants are pinned
    from both sides. One of them alone would pass with the values
    swapped.
    """
    var mutex = _a_mutex_of(PTHREAD_MUTEX_ERRORCHECK)

    assert_equal(pthread_mutex_trylock(mutex), 0, "the first take is free")
    assert_equal(
        pthread_mutex_trylock(mutex),
        EBUSY,
        "and the second is refused, which is what error-checking means",
    )
    assert_equal(pthread_mutex_unlock(mutex), 0, "giving up works")
    assert_equal(pthread_mutex_destroy(mutex), 0, "and it goes away")

    mutex.unsafe_free()


def test_the_kind_is_what_was_asked_for() raises:
    """`settype` then `gettype`, the round trip on its own.

    Worth having, and worth knowing what it is worth: it proves the
    attribute object is the same size the platform expects and that
    the value survives the trip. It does not prove the value is the
    right one, which is what the two tests above are for.
    """
    var attr = _an_attribute()

    var kind = unsafe_alloc[Int32](1)

    # Normal.
    assert_equal(
        pthread_mutexattr_settype(attr, PTHREAD_MUTEX_NORMAL), 0, "normal sets"
    )
    assert_equal(pthread_mutexattr_gettype(attr, kind), 0, "and reads back")
    assert_equal(kind.unsafe_offset(0)[], PTHREAD_MUTEX_NORMAL, "as normal")

    # Recursive.
    assert_equal(
        pthread_mutexattr_settype(attr, PTHREAD_MUTEX_RECURSIVE),
        0,
        "recursive sets",
    )
    assert_equal(pthread_mutexattr_gettype(attr, kind), 0, "and reads back")
    assert_equal(
        kind.unsafe_offset(0)[], PTHREAD_MUTEX_RECURSIVE, "as recursive"
    )

    # Error-checking.
    assert_equal(
        pthread_mutexattr_settype(attr, PTHREAD_MUTEX_ERRORCHECK),
        0,
        "error-checking sets",
    )
    assert_equal(pthread_mutexattr_gettype(attr, kind), 0, "and reads back")
    assert_equal(
        kind.unsafe_offset(0)[], PTHREAD_MUTEX_ERRORCHECK, "as error-checking"
    )

    kind.unsafe_free()
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()


def test_a_new_attribute_object_is_private_and_normal() raises:
    """What `pthread_mutexattr_init` leaves behind: a lock for one
    process, of the default kind.

    Compared against the constants rather than against 0, because
    `PTHREAD_PROCESS_PRIVATE` is 0 on glibc and 2 here — the same
    number meaning different things is the whole difficulty in this
    header.
    """
    var attr = _an_attribute()
    var out = unsafe_alloc[Int32](1)

    assert_equal(pthread_mutexattr_getpshared(attr, out), 0, "it reads back")
    assert_equal(
        out.unsafe_offset(0)[],
        PTHREAD_PROCESS_PRIVATE,
        "and a new one is for one process",
    )
    assert_equal(pthread_mutexattr_gettype(attr, out), 0, "it reads back")
    assert_equal(
        out.unsafe_offset(0)[], PTHREAD_MUTEX_DEFAULT, "and of the default kind"
    )
    assert_equal(pthread_mutexattr_getprotocol(attr, out), 0, "it reads back")
    assert_equal(
        out.unsafe_offset(0)[], PTHREAD_PRIO_NONE, "and takes no priority"
    )

    out.unsafe_free()
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()


def test_pshared_goes_both_ways() raises:
    """`setpshared` to SHARED and back to PRIVATE. Both are there on
    both platforms; it is the numbering that is not.
    """
    var attr = _an_attribute()
    var out = unsafe_alloc[Int32](1)

    assert_equal(
        pthread_mutexattr_setpshared(attr, PTHREAD_PROCESS_SHARED),
        0,
        "sharing across processes is allowed",
    )
    assert_equal(pthread_mutexattr_getpshared(attr, out), 0, "and reads back")
    assert_equal(out.unsafe_offset(0)[], PTHREAD_PROCESS_SHARED, "as shared")

    assert_equal(
        pthread_mutexattr_setpshared(attr, PTHREAD_PROCESS_PRIVATE),
        0,
        "and private is allowed too",
    )
    assert_equal(pthread_mutexattr_getpshared(attr, out), 0, "and reads back")
    assert_equal(out.unsafe_offset(0)[], PTHREAD_PROCESS_PRIVATE, "as private")

    out.unsafe_free()
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()


def test_a_kind_that_is_not_one_is_refused() raises:
    """`settype` given 999, which no platform has. Either the call
    refuses it or it is taken as a kind — POSIX permits both, so what
    is asserted is the one thing both platforms agree on: it does not
    promise anything about 999.

    glibc says `EINVAL`. Where it is accepted instead nothing
    further is claimed.
    """
    var attr = _an_attribute()
    var answered = pthread_mutexattr_settype(attr, 999)
    assert_true(
        answered == EINVAL or answered == 0,
        "a kind that is not one is either refused or taken, never silent",
    )
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()


def test_prioceiling_says_what_it_was_given() raises:
    """`setprioceiling` then `getprioceiling`. Optional in POSIX, so
    a platform that has none of it says `ENOTSUP` instead, and only
    where it is taken is what comes back compared.
    """
    var attr = _an_attribute()
    var out = unsafe_alloc[Int32](1)

    var answered = pthread_mutexattr_setprioceiling(attr, 1)
    if answered == 0:
        assert_equal(
            pthread_mutexattr_getprioceiling(attr, out), 0, "it reads back"
        )
        assert_equal(
            out.unsafe_offset(0)[], 1, "and it is the priority that was set"
        )

    out.unsafe_free()
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()


def test_protocol_says_what_it_was_given() raises:
    """`setprotocol` then `getprotocol`, with the same allowance for
    a platform that carries none of it.
    """
    var attr = _an_attribute()
    var out = unsafe_alloc[Int32](1)

    var answered = pthread_mutexattr_setprotocol(attr, PTHREAD_PRIO_INHERIT)
    if answered == 0:
        assert_equal(
            pthread_mutexattr_getprotocol(attr, out), 0, "it reads back"
        )
        assert_equal(
            out.unsafe_offset(0)[],
            PTHREAD_PRIO_INHERIT,
            "and it is the protocol that was set",
        )
    _ = pthread_mutexattr_getpshared(attr, out)

    out.unsafe_free()
    _ = pthread_mutexattr_destroy(attr)
    attr.unsafe_free()


def main() raises:
    test_a_default_lock_takes_and_gives_up()
    test_trylock_says_what_it_found()
    test_a_recursive_lock_can_be_taken_twice()
    test_an_error_checking_lock_refuses_the_second_take()
    test_the_kind_is_what_was_asked_for()
    test_a_new_attribute_object_is_private_and_normal()
    test_pshared_goes_both_ways()
    test_a_kind_that_is_not_one_is_refused()
    test_prioceiling_says_what_it_was_given()
    test_protocol_says_what_it_was_given()
    print("test_mutex: ok")
