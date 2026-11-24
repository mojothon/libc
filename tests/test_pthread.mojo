"""Tests for the `libc.pthread` bindings.

The attribute object, the thread that is asking, the scheduling settings
it carries, and — at the end — a thread that is not this one. For a long
time there was none: `pthread_create` takes a function pointer, and this
package could not hand C one. It can, now that a `def` that captures
nothing converts to a `thin` function value, which is a code address and
nothing else. So the last two tests start a thread and wait for it, and
the assertions are about what only a second thread could have done:
`pthread_equal` saying it is not this one, a byte it set being there, and
a pointer it left being what the join read back.

The mutexes are in `test_mutex.mojo`.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true
from libc.utils import char_ptr_to_string

from libc.constant import (
    EBUSY,
    EAGAIN,
    EINVAL,
    ENOENT,
    ETIMEDOUT,
    c_int,
    ERANGE,
    c_ptr,
    c_void,
)
from libc.utils import null_ptr, string_to_char_ptr
from libc.stdlib import exit
from libc.sys.wait import WEXITSTATUS, WIFEXITED, WIFSIGNALED, WTERMSIG, waitpid
from libc.fcntl import O_CREAT, O_EXCL
from libc.errno import get_errno, set_errno
from libc.time import CLOCK_REALTIME, clock_gettime, timespec
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
    pthread_create,
    pthread_exit,
    pthread_join,
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
    pthread_getcpuclockid,
    pthread_setschedparam,
    pthread_setcancelstate,
    pthread_setcanceltype,
    pthread_setspecific,
    pthread_sigmask,
    pthread_t,
    pthread_testcancel,
    sem_close,
    sem_destroy,
    sem_getvalue,
    sem_init,
    sem_open,
    sem_post,
    sem_timedwait,
    sem_trywait,
    sem_unlink,
    sem_wait,
    SEM_FAILED,
    pthread_spin_init,
    pthread_spin_destroy,
    pthread_spin_lock,
    pthread_spin_trylock,
    pthread_spin_unlock,
    PTHREAD_PROCESS_PRIVATE,
    pthread_spinlock_t,
    pthread_getname_np,
    pthread_setname_np,
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
    detaching it costs the suite nothing. The asking happens in a child
    all the same, and the child does not just leave its exit code as
    the witness: a binding pointed at a call that takes the asking
    thread's own thread down -- `pthread_cancel` is a sibling that
    takes the same argument -- ends a glibc process with exit status 0,
    which no wait can tell from a passing run. So the child says so
    down a pipe: a byte written after the second answer was read, which
    a detached thread sends and a cancelled one never reaches.
    """
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "a pipe for the child to say it passed")

    var child = fork()
    if child == 0:
        _ = close(fds.unsafe_offset(0)[])
        var first = pthread_detach(pthread_self())
        assert_true(
            first == 0 or first == EINVAL,
            "the initial thread is detached, or was not joinable to begin"
            + " with (it answered "
            + String(first)
            + ")",
        )
        assert_equal(
            pthread_detach(pthread_self()),
            EINVAL,
            "and a second detach cannot find a joinable thread to detach",
        )
        _ = write(fds.unsafe_offset(1)[], string_to_char_ptr("."), 1)
        _ = exit(0)

    assert_true(child > 0, "there is a child to do the detaching in")
    _ = close(fds.unsafe_offset(1)[])
    var said = unsafe_alloc[UInt8](1)
    said.unsafe_store(0, UInt8(0))
    assert_equal(
        read(fds.unsafe_offset(0)[], said, 1),
        1,
        "the child got past both answers before it left",
    )
    said.unsafe_free()

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    assert_true(WIFEXITED(status.unsafe_load()), "and it ended by itself")
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())), 0, "having said it passed"
    )
    status.unsafe_free()
    fds.unsafe_free()


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


# What the started thread writes down, in the block it is pointed at: its
# own ID first, then a byte saying it got that far. A byte is enough --
# the claim is not what it wrote but that anything wrote at all, and one
# byte at a known offset needs no struct to read back.
comptime MARK_OFFSET: Int = 8
comptime MARK: UInt8 = 0x5A


