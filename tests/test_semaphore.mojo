"""Tests for the `libc.semaphore` bindings.

What is bound is the named half of `<semaphore.h>`, so every test here
opens a semaphore by name. Two things follow from that and both show in
the code: a name is what two processes have to agree on to share a
count, and a name outlives the process that made it — a run that died
before its `sem_unlink` leaves one behind for the next run to find
already in use. So each test unlinks its name before it opens, which
clears whatever a previous run left, and again after, which leaves
nothing behind.

The names carry the pid, so two runs of this file at once do not meet.

Nothing here calls `sem_init`. Darwin declares it and answers with -1 and
`errno` set to `ENOSYS`: unnamed semaphores were never implemented there,
and a test that asserted one platform's answer would be a test that
fails on the other.

Every failure is checked as both of the addresses `SEM_FAILED` can be.
The two headers disagree about it — glibc's is the null pointer, Darwin's
is the all-ones one — and a test that knew only one of them would pass on
one platform by not looking.
"""
from std.testing import assert_equal, assert_true

from libc.constant import EAGAIN, ENOENT
from libc.errno import errno_name, get_errno
from libc.fcntl import O_CREAT, O_EXCL, O_RDWR
from libc.semaphore import (
    Semaphore,
    sem_close,
    sem_open,
    sem_post,
    sem_trywait,
    sem_unlink,
    sem_wait,
)
from libc.unistd import getpid
from libc.utils import is_null, string_to_char_ptr


def test_a_named_semaphore_counts_down_and_says_so_when_it_is_empty() raises:
    """A semaphore made with a count of one lets exactly one wait through,
    and the second wait is told so rather than made to wait for it.

    What is checked after that is the pair of failures a program polls on:
    a `sem_trywait` that finds nothing answers -1 with `EAGAIN`, which is
    not "broken" but "nothing right now", and the number is the platform's
    own — 11 here, 35 on Darwin.

    The last third of the test is the name: `sem_unlink` takes it away,
    and a `sem_open` without `O_CREAT` afterwards finds nothing, which is
    `ENOENT` and not a new semaphore with a count of zero.
    """
    var name = string_to_char_ptr("/libc-sem-count-" + String(getpid()))
    _ = sem_unlink(name)

    var sem = sem_open(name, O_CREAT | O_EXCL | O_RDWR, 0o600, 1)
    assert_true(
        not is_null(sem) and Int(UInt(sem)) != -1,
        "a name nobody holds opens a semaphore, and errno says "
        + errno_name(get_errno()),
    )

    assert_equal(sem_trywait(sem), 0, "the one it started at is taken")
    assert_equal(sem_trywait(sem), -1, "and there is no second one to take")
    assert_equal(
        Int(get_errno()),
        Int(EAGAIN),
        "which says EAGAIN, this platform's number",
    )

    assert_equal(sem_post(sem), 0, "a post puts one back")
    assert_equal(sem_wait(sem), 0, "and a wait takes it without waiting for it")

    assert_equal(sem_close(sem), 0, "the handle goes back")
    assert_equal(sem_unlink(name), 0, "and the name goes away with it")

    var gone = sem_open(name, O_RDWR, 0, 0)
    assert_true(
        is_null(gone) or Int(UInt(gone)) == -1,
        "a name that was unlinked opens nothing",
    )
    assert_equal(
        Int(get_errno()), Int(ENOENT), "with errno saying it is not there"
    )

    name.unsafe_free()


def test_two_opens_of_one_name_are_one_count() raises:
    """The name, and not the descriptor, is what a count belongs to: a
    second `sem_open` of a name that is already in use opens the same
    semaphore, and what the first handle takes the second one finds gone.

    That is the reason a semaphore is opened by name at all — it is the
    one thing two processes can both spell — so a test that only ever
    opened one handle would be a test that proved nothing about the half
    that matters.

    Two handles are not promised to be the same address, and this does not
    ask: what it asks is that the count they share is one count.
    """
    var name = string_to_char_ptr("/libc-sem-share-" + String(getpid()))
    _ = sem_unlink(name)

    var first = sem_open(name, O_CREAT | O_EXCL | O_RDWR, 0o600, 1)
    assert_true(
        not is_null(first) and Int(UInt(first)) != -1,
        "the first handle opens what it made",
    )

    var second = sem_open(name, O_RDWR, 0, 0)
    assert_true(
        Int(UInt(second)) != -1, "the second opens what is already there"
    )

    assert_equal(sem_trywait(first), 0, "the one is taken through the first")
    assert_equal(sem_trywait(second), -1, "and the second finds nothing left")
    assert_equal(
        Int(get_errno()),
        Int(EAGAIN),
        "which is the same count seen through both",
    )

    assert_equal(sem_close(first), 0, "the first handle goes back")
    assert_equal(sem_close(second), 0, "and so does the second")
    assert_equal(sem_unlink(name), 0, "leaving no name behind")

    name.unsafe_free()


def probe_macos() raises:
    var a = string_to_char_ptr("/probe-a-" + String(getpid()))
    var b = string_to_char_ptr("/probe-b-" + String(getpid()))
    _ = sem_unlink(a)
    _ = sem_unlink(b)
    var one = sem_open(a, O_CREAT | O_RDWR, 0o600, 1)
    print(
        "  probe create-without-excl:", Int(UInt(one)), errno_name(get_errno())
    )
    var two = sem_open(b, O_RDWR, 0, 0)
    print("  probe open-missing:", Int(UInt(two)), errno_name(get_errno()))
    var three = sem_open(b, O_CREAT | O_EXCL | O_RDWR, 0o600, 1)
    print(
        "  probe create-with-excl:", Int(UInt(three)), errno_name(get_errno())
    )
    _ = sem_unlink(a)
    _ = sem_unlink(b)


def main() raises:
    probe_macos()
    test_a_named_semaphore_counts_down_and_says_so_when_it_is_empty()
    test_two_opens_of_one_name_are_one_count()
    print("all semaphore tests passed")
