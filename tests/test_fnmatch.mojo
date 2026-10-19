"""Tests for the `libc.fnmatch` bindings.

Matching a name against a pattern is pure — it reads nothing and writes
nothing — so these are all about the semantics: that `*` stops at a `/`
when asked to, that a leading dot hides from it when asked to, and that
the two flags that trade numbers between the platforms still mean what
they say when asked for by name.
"""
from std.testing import assert_equal

from libc.fnmatch import (
    FNM_NOMATCH,
    FNM_PATHNAME,
    FNM_PERIOD,
    fnmatch,
)
from libc.utils import string_to_char_ptr


def test_a_star_and_a_question_mark_match_what_they_cover() raises:
    """The two metacharacters with no flags, on names made up for the
    occasion: `*` covers a run of characters, `?` covers exactly one,
    and a name that does not fit is `FNM_NOMATCH` rather than 0.
    """
    var star = string_to_char_ptr("*.mojo")
    var name = string_to_char_ptr("test_fnmatch.mojo")
    var other = string_to_char_ptr("main.rs")
    assert_equal(fnmatch(star, name, 0), 0, "a star covers a run")
    assert_equal(fnmatch(star, other, 0), FNM_NOMATCH, "but not a wrong ending")

    var question = string_to_char_ptr("test_?.mojo")
    var one = string_to_char_ptr("test_x.mojo")
    var two = string_to_char_ptr("test_xy.mojo")
    assert_equal(fnmatch(question, one, 0), 0, "a question mark covers one")
    assert_equal(
        fnmatch(question, two, 0), FNM_NOMATCH, "and exactly one at that"
    )

    star.unsafe_free()
    name.unsafe_free()
    other.unsafe_free()
    question.unsafe_free()
    one.unsafe_free()
    two.unsafe_free()


def test_a_star_does_not_cross_a_slash_when_asked_not_to() raises:
    """Without `FNM_PATHNAME` a `*` will happily match across a `/`,
    which is rarely what matching pathnames wants; with it, `/` has to
    be matched by a `/`.

    The flag is 1 on glibc and 2 on Darwin — asked for by name either
    way, it means the same thing.
    """
    var star = string_to_char_ptr("*")
    var path = string_to_char_ptr("usr/bin")

    assert_equal(fnmatch(star, path, 0), 0, "a star crosses a slash by default")
    assert_equal(
        fnmatch(star, path, FNM_PATHNAME),
        FNM_NOMATCH,
        "but not when pathnames are being matched",
    )

    var deep = string_to_char_ptr("usr/*")
    assert_equal(
        fnmatch(deep, path, FNM_PATHNAME),
        0,
        "and a slash matched by a slash is fine",
    )

    star.unsafe_free()
    path.unsafe_free()
    deep.unsafe_free()


def test_a_leading_dot_hides_from_a_star_when_asked_to() raises:
    """`FNM_PERIOD` is what keeps `*` from showing you the dotfiles: a
    leading `.` matches only a literal one, which is why `ls` does not
    list them unless asked.
    """
    var star = string_to_char_ptr("*")
    var hidden = string_to_char_ptr(".gitignore")

    assert_equal(
        fnmatch(star, hidden, 0), 0, "a star finds a dotfile by default"
    )
    assert_equal(
        fnmatch(star, hidden, FNM_PERIOD),
        FNM_NOMATCH,
        "and does not when a period must be matched by a period",
    )

    var dot_star = string_to_char_ptr(".*")
    assert_equal(
        fnmatch(dot_star, hidden, FNM_PERIOD),
        0,
        "but a literal dot still finds it",
    )

    star.unsafe_free()
    hidden.unsafe_free()
    dot_star.unsafe_free()


def main() raises:
    test_a_star_and_a_question_mark_match_what_they_cover()
    test_a_star_does_not_cross_a_slash_when_asked_not_to()
    test_a_leading_dot_hides_from_a_star_when_asked_to()
    print("test_fnmatch: ok")
