"""Tests for the `libc.regex` bindings.

Each of these is a pattern against a string already in memory, so nothing
here touches the file system, the network, or a clock. The one that is
worth pointing at is `REG_NEWLINE`: it is 4 on glibc and 8 on Darwin, so
a binding that had one of them written down would compile, run, and
answer differently on the two platforms. It is tested by what it does to
`^` rather than by what number it is.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.regex import (
    REG_EBRACK,
    REG_EPAREN,
    REG_EXTENDED,
    REG_ICASE,
    REG_NEWLINE,
    REG_NOMATCH,
    regcomp,
    regerror,
    regex_t,
    regexec,
    regfree,
    regmatch_t,
)
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def test_a_match_says_where_each_part_of_it_is() raises:
    """`regexec` answers more than yes: with room to write in, it says
    which bytes matched, for the whole match and for every parenthesised
    part of it after that.

    `xxabbbcyy` puts `abbbc` at 2 through 7 and the `bbb` inside it at 3
    through 6, and both pairs of numbers come from one call.
    """
    var compiled = unsafe_alloc[regex_t](1)
    compiled.unsafe_offset(0)[] = regex_t()
    var pattern = string_to_char_ptr("a(b+)c")

    assert_equal(
        regcomp(compiled, pattern, REG_EXTENDED), 0, "the pattern compiles"
    )

    var text = string_to_char_ptr("xxabbbcyy")
    var found = unsafe_alloc[regmatch_t](2)

    assert_equal(regexec(compiled, text, 2, found, 0), 0, "and it matches")

    var whole = found.unsafe_offset(0)
    assert_equal(Int(whole[].rm_so()), 2, "starting at the a")
    assert_equal(Int(whole[].rm_eo()), 7, "and running up to the c")

    var group = found.unsafe_offset(1)
    assert_equal(
        Int(group[].rm_so()), 3, "the parenthesised part begins after it"
    )
    assert_equal(Int(group[].rm_eo()), 6, "and ends before the c")

    regfree(compiled)
    compiled.unsafe_free()
    found.unsafe_free()
    pattern.unsafe_free()
    text.unsafe_free()


def test_reg_icase_is_what_makes_the_case_not_matter() raises:
    """Case is significant unless it is switched off, and `REG_ICASE` is
    what switches it off at compile time rather than in the pattern.

    `nmatch` of 0 asks for the answer and nothing else, which is what a
    caller wanting only to know whether the pattern is there gives.
    """
    var compiled = unsafe_alloc[regex_t](1)
    compiled.unsafe_offset(0)[] = regex_t()
    var pattern = string_to_char_ptr("abc")
    var text = string_to_char_ptr("ABC")

    assert_equal(
        regcomp(compiled, pattern, REG_EXTENDED), 0, "compiled plainly"
    )
    assert_equal(
        regexec(compiled, text, 0, null_ptr[regmatch_t](), 0),
        REG_NOMATCH,
        "and then uppercase does not match it",
    )
    regfree(compiled)

    compiled.unsafe_offset(0)[] = regex_t()
    assert_equal(
        regcomp(compiled, pattern, REG_EXTENDED | REG_ICASE),
        0,
        "compiled ignoring case",
    )
    assert_equal(
        regexec(compiled, text, 0, null_ptr[regmatch_t](), 0),
        0,
        "and then it does",
    )

    regfree(compiled)
    compiled.unsafe_free()
    pattern.unsafe_free()
    text.unsafe_free()


def test_reg_newline_decides_whether_the_caret_sees_the_lines() raises:
    """`^` anchors the start of the string, not of each line in it, and
    `REG_NEWLINE` is what changes that. It is also the one of these flags
    numbered differently on the two platforms, so this is the test that
    would notice: compiled without it there is no match at all, compiled
    with it there is one at the byte after the newline.
    """
    var compiled = unsafe_alloc[regex_t](1)
    compiled.unsafe_offset(0)[] = regex_t()
    var pattern = string_to_char_ptr("^b")
    var two_lines = string_to_char_ptr("a\nb")

    assert_equal(
        regcomp(compiled, pattern, REG_EXTENDED), 0, "compiled plainly"
    )
    assert_equal(
        regexec(compiled, two_lines, 0, null_ptr[regmatch_t](), 0),
        REG_NOMATCH,
        "and then the caret sees only the beginning",
    )
    regfree(compiled)

    compiled.unsafe_offset(0)[] = regex_t()
    assert_equal(
        regcomp(compiled, pattern, REG_EXTENDED | REG_NEWLINE),
        0,
        "compiled caring about newlines",
    )
    var found = unsafe_alloc[regmatch_t](1)
    assert_equal(
        regexec(compiled, two_lines, 1, found, 0), 0, "and now it matches"
    )
    assert_equal(
        Int(found.unsafe_offset(0)[].rm_so()),
        2,
        "at the byte just past the newline",
    )

    regfree(compiled)
    compiled.unsafe_free()
    found.unsafe_free()
    pattern.unsafe_free()
    two_lines.unsafe_free()


def test_a_pattern_that_will_not_compile_says_which_one_it_is() raises:
    """A broken pattern is refused by `regcomp`, and answered with one of
    the `REG_*` rather than with -1:     `REG_EPAREN` for a parenthesis left
    open, `REG_EBRACK` for a bracket left unclosed.

    Which error comes back for which pattern is not something either libc
    promises, beyond the two here: `a[` — an empty bracket — is reported
    as `REG_EBRACK` by nothing either side ships, glibc calling it
    `REG_BADPAT` instead, so what is asked below is the unclosed
    `[a-`, which is the bracket neither argues about.

    The thirteen error numbers are the same on both platforms — the one
    part of this header they agree on — so these two can be written down
    where `REG_NOSUB` and `REG_NEWLINE` cannot.
    """
    var compiled = unsafe_alloc[regex_t](1)
    compiled.unsafe_offset(0)[] = regex_t()
    var open_paren = string_to_char_ptr("a(")

    assert_equal(
        regcomp(compiled, open_paren, REG_EXTENDED),
        REG_EPAREN,
        "an open parenthesis is reported as one",
    )

    var message = unsafe_alloc[UInt8](256)
    message.unsafe_offset(0)[] = 0
    assert_true(
        Int(regerror(REG_EPAREN, compiled, message, UInt64(256))) > 0,
        "and regerror has a length for it",
    )
    assert_true(
        char_ptr_to_string(message).byte_length() > 0,
        "which is a sentence rather than nothing",
    )

    compiled.unsafe_offset(0)[] = regex_t()
    var open_bracket = string_to_char_ptr("[a-")
    assert_equal(
        regcomp(compiled, open_bracket, REG_EXTENDED),
        REG_EBRACK,
        "and an unclosed bracket is reported as one",
    )

    regfree(compiled)
    compiled.unsafe_free()
    message.unsafe_free()
    open_paren.unsafe_free()
    open_bracket.unsafe_free()


def main() raises:
    test_a_match_says_where_each_part_of_it_is()
    test_reg_icase_is_what_makes_the_case_not_matter()
    test_reg_newline_decides_whether_the_caret_sees_the_lines()
    test_a_pattern_that_will_not_compile_says_which_one_it_is()
    print("test_regex: ok")
