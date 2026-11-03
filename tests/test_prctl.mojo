"""Tests for the `libc.sys.prctl` bindings, which had been called by nothing.

`prctl` is one entry point with a hundred meanings: the first argument
chooses which question is asked, and the other four are whatever that
question takes — which is why it is bound with all five spelled out and
nothing left to a variadic tail. Only Linux answers it, so every test here
is skipped on Darwin, and the reason is that the symbol is not there rather
than that the call cannot be asked anything.

What is asked is the part that reads: the flag that says whether this
process may dump core, and the slack the kernel adds to its timers. Beside
them is one write whose answer is read straight back — the name the kernel
files the thread under is set, read, and put back the way it was found, so
what the rest of the suite sees is what it started with. The last question
is one the call has to refuse: an option that is not one of its own comes
back -1 with `EINVAL`, and a call that can say no is what makes its yes
mean something.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import EINVAL, c_ptr
from libc.errno import get_errno, set_errno
from libc.sys.prctl import (
    PR_GET_DUMPABLE,
    PR_GET_NAME,
    PR_GET_TIMERSLACK,
    PR_SET_NAME,
    prctl,
)
from libc.utils import char_ptr_to_string, string_to_char_ptr

# What `PR_GET_NAME` writes: the kernel keeps fifteen bytes of name and the
# NUL after them. A buffer this wide is one the call cannot overrun, and the
# name is read back out of it rather than assumed to fill it.
comptime NAME_ROOM = 16

# A number no option has ever had. Anything the kernel does not know is a
# refusal, which is the answer this file wants from it.
comptime NO_SUCH_OPTION: Int32 = 9999


def _read_name(room: c_ptr[UInt8]) -> Int32:
    """Ask for the calling thread's name, into `room`."""
    for i in range(NAME_ROOM):
        room.unsafe_offset(i)[] = 0
    return prctl(PR_GET_NAME, UInt64(Int(room)), 0, 0, 0)


def test_the_flags_that_only_read() raises:
    """Two questions the kernel answers without being asked to change anything.

    `PR_GET_DUMPABLE` is the flag that decides whether this process may leave
    a core file, which is on unless somebody turned it off or the process was
    started set-user-ID — so the answer is one of two, not a number to pin.
    `PR_GET_TIMERSLACK` is how much lateness the kernel forgives a timer set
    by this process, in nanoseconds: a positive count, fifty thousand by
    default, and the default is the kernel's to change.
    """
    comptime if CompilationTarget.is_macos():
        return
    var dumpable = prctl(PR_GET_DUMPABLE, 0, 0, 0, 0)
    assert_true(
        dumpable == 0 or dumpable == 1,
        "the core-dump flag is off or on, and nothing else",
    )
    assert_true(
        prctl(PR_GET_TIMERSLACK, 0, 0, 0, 0) > 0,
        (
            "the slack the kernel grants a timer is a positive number of"
            " nanoseconds"
        ),
    )


def test_the_name_comes_back_the_way_it_was_put() raises:
    """`PR_SET_NAME` and `PR_GET_NAME` are the write and the read of one thing.

    The name is fifteen bytes of the kernel's own, reached through the second
    argument as a pointer — which is the part worth asking, since a binding
    that passed the pointer's value instead of the pointer would set a name
    made of its address. Putting back the name that was found makes the same
    question twice with two different answers, and leaves the thread as it
    was for whatever runs next.
    """
    comptime if CompilationTarget.is_macos():
        return
    var room = unsafe_alloc[UInt8](NAME_ROOM)
    var saved = unsafe_alloc[UInt8](NAME_ROOM)
    assert_equal(
        _read_name(room), 0, "the name is written where it was told to"
    )

    var length = 0
    while length < NAME_ROOM and room.unsafe_offset(length)[] != 0:
        length += 1
    assert_true(length > 0, "the thread starts out with a name")
    assert_true(
        length < NAME_ROOM,
        "and ends inside the room the call was given, at a NUL",
    )
    for i in range(length + 1):
        saved.unsafe_offset(i)[] = room.unsafe_offset(i)[]

    var put = string_to_char_ptr("libc-prctl")
    assert_equal(
        prctl(PR_SET_NAME, UInt64(Int(put)), 0, 0, 0), 0, "the name is taken"
    )
    put.unsafe_free()
    assert_equal(_read_name(room), 0, "and asked for again")
    assert_equal(
        char_ptr_to_string(room),
        "libc-prctl",
        "the name that comes back is the one that was put",
    )

    assert_equal(
        prctl(PR_SET_NAME, UInt64(Int(saved)), 0, 0, 0),
        0,
        "the name found at the start goes back",
    )
    assert_equal(_read_name(room), 0, "and is read back as well")
    assert_equal(
        char_ptr_to_string(room),
        char_ptr_to_string(saved),
        "so the thread is named the way the suite found it",
    )
    room.unsafe_free()
    saved.unsafe_free()


def test_an_option_that_is_not_one_of_its_own() raises:
    """The refusal, without which "it returned 0" would only mean "it returned".

    An option the kernel does not know is turned away with `EINVAL` rather
    than ignored, and that is the one answer a caller can tell apart from a
    request quietly doing nothing.
    """
    comptime if CompilationTarget.is_macos():
        return
    set_errno(0)
    assert_equal(
        prctl(NO_SUCH_OPTION, 0, 0, 0, 0),
        -1,
        "an option that is not one is refused",
    )
    assert_equal(
        get_errno(), EINVAL, "with the reason the call has for refusing"
    )


def main() raises:
    test_the_flags_that_only_read()
    test_the_name_comes_back_the_way_it_was_put()
    test_an_option_that_is_not_one_of_its_own()
    print("test_prctl: ok")
