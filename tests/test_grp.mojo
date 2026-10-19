"""Tests for the `libc.grp` bindings.

The group database is not a file this test opens: it is the database
libc already reads, and the tests only ask it things both platforms
answer the same way. What is *not* assumed is which groups exist — the
name under id 0 is `root` on Linux and `wheel` on Darwin — so the
round-trip takes whatever name the database hands out first and asks
for that back.
"""
from std.testing import assert_equal, assert_false, assert_true

from libc.grp import endgrent, getgrent, getgrgid, getgrnam, setgrent
from libc.utils import is_null, string_to_char_ptr


def test_the_first_row_is_a_whole_group() raises:
    """Wound back to the top, the database has a first row in it, and
    the four members of it are there to read: a name, the placeholder
    that stands where a password used to be, an id, and a list of
    members that is at worst empty rather than missing.
    """
    setgrent()
    var row = getgrent()
    assert_false(is_null(row), "the group database has rows in it")
    assert_true(row[].gr_name().byte_length() > 0, "the first one is named")
    assert_true(
        row[].gr_passwd().byte_length() > 0, "and a placeholder password"
    )
    assert_false(is_null(row[].gr_mem()), "and a member list, empty or not")

    endgrent()


def test_group_zero_is_there_under_whatever_name_it_has() raises:
    """Id 0 exists on both platforms and is named differently on them,
    so what is checked is that it is there and says 0 when asked, not
    what it calls itself.
    """
    var row = getgrgid(0)
    assert_false(is_null(row), "group id 0 exists")
    assert_true(row[].gr_name().byte_length() > 0, "under some name")
    assert_equal(row[].gr_gid(), 0, "and its id is 0")


def test_a_name_asks_for_the_row_the_database_already_gave() raises:
    """The two directions of looking one up are the same row: whatever
    the database hands out first, asking for it by name gets the same id
    back. Nothing here assumes what that name is.
    """
    setgrent()
    var row = getgrent()
    assert_false(is_null(row), "there is a first group")

    var name = row[].gr_name()
    var wanted = row[].gr_gid()
    endgrent()

    var name_c = string_to_char_ptr(name)
    var again = getgrnam(name_c)
    assert_false(is_null(again), "and it can be asked for by name")
    assert_equal(again[].gr_name(), name, "which is the same name")
    assert_equal(again[].gr_gid(), wanted, "and the same id")

    name_c.unsafe_free()


def test_a_name_that_is_not_there_answers_null() raises:
    """A group that does not exist is not an error, it is a null: the
    same answer a walk gives at its end, which is why `is_null` is how
    every one of these is asked after.
    """
    var name = string_to_char_ptr("no_such_group_name_zzz")
    assert_true(is_null(getgrnam(name)), "there is no group with that name")
    name.unsafe_free()


def main() raises:
    test_the_first_row_is_a_whole_group()
    test_group_zero_is_there_under_whatever_name_it_has()
    test_a_name_asks_for_the_row_the_database_already_gave()
    test_a_name_that_is_not_there_answers_null()
    print("test_grp: ok")
