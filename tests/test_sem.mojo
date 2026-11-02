"""Tests for the `libc.sys.sem` bindings.

A set of one counter, moved up and down and read back after each move.
The counter starts at zero, which is what says `semget` made the set
rather than finding an old one, and every number after that is the
arithmetic of `sem_op` — adding raises it, subtracting lowers it, and
subtracting more than is there is refused.

The refusal is asked with `IPC_NOWAIT` on it, and that is not a detail:
the same call without the flag waits, and a test that waits is a test
that stops. What is asked instead is that the call answer at once with
-1 and leave the counter where it was, so that "refused" and "did
nothing" are the same answer rather than two.

The counter is read with `semctl` and `GETVAL`, which takes no fourth
argument. Nothing here uses `SETVAL`: that one wants a fourth argument
this binding does not pass, so the set is brought up to three by adding
three, and the test both says that and depends on it.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.sys.ipc import IPC_CREAT, IPC_NOWAIT, IPC_PRIVATE, IPC_RMID
from libc.sys.sem import GETVAL, SEM_UNDO, sembuf, semctl, semget, semop


def test_a_counter_moves_and_is_read_back() raises:
    """One counter, five operations, and a set removed at the end.

    The set is removed before the test ends and not left to the process
    exiting: a set left behind outlives everything that made it, and
    there are only so many a machine will hold — thirty-two on one of
    them, which a test that leaked would reach in a morning.
    """
    var counting = semget(IPC_PRIVATE, 1, IPC_CREAT | 0o600)
    assert_true(counting >= 0, "a private set of one counter can be made")

    assert_equal(Int(semctl(counting, 0, GETVAL)), 0, "and it starts at zero")

    var op = unsafe_alloc[sembuf](1)
    op.unsafe_offset(0)[].sem_num = 0
    op.unsafe_offset(0)[].sem_flg = 0

    op.unsafe_offset(0)[].sem_op = 3
    assert_equal(semop(counting, op, 1), 0, "three is added")
    assert_equal(
        Int(semctl(counting, 0, GETVAL)), 3, "and the counter says three"
    )

    op.unsafe_offset(0)[].sem_op = -1
    assert_equal(semop(counting, op, 1), 0, "one is taken away")
    assert_equal(Int(semctl(counting, 0, GETVAL)), 2, "leaving two")

    op.unsafe_offset(0)[].sem_op = -5
    op.unsafe_offset(0)[].sem_flg = Int16(IPC_NOWAIT)
    assert_equal(
        semop(counting, op, 1),
        -1,
        "five out of two is refused rather than waited for",
    )
    assert_equal(
        Int(semctl(counting, 0, GETVAL)),
        2,
        "and the counter is left where it was, not half moved",
    )

    op.unsafe_offset(0)[].sem_op = 1
    op.unsafe_offset(0)[].sem_flg = Int16(SEM_UNDO)
    assert_equal(
        semop(counting, op, 1), 0, "one more, marked to be undone at exit"
    )
    assert_equal(
        Int(semctl(counting, 0, GETVAL)),
        3,
        "which counts now and not later — the undo is for what exits",
    )

    assert_equal(semctl(counting, 0, IPC_RMID), 0, "the set is removed")
    assert_equal(
        semctl(counting, 0, GETVAL),
        -1,
        "and the counter goes with it, not with us",
    )

    op.unsafe_free()


def main() raises:
    test_a_counter_moves_and_is_read_back()
    print("test_sem: ok")
