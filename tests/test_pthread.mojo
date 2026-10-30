"""Tests for the `libc.pthread` bindings, none of which had been called.

The module is the attribute object and nothing else: `pthread_create`
and the mutexes are not here yet.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.pthread import (
    PTHREAD_CANCEL_ASYNCHRONOUS,
    PTHREAD_CANCEL_DEFERRED,
    PTHREAD_CANCEL_DISABLE,
    PTHREAD_CANCEL_ENABLE,
    PTHREAD_CREATE_DETACHED,
    PTHREAD_CREATE_JOINABLE,
    PTHREAD_EXPLICIT_SCHED,
    PTHREAD_INHERIT_SCHED,
    PTHREAD_SCOPE_SYSTEM,
    pthread_attr_destroy,
    pthread_attr_getdetachstate,
    pthread_attr_getguardsize,
    pthread_attr_getinheritsched,
    pthread_attr_getschedparam,
    pthread_attr_getschedpolicy,
    pthread_attr_getscope,
    pthread_attr_getstack,
    pthread_attr_getstacksize,
    pthread_attr_init,
    pthread_attr_setdetachstate,
    pthread_attr_setguardsize,
    pthread_attr_setinheritsched,
    pthread_attr_setschedparam,
    pthread_attr_setschedpolicy,
    pthread_attr_setscope,
    pthread_attr_setstack,
    pthread_attr_setstacksize,
    pthread_attr_t,
    pthread_cancel,
    pthread_condattr_destroy,
    pthread_condattr_t,
    pthread_detach,
    pthread_equal,
    pthread_getspecific,
    pthread_key_create,
    pthread_key_delete,
    pthread_key_t,
    pthread_kill,
    pthread_self,
    pthread_setcancelstate,
    pthread_setcanceltype,
    pthread_setspecific,
    pthread_sigmask,
    pthread_t,
    pthread_testcancel,
)
from libc.signal import SIG_BLOCK, sigemptyset
from libc.sched import SCHED_OTHER, sched_param
from libc.utils import is_null, null_ptr

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


def test_the_scheduling_settings() raises:
    """The three pairs of attribute calls to do with scheduling, each
    asked whether the one beside it reads back what was written:
    `pthread_attr_setschedparam` and `pthread_attr_getschedparam` for
    the priority, `_setschedpolicy` and `_getschedpolicy` for the
    policy, and `_setinheritsched` and `_getinheritsched` for whether
    a thread is to take its scheduling from the one that makes it.

    Each is asked twice, once with the setting it was found with and
    once with the other. That is what the constant is for: the
    inheritsched constants are 0 and 1 on glibc and 1 and 2 here, so a
    test that named only one of them would pass just as well if the two
    had been swapped. Asking for the other one and finding it there is
    what would notice.

    `pthread_attr_setscope` is asked for SYSTEM alone. Darwin supports
    SYSTEM only, by its own header's account, so asking for PROCESS
    there is a question with an answer that is not a setting.
    """
    var attr = unsafe_alloc[pthread_attr_t](1)
    assert_equal(pthread_attr_init(attr), 0, "pthread_attr_init fills one in")

    var param = unsafe_alloc[sched_param](1)
    param.unsafe_offset(0)[] = sched_param()
    var again = unsafe_alloc[sched_param](1)
    again.unsafe_offset(0)[] = sched_param()
    assert_equal(
        pthread_attr_getschedparam(attr, param), 0, "the priority reads out"
    )
    assert_equal(
        pthread_attr_setschedparam(attr, param),
        0,
        "and the same one is taken back",
    )
    assert_equal(pthread_attr_getschedparam(attr, again), 0)
    assert_equal(
        again.unsafe_offset(0)[].sched_priority(),
        param.unsafe_offset(0)[].sched_priority(),
        "and it is the one that was written",
    )

    var policy = unsafe_alloc[Int32](1)
    assert_equal(
        pthread_attr_getschedpolicy(attr, policy), 0, "the policy reads out"
    )
    assert_equal(
        policy.unsafe_offset(0)[],
        SCHED_OTHER,
        "and a new one is on the ordinary policy",
    )
    assert_equal(
        pthread_attr_setschedpolicy(attr, SCHED_OTHER),
        0,
        "and the ordinary policy is taken back",
    )
    assert_equal(pthread_attr_getschedpolicy(attr, policy), 0)
    assert_equal(
        policy.unsafe_offset(0)[],
        SCHED_OTHER,
        "and is the one that was written",
    )

    # The pair that is asked for both of its values, for the reason
    # given above.
    var inheritsched = unsafe_alloc[Int32](1)
    assert_equal(
        pthread_attr_setinheritsched(attr, PTHREAD_INHERIT_SCHED),
        0,
        "taking its scheduling from the caller is accepted",
    )
    assert_equal(pthread_attr_getinheritsched(attr, inheritsched), 0)
    assert_equal(
        inheritsched.unsafe_offset(0)[],
        PTHREAD_INHERIT_SCHED,
        "and that is what comes back",
    )
    assert_equal(
        pthread_attr_setinheritsched(attr, PTHREAD_EXPLICIT_SCHED),
        0,
        "carrying its own is accepted too",
    )
    assert_equal(pthread_attr_getinheritsched(attr, inheritsched), 0)
    assert_equal(
        inheritsched.unsafe_offset(0)[],
        PTHREAD_EXPLICIT_SCHED,
        "and the two are told apart",
    )

    var scope = unsafe_alloc[Int32](1)
    assert_equal(
        pthread_attr_setscope(attr, PTHREAD_SCOPE_SYSTEM),
        0,
        "contending with every thread is accepted",
    )
    assert_equal(pthread_attr_getscope(attr, scope), 0)
    assert_equal(
        scope.unsafe_offset(0)[], PTHREAD_SCOPE_SYSTEM, "and that comes back"
    )

    assert_equal(
        pthread_attr_destroy(attr), 0, "pthread_attr_destroy takes it back"
    )

    scope.unsafe_free()
    inheritsched.unsafe_free()
    policy.unsafe_free()
    again.unsafe_free()
    param.unsafe_free()
    attr.unsafe_free()


def test_which_thread_and_whether_it_may_end() raises:
    """`pthread_self` names the thread that asked, and `pthread_equal`
    says whether two names are the same thread. Asking twice has to name
    the same thread both times, and a zeroed handle is no thread at all,
    so it has to answer no against that — which is the half that makes
    the first answer worth anything, a test that asked only whether a
    thing equals itself would pass whatever the call did.

    The cancellation state and type are each asked for both of their
    values in turn. Here again the constants are one another's numbers
    across the two platforms — ENABLE is 0 on glibc and 1 here, while
    DISABLE is 1 and 0, and DEFERRED is 0 against 2 — so naming one
    value would pass just as well if the pair had been swapped. What is
    checked is that each one comes back out again behind the other.

    `pthread_testcancel` puts a cancellation point here, which is
    nothing at all while no cancellation is waiting: it comes straight
    back. Nothing here asks for one, that being a thing which cannot be
    taken back once asked, and so a test that asked it of itself would
    end at that line rather than go on to the next.

    `pthread_cancel` and `pthread_detach` are bound and not called. The
    first is a request that cannot be withdrawn, and the second, asked
    of the thread that is running the tests, leaves nothing after it
    for the rest of them to go on with.
    """
    var me = pthread_self()
    var again = pthread_self()
    assert_true(pthread_equal(me, again) != 0, "the same thread, asked twice")

    var nobody = pthread_t()
    assert_equal(
        pthread_equal(me, nobody),
        0,
        "and a zeroed handle is no thread at all",
    )

    var old = unsafe_alloc[Int32](1)
    assert_equal(
        pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, old),
        0,
        "not being cancellable is accepted",
    )
    assert_equal(
        pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, old),
        0,
        "and being cancellable is too, from which",
    )
    assert_equal(
        old.unsafe_offset(0)[],
        PTHREAD_CANCEL_DISABLE,
        "the one that was there before comes back, the two told apart",
    )

    assert_equal(
        pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, old),
        0,
        "ending at once is accepted",
    )
    assert_equal(
        old.unsafe_offset(0)[],
        PTHREAD_CANCEL_DEFERRED,
        "and waiting for a point is what it was before",
    )
    assert_equal(
        pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, old),
        0,
        "waiting for a point is accepted, from which",
    )
    assert_equal(
        old.unsafe_offset(0)[],
        PTHREAD_CANCEL_ASYNCHRONOUS,
        "the other comes back, the two told apart",
    )

    # Comes back at once: no cancellation has been asked for here, and
    # none is ever, for the reason given above.
    pthread_testcancel()

    old.unsafe_free()


def test_a_slot_of_its_own() raises:
    """`pthread_key_create` has the library set aside a slot this
    thread may keep one thing in, `pthread_setspecific` puts a thing
    there and `pthread_getspecific` reads it back, and
    `pthread_key_delete` gives the slot away again.

    What is asked of `pthread_getspecific` is not only that it hands
    back what was put in but that a slot nobody has put anything in
    answers nothing. That is the half that makes the first half worth
    asking: a call that answered whatever it happened to find would
    still hand back what was just written, since it is the same place
    either way, and only the empty slot tells the two apart.

    The destructor that `pthread_key_create` takes is `null_ptr` here,
    which is to say that nothing is done with the value when the
    thread ends. A Mojo closure cannot be made into a C function
    pointer, so this is the only thing that can be given, and it is
    what the binding says in its own notes.
    """
    var key = unsafe_alloc[pthread_key_t](1)
    assert_equal(
        pthread_key_create(key, null_ptr[UInt8]()),
        0,
        "pthread_key_create hands out a key",
    )

    assert_true(
        is_null(pthread_getspecific(key.unsafe_offset(0)[])),
        "and the slot it names starts out holding nothing",
    )

    var thing = unsafe_alloc[UInt8](1)
    assert_equal(
        pthread_setspecific(key.unsafe_offset(0)[], thing),
        0,
        "pthread_setspecific puts something in it, and",
    )
    assert_true(
        pthread_getspecific(key.unsafe_offset(0)[]) == thing,
        "pthread_getspecific hands back the very thing that went in",
    )

    assert_equal(
        pthread_setspecific(key.unsafe_offset(0)[], null_ptr[UInt8]()),
        0,
        "pthread_setspecific takes it out again, and",
    )
    assert_true(
        is_null(pthread_getspecific(key.unsafe_offset(0)[])),
        "nothing is what is there after",
    )

    assert_equal(
        pthread_key_delete(key.unsafe_offset(0)[]),
        0,
        "pthread_key_delete gives the slot back",
    )

    thing.unsafe_free()
    key.unsafe_free()


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


def empty_set() -> c_ptr[UInt8]:
    """A zeroed block big enough for either platform's `sigset_t`."""
    var mask = unsafe_alloc[UInt8](128)
    for i in range(128):
        mask.unsafe_store(i, UInt8(0))
    _ = sigemptyset(mask)
    return mask


