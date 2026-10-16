from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import EINVAL
from libc.errno import get_errno, set_errno
from libc.sys.resource import (
    PRIO_PROCESS,
    RLIMIT_NOFILE,
    Rlimit,
    getpriority,
    getrlimit,
    nice,
    prlimit,
    setpriority,
    setrlimit,
)
from libc.utils import null_ptr


def _current() raises -> Int32:
    """This process's niceness, asked for with errno zeroed first.

    Every reading here can legitimately answer -1, so errno has to be clean
    before the call for afterwards to mean anything.
    """
    set_errno(0)
    var value = getpriority(PRIO_PROCESS, 0)
    assert_true(get_errno() == 0, "reading own niceness succeeded")
    assert_true(
        value >= -20 and value <= 20,
        "niceness is inside the twenty each way it is allowed to be",
    )
    return value


def test_getpriority_and_nice_agree_on_who_the_caller_is() raises:
    """Two different calls, one answer.

    `nice(0)` changes nothing and says what landed, while `getpriority` asks
    outright: neither goes near the other's number, so a priority read out
    of the wrong argument comes out different in the two of them.
    """
    var asked = _current()
    set_errno(0)
    var moved = nice(0)
    assert_true(get_errno() == 0, "nice(0) succeeded")
    assert_equal(moved, asked, "and it says the same niceness")


def test_setpriority_can_only_be_moved_this_way() raises:
    """Lowering demand on the processor is not privileged; raising it is.

    Making this process nicer is allowed whoever is asking, and taking it
    back afterwards would need privileges it does not have, so the move is
    made towards the polite end and left there. Nineteen is inside what
    both platforms allow as a ceiling, so it is asked for rather than one
    past what it already is.
    """
    var before = _current()

    assert_equal(setpriority(PRIO_PROCESS, 0, 19), 0, "asking for 19 succeeded")
    var after = _current()
    assert_true(after >= before, "and it is no less polite than it was")

    # A request past the end is pulled back to it rather than refused: twenty
    # five asked for lands on nineteen, and nothing complains.
    assert_equal(setpriority(PRIO_PROCESS, 0, 25), 0, "asking past the end too")
    assert_equal(_current(), after, "and it landed in the same place")


def test_a_which_that_is_not_one_of_the_three_is_refused() raises:
    """Both calls answer EINVAL, and neither by way of errno alone."""
    set_errno(0)
    var failed = getpriority(999, 0)
    assert_true(failed <= 0, "nothing sensible came back")
    assert_equal(get_errno(), EINVAL, "getpriority says which is wrong")

    set_errno(0)
    assert_equal(setpriority(999, 0, 0), -1, "setpriority refuses it")
    assert_equal(get_errno(), EINVAL, "and says the same thing")


def test_setrlimit_asked_for_the_limit_already_there() raises:
    """`setrlimit` sets a limit, which makes it an awkward thing to
    try: what is asked of it here is the limit that is already
    there, read first, so that setting it changes nothing. The hard
    limit cannot be raised by an ordinary process in any case, so
    there is nothing else it could safely be asked for.

    `prlimit` is the setting and the reading in one call, and can be
    asked of another process — pid 0 meaning this one. Given nothing
    to set it only reads, and is asked here so that the two of them
    can be set against each other.
    """
    var here = unsafe_alloc[Rlimit](1)
    here.unsafe_offset(0)[] = Rlimit()
    assert_equal(getrlimit(RLIMIT_NOFILE, here), 0, "the limit is read")

    assert_equal(
        setrlimit(RLIMIT_NOFILE, here), 0, "and set to what it already was"
    )

    var after = unsafe_alloc[Rlimit](1)
    after.unsafe_offset(0)[] = Rlimit()
    assert_equal(getrlimit(RLIMIT_NOFILE, after), 0, "and read again")

    comptime if not CompilationTarget.is_macos():
        var asked = unsafe_alloc[Rlimit](1)
        asked.unsafe_offset(0)[] = Rlimit()
        assert_equal(
            prlimit(0, RLIMIT_NOFILE, null_ptr[Rlimit](), asked),
            0,
            "and prlimit reads it as well",
        )
        assert_equal(
            Int(after.unsafe_offset(0)[].rlim_cur),
            Int(asked.unsafe_offset(0)[].rlim_cur),
            "and the two of them say the same",
        )
        asked.unsafe_free()

    here.unsafe_free()
    after.unsafe_free()


def main() raises:
    test_getpriority_and_nice_agree_on_who_the_caller_is()
    test_setpriority_can_only_be_moved_this_way()
    test_a_which_that_is_not_one_of_the_three_is_refused()
    test_setrlimit_asked_for_the_limit_already_there()
    print("resource ok")