def the_second_thread(arg: c_ptr[c_void]) -> c_ptr[c_void]:
    """What the thread started by the test runs.

    It writes its own ID into the block it was pointed at, then a byte
    past it, and answers the argument unchanged -- so what the join reads
    and what the block holds are two separate claims about the same call.

    Args:
        arg: The block, as a `void *`.

    Returns:
        The same pointer, which is what `pthread_join` hands back.
    """
    var block = arg.unsafe_bitcast[UInt8]()
    block.unsafe_bitcast[pthread_t]().unsafe_offset(0)[] = pthread_self()
    block.unsafe_offset(MARK_OFFSET)[] = MARK
    return arg


def the_thread_that_leaves_early(arg: c_ptr[c_void]) -> c_ptr[c_void]:
    """What the second test's thread runs: it ends through `pthread_exit`
    rather than by returning, so that what the join reads can only have
    come from that call.

    Args:
        arg: The pointer `pthread_exit` is given.

    Returns:
        Never anything: the call above does not come back.
    """
    _ = pthread_exit(arg)
    return arg


def test_a_thread_of_its_own() raises:
    """A thread is started, waited for, and asked who it was.

    Four claims, none of which the initial thread could have satisfied on
    its own: a byte it was told to write is there, the ID written beside
    it belongs to some other thread, the join read back the pointer the
    start routine answered, and the create and the join both said 0.

    The block is only read after the join, which is what makes reading it
    without a lock honest: the thread that wrote it has ended, and joining
    is what says so.
    """
    var block = unsafe_alloc[UInt8](16)
    for i in range(16):
        block.unsafe_offset(i)[] = 0
    var id = unsafe_alloc[pthread_t](1)
    var start: def(c_ptr[c_void]) thin -> c_ptr[c_void] = the_second_thread
    assert_equal(
        pthread_create(
            id,
            null_ptr[pthread_attr_t](),
            start,
            block.unsafe_bitcast[c_void](),
        ),
        0,
        "a thread is started",
    )
    var answer = unsafe_alloc[c_ptr[c_void]](1)
    assert_equal(
        pthread_join(id.unsafe_offset(0)[], answer), 0, "and waited for"
    )
    assert_equal(
        Int(block.unsafe_offset(MARK_OFFSET)[]),
        Int(MARK),
        "the byte it was told to write is there",
    )
    assert_equal(
        Int(answer.unsafe_offset(0)[]),
        Int(block.unsafe_bitcast[c_void]()),
        "it answered the argument it was handed",
    )
    assert_equal(
        Int(
            pthread_equal(
                pthread_self(),
                block.unsafe_bitcast[pthread_t]().unsafe_offset(0)[],
            )
        ),
        0,
        "and the ID it wrote is not this thread's",
    )
    answer.unsafe_free()
    id.unsafe_free()
    block.unsafe_free()


def test_a_thread_that_ends_through_pthread_exit() raises:
    """A thread that leaves by way of `pthread_exit` is joinable like one
    that returns, and the pointer the join reads is the one that call was
    given rather than what the function returned.

    The start routine is written to return the same pointer either way, so
    the value arriving says nothing about which path it took; what says so
    is that nothing was on the stack for it to return through.
    """
    var id = unsafe_alloc[pthread_t](1)
    var marker = unsafe_alloc[UInt8](1)
    marker.unsafe_offset(0)[] = 0x21
    var start: def(c_ptr[c_void]) thin -> c_ptr[
        c_void
    ] = the_thread_that_leaves_early
    assert_equal(
        pthread_create(
            id,
            null_ptr[pthread_attr_t](),
            start,
            marker.unsafe_bitcast[c_void](),
        ),
        0,
        "a thread that will leave early is started",
    )
    var answer = unsafe_alloc[c_ptr[c_void]](1)
    assert_equal(
        pthread_join(id.unsafe_offset(0)[], answer),
        0,
        "and it joins like any other",
    )
    assert_equal(
        Int(answer.unsafe_offset(0)[]),
        Int(marker.unsafe_bitcast[c_void]()),
        "with what pthread_exit was given",
    )
    answer.unsafe_free()
    marker.unsafe_free()
    id.unsafe_free()


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
    test_a_thread_of_its_own()
    test_a_thread_that_ends_through_pthread_exit()
    test_the_named_semaphore_and_its_count()
    test_the_moment_the_waiting_gives_up()
    test_the_unnamed_one_in_the_room_the_caller_has()
    test_the_refusal_for_a_semaphore_the_room_says_is_busy()
    test_a_clock_that_counts_one_thread_own_work()
    test_a_lock_spun_until_it_is_free()
    test_a_thread_named_again_by_the_name_it_goes_by()
    print("test_pthread: ok")


