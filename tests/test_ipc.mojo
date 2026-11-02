"""Tests for the `libc.sys.ipc` bindings.

`ftok` is the whole of it, and it is a mixing function: a path and a
byte in, a number out. Two things about it can be pinned without
knowing how the mixing is done — that the same pair gives the same
number twice, and that a pair which differs only in the byte gives a
different one — and those two are what makes it useful, so they are
what is asked.
"""
from std.testing import assert_equal, assert_true

from libc.sys.ipc import ftok
from libc.utils import string_to_char_ptr


def test_the_same_pair_gives_the_same_key() raises:
    """A path and a byte, asked for twice.

    The second call is the one that matters: the answer has to be the
    same number, or two processes that agreed on a path would not be
    agreeing on anything. The path is the current directory, which
    every process has and which both platforms will look at.

    The byte is then changed and the same path asked again. The byte
    goes into the top eight bits of the key and nothing else does, so a
    different byte is a different key by construction rather than by
    luck — this is the one part of the number that can be relied on.

    A path that is not there is then asked for, which is -1 and says
    that `ftok` looked rather than guessed.
    """
    var here = string_to_char_ptr(".")
    var first = ftok(here, 1)
    var again = ftok(here, 1)
    var other = ftok(here, 2)

    assert_true(first != -1, "the current directory is a path C can see")
    assert_equal(again, first, "and it mixes to the same key twice")
    assert_true(other != first, "while another byte is another key")

    var nowhere = string_to_char_ptr("/nonexistent/ftok")
    assert_equal(ftok(nowhere, 1), -1, "and a path that is not there is -1")
    nowhere.unsafe_free()

    here.unsafe_free()


def main() raises:
    test_the_same_pair_gives_the_same_key()
    print("test_ipc: ok")
