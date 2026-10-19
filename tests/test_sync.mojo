"""Tests for the `libc.pthread` condition and read-write lock bindings.

Two more ways to wait, and the attributes that go with them. As with
the mutex tests, nothing here starts a thread — `pthread_create` wants
a function pointer, which is the one thing a Mojo binding cannot make
— so what is exercised is the part that does not need a second
thread: making each object, using it where using it does not wait,
and giving it back.

`pthread_cond_wait` is bound but not called. It waits until somebody
wakes it, and with no second thread nobody will, so calling it in a
test would stop the test rather than fail it. `pthread_cond_timedwait`
is the same call with a time on it, and a time already past comes
straight back — which is the one waiting call in this file that is
safe to make.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget, size_of
from std.testing import assert_equal, assert_true

from libc.constant import ETIMEDOUT, c_ptr
from libc.pthread import (
    PTHREAD_PROCESS_PRIVATE,
    PTHREAD_PROCESS_SHARED,
    pthread_cond_broadcast,
    pthread_cond_destroy,
    pthread_cond_init,
    pthread_cond_signal,
    pthread_cond_t,
    pthread_cond_timedwait,
    pthread_condattr_destroy,
    pthread_condattr_getpshared,
    pthread_condattr_init,
    pthread_condattr_setpshared,
    pthread_condattr_t,
    pthread_mutex_destroy,
    pthread_mutexattr_t,
    pthread_mutex_init,
    pthread_mutex_lock,
    pthread_mutex_t,
    pthread_mutex_unlock,
    pthread_rwlock_destroy,
    pthread_rwlock_init,
    pthread_rwlock_rdlock,
    pthread_rwlock_t,
    pthread_rwlock_tryrdlock,
    pthread_rwlock_trywrlock,
    pthread_rwlock_unlock,
    pthread_rwlock_wrlock,
    pthread_rwlockattr_destroy,
    pthread_rwlockattr_getpshared,
    pthread_rwlockattr_init,
    pthread_rwlockattr_setpshared,
    pthread_rwlockattr_t,
)
from libc.time import CLOCK_REALTIME, clock_gettime, timespec
from libc.utils import null_ptr


def _a_cond_attribute() raises -> c_ptr[pthread_condattr_t]:
    """One initialised, default set of condition attributes."""
    var attr = unsafe_alloc[pthread_condattr_t](1)
    attr.unsafe_offset(0)[] = pthread_condattr_t()
    assert_equal(pthread_condattr_init(attr), 0, "attributes initialise")
    return attr


def _a_condition() raises -> c_ptr[pthread_cond_t]:
    """One condition variable, made with no attributes."""
    var cond = unsafe_alloc[pthread_cond_t](1)
    cond.unsafe_offset(0)[] = pthread_cond_t()
    assert_equal(
        pthread_cond_init(cond, null_ptr[pthread_condattr_t]()),
        0,
        "the condition initialises",
    )
    return cond


def _a_locked_mutex() raises -> c_ptr[pthread_mutex_t]:
    """One initialised mutex, which this caller holds."""
    var mutex = unsafe_alloc[pthread_mutex_t](1)
    mutex.unsafe_offset(0)[] = pthread_mutex_t()
    assert_equal(
        pthread_mutex_init(mutex, null_ptr[pthread_mutexattr_t]()),
        0,
        "the mutex initialises",
    )
    assert_equal(pthread_mutex_lock(mutex), 0, "and this caller takes it")
    return mutex


def test_a_condition_makes_and_goes_away() raises:
    """`pthread_cond_init` with no attributes, then
    `pthread_cond_destroy`.
    """
    var cond = _a_condition()
    assert_equal(pthread_cond_destroy(cond), 0, "and it goes away")
    cond.unsafe_free()


def test_a_condition_can_be_made_from_attributes() raises:
    """`pthread_cond_init` given a set of attributes it was handed
    rather than nothing, which is the other way to call it.
    """
    var attr = _a_cond_attribute()
    var cond = unsafe_alloc[pthread_cond_t](1)
    cond.unsafe_offset(0)[] = pthread_cond_t()
    assert_equal(pthread_cond_init(cond, attr), 0, "it takes the attributes")
    assert_equal(pthread_cond_destroy(cond), 0, "and goes away")
    cond.unsafe_free()
    _ = pthread_condattr_destroy(attr)
    attr.unsafe_free()


def test_waking_nobody_is_not_an_error() raises:
    """`pthread_cond_signal` and `pthread_cond_broadcast` with no
    thread waiting.

    Both answer 0 having done nothing. That is not a quirk to work
    round but the ordinary case: a condition variable keeps no count
    of who is waiting, so signalling one is a no-op unless somebody
    happens to be there, and `pthread_cond_wait` is written in a loop
    for exactly that reason.
    """
    var cond = _a_condition()
    assert_equal(pthread_cond_signal(cond), 0, "waking nobody is not an error")
    assert_equal(pthread_cond_broadcast(cond), 0, "nor is waking everybody")
    assert_equal(pthread_cond_destroy(cond), 0, "and it goes away")
    cond.unsafe_free()


def test_waiting_for_a_time_that_has_gone() raises:
    """`pthread_cond_timedwait` given a time in the past.

    It comes straight back with `ETIMEDOUT`, having taken the mutex
    again — which is the part worth checking, since a caller that
    assumed otherwise would be holding no lock at all.

    This is the one waiting call here that is safe: it cannot hang,
    so it is the only one the test file makes.
    """
    var mutex = _a_locked_mutex()
    var cond = _a_condition()

    # A time that has already gone by.
    var when = unsafe_alloc[timespec](1)
    when.unsafe_offset(0)[] = timespec()
    assert_equal(clock_gettime(CLOCK_REALTIME, when), 0, "the time reads")
    when.unsafe_offset(0)[] = timespec(
        when.unsafe_offset(0)[].tv_sec - 1, when.unsafe_offset(0)[].tv_nsec
    )

    assert_equal(
        pthread_cond_timedwait(cond, mutex, when),
        Int32(ETIMEDOUT),
        "a time already past times out at once",
    )

    # The mutex came back. Holding it is what lets this be said.
    assert_equal(pthread_mutex_unlock(mutex), 0, "and the lock came back")

    when.unsafe_free()
    _ = pthread_cond_destroy(cond)
    cond.unsafe_free()
    _ = pthread_mutex_destroy(mutex)
    mutex.unsafe_free()


def test_the_condition_attributes_go_both_ways() raises:
    """`pthread_condattr_setpshared` to SHARED and back, with the
    default being PRIVATE.
    """
    var attr = _a_cond_attribute()
    var out = unsafe_alloc[Int32](1)

    assert_equal(pthread_condattr_getpshared(attr, out), 0, "it reads back")
    assert_equal(
        out.unsafe_offset(0)[],
        PTHREAD_PROCESS_PRIVATE,
        "and a new one is for one process",
    )

    assert_equal(
        pthread_condattr_setpshared(attr, PTHREAD_PROCESS_SHARED),
        0,
        "sharing across processes is allowed",
    )
    assert_equal(pthread_condattr_getpshared(attr, out), 0, "and reads back")
    assert_equal(out.unsafe_offset(0)[], PTHREAD_PROCESS_SHARED, "as shared")

    out.unsafe_free()
    _ = pthread_condattr_destroy(attr)
    attr.unsafe_free()


def test_a_read_write_lock_takes_for_reading_and_writing() raises:
    """A `pthread_rwlock_t` taken to read and to write, one at a
    time.

    `rdlock`, `wrlock`, `tryrdlock` and `trywrlock`, each given the
    whole lock to itself. With one thread there is no writer to wait
    for and no reader to share with, so all four say 0.
    """
    var rwlock = unsafe_alloc[pthread_rwlock_t](1)
    rwlock.unsafe_offset(0)[] = pthread_rwlock_t()
    assert_equal(
        pthread_rwlock_init(rwlock, null_ptr[pthread_rwlockattr_t]()),
        0,
        "the lock initialises",
    )

    # To read.
    assert_equal(pthread_rwlock_rdlock(rwlock), 0, "it takes to read")
    assert_equal(pthread_rwlock_unlock(rwlock), 0, "and gives up")

    # To write.
    assert_equal(pthread_rwlock_wrlock(rwlock), 0, "it takes to write")
    assert_equal(pthread_rwlock_unlock(rwlock), 0, "and gives up")

    # The same two, without waiting.
    assert_equal(pthread_rwlock_tryrdlock(rwlock), 0, "it takes to read")
    assert_equal(pthread_rwlock_unlock(rwlock), 0, "and gives up")
    assert_equal(pthread_rwlock_trywrlock(rwlock), 0, "it takes to write")
    assert_equal(pthread_rwlock_unlock(rwlock), 0, "and gives up")

    assert_equal(pthread_rwlock_destroy(rwlock), 0, "and it goes away")
    rwlock.unsafe_free()


def test_a_read_write_lock_can_be_made_from_attributes() raises:
    """`pthread_rwlockattr_init`, `_setpshared`, `_getpshared` and
    `_destroy`, and a lock made from the result.

    The attribute object is the one whose size the two platforms
    disagree about most: 8 bytes on glibc, 24 here.
    """
    var attr = unsafe_alloc[pthread_rwlockattr_t](1)
    attr.unsafe_offset(0)[] = pthread_rwlockattr_t()
    assert_equal(pthread_rwlockattr_init(attr), 0, "attributes initialise")

    var out = unsafe_alloc[Int32](1)
    assert_equal(pthread_rwlockattr_getpshared(attr, out), 0, "it reads back")
    assert_equal(
        out.unsafe_offset(0)[],
        PTHREAD_PROCESS_PRIVATE,
        "and a new one is for one process",
    )
    assert_equal(
        pthread_rwlockattr_setpshared(attr, PTHREAD_PROCESS_SHARED),
        0,
        "sharing across processes is allowed",
    )
    assert_equal(pthread_rwlockattr_getpshared(attr, out), 0, "and reads back")
    assert_equal(out.unsafe_offset(0)[], PTHREAD_PROCESS_SHARED, "as shared")
    out.unsafe_free()

    var rwlock = unsafe_alloc[pthread_rwlock_t](1)
    rwlock.unsafe_offset(0)[] = pthread_rwlock_t()
    assert_equal(pthread_rwlock_init(rwlock, attr), 0, "the lock takes them")
    assert_equal(pthread_rwlock_destroy(rwlock), 0, "and goes away")
    rwlock.unsafe_free()

    _ = pthread_rwlockattr_destroy(attr)
    attr.unsafe_free()


def test_the_rwlock_attribute_object_is_the_size_it_has_to_be() raises:
    """The read-write lock attribute object is 8 bytes on glibc and
    24 here, so the one this package hands over has to hold 24.

    It is the same claim the layout check makes, asked from the Mojo
    side rather than from C, which is the only place it can be asked
    from once the package has been compiled — and it is the object
    most likely to be got wrong, being four times the size on one
    platform of what it is on the other.
    """
    assert_equal(
        size_of[pthread_rwlockattr_t](),
        24,
        "the attribute object holds the larger of the two",
    )
    assert_equal(
        size_of[pthread_rwlock_t](),
        200,
        "and so does the lock: 56 on glibc, 200 here",
    )
    assert_equal(
        size_of[pthread_cond_t](),
        48,
        "the condition variable is 48 on both, which is the one they agree on",
    )


def main() raises:
    test_a_condition_makes_and_goes_away()
    test_a_condition_can_be_made_from_attributes()
    test_waking_nobody_is_not_an_error()
    test_waiting_for_a_time_that_has_gone()
    test_the_condition_attributes_go_both_ways()
    test_a_read_write_lock_takes_for_reading_and_writing()
    test_a_read_write_lock_can_be_made_from_attributes()
    test_the_rwlock_attribute_object_is_the_size_it_has_to_be()
    print("test_sync: ok")