def test_a_thread_can_be_asked_for_and_keeps_its_own_mask() raises:
    """`pthread_kill` sends a signal to one thread, and
    `pthread_sigmask` says which signals a thread is to be handed.

    `pthread_kill` is asked with signal 0, which sends nothing and
    only asks whether the thread is there — and it is, being the one
    doing the asking. Nothing is sent, so nothing is disturbed.

    `pthread_sigmask` is given `SIG_BLOCK` and a set with nothing in
    it, which blocks nothing and so changes nothing, meaning it can
    be asked twice and the mask it hands back — which is the mask as
    it was before — is the same both times. That is what is asked
    here, and it is the same thing `sigprocmask` is asked.

    The set is a block of zeroes big enough for either platform's
    `sigset_t`, filled by `sigemptyset`, which is how this package
    keeps from having to lay that struct out.
    """
    assert_equal(
        pthread_kill(pthread_self(), 0),
        0,
        "this thread is there to be asked for",
    )

    var empty = empty_set()
    var before = empty_set()
    var also_before = empty_set()

    assert_equal(
        pthread_sigmask(SIG_BLOCK, empty, before),
        0,
        "pthread_sigmask blocks nothing and says so",
    )
    assert_equal(
        pthread_sigmask(SIG_BLOCK, empty, also_before),
        0,
        "and asked again, hands back",
    )
    assert_equal(
        before.unsafe_load(0),
        also_before.unsafe_load(0),
        "the same mask it handed back the first time",
    )

    empty.unsafe_free()
    before.unsafe_free()
    also_before.unsafe_free()


def main() raises:
    test_the_attribute_object()
    test_the_scheduling_settings()
    test_which_thread_and_whether_it_may_end()
    test_a_slot_of_its_own()
    test_the_one_that_is_left()
    test_a_thread_can_be_asked_for_and_keeps_its_own_mask()
    print("test_pthread: ok")