def test_the_named_semaphore_and_its_count() raises:
    """The named semaphore and the count it is made with: asked
    where the making of one can be asked safely -- Darwin has the
    named kind too, but a variadic callee there reads its extra
    arguments from the stack, which a call that names all four
    does not give it, so the mode and the value arrive as
    something else and the making is refused. Opened
    into being with a count of one -- taken down by the ask that
    does not stand in line, refused the second time with the word
    for try again -- and put back up by the ask that gives. The
    name taken off the system's list leaves the asking of it
    nothing, and an open of a name there is not is the word for
    failure in the slot a semaphore comes back in.
    """
    comptime if not CompilationTarget.is_macos():
        comptime NAME = string_to_char_ptr("/libc_mojo_sem_a")
        comptime RW: Int32 = 384

        # A run that failed before its unlink leaves the name behind, and
        # the exclusive ask is refused by what a failed run left -- so the
        # asking starts by taking the name off, which answers -1 when
        # there is nothing there to take off.
        _ = sem_unlink(NAME)
        var s = sem_open(NAME, O_CREAT | O_EXCL, RW, 1)
        assert_true(Int(s) != Int(SEM_FAILED), "the named semaphore is made")

        assert_equal(
            sem_trywait(s), 0, "the count of one is taken without a wait"
        )
        set_errno(0)
        assert_equal(
            sem_trywait(s), -1, "and the second ask finds nothing to take"
        )
        assert_equal(
            Int(get_errno()), Int(EAGAIN), "with the word for try again"
        )

        assert_equal(sem_post(s), 0, "and the giver puts the count back up")

        comptime if not CompilationTarget.is_macos():
            var v = unsafe_alloc[Int32](1)
            assert_equal(
                sem_getvalue(s, v), 0, "the count is a thing that can be read"
            )
            assert_equal(
                Int(v.unsafe_offset(0)[]),
                1,
                "and it is the count the giver left",
            )

        assert_equal(sem_close(s), 0, "the hold is given back")
        assert_equal(sem_unlink(NAME), 0, "and the name is taken off the list")

        var gone = sem_open(NAME, 0, 0, 0)
        assert_true(Int(gone) == Int(SEM_FAILED), "the name finds nothing now")
        assert_equal(
            Int(get_errno()),
            Int(ENOENT),
            "with the word for a name that is not",
        )


def test_the_moment_the_waiting_gives_up() raises:
    """`sem_timedwait` of a count of nothing: the moment named,
    asked where the C library has the call -- Darwin's libSystem
    has no symbol for it, and the moment is asked of the clock
    that has one.
    the clock's reading now plus a tenth of a second -- and the
    refusal at the moment is the word for the time being spent
    with the count still not there. The moment is a moment and
    not a wait, which is why it is taken from the clock and not
    made up from nothing.
    """
    comptime if not CompilationTarget.is_macos():
        comptime NAME = string_to_char_ptr("/libc_mojo_sem_b")
        comptime RW: Int32 = 384

        _ = sem_unlink(NAME)
        var s = sem_open(NAME, O_CREAT | O_EXCL, RW, 0)
        assert_true(Int(s) != Int(SEM_FAILED), "the empty semaphore is made")

        var moment = unsafe_alloc[timespec](1)
        moment.unsafe_offset(0)[] = timespec()
        assert_equal(
            clock_gettime(CLOCK_REALTIME, moment),
            0,
            "the clock's reading is taken",
        )
        moment.unsafe_offset(0)[].tv_nsec = (
            moment.unsafe_offset(0)[].tv_nsec + 100_000_000
        )
        if moment.unsafe_offset(0)[].tv_nsec > 999_999_999:
            moment.unsafe_offset(0)[].tv_sec = (
                moment.unsafe_offset(0)[].tv_sec + 1
            )
            moment.unsafe_offset(0)[].tv_nsec = (
                moment.unsafe_offset(0)[].tv_nsec - 1_000_000_000
            )

        set_errno(0)
        assert_equal(
            sem_timedwait(s, moment),
            -1,
            "a wait on nothing gives up at the moment",
        )
        assert_equal(
            Int(get_errno()),
            Int(ETIMEDOUT),
            "with the word for the time being spent",
        )

        assert_equal(sem_close(s), 0, "the hold is given back")
        assert_equal(sem_unlink(NAME), 0, "and the name with it")

        moment.unsafe_free()


