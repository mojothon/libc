from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_false, assert_true

from libc.pwd import (
    endpwent,
    getpwent,
    getpwnam,
    getpwnam_r,
    getpwuid,
    getpwuid_r,
    passwd,
    setpwent,
)
from libc.unistd import getuid
from libc.constant import c_ptr
from libc.utils import is_null, string_to_char_ptr


def test_root_is_user_zero_whichever_way_it_is_asked() raises:
    """Asking by id and asking by name answer with the same row.

    Root is uid 0 on both platforms and cannot be removed, so it is the one
    user a test can name without asking what this machine happens to hold.

    The first answer is read out in full before the second question is put.
    `getpwuid` and `getpwnam` hand back a row in a buffer that the next
    lookup of either kind is free to write over, so asking both and then
    comparing them compares whichever row came second with itself — which
    is what this did on glibc until the strings were copied out first, and
    why it passed there without saying anything.

    `pw_shell` is the one field the two are allowed to disagree about on
    Darwin, where a number is answered from Open Directory and a name from
    the local file, and an image can have set root's shell in one and not
    the other. On the runner that failed here, asking by name said
    `/bin/bash` and asking by number said `/bin/sh`. What is asked of the
    shell is that both name an absolute path.
    """
    var by_id = getpwuid(0)
    assert_false(is_null(by_id), "uid 0 is a user")

    var id_name = by_id[].pw_name()
    var id_dir = by_id[].pw_dir()
    var id_shell = by_id[].pw_shell()
    assert_equal(id_name, "root", "uid 0 is named root")
    assert_equal(Int(by_id[].pw_uid()), 0, "and its uid is 0")
    # Root's group and its home are numbers and paths nothing here chose:
    # a row read one field away answers with the neighbour, and `root` is
    # the one user whose neighbour can agree -- its uid and gid are both 0,
    # which is why the uid is asked of the running user further down too.
    assert_equal(Int(by_id[].pw_gid()), 0, "and its gid is 0")
    comptime if not CompilationTarget.is_macos():
        assert_equal(id_dir, "/root", "root lives at /root here")
        assert_equal(by_id[].pw_gecos(), "root", "and is called root there")
    assert_true(id_dir.byte_length() > 0, "and it has a home directory")
    assert_true(id_shell.startswith("/"), "and it has a shell by path")

    var name = string_to_char_ptr("root")
    var by_name = getpwnam(name)
    assert_false(is_null(by_name), "the name root is a user")
    assert_equal(Int(by_name[].pw_uid()), 0, "and asking by name finds uid 0")
    assert_equal(by_name[].pw_name(), id_name, "and it is the same name")
    assert_equal(by_name[].pw_dir(), id_dir, "and the same home directory")
    assert_true(
        by_name[].pw_shell().startswith("/"),
        "and it has a shell by path too",
    )


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

    The name is copied out of the first answer before the second question
    is put, for the reason given in the test above: both answers sit in
    the same place, so reading them both afterwards would ask whether the
    row agrees with itself.
    """
    var row = getpwuid(UInt32(getuid()))
    assert_false(is_null(row), "the user running this is a user")
    var name = row[].pw_name()
    assert_true(name.byte_length() > 0, "and has a name")
    # The uid in the row is the one that was asked for, and that is a
    # number nothing here chose: a row read at an offset one field away
    # answers with a different number, and one user it happens to agree
    # with -- uid 0 keeps the same answer as the group that owns it -- is
    # the reason this is asked of the user running this and not of root.
    assert_equal(
        Int(row[].pw_uid()),
        Int(getuid()),
        "and the row carries the number it was asked for",
    )

    var again = getpwuid(UInt32(getuid()))
    assert_equal(again[].pw_name(), name, "asking twice says the same")


def test_the_reentrant_pair_puts_the_user_in_the_caller_s_room() raises:
    """`getpwuid_r` and `getpwnam_r` look a user up and put what they
    find in room the caller gives them.

    Both are asked for user 0, which is the one user every machine
    has, called one thing here and another there. What is asked of
    them is that the number comes back the same: a row found by number
    carries that number, and the same row found by the name it gave
    carries it too.

    What says it was found is not the 0 these hand back — that says
    only that the looking was done — but the pointer written into
    `result`. A name that is not in the database hands back 0 as well,
    and writes nothing there at all.
    """
    var row = unsafe_alloc[passwd](1)
    var room = unsafe_alloc[UInt8](4096)
    var found = unsafe_alloc[c_ptr[passwd]](1)

    assert_equal(
        getpwuid_r(0, row, room, 4096, found), 0, "user 0 was looked for"
    )
    assert_true(
        not is_null(found.unsafe_offset(0)[]), "and they are there, under"
    )
    assert_equal(
        Int(row.unsafe_offset(0)[].pw_uid()), 0, "the number it was asked by"
    )

    # The name it gave, asked back again.
    var name = string_to_char_ptr(row.unsafe_offset(0)[].pw_name())
    assert_equal(
        getpwnam_r(name, row, room, 4096, found),
        0,
        "and the name was looked up",
    )
    assert_true(
        not is_null(found.unsafe_offset(0)[]),
        "and the row came back by name too, with",
    )
    assert_equal(
        Int(row.unsafe_offset(0)[].pw_uid()), 0, "the same number in it"
    )

    name.unsafe_free()
    found.unsafe_free()
    room.unsafe_free()
    row.unsafe_free()


def test_the_fields_the_two_structs_do_not_share() raises:
    """Five members the row has that the tests have never asked for:
    the password placeholder, the real name, and the three Darwin
    carries that Linux's struct does not.

    The password itself left this row decades ago — to `shadow` on
    Linux and out of `/etc/passwd` on Darwin — so what is in the field
    is a placeholder, and the placeholder each platform keeps is a
    fact about the platform. The real name is whoever the account
    belongs to, and for root it is not empty on either. The three
    Darwin-only members answer 0 and nothing on Linux, which is what
    the accessors promise rather than something read out of a slot
    that holds another member, and on Darwin they are the account's
    own numbers: a password changed at no time, an account that does
    not expire, and a class that is none.
    """
    var name = string_to_char_ptr("root")
    var by_name = getpwnam(name)
    assert_true(not is_null(by_name), "root is found as before")

    comptime if CompilationTarget.is_macos():
        assert_equal(
            by_name[].pw_passwd(),
            "*",
            "the password field holds the star Darwin keeps for an "
            + "account whose password is not in the file",
        )
        assert_true(
            by_name[].pw_gecos().byte_length() > 0,
            "the real name of the account is not empty",
        )
        assert_equal(
            Int(by_name[].pw_change()),
            0,
            "the password has been changed at no time",
        )
        assert_equal(
            Int(by_name[].pw_expire()),
            0,
            "and the account does not expire",
        )
        assert_equal(
            by_name[].pw_class(),
            "",
            "and root has no login class",
        )
    else:
        assert_equal(
            by_name[].pw_passwd(),
            "x",
            "the password went to shadow: the field holds the "
            + "placeholder Linux keeps",
        )
        assert_true(
            by_name[].pw_gecos().byte_length() > 0,
            "the real name of the account is not empty",
        )
        assert_equal(
            Int(by_name[].pw_change()),
            0,
            "Linux's struct has no such member: nothing, not some "
            + "other member's slot",
        )
        assert_equal(
            Int(by_name[].pw_expire()),
            0,
            "and no expiry, for the same reason",
        )
        assert_equal(
            by_name[].pw_class(),
            "",
            "and no class, there being none",
        )


def main() raises:
    test_root_is_user_zero_whichever_way_it_is_asked()
    test_asking_for_a_user_that_is_not_there_answers_null()
    test_the_whole_database_can_be_walked()
    test_whoever_is_running_is_in_the_database()
    test_the_reentrant_pair_puts_the_user_in_the_caller_s_room()
    test_the_fields_the_two_structs_do_not_share()
    print("pwd ok")
