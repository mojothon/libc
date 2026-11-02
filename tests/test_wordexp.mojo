"""Tests for `libc.wordexp`, the shell's line-splitting without the shell.

Three words are asked for out of a line with a doubled space between two
of them, and what makes the answer worth checking is the two spaces: a
cut on every space would give four pieces and an empty one in the
middle, while what a shell does — and what this does — is treat a run of
whitespace as one gap.

The vector is walked as a string vector and read past its end, because
it is NULL-terminated as well as counted and either number will do.

The second test asks for a command substitution and forbids it, which is
the flag that exists so that a line from somewhere untrusted can be
split without running anything in it. It is asked to be refused rather
than to answer a particular number: six numbers are possible and which
one a platform picks is its business, not this binding's.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.utils import char_ptr_to_string, is_null, null_ptr, string_to_char_ptr
from libc.wordexp import WRDE_NOCMD, wordexp, wordfree, wordexp_t


def test_a_line_becomes_words() raises:
    """One line in, three words out, and a vector that ends in NULL.

    The pieces are libc's storage once `wordexp` has returned, so they
    are read before `wordfree` and not after — that is the whole of what
    this test does in the right order on purpose.
    """
    var result = unsafe_alloc[wordexp_t](1)
    result.unsafe_offset(0)[].we_wordc = 0
    result.unsafe_offset(0)[].we_wordv = null_ptr[c_ptr[UInt8]]()
    result.unsafe_offset(0)[].we_offs = 0

    var line = string_to_char_ptr("one  two three")
    assert_equal(
        wordexp(line, result, WRDE_NOCMD), 0, "a line of plain words expands"
    )

    assert_equal(
        Int(result.unsafe_offset(0)[].we_wordc),
        3,
        "into three, because two spaces are one gap",
    )

    var vector = result.unsafe_offset(0)[].we_wordv
    assert_equal(
        char_ptr_to_string(vector.unsafe_offset(0)[]),
        "one",
        "the first word is first",
    )
    assert_equal(
        char_ptr_to_string(vector.unsafe_offset(1)[]),
        "two",
        "the second came after the gap",
    )
    assert_equal(
        char_ptr_to_string(vector.unsafe_offset(2)[]),
        "three",
        "and the third is last",
    )
    assert_true(
        is_null(vector.unsafe_offset(3)[]),
        "and what ends the vector is NULL, not a word",
    )

    wordfree(result)
    line.unsafe_free()
    result.unsafe_free()


def test_a_command_substitution_is_refused() raises:
    """`WRDE_NOCMD` is what makes this safe on a line that came from
    somewhere else: the substitution is not run and nothing is handed
    back, which is why the count is still zero afterwards.

    A version of this call that ran `$(...)` and filled the vector would
    pass a test that only asked for a non-zero answer, so what is asked
    here is also that the refusal left nothing behind to free.
    """
    var result = unsafe_alloc[wordexp_t](1)
    result.unsafe_offset(0)[].we_wordc = 0
    result.unsafe_offset(0)[].we_wordv = null_ptr[c_ptr[UInt8]]()
    result.unsafe_offset(0)[].we_offs = 0

    var line = string_to_char_ptr("$(echo hi)")
    assert_true(
        wordexp(line, result, WRDE_NOCMD) != 0,
        "a command substitution is refused rather than run",
    )
    assert_equal(
        Int(result.unsafe_offset(0)[].we_wordc),
        0,
        "and nothing was handed back to walk",
    )

    line.unsafe_free()
    result.unsafe_free()


def main() raises:
    test_a_line_becomes_words()
    test_a_command_substitution_is_refused()
    print("test_wordexp: ok")