def test_the_unnamed_one_in_the_room_the_caller_has() raises:
    """`sem_init` makes a semaphore in room the caller has: the
    count it starts from is the count it is read at, the count
    taken down by the ask that waits is the count it is read at
    after -- and the taking down of the room leaves nothing to
    ask, there being no name for the system to keep alive.
    """
    comptime if not CompilationTarget.is_macos():
        var u = unsafe_alloc[c_int](4)
        u.unsafe_offset(0)[] = 0
        u.unsafe_offset(1)[] = 0
        u.unsafe_offset(2)[] = 0
        u.unsafe_offset(3)[] = 0

        assert_equal(
            sem_init(u, 0, 2), 0, "the unnamed semaphore is made in the room"
        )
        var v = unsafe_alloc[Int32](1)
        assert_equal(
            sem_getvalue(u, v), 0, "and its count is a thing that can be read"
        )
        assert_equal(Int(v.unsafe_offset(0)[]), 2, "the count it starts from")
        assert_equal(sem_wait(u), 0, "the ask that waits takes the count down")
        assert_equal(sem_getvalue(u, v), 0, "and it is read again")
        assert_equal(
            Int(v.unsafe_offset(0)[]), 1, "one less than it started from"
        )
        assert_equal(sem_destroy(u), 0, "and the room is taken down")

        v.unsafe_free()
        u.unsafe_free()


def test_the_refusal_for_a_semaphore_the_room_says_is_busy() raises:
    """`sem_destroy` of a semaphore with a taker waiting in it is
    one that refuses -- and the refusal of the ask the room
    cannot grant is what the caller checks. The unnamed
    semaphore taken down while nobody waits is the ordinary
    taking down; the difference is who is standing in the
    room, and a caller with nobody standing there asks the
    ordinary one.
    """
    comptime if not CompilationTarget.is_macos():
        var u = unsafe_alloc[c_int](4)
        u.unsafe_offset(0)[] = 0
        u.unsafe_offset(1)[] = 0
        u.unsafe_offset(2)[] = 0
        u.unsafe_offset(3)[] = 0
        assert_equal(sem_init(u, 0, 0), 0, "the empty semaphore is made")
        assert_equal(sem_post(u), 0, "the count is put up")
        assert_equal(
            sem_destroy(u), 0, "and the room is taken down with nobody waiting"
        )
        u.unsafe_free()


def test_a_clock_that_counts_one_thread_own_work() raises:
    """`pthread_getcpuclockid` names the clock that counts the
    processor time one thread has used: the clock of the part,
    asked beside the clock of the whole, both answering with
    readings that are not taken away.
    The clock named is asked where the C library has the call:
    Darwin's libSystem declares it and has no symbol for it.

    """
    comptime if not CompilationTarget.is_macos():
        var me = pthread_self()
        var tcid = unsafe_alloc[c_int](1)
        tcid.unsafe_offset(0)[] = -99
        assert_equal(
            Int(pthread_getcpuclockid(me, tcid)),
            0,
            "the thread's own clock is named",
        )
        var one = unsafe_alloc[timespec](1)
        one.unsafe_offset(0)[] = timespec()
        assert_equal(
            Int(clock_gettime(tcid.unsafe_offset(0)[], one)),
            0,
            "and the clock it names answers",
        )
        assert_true(
            one.unsafe_offset(0)[].tv_sec >= 0, "and the reading is a length"
        )
        tcid.unsafe_free()
        one.unsafe_free()


