from std.testing import assert_equal, assert_false, assert_true

from libc.pwd import endpwent, getpwent, getpwnam, getpwuid, setpwent
from libc.unistd import getuid
from libc.utils import is_null, string_to_char_ptr


def test_root_is_user_zero_whichever_way_it_is_asked() raises:
    """Asking by id and asking by name answer with the same row.

    Root is uid 0 on both platforms and cannot be removed, so it is the one
    user a test can name without asking what this machine happens to hold.
    """
    var by_id = getpwuid(0)
    assert_false(is_null(by_id), "uid 0 is a user")

    assert_equal(by_id[].pw_name(), "root", "uid 0 is named root")
    assert_equal(Int(by_id[].pw_uid()), 0, "and its uid is 0")
    assert_true(
        by_id[].pw_dir().byte_length() > 0, "and it has a home directory"
    )
    assert_true(by_id[].pw_shell().byte_length() > 0, "and it has a shell")

    var name = string_to_char_ptr("root")
    var by_name = getpwnam(name)
    assert_false(is_null(by_name), "the name root is a user")
    assert_equal(Int(by_name[].pw_uid()), 0, "and asking by name finds uid 0")
    assert_equal(
        by_name[].pw_dir(),
        by_id[].pw_dir(),
        "and it is the same home directory",
    )
    assert_equal(by_name[].pw_shell(), by_id[].pw_shell(), "and the same shell")


def test_asking_for_a_user_that_is_not_there_answers_null() raises:
    """A lookup that finds nothing says so with NULL, not with errno."""
    var nobody = getpwuid(UInt32(0x7FFFFFFF))
    assert_true(is_null(nobody), "there is no user with that id")

    var name = string_to_char_ptr("no-user-has-ever-been-called-this")
    assert_true(is_null(getpwnam(name)), "and none with that name")


def test_the_whole_database_can_be_walked() raises:
    """Every user, taken one at a time.

    This is what proves the members sit where the struct says: root comes
    out of the walk with the same home directory it had from `getpwuid`, so
    a member read from the wrong slot would disagree with itself.
    """
    setpwent()
    var seen = 0
    var found_root = False

    while seen < 10000:
        var row = getpwent()
        if is_null(row):
            break
        seen += 1
        if row[].pw_uid() == 0:
            found_root = True
            assert_equal(row[].pw_name(), "root", "uid 0 is root here too")
            assert_true(
                row[].pw_dir().byte_length() > 0, "with a home directory"
            )
            assert_true(row[].pw_shell().byte_length() > 0, "and a shell")

    endpwent()
    assert_true(seen > 0, "the database has users in it")
    assert_true(found_root, "and root is one of them")


def test_whoever_is_running_is_in_the_database() raises:
    """The login name of this process, from its id.

    Which user this comes back as is the platform's business, so what is
    asked is that asking works and agrees with itself.
    """
    var row = getpwuid(UInt32(getuid()))
    assert_false(is_null(row), "the user running this is a user")
    assert_true(row[].pw_name().byte_length() > 0, "and has a name")

    var again = getpwuid(UInt32(getuid()))
    assert_equal(
        row[].pw_name(), again[].pw_name(), "asking twice says the same"
    )


def main() raises:
    test_root_is_user_zero_whichever_way_it_is_asked()
    test_asking_for_a_user_that_is_not_there_answers_null()
    test_the_whole_database_can_be_walked()
    test_whoever_is_running_is_in_the_database()
    print("pwd ok")
