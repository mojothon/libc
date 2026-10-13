from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal

from libc.constant import EINVAL, c_ptr
from libc.errno import get_errno, set_errno
from libc.signal import (
    SIGINT,
    sigaddset,
    sigdelset,
    sigemptyset,
    sigismember,
    sigpending,
)


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


def main() raises:
    test_sigaddset_round_trips_through_sigismember()
    test_sigismember_refuses_a_number_that_is_not_a_signal()
    test_sigpending_reports_an_empty_set_when_nothing_waits()
    print("signal ok")