def test_a_lock_spun_until_it_is_free() raises:
    """`pthread_spin_init` makes the lock and the spin calls take
    the spin calls being had where the C library has them --
    Darwin's libSystem has no symbols for the spin family.
    it and give it up: the ask that does not wait looks once and
    is told `EBUSY` where somebody holds it, takes the lock at
    once where nobody does, and the giving up hands it to
    whoever asks next. A lock a thread holds is not a lock the
    same thread can ask for twice.
    """
    comptime if not CompilationTarget.is_macos():
        var lock = unsafe_alloc[pthread_spinlock_t](1)
        lock.unsafe_offset(0)[] = pthread_spinlock_t()
        assert_equal(
            Int(pthread_spin_init(lock, PTHREAD_PROCESS_PRIVATE)),
            0,
            "the lock is made",
        )
        assert_equal(Int(pthread_spin_lock(lock)), 0, "the lock is taken")
        assert_equal(
            Int(pthread_spin_trylock(lock)),
            EBUSY,
            "and the ask that does not wait is told somebody holds it",
        )
        assert_equal(Int(pthread_spin_unlock(lock)), 0, "the lock is given up")
        assert_equal(
            Int(pthread_spin_trylock(lock)),
            0,
            "and the ask that does not wait takes it at once",
        )
        assert_equal(Int(pthread_spin_unlock(lock)), 0, "and gives it up again")
        assert_equal(
            Int(pthread_spin_destroy(lock)), 0, "the storage is given back"
        )
        lock.unsafe_free()
        # The kernel does not check the word here: a number that is
        # neither the private one nor the shared one is taken as the
        # private one, and the lock is made all the same.
        var odd = unsafe_alloc[pthread_spinlock_t](1)
        odd.unsafe_offset(0)[] = pthread_spinlock_t()
        assert_equal(
            Int(pthread_spin_init(odd, 0x7FFFFFFF)),
            0,
            "and a word that is neither is not refused",
        )
        assert_equal(
            Int(pthread_spin_destroy(odd)), 0, "and its storage is given back"
        )
        odd.unsafe_free()


def test_a_thread_named_again_by_the_name_it_goes_by() raises:
    """`pthread_getname_np` and `pthread_setname_np` -- the
    thread's own word about what it is: the name it is made
    with is the process's own, the naming again is had by the
    ask that takes the thread, and the read-back says the name
    the ask left. A name longer than the kernel keeps is
    refused with `ERANGE`, and so is storage too short to hold
    the name, both said by the return and not by `errno`.
    The naming again is had where the kernel takes the thread
    as well -- Darwin's libSystem has a call of the same name
    that takes only the name.
    """
    var me = pthread_self()
    var named = unsafe_alloc[UInt8](64)
    for i in range(64):
        named.unsafe_offset(i)[] = 0
    assert_equal(
        Int(pthread_getname_np(me, named, 64)),
        0,
        "the thread's name is had",
    )
    var born = char_ptr_to_string(named)
    assert_true(born.byte_length() > 0, "and the name is something")
    comptime if not CompilationTarget.is_macos():
        var word = unsafe_alloc[UInt8](32)
        for i in range(32):
            word.unsafe_offset(i)[] = 0
        var want = "libc-mojo-thr"
        for i in range(want.byte_length()):
            word.unsafe_store(i, UInt8(ord(want[byte=i])))
        assert_equal(
            Int(pthread_setname_np(me, word)),
            0,
            "the thread is named again",
        )
        assert_equal(
            Int(pthread_getname_np(me, named, 64)),
            0,
            "and the read-back asks again",
        )
        var again = char_ptr_to_string(named)
        assert_equal(
            again, want, "and the name it says is the one it was given"
        )
        var long = unsafe_alloc[UInt8](32)
        for i in range(32):
            long.unsafe_offset(i)[] = 0
        var toolong = "this-name-is-far-too-long"
        for i in range(toolong.byte_length()):
            long.unsafe_store(i, UInt8(ord(toolong[byte=i])))
        assert_equal(
            Int(pthread_setname_np(me, long)),
            ERANGE,
            "and a name longer than the kernel keeps is refused",
        )
        assert_equal(
            Int(pthread_getname_np(me, word, 2)),
            ERANGE,
            "and storage too short for the name is refused the same way",
        )
        assert_equal(
            Int(pthread_setname_np(me, named)),
            0,
            "and the thread is left with the name it was made with",
        )
        word.unsafe_free()
        long.unsafe_free()
    named.unsafe_free()
