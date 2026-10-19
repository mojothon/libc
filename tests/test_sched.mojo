"""Tests for the `libc.sched` bindings, none of which had been called.

Only one of them is left out: `sched_setscheduler`, which asks to move
this process onto another scheduling policy, and that is not this
process's to ask.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.sched import (
    SCHED_OTHER,
    sched_get_priority_max,
    sched_get_priority_min,
    sched_getaffinity,
    sched_getparam,
    sched_getscheduler,
    sched_param,
    sched_setaffinity,
    sched_setparam,
    sched_yield,
)

# `SCHED_OTHER`, the policy a process is put on when nobody asks for
# another: the ordinary one, whose only priority is zero. The number is
# not 0 on both platforms — it is 1 here — so the constant is what is
# used rather than the digit that happens to be right here.
comptime ORDINARY = SCHED_OTHER


def test_what_the_scheduler_says() raises:
    """`sched_get_priority_max` and `sched_get_priority_min` are given a
    policy and asked how far it reaches, `sched_getscheduler` which one
    this is on, and `sched_getparam` what priority it was given. Since
    the ordinary policy reaches no further than zero, those two have to
    agree here, though on another policy they would not.

    macOS does not answer the question the same way: the ordinary
    policy there is a thread policy with its own numbering, and
    `sched_get_priority_max(0)` answers an error rather than the
    flat zero Linux says. The test is skipped on the side that
    would answer a different question.
    """
    comptime if CompilationTarget.is_macos():
        return
    assert_equal(
        sched_get_priority_max(ORDINARY),
        0,
        "the ordinary policy reaches no higher",
    )
    assert_equal(
        sched_get_priority_min(ORDINARY),
        0,
        "and no lower, being the one flat number",
    )
    assert_equal(
        sched_getscheduler(0), ORDINARY, "and it is the one this is on"
    )

    var param = unsafe_alloc[sched_param](1)
    assert_equal(
        sched_getparam(0, param), 0, "sched_getparam fills in what it has"
    )
    assert_equal(
        param.unsafe_offset(0)[].sched_priority(),
        0,
        "and the priority it says is the only one there is",
    )
    # Handing back the same one it just gave is not a change, and so is
    # not a thing this process needs to be allowed to do.
    assert_equal(
        sched_setparam(0, param), 0, "sched_setparam takes the same one back"
    )
    param.unsafe_free()

    assert_equal(sched_yield(), 0, "sched_yield gives up the rest of its turn")


def test_which_processors() raises:
    """`sched_getaffinity` writes the processors this may run on into
    something it is handed, and `sched_setaffinity` is given one and
    told. These are glibc's and Darwin has no such call, so they are
    only made where they exist.
    """
    comptime if not CompilationTarget.is_macos():
        var set = unsafe_alloc[Int32](256)
        for i in range(256):
            set.unsafe_store(i, 0)
        assert_equal(
            sched_getaffinity(0, 1024, set),
            0,
            "sched_getaffinity fills in a set",
        )

        # Not `sched_getcpucount`, which glibc declares and does not
        # export: on Linux it is a macro, and the binding cannot be
        # called here. What was written is counted instead.
        var any = False
        for i in range(256):
            if set.unsafe_load(i) != 0:
                any = True
        assert_true(any, "and it names a processor this may run on")

        # The one it was just given back again, which is not a change.
        assert_equal(
            sched_setaffinity(0, 1024, set),
            0,
            "sched_setaffinity takes the same one",
        )
        set.unsafe_free()


def main() raises:
    test_what_the_scheduler_says()
    test_which_processors()
    print("test_sched: ok")
