"""Tests for the `libc.pthread` bindings, none of which had been called.

The attribute object, the thread that is asking, and the scheduling
settings it carries. No second thread is ever started: `pthread_create`
takes a function pointer, which Mojo cannot make one of. So the one call
that is about a thread ending — `pthread_detach` — is asked about the
initial thread instead, which is the only thread there is. The mutexes
are in `test_mutex.mojo`.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import EINVAL, c_ptr
from libc.stdlib import exit
from libc.sys.wait import WEXITSTATUS, WIFEXITED, WIFSIGNALED, WTERMSIG, waitpid
from libc.unistd import close, fork, pipe, read, usleep, write
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
    pthread_getschedparam,
    pthread_self,
    pthread_setschedparam,
    pthread_setcancelstate,
    pthread_setcanceltype,
    pthread_setspecific,
    pthread_sigmask,
    pthread_t,
    pthread_testcancel,
)
from libc.signal import (
    SIGWINCH,
    SIG_BLOCK,
    SIG_UNBLOCK,
    sigaddset,
    sigemptyset,
    sigismember,
)
from libc.sched import SCHED_FIFO, SCHED_OTHER, sched_param
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

    # `_init` is not only a call that answers 0: it puts the defaults in, and
    # a stack size is the one of them that is not 0 on either platform, so it
    # is what says the object was filled in rather than left as found.
    var fresh = unsafe_alloc[Int](1)
    assert_equal(pthread_attr_getstacksize(attr, fresh), 0)
    assert_true(
        Int(fresh.unsafe_load()) > 0,
        "a stack size is filled in, not left at nothing",
    )
    # And it puts them back: moved off the default, `init` again, and the
    # default is what is there. That is what tells it from `_destroy`, which
    # has the same signature, the same answer of 0, and leaves the object as
    # it found it -- measurably so: the detach state stays where it was put.
    assert_equal(pthread_attr_setdetachstate(attr, PTHREAD_CREATE_DETACHED), 0)
    assert_equal(pthread_attr_init(attr), 0, "and init puts them back")
    assert_equal(pthread_attr_getdetachstate(attr, state), 0)
    assert_equal(
        state.unsafe_load(), PTHREAD_CREATE_JOINABLE, "the default state again"
    )
    fresh.unsafe_free()
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

    # A priority of nothing is what a new object has, so reading it and then
    # writing it back says nothing about which of the two calls did which: a
    # `set` that only read would leave the same nothing behind and the pair
    # would look right. What is written is seven, which glibc refuses under
    # the ordinary policy -- EINVAL -- so the policy goes to FIFO first.
    var policy = unsafe_alloc[Int32](1)
    assert_equal(
        pthread_attr_setschedpolicy(attr, SCHED_FIFO),
        0,
        "the policy goes to FIFO",
    )
    param.unsafe_offset(0)[] = sched_param(7)
    assert_equal(
        pthread_attr_setschedparam(attr, param),
        0,
        "and a priority of seven is written",
    )
    assert_equal(pthread_attr_getschedparam(attr, again), 0)
    assert_equal(
        again.unsafe_offset(0)[].sched_priority(),
        7,
        "and it is the one that was written",
    )

    # FIFO is on the object now, so a `get` that read the detach state instead
    # -- 1 against 0 and the two told apart on both platforms -- answers the
    # other one of them. And a `set` that wrote the detach state leaves the
    # policy where it was, which is the assertion after the write.
    assert_equal(
        pthread_attr_getschedpolicy(attr, policy), 0, "the policy reads out"
    )
    assert_equal(
        policy.unsafe_offset(0)[],
        SCHED_FIFO,
        "and it is the one that was written",
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

    # `PTHREAD_CREATE_JOINABLE` and `PTHREAD_SCOPE_SYSTEM` are the same
    # number on both platforms, so a binding that called
    # `pthread_attr_getdetachstate` would write exactly the value the assert
    # below wants unless the detach state is the other one. It is put on
    # DETACHED here, which is not SYSTEM on glibc, and the assertion after
    # the scope call reads it back: a `setscope` that moved the detach state
    # instead leaves it at SYSTEM, which is where this notices. On Darwin the
    # two numbers are both 1, so that half of the question has one answer
    # there and it is the one that says nothing.
    assert_equal(
        pthread_attr_setdetachstate(attr, PTHREAD_CREATE_DETACHED),
        0,
        "the detach state is put away from the scope's own number",
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
    # That answer is not the one this test can rest on: both platforms
    # implement one scope, and `pthread_attr_getscope` answers SYSTEM
    # whatever is on the object, so a `setscope` that wrote somewhere else
    # entirely would leave the same SYSTEM behind. What it would have moved
    # is the detach state -- the two calls have the same signature -- and
    # that one is JOINABLE here and readable, so it is what is asked.
    var detach = unsafe_alloc[Int32](1)
    assert_equal(pthread_attr_getdetachstate(attr, detach), 0)
    assert_equal(
        detach.unsafe_load(),
        PTHREAD_CREATE_DETACHED,
        "and setting the scope moved nothing else",
    )
    detach.unsafe_free()

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

    `pthread_cancel` is a request that cannot be withdrawn, so it is
    asked below of a child rather than of the thread that is running
    the tests; `pthread_detach` is asked further down, of this thread.
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

    # The type and the state are the two calls with the same signature, the
    # same two values 0 and 1, and the same answer of 0. What tells them
    # apart is which of the two is written back into `old`: so the state is
    # put on the value the type is not, before each of them. Left on the
    # other one, the answer would be the same number either way.
    assert_equal(
        pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, old),
        0,
        "the state goes to DISABLE, which the type is not",
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
        pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, old),
        0,
        "the state goes back to ENABLE, which the type is not",
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

    `pthread_atfork` is the one of the twelve not called at all, and it is
    the run that fails rather than the call: glibc exports it with no
    default version, so the just-in-time run's lookup of the bare name
    finds nothing, while a built binary resolves it at link time and gets
    0 back. This suite is the just-in-time run, so the call is not made
    here; the binding's docstring records both answers.
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

    # And then asked for something that changes the mask, which is what tells
    # the two arguments apart: the set goes in first and the mask it replaces
    # comes back second, and the assertions above hold with them either way
    # round because both are the same empty mask. `SIGWINCH` is the signal
    # borrowed -- nothing sends one -- and blocking it is undone below.
    var winch = empty_set()
    assert_equal(sigaddset(winch, SIGWINCH), 0, "a set with one signal in it")
    assert_equal(
        pthread_sigmask(SIG_BLOCK, winch, before),
        0,
        "the one signal is blocked",
    )
    assert_equal(
        sigismember(before, SIGWINCH), 0, "the mask handed back predates that"
    )
    assert_equal(
        pthread_sigmask(SIG_BLOCK, null_ptr[UInt8](), before),
        0,
        "and asked with no set, it only reports",
    )
    assert_equal(
        sigismember(before, SIGWINCH), 1, "which is the block in force"
    )
    assert_equal(
        pthread_sigmask(SIG_UNBLOCK, winch, null_ptr[UInt8]()),
        0,
        "and put back",
    )
    winch.unsafe_free()

    empty.unsafe_free()
    before.unsafe_free()
    also_before.unsafe_free()


def test_the_scheduling_parameters_of_this_thread() raises:
    """`pthread_getschedparam` says which policy a thread runs under and
    what its priority in it is, and `pthread_setschedparam` asks for a
    pair.

    The policy is asserted to be the one the constant names rather than
    merely to be a number that came back, the thread a program starts on
    running under it: which policy it is, is the answer.

    Whether asking for a policy that does exist is granted is not
    asserted, and cannot be: on Darwin the call goes to the kernel and
    comes back refused for want of the right to set a priority, where on
    Linux asking for the pair already in place is granted to anyone. So
    what is asked is that the pair be left as it was either way — which
    is the same pair, and the one thing both answers agree on — and that
    a policy which does not exist be refused outright.
    """
    var policy = unsafe_alloc[Int32](1)
    policy.unsafe_offset(0)[] = -1
    var param = unsafe_alloc[sched_param](1)
    param.unsafe_offset(0)[] = sched_param()

    assert_equal(
        pthread_getschedparam(pthread_self(), policy, param),
        0,
        "the scheduling parameters of this thread are read",
    )
    assert_equal(
        Int(policy.unsafe_load(0)),
        Int(SCHED_OTHER),
        "and the policy is the one every thread starts under",
    )

    var asked = param.unsafe_offset(0)[].sched_priority()
    _ = pthread_setschedparam(pthread_self(), policy.unsafe_load(0), param)

    var again_policy = unsafe_alloc[Int32](1)
    again_policy.unsafe_offset(0)[] = -1
    var again = unsafe_alloc[sched_param](1)
    again.unsafe_offset(0)[] = sched_param()
    assert_equal(pthread_getschedparam(pthread_self(), again_policy, again), 0)
    assert_equal(
        Int(again_policy.unsafe_load(0)),
        Int(policy.unsafe_load(0)),
        "and asking for the pair in place leaves the policy where it was",
    )
    assert_equal(
        Int(again.unsafe_offset(0)[].sched_priority()),
        Int(asked),
        "and the priority too, whether or not the ask was granted",
    )

    assert_true(
        pthread_setschedparam(pthread_self(), 9999, param) != 0,
        "a policy that does not exist is refused",
    )

    policy.unsafe_free()
    param.unsafe_free()
    again_policy.unsafe_free()
    again.unsafe_free()


def test_detaching_the_thread_that_is_asking() raises:
    """There is one thread here, and nobody is going to join it. What is
    asked of `pthread_detach` is that it says either that the thread was
    detached or that it was never joinable in the first place, and that
    asking twice cannot detach it twice.

    That second answer is the one both libcs agree on: `EINVAL`. POSIX
    leaves the initial thread's detachability to the implementation, so
    the first answer is 0 on one and `EINVAL` on another — but the flag
    it changes is gone either way, and the second call is the one that
    would catch a binding that never made the change.

    The initial thread is not joined by anything in this process, so
    detaching it costs the suite nothing.
    """
    var first = pthread_detach(pthread_self())
    assert_true(
        first == 0 or first == EINVAL,
        "the initial thread is detached, or was not joinable to begin with"
        + " (it answered "
        + String(first)
        + ")",
    )
    assert_equal(
        pthread_detach(pthread_self()),
        EINVAL,
        "and a second detach cannot find a joinable thread to detach",
    )


def _ask_to_be_cancelled_from_a_child(disabled: Bool, fds: c_ptr[Int32]) raises:
    """The child's half: ask for this thread to be cancelled, wait at a
    cancellation point, and write a byte if it comes back.

    With cancellation disabled the request is held rather than dropped,
    which is the state a caller sets when it must not be interrupted
    part-way through something -- so the byte is written and the child
    leaves with 0. With cancellation left at its default the byte is
    what is never written.
    """
    if disabled:
        var old = unsafe_alloc[Int32](1)
        assert_equal(
            pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, old),
            0,
            "this child will not be interrupted part-way",
        )
        old.unsafe_free()

    _ = pthread_cancel(pthread_self())

    # A cancellation point: `usleep` is on the list, so a request that
    # is enabled is taken here and the code below never runs.
    _ = usleep(50000)

    var said = unsafe_alloc[UInt8](1)
    said.unsafe_store(0, UInt8(1))
    _ = write(fds.unsafe_offset(1)[], said, 1)
    said.unsafe_free()
    _ = exit(0)


def test_cancelling_this_thread_ends_it_unless_it_is_disabled() raises:
    """`pthread_cancel` asked of the only thread there is, in a child, so
    that what it does is done to the child.

    Two children ask, and the difference between them is one call.
    `pthread_setcancelstate(DISABLE)` is what a caller uses to say "not
    part-way through this", and a cancellation point reached with the
    request held comes back: the child writes a byte and leaves with 0.
    The child that asked with cancellation left enabled never writes
    anything at all, which is the whole of what the parent can see of it
    -- how the run ends is the platform's business (glibc ends this
    process with status 0, Darwin ends it on a signal), and neither is
    asserted.

    The pair is what makes it a question with an answer. A cancel that
    did nothing would leave both children writing; a cancel that killed
    outright would leave neither, and would also fail the first one,
    which is asked to survive it.
    """
    for which in range(2):
        var disabled = which == 1
        var fds = unsafe_alloc[Int32](2)
        assert_equal(pipe(fds), 0, "a pipe for the child to answer down")

        var child = fork()
        if child == 0:
            _ = close(fds.unsafe_offset(0)[])
            _ask_to_be_cancelled_from_a_child(disabled, fds)

        _ = close(fds.unsafe_offset(1)[])
        var status = unsafe_alloc[Int32](1)
        status.unsafe_offset(0)[] = 0
        assert_equal(
            waitpid(child, status, 0), child, "the child is waited for"
        )

        var said = unsafe_alloc[UInt8](1)
        said.unsafe_store(0, UInt8(0))
        var came_back = read(fds.unsafe_offset(0)[], said, 1)
        said.unsafe_free()

        if disabled:
            assert_equal(
                came_back,
                1,
                (
                    "with cancellation disabled the child comes back from the"
                    " point"
                ),
            )
            assert_true(
                WIFEXITED(status.unsafe_load()), "and leaves of its own accord"
            )
            assert_equal(
                Int(WEXITSTATUS(status.unsafe_load())), 0, "having written it"
            )
        else:
            assert_equal(
                came_back,
                0,
                "with cancellation enabled it does not come back at all",
            )
            assert_true(
                WIFEXITED(status.unsafe_load())
                or WIFSIGNALED(status.unsafe_load()),
                "and the run has ended it, one way or the other",
            )

        status.unsafe_free()
        fds.unsafe_free()


def main() raises:
    test_the_attribute_object()
    test_the_scheduling_settings()
    test_the_scheduling_parameters_of_this_thread()
    test_which_thread_and_whether_it_may_end()
    test_a_slot_of_its_own()
    test_the_one_that_is_left()
    test_a_thread_can_be_asked_for_and_keeps_its_own_mask()
    test_detaching_the_thread_that_is_asking()
    test_cancelling_this_thread_ends_it_unless_it_is_disabled()
    print("test_pthread: ok")
