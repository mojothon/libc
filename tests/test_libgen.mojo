"""Tests for the `libc.libgen` bindings.

Cutting a path into its parts is string work, not filesystem work, so
nothing here touches a file: each test builds a path out of characters
and checks which side of the last slash it comes back as. What is worth
remembering about these two is not the answers but the manners —
`dirname` shortens the string it was given, and `basename` may, so the
answer is read before anything else is.
"""
from std.testing import assert_equal

from libc.libgen import basename, dirname
from libc.utils import char_ptr_to_string, string_to_char_ptr


def test_the_last_part_of_a_path_is_its_base_name() raises:
    """`/usr/bin/ls` is `ls`, a name with no slash in it is its own last
    part, and trailing slashes are trimmed before the question is asked,
    so `/usr/lib/` is `lib` and not the empty string.
    """
    var full = string_to_char_ptr("/usr/bin/ls")
    assert_equal(
        char_ptr_to_string(basename(full)), "ls", "the last part of a path"
    )

    var bare = string_to_char_ptr("ls")
    assert_equal(
        char_ptr_to_string(basename(bare)),
        "ls",
        "and a bare name is its own last part",
    )

    var trailing = string_to_char_ptr("/usr/lib/")
    assert_equal(
        char_ptr_to_string(basename(trailing)),
        "lib",
        "and a trailing slash does not count",
    )

    full.unsafe_free()
    bare.unsafe_free()
    trailing.unsafe_free()


def test_everything_before_the_last_part_is_the_directory() raises:
    """`/usr/bin/ls` lives in `/usr/bin`, a bare name lives in `.`, and
    `/` is its own directory — the corners POSIX pinned down because
    every script that moved a file had to agree on them.
    """
    var full = string_to_char_ptr("/usr/bin/ls")
    assert_equal(
        char_ptr_to_string(dirname(full)), "/usr/bin", "everything before it"
    )

    var bare = string_to_char_ptr("ls")
    assert_equal(
        char_ptr_to_string(dirname(bare)), ".", "which is . for a bare name"
    )

    var root = string_to_char_ptr("/")
    assert_equal(
        char_ptr_to_string(dirname(root)), "/", "and / is its own directory"
    )

    full.unsafe_free()
    bare.unsafe_free()
    root.unsafe_free()


def test_the_two_are_the_two_halves_of_the_same_cut() raises:
    """Asked of the same path they come back as its two halves: cutting
    `/usr/bin/ls` one way gives `ls` and the other way gives `/usr/bin`,
    and neither answer borrows anything the other cut away.
    """
    var for_base = string_to_char_ptr("/usr/bin/ls")
    var for_dir = string_to_char_ptr("/usr/bin/ls")
    assert_equal(char_ptr_to_string(basename(for_base)), "ls", "the name half")
    assert_equal(
        char_ptr_to_string(dirname(for_dir)), "/usr/bin", "and the rest of it"
    )

    for_base.unsafe_free()
    for_dir.unsafe_free()


def main() raises:
    test_the_last_part_of_a_path_is_its_base_name()
    test_everything_before_the_last_part_is_the_directory()
    test_the_two_are_the_two_halves_of_the_same_cut()
    print("test_libgen: ok")
