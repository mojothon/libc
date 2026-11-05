"""Tests for the `libc.pthread` condition and read-write lock bindings.

Two more ways to wait, and the attributes that go with them. As with
the mutex tests, nothing here starts a thread — `pthread_create` wants
a function pointer, which is the one thing a Mojo binding cannot make
— so what is exercised is the part that does not need a second
thread: making each object, using it where using it does not wait,
and giving it back.

Nothing here starts a thread, and one call does not need a thread to
be woken by: `pthread_cond_wait` waits until somebody signals the
condition, and a condition variable and the lock beside it can live in
a page both a process and its child see (`PTHREAD_PROCESS_SHARED`).
The child is that second waiter's other half — it takes the lock,
signals, and lets go. `pthread_cond_timedwait` is the same call with a
time on it, and a time already past comes straight back.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget, size_of
from std.testing import assert_equal, assert_true

from libc.constant import (
    EBUSY,
    EDEADLK,
    EINVAL,
    ETIMEDOUT,
    MAP_ANONYMOUS,
    MAP_SHARED,
    PROT_READ,
    PROT_WRITE,
    c_ptr,
)
from libc.pthread import (
    PTHREAD_PROCESS_PRIVATE,
    PTHREAD_PROCESS_SHARED,
    pthread_cond_broadcast,
    pthread_cond_destroy,
    pthread_cond_init,
    pthread_cond_signal,
    pthread_cond_t,
    pthread_cond_wait,
    pthread_cond_timedwait,
    pthread_condattr_destroy,
    pthread_condattr_getpshared,
    pthread_condattr_init,
    pthread_condattr_setpshared,
    pthread_condattr_t,
    pthread_mutex_destroy,
    pthread_mutexattr_init,
    pthread_mutexattr_setpshared,
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
from libc.stdlib import exit
from libc.sys.mman import mmap, munmap
from libc.signal import SIGKILL, kill
from libc.sys.wait import WIFEXITED, WEXITSTATUS, WNOHANG, waitpid
from libc.time import CLOCK_REALTIME, clock_gettime, timespec
from libc.unistd import fork, usleep
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

    # `_init` puts the defaults back, which is what tells it from `_destroy`:
    # same signature, same answer of 0, and the object left as it was found.
    assert_equal(pthread_condattr_init(attr), 0, "init puts them back")
    assert_equal(pthread_condattr_getpshared(attr, out), 0)
    assert_equal(
        out.unsafe_offset(0)[], PTHREAD_PROCESS_PRIVATE, "for one process again"
    )

    out.unsafe_free()
    _ = pthread_condattr_destroy(attr)
    attr.unsafe_free()


def _the_condition_wait_exercise() raises:
    """`pthread_cond_wait` waits until the condition is signalled. The
    only thread here is this one, so the signaller is a child — and for
    the two to be waiting on the same condition they have to be looking
    at the same bytes, which a fork does not give them: it copies the
    page, and a copy of a condition variable is a different condition
    variable. So the lock and the condition are made in a page that is
    shared (`MAP_SHARED`) and made for sharing
    (`PTHREAD_PROCESS_SHARED`), and both sides address it.

    The order is what makes the wake-up impossible to miss rather than
    merely unlikely. This process takes the lock **before** the fork,
    and a condition variable is waited on with the lock held. The child
    therefore cannot get the lock until this process is inside
    `pthread_cond_wait`, where the lock is let go — so the signal
    cannot be sent to a condition nobody is waiting on yet, and no
    sleep is standing in for the ordering that guarantees it.

    What comes back is 0, and the lock is held again on the way out,
    which is checked by unlocking it. The child leaves with 0 after
    having said the same about its own three calls, so a child that
    never signalled is a red run and not a passing one.

    The waiting is done by the child, and this process reads the
    ending rather than trusting it. A binding pointed at a call that
    takes the condition apart instead of waking it -- `destroy` takes
    the same argument and answers 0 -- leaves a waiter waiting for
    himself, and a wait with no wake-up used to be covered by ten
    seconds of `alarm`; a signal a handler elsewhere keeps to itself
    leaves the run stopped answering rather than ended. So the child
    is watched: the one that stops answering is killed and said so,
    and the one that was woken says so by leaving of its own accord.
    """
    comptime PAGE = 4096
    comptime RW: Int32 = PROT_READ | PROT_WRITE
    comptime SHARED_ANON: Int32 = MAP_SHARED | MAP_ANONYMOUS

    var page = mmap(null_ptr[UInt8](), PAGE, RW, SHARED_ANON, -1, 0)
    assert_true(
        Int(UInt(page)) > 0, "there is a page the child will also be looking at"
    )
    var mutex = page.unsafe_bitcast[pthread_mutex_t]()
    var cond = page.unsafe_offset(128).unsafe_bitcast[pthread_cond_t]()
    mutex.unsafe_offset(0)[] = pthread_mutex_t()
    cond.unsafe_offset(0)[] = pthread_cond_t()

    var mutex_attr = unsafe_alloc[pthread_mutexattr_t](1)
    mutex_attr.unsafe_offset(0)[] = pthread_mutexattr_t()
    assert_equal(pthread_mutexattr_init(mutex_attr), 0, "the lock attributes")
    assert_equal(
        pthread_mutexattr_setpshared(mutex_attr, PTHREAD_PROCESS_SHARED),
        0,
        "for a lock two processes share",
    )
    assert_equal(pthread_mutex_init(mutex, mutex_attr), 0, "and the lock")

    var cond_attr = _a_cond_attribute()
    assert_equal(
        pthread_condattr_setpshared(cond_attr, PTHREAD_PROCESS_SHARED),
        0,
        "the condition is made for sharing too",
    )
    assert_equal(pthread_cond_init(cond, cond_attr), 0, "and it is made")

    # Taken before the fork, so the child's own attempt waits for the
    # one moment this process is inside the wait.
    assert_equal(pthread_mutex_lock(mutex), 0, "this process holds the lock")

    var child = fork()
    if child == 0:
        assert_equal(
            pthread_mutex_lock(mutex),
            0,
            "the child gets it when the wait starts",
        )
        assert_equal(pthread_cond_signal(cond), 0, "and signals the condition")
        assert_equal(pthread_mutex_unlock(mutex), 0, "then lets go of the lock")
        _ = exit(0)

    assert_true(child > 0, "there is a child to be woken by")
    assert_equal(
        pthread_cond_wait(cond, mutex),
        0,
        "the wait comes back when it is signalled",
    )
    assert_equal(pthread_mutex_unlock(mutex), 0, "holding the lock again")

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it left of its own accord"
    )
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        0,
        "having locked, signalled and unlocked",
    )
    status.unsafe_free()

    # The same question asked with `pthread_cond_broadcast`, which with one
    # waiter wakes exactly the one `_signal` wakes and is a different call
    # besides: same signature, same answer of 0. A child that destroyed the
    # condition instead of broadcasting leaves this process waiting, and
    # the deadline below is what turns that into a red run.
    assert_equal(pthread_mutex_lock(mutex), 0, "the lock is taken again")
    var second = fork()
    if second == 0:
        assert_equal(pthread_mutex_lock(mutex), 0, "the second child gets it")
        assert_equal(
            pthread_cond_broadcast(cond),
            0,
            "and wakes everybody who is waiting",
        )
        assert_equal(pthread_mutex_unlock(mutex), 0, "then lets go of the lock")
        _ = exit(0)

    assert_true(second > 0, "there is a second child to be woken by")
    # A time ten seconds out rather than `_wait`, and not the `alarm` the round
    # above uses: a signal that a handler elsewhere in the suite catches leaves
    # this waiting rather than ending it, and a wake-up that never comes should
    # be an `ETIMEDOUT` this file can read rather than a run that hangs.
    var when = unsafe_alloc[timespec](1)
    when.unsafe_offset(0)[] = timespec()
    assert_equal(clock_gettime(CLOCK_REALTIME, when), 0)
    when.unsafe_offset(0)[] = timespec(
        when.unsafe_offset(0)[].tv_sec + 10, when.unsafe_offset(0)[].tv_nsec
    )
    assert_equal(
        pthread_cond_timedwait(cond, mutex, when),
        0,
        "the wait comes back when everybody is woken",
    )
    when.unsafe_free()
    assert_equal(pthread_mutex_unlock(mutex), 0, "holding the lock again")

    var second_status = unsafe_alloc[Int32](1)
    second_status.unsafe_offset(0)[] = 0
    assert_equal(
        waitpid(second, second_status, 0),
        second,
        "the second child is waited for",
    )
    assert_true(
        WIFEXITED(second_status.unsafe_load()), "and it left of its own accord"
    )
    assert_equal(
        Int(WEXITSTATUS(second_status.unsafe_load())),
        0,
        "having locked, broadcast and unlocked",
    )
    second_status.unsafe_free()

    _ = pthread_cond_destroy(cond)
    _ = pthread_mutex_destroy(mutex)
    _ = pthread_condattr_destroy(cond_attr)
    _ = munmap(page, PAGE)
    cond_attr.unsafe_free()
    mutex_attr.unsafe_free()


def test_a_condition_wait_is_woken_by_the_process_that_holds_the_lock() raises:
    """The condition exercise, run where a stop answering can be
    harvested.

    The waiting, the lock and the fork that wakes it are as the
    exercise above describes. The whole round runs in a child of this
    one, because a binding pointed at a call that takes the condition
    apart instead of waking it -- `destroy` takes the same argument and
    answers 0 -- leaves the waiter waiting for himself, and a wait with
    no wake-up used to be covered by ten seconds of `alarm`; a signal a
    handler elsewhere keeps to itself leaves the run stopped answering
    rather than ended. Here the stop is survivable: the child that
    stops answering is killed and said so, and the one that was woken
    says so by leaving of its own accord.
    """
    var child = fork()
    if child == 0:
        _the_condition_wait_exercise()
        _ = exit(0)

    assert_true(child > 0, "there is a child to run the round in")
    watch_the_child(child, "the condition exercise")


def watch_the_child(pid: Int32, what: String) raises:
    """Waits four seconds for a forked child and reads its ending.

    The exercises this runs in the child are ones where a call that
    goes wrong does not answer wrongly but stops answering -- a lock
    that was destroyed being waited on does exactly that. In the child
    that is survivable; the parent kills it and says so, which turns a
    stop answering into something the suite can catch.

    Args:
        pid: The child to wait for.
        what: What to call it in the failure message.
    """
    var status = unsafe_alloc[Int32](1)
    var done = False
    for i in range(400):
        if waitpid(pid, status, WNOHANG) == pid:
            done = True
            break
        _ = usleep(10000)
    if not done:
        _ = kill(pid, SIGKILL)
        _ = waitpid(pid, status, 0)
        status.unsafe_free()
        assert_true(False, what + " stopped answering and had to be killed")
    assert_true(WIFEXITED(status.unsafe_offset(0)[]), what + " ended by itself")
    assert_equal(
        WEXITSTATUS(status.unsafe_offset(0)[]), 0, "and ended saying it passed"
    )
    status.unsafe_free()


def _the_read_write_lock_exercise() raises:
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
    # Which is what a writer holds: a read taken now waits for it. Without
    # this, `trywrlock` and `_destroy` -- the two calls with no arguments and
    # the same answer of 0 -- are the same call in a process with one thread.
    # What it answers is the platform's to say: glibc answers EBUSY and
    # Darwin answers EDEADLK, having noticed that the thread asking is the
    # one holding it. Either is the same answer to the question -- no -- and
    # both are a different answer from the 0 that a destroyed lock gives.
    comptime WRITER_IS_IN: Int32 = (
        Int32(EDEADLK) if CompilationTarget.is_macos() else Int32(EBUSY)
    )
    assert_equal(
        pthread_rwlock_tryrdlock(rwlock),
        WRITER_IS_IN,
        "and a reader cannot get in while it is held",
    )
    assert_equal(pthread_rwlock_unlock(rwlock), 0, "and gives up")

    assert_equal(pthread_rwlock_destroy(rwlock), 0, "and it goes away")
    rwlock.unsafe_free()


def test_a_read_write_lock_takes_for_reading_and_writing() raises:
    """The lock exercise, run where a stop answering can be harvested.

    `rdlock` and `unlock` are calls a binding pointed at a sibling can
    turn into a call that takes the lock apart instead of taking it --
    and a thread that then waits on what is left waits for itself, so
    the exercise asks its questions in a child: the child that stops
    answering is killed and said so, and the one that passes says so by
    leaving of its own accord.
    """
    var child = fork()
    if child == 0:
        _the_read_write_lock_exercise()
        _ = exit(0)

    assert_true(child > 0, "there is a child to take the lock in")
    watch_the_child(child, "the read-write lock exercise")


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

    # As with the condition's: `_init` puts the default back, and `_destroy`
    # leaves it there, so the reset is the only thing that tells the two
    # apart. Done before the lock is made, since the lock is to be private.
    assert_equal(pthread_rwlockattr_init(attr), 0, "init puts it back")
    assert_equal(pthread_rwlockattr_getpshared(attr, out), 0)
    assert_equal(
        out.unsafe_offset(0)[], PTHREAD_PROCESS_PRIVATE, "for one process again"
    )
    assert_equal(
        pthread_rwlockattr_setpshared(attr, PTHREAD_PROCESS_SHARED),
        0,
        "and shareable again, for the lock below",
    )
    out.unsafe_free()

    var rwlock = unsafe_alloc[pthread_rwlock_t](1)
    rwlock.unsafe_offset(0)[] = pthread_rwlock_t()
    assert_equal(pthread_rwlock_init(rwlock, attr), 0, "the lock takes them")
    assert_equal(pthread_rwlock_destroy(rwlock), 0, "and goes away")
    # What a destroyed lock answers depends on the platform and both answers
    # are honest: glibc leaves the object unlocked and a write is taken at
    # once, and Darwin has taken the lock's own storage away and refuses with
    # EINVAL. Either is a different answer from the EBUSY that a read lock
    # still held would give, which is what tells `_destroy` from `_rdlock` --
    # the two have the same signature and the same answer of 0.
    comptime AFTER_DESTROY: Int32 = (
        Int32(EINVAL) if CompilationTarget.is_macos() else 0
    )
    assert_equal(
        pthread_rwlock_trywrlock(rwlock),
        AFTER_DESTROY,
        "and nothing is held on it any more",
    )
    # Not unlocked again: on the platform that took the write there is nothing
    # to give back, and on the other the object is gone.
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
    test_a_condition_wait_is_woken_by_the_process_that_holds_the_lock()
    test_a_condition_can_be_made_from_attributes()
    test_waking_nobody_is_not_an_error()
    test_waiting_for_a_time_that_has_gone()
    test_the_condition_attributes_go_both_ways()
    test_a_read_write_lock_takes_for_reading_and_writing()
    test_a_read_write_lock_can_be_made_from_attributes()
    test_the_rwlock_attribute_object_is_the_size_it_has_to_be()
    print("test_sync: ok")
