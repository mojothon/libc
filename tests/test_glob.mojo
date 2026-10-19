"""Tests for the `libc.glob` bindings.

These read names that are already on whichever machine runs them and
write nothing of their own: `/dev/null` because both platforms have it,
and a path nothing could have so that not matching can be tested without
having to arrange it. The two answers worth reading about are the ones
that disagree: `GLOB_NOMATCH` is 3 on glibc and -3 on Darwin, and the
vector of paths is twenty-four bytes further along on one than the other.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.glob import (
    GLOB_NOCHECK,
    GLOB_NOMATCH,
    GLOB_NOSORT,
    glob,
    glob_t,
    globfree,
)
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def test_a_pattern_with_no_magic_in_it_finds_the_one_name_it_names() raises:
    """Expansion of a pattern with no characters in it still asks the
    directory whether the name exists, which is how a plain path becomes
    one entry — nothing here assumes there is anything to match.

    `/dev/null` is the name: it is on every Unix this package runs on,
    and it does not depend on what happened to be checked out.
    """
    var found = unsafe_alloc[glob_t](1)
    found.unsafe_offset(0)[] = glob_t()
    var pattern = string_to_char_ptr("/dev/null")

    assert_equal(
        glob(pattern, 0, null_ptr[UInt8](), found),
        0,
        "a name that exists expands",
    )

    var paths = found.unsafe_offset(0)[].gl_pathv()
    assert_equal(found.unsafe_offset(0)[].gl_pathc(), 1, "to exactly one path")
    assert_equal(
        char_ptr_to_string(paths.unsafe_offset(0)[]),
        "/dev/null",
        "which is the one asked for",
    )

    globfree(found)
    found.unsafe_free()
    pattern.unsafe_free()


def test_nothing_matching_is_a_number_or_the_pattern_itself() raises:
    """What comes back when nothing matches depends on `GLOB_NOCHECK`,
    and both answers are worth having: without it a number that can be
    told apart from an empty list, with it the pattern itself, so a
    caller can hand back what it was given.

    Which number is the part that differs — see the module — so it is
    compared against the name.
    """
    var found = unsafe_alloc[glob_t](1)
    found.unsafe_offset(0)[] = glob_t()
    var nothing = string_to_char_ptr("/there/is/no/such/place/*")

    assert_equal(
        glob(nothing, 0, null_ptr[UInt8](), found),
        GLOB_NOMATCH,
        "nothing matching is reported as that",
    )
    globfree(found)

    found.unsafe_offset(0)[] = glob_t()
    assert_equal(
        glob(nothing, GLOB_NOCHECK, null_ptr[UInt8](), found),
        0,
        "unless the pattern itself was asked for",
    )
    assert_equal(
        found.unsafe_offset(0)[].gl_pathc(), 1, "and then there is one"
    )
    assert_equal(
        char_ptr_to_string(
            found.unsafe_offset(0)[].gl_pathv().unsafe_offset(0)[]
        ),
        "/there/is/no/such/place/*",
        "which is the pattern, unexpanded",
    )

    globfree(found)
    found.unsafe_free()
    nothing.unsafe_free()


def test_a_star_finds_the_names_it_covers() raises:
    """`*` is the whole point of the call, and this is the only test that
    actually expands one: `/dev/nul*` covers `/dev/null`, and covers more
    besides on a machine that has more.

    Nothing is assumed about the order, because `GLOB_NOSORT` says there
    is none; what is checked is that `/dev/null` is among them.
    """
    var found = unsafe_alloc[glob_t](1)
    found.unsafe_offset(0)[] = glob_t()
    var pattern = string_to_char_ptr("/dev/nul*")

    assert_equal(
        glob(pattern, GLOB_NOSORT, null_ptr[UInt8](), found),
        0,
        "the expansion finds something",
    )

    var paths = found.unsafe_offset(0)[].gl_pathv()
    var seen_it = False
    var count = found.unsafe_offset(0)[].gl_pathc()
    for at in range(Int(count)):
        if char_ptr_to_string(paths.unsafe_offset(at)[]) == "/dev/null":
            seen_it = True
    assert_true(seen_it, "and /dev/null is one of them")

    globfree(found)
    found.unsafe_free()
    pattern.unsafe_free()


def main() raises:
    test_a_pattern_with_no_magic_in_it_finds_the_one_name_it_names()
    test_nothing_matching_is_a_number_or_the_pattern_itself()
    test_a_star_finds_the_names_it_covers()
    print("test_glob: ok")
