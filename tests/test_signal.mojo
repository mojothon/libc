from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import EINVAL, c_ptr
from libc.errno import get_errno, set_errno
from libc.signal import (
    SIGINT,
    SIG_BLOCK,
    craise,
    kill,
    sigaction,
    sigaddset,
    sigaltstack,
    sigdelset,
    sigemptyset,
    sigfillset,
    sigismember,
    sigpending,
    sigprocmask,
)
from libc.unistd import getpid
from libc.utils import null_ptr


def empty_set() -> c_ptr[UInt8]:
    """A zeroed block big enough for either platform's `sigset_t`."""
    var mask = unsafe_alloc[UInt8](128)
    for i in range(128):
        mask.unsafe_store(i, UInt8(0))
    _ = sigemptyset(mask)
    return mask


def test_sigaddset_round_trips_through_sigismember() raises:
    """Adding a signal is what `sigismember` then says yes about."""
    var mask = empty_set()
    assert_equal(sigismember(mask, SIGINT), 0, "an empty set holds nothing")

    assert_equal(sigaddset(mask, SIGINT), 0, "adding SIGINT succeeded")
    assert_equal(sigismember(mask, SIGINT), 1, "SIGINT is in the set now")

    assert_equal(sigdelset(mask, SIGINT), 0, "removing SIGINT succeeded")
    assert_equal(sigismember(mask, SIGINT), 0, "and it is gone again")


def test_sigismember_refuses_a_number_that_is_not_a_signal() raises:
    """Asking about a number no platform has answers -1, not 0."""
    var mask = empty_set()
    set_errno(0)
    assert_equal(sigismember(mask, Int32(100000)), -1, "not a signal here")
    assert_equal(get_errno(), EINVAL, "errno says which way it went wrong")

    set_errno(0)
    assert_equal(sigaddset(mask, Int32(100000)), -1, "nothing was added")
    assert_equal(get_errno(), EINVAL, "errno says which way it went wrong")


def test_sigpending_reports_an_empty_set_when_nothing_waits() raises:
    """Whatever is waiting, asking about it succeeds and uses the set."""
    var mask = empty_set()
    var waiting = empty_set()
    assert_equal(sigpending(waiting), 0, "sigpending succeeded")

    # A signal nobody is blocking has nowhere pending to be, so ask about
    # one using the empty mask rather than whatever it wrote down.
    assert_equal(
        sigismember(waiting, SIGINT), 0, "SIGINT is not waiting to be delivered"
    )
    _ = mask


comptime SET_SIZE = 128


def test_sigfillset_fills() raises:
    """`sigfillset` puts every signal into the set it is given. What
    that leaves is bytes that are not zeroes, and a set that was
    cleared first is the only way of knowing they came from it.
    """
    var set = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        set.unsafe_store(i, 0)

    assert_equal(sigfillset(set), 0, "sigfillset answers 0")
    assert_true(
        Int(set.unsafe_load(0)) != 0,
        "and what was zeroed is no longer zero",
    )
    set.unsafe_free()


def test_sigprocmask_read_twice_reads_the_same() raises:
    """`sigprocmask` is told what to do with a set and hands back the
    mask as it was before. Given `SIG_BLOCK` and a set with nothing in
    it, it blocks nothing and changes nothing, so it can be asked
    twice and the answer is the same both times — and the same as when
    it is given no set at all, which is how it is asked to only read.

    A test that blocked a signal and did not put the mask back would
    leave the process changed for everything after it, so none is
    blocked here.
    """
    var nothing = unsafe_alloc[UInt8](SET_SIZE)
    var first = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        nothing.unsafe_store(i, 0)
        first.unsafe_store(i, 0)

    assert_equal(
        sigprocmask(SIG_BLOCK, nothing, first), 0, "the mask is read once"
    )

    var second = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        second.unsafe_store(i, 0)
    assert_equal(sigprocmask(SIG_BLOCK, nothing, second), 0, "and again")

    for i in range(SET_SIZE):
        assert_equal(
            Int(first.unsafe_load(i)),
            Int(second.unsafe_load(i)),
            "and it reads the same both times",
        )

    var third = unsafe_alloc[UInt8](SET_SIZE)
    for i in range(SET_SIZE):
        third.unsafe_store(i, 0)
    assert_equal(
        sigprocmask(SIG_BLOCK, null_ptr[UInt8](), third),
        0,
        "and asked with no set at all it still answers",
    )
    for i in range(SET_SIZE):
        assert_equal(
            Int(first.unsafe_load(i)),
            Int(third.unsafe_load(i)),
            "and says the same as when it was given one",
        )

    nothing.unsafe_free()
    first.unsafe_free()
    second.unsafe_free()
    third.unsafe_free()


def test_kill_with_nothing_to_send() raises:
    """Signal 0 sends nothing. `kill` with it only asks whether the
    process is there, and answers 0 when it is.
    """
    var me = getpid()
    assert_true(me > 0, "there is a process")
    assert_equal(kill(me, 0), 0, "kill with signal 0 asks and sends nothing")


def test_sigaltstack_asked_and_told_nothing() raises:
    """`sigaltstack` given nothing to install has nothing to do but
    say what the alternate stack is, which for a process that never
    set one is: there is not one.
    """
    assert_equal(
        sigaltstack(null_ptr[UInt8](), null_ptr[UInt8]()),
        0,
        "sigaltstack answers when given nothing",
    )


def test_sigaction_asked_and_told_nothing() raises:
    """`sigaction` given nothing to install and nowhere to put what
    is already there has nothing to do but check the signal is one
    there is such a thing as, which is what it answers about.

    Installing a handler wants a C function pointer, which is why
    this is as far as it goes.
    """
    assert_equal(
        sigaction(SIGINT, null_ptr[UInt8](), null_ptr[UInt8]()),
        0,
        "sigaction answers for a signal there is such a thing as",
    )
    assert_equal(
        sigaction(0, null_ptr[UInt8](), null_ptr[UInt8]()),
        -1,
        "and refuses one there is not",
    )


def test_craise_with_nothing_to_send() raises:
    """`craise` sends a signal to whoever called it. Signal 0 sends
    nothing at all, so it is the one that can be asked for here:
    every other number either ends the process or is a thing this
    test cannot say what it would do.
    """
    assert_equal(craise(0), 0, "craise with signal 0 sends nothing and says so")


def main() raises:
    test_sigaddset_round_trips_through_sigismember()
    test_sigismember_refuses_a_number_that_is_not_a_signal()
    test_sigpending_reports_an_empty_set_when_nothing_waits()
    test_sigfillset_fills()
    test_sigprocmask_read_twice_reads_the_same()
    test_kill_with_nothing_to_send()
    test_sigaltstack_asked_and_told_nothing()
    test_sigaction_asked_and_told_nothing()
    test_craise_with_nothing_to_send()
    print("signal ok")
