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
    GLOB_DOOFFS,
    GLOB_MAGCHAR,
    GLOB_MARK,
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


def test_the_mark_flags_the_directories_with_a_slash() raises:
    """`GLOB_MARK` is the one flag whose work is visible in the answer
    rather than in the list: every name under `/dev` that is a
    directory comes back with a trailing slash, and the same names
    asked without the flag do not.

    The pair is the point. A machine that reads the flag as the one
    beside it in the header does not mark anything, and the two runs
    then answer with the same strings -- so the difference between
    them is what says the flag was read at all.
    """
    var marked = unsafe_alloc[glob_t](1)
    marked.unsafe_offset(0)[] = glob_t()
    var plain = unsafe_alloc[glob_t](1)
    plain.unsafe_offset(0)[] = glob_t()
    var pattern = string_to_char_ptr("/dev/*")

    assert_equal(
        glob(pattern, GLOB_NOSORT | GLOB_MARK, null_ptr[UInt8](), marked),
        0,
        "the expansion with the mark finds something",
    )
    assert_equal(
        glob(pattern, GLOB_NOSORT, null_ptr[UInt8](), plain),
        0,
        "and so does the one without it",
    )

    var marked_paths = marked.unsafe_offset(0)[].gl_pathv()
    var marked_count = Int(marked.unsafe_offset(0)[].gl_pathc())
    var plain_paths = plain.unsafe_offset(0)[].gl_pathv()
    var plain_count = Int(plain.unsafe_offset(0)[].gl_pathc())
    assert_equal(marked_count, plain_count, "the two runs list the same names")

    var marked_a_directory = False
    var plain_a_directory = False
    for at in range(marked_count):
        var name = char_ptr_to_string(marked_paths.unsafe_offset(at)[])
        if name.endswith("/"):
            marked_a_directory = True
    for at in range(plain_count):
        var name = char_ptr_to_string(plain_paths.unsafe_offset(at)[])
        if name.endswith("/"):
            plain_a_directory = True
    # `/dev` holds directories -- `pts`, `shm`, `mqueue` on both
    # platforms -- so a run with the mark has to have marked one.
    assert_true(marked_a_directory, "a directory among the matches is marked")
    assert_true(not plain_a_directory, "and unmarked when nobody asked")


def test_the_flags_are_the_ones_asked_for_and_the_magic_bit_beside_them() raises:
    """`gl_flags` is the one member of this struct that is neither a count
    nor a pointer, and it is the one that sits in the half of a word the
    count next to it does not — so it is the one a reader can get wrong
    without any count going wrong with it.

    What libc promises is that the flags it was given come back, with
    `GLOB_MAGCHAR` added when the pattern had a metacharacter in it. Both
    platforms do that — XNU clears the bit before copying the flags in and
    sets it again if the pattern needs it — so a pattern with a `*` has it
    and a plain path does not, and that pair is the assertion.
    """
    var found = unsafe_alloc[glob_t](1)
    found.unsafe_offset(0)[] = glob_t()
    var magic = string_to_char_ptr("/dev/nul*")

    assert_equal(
        glob(magic, GLOB_NOSORT, null_ptr[UInt8](), found),
        0,
        "a pattern with a star in it expands",
    )
    assert_true(
        (found.unsafe_offset(0)[].gl_flags() & GLOB_MAGCHAR) != 0,
        "and comes back saying the pattern had magic in it",
    )
    globfree(found)

    found.unsafe_offset(0)[] = glob_t()
    var plain = string_to_char_ptr("/dev/null")
    assert_equal(
        glob(plain, 0, null_ptr[UInt8](), found),
        0,
        "a path with no star in it is not a pattern",
    )
    assert_equal(
        found.unsafe_offset(0)[].gl_flags() & GLOB_MAGCHAR,
        0,
        "so the magic bit stays clear",
    )

    globfree(found)
    found.unsafe_free()
    magic.unsafe_free()
    plain.unsafe_free()


def test_the_head_of_the_vector_is_left_empty_when_asked() raises:
    """`GLOB_DOOFFS` is the one flag that changes what C reads rather
    than what it looks for: it makes `glob` read `gl_offs` out of the
    block before it fills it, and leave that many entries empty at the
    head of `gl_pathv`.

    The setter puts a two in the block, the call comes back with the
    two still there, and the proof that C actually read it is what it
    did with the vector: the two at the head are null, and the pattern
    itself — kept by `GLOB_NOCHECK` — sits behind them, at the third
    place. Every other test here reads a vector that starts at its
    first path; this one is the exception the flag exists for.
    """
    var nothing = string_to_char_ptr("/no/such/name/*")
    var found = unsafe_alloc[glob_t](1)
    found.unsafe_offset(0)[] = glob_t()
    found.unsafe_offset(0)[].set_gl_offs(2)

    assert_equal(
        glob(nothing, GLOB_NOCHECK | GLOB_DOOFFS, null_ptr[UInt8](), found),
        0,
        "the pattern itself is kept, with room left before it",
    )
    assert_equal(
        found.unsafe_offset(0)[].gl_offs(),
        2,
        "and the two is still there",
    )
    assert_equal(
        found.unsafe_offset(0)[].gl_pathc(),
        1,
        "with one path behind the room",
    )
    var paths = found.unsafe_offset(0)[].gl_pathv()
    assert_true(
        Int(paths.unsafe_offset(0)[]) == 0,
        "the first place is empty, as the two asked",
    )
    assert_true(
        Int(paths.unsafe_offset(1)[]) == 0,
        "and so is the second",
    )
    assert_equal(
        char_ptr_to_string(paths.unsafe_offset(2)[]),
        "/no/such/name/*",
        "and the path itself is the third thing in the vector",
    )

    globfree(found)
    found.unsafe_free()


def main() raises:
    test_a_pattern_with_no_magic_in_it_finds_the_one_name_it_names()
    test_nothing_matching_is_a_number_or_the_pattern_itself()
    test_a_star_finds_the_names_it_covers()
    test_the_flags_are_the_ones_asked_for_and_the_magic_bit_beside_them()
    test_the_mark_flags_the_directories_with_a_slash()
    test_the_head_of_the_vector_is_left_empty_when_asked()
    print("test_glob: ok")
