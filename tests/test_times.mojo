"""Tests for `libc.sys.times`, which had not been called.

`times` says how much processor time this process has had. What is
asked of it here is only that the number does not go backwards: a
process that has spent time since it was last asked has at least as
much to show now, and one read out of the wrong place in the struct
has a number that means nothing at all.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_true

from libc.sys.times import times, tms


comptime TURNS = 200000


def _spend_a_little_time() -> Int:
    """Adds up a good many numbers and hands back the last of them.

    What is wanted is a call that takes some processor time, and one
    that hands back something so it cannot be done away with.
    """
    var total = 0
    for i in range(TURNS):
        total += i
    return total


def test_processor_time_does_not_go_backwards() raises:
    """`times` fills in four numbers, and the one for this process's
    own user time is the one asked about here.

    It is asked twice with some counting in between, and what is
    asked is that the second answer is at least the first. That is
    what processor time does: it is spent and not unspent. A number
    read out of the wrong member, or out of the right member at the
    wrong offset, is not one that goes up because work was done.

    The counting may well finish inside one clock tick, in which
    case the two answers are the same, which is why this asks `at
    least` and not `more`.
    """
    var before = unsafe_alloc[tms](1)
    before.unsafe_offset(0)[].tms_utime = 0
    before.unsafe_offset(0)[].tms_stime = 0
    before.unsafe_offset(0)[].tms_cutime = 0
    before.unsafe_offset(0)[].tms_cstime = 0

    assert_true(times(before) >= 0, "times says how long since it began")

    var spent = _spend_a_little_time()
    assert_true(spent > 0, "and some work was done in between")

    var after = unsafe_alloc[tms](1)
    after.unsafe_offset(0)[].tms_utime = 0
    after.unsafe_offset(0)[].tms_stime = 0
    after.unsafe_offset(0)[].tms_cutime = 0
    after.unsafe_offset(0)[].tms_cstime = 0

    assert_true(times(after) >= 0, "and is asked again, saying")

    assert_true(
        after.unsafe_offset(0)[].tms_utime
        >= before.unsafe_offset(0)[].tms_utime,
        "at least as much user time as it said before",
    )
    assert_true(
        after.unsafe_offset(0)[].tms_stime
        >= before.unsafe_offset(0)[].tms_stime,
        "and at least as much system time",
    )

    before.unsafe_free()
    after.unsafe_free()


def main() raises:
    test_processor_time_does_not_go_backwards()
    print("test_times: ok")
