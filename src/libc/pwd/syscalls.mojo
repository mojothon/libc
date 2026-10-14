# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr
from libc.utils import char_ptr_to_string


struct passwd:
    """A C `struct passwd`: one row of the user database.

    POSIX fixes the order the seven members come in and both platforms honour
    it, but Darwin carries three more of its own — `pw_change`, `pw_expire`
    and `pw_class` — and puts them in the middle, after `pw_gid`. That makes
    the whole struct seventy-two bytes there against forty-eight here, and
    `pw_gecos` and everything after it a different distance in. So this holds
    the larger block and reads each member at the offset that fits, which is
    why the members come from methods rather than fields.

    libc owns the object this points at, and may hand every caller the same
    one: two calls overwrite each other's answer, and nothing here frees it.
    """

    var _bytes: Array[UInt64, 9]

    def __init__(out self):
        """Zeroes the block, which is the state of one nothing has filled."""
        self._bytes = Array[UInt64, 9](fill=0)

    def _member(self, offset: Int) -> UInt64:
        """The eight bytes at `offset`, where each of these members begins."""
        return self._bytes[offset // 8]

    def _text_at(self, offset: Int) raises -> String:
        """What the `char *` stored at `offset` points at."""
        var held = self._member(offset)
        if held == 0:
            return String("")
        return char_ptr_to_string(c_ptr[UInt8](unsafe_from_address=Int(held)))

    def pw_name(self) raises -> String:
        """The user's login name, as in `root`."""
        return self._text_at(0)

    def pw_passwd(self) raises -> String:
        """The password field.

        The password itself has not been in here for decades, having gone to
        `shadow` on Linux and out of `/etc/passwd` on Darwin, so what is here
        is a placeholder such as `x` or `*`.
        """
        return self._text_at(8)

    def pw_uid(self) raises -> UInt32:
        """The user's id, which is what files are owned by."""
        return UInt32(self._member(16) & 0xFFFFFFFF)

    def pw_gid(self) raises -> UInt32:
        """The user's principal group id."""
        return UInt32(self._member(16) >> 32)

    def pw_gecos(self) raises -> String:
        """The user's real name, and whatever else follows it."""
        return self._text_at(24 if not CompilationTarget.is_macos() else 40)

    def pw_dir(self) raises -> String:
        """The user's home directory."""
        return self._text_at(32 if not CompilationTarget.is_macos() else 48)

    def pw_shell(self) raises -> String:
        """The user's login shell, which is `/bin/false` for nobody."""
        return self._text_at(40 if not CompilationTarget.is_macos() else 56)

    def pw_change(self) raises -> Int64:
        """When the password was last changed. Darwin only.

        Linux's struct has no such member, so this answers 0 there rather
        than something read out of a slot holding the gecos field.
        """
        comptime if CompilationTarget.is_macos():
            return Int64(self._member(24))
        else:
            return Int64(0)

    def pw_expire(self) raises -> Int64:
        """When the account expires, in seconds. Darwin only.

        It is a `time_t` in the struct, not a `char *`, so reading it as
        text would have followed a small integer as though it were an
        address. Linux's struct has no such member and this answers 0
        there.
        """
        comptime if CompilationTarget.is_macos():
            return Int64(self._member(64))
        else:
            return Int64(0)

    def pw_class(self) raises -> String:
        """The user's access class. Darwin only."""
        comptime if CompilationTarget.is_macos():
            return self._text_at(32)
        else:
            return String("")


def setpwent() -> None:
    """C library <pwd.h> function `setpwent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getpwent.3.html

    Prototype:
        void setpwent(void)

    Description:
        The setpwent() function winds the user database back to the top, so
        that a following `getpwent` starts over from the first user rather
        than carrying on from wherever it had got to.

    Return Value:
        Nothing. There is no failure this can report and no way to ask
        whether it took.
    """
    _ = external_call["setpwent", NoneType]()


def endpwent() -> None:
    """C library <pwd.h> function `endpwent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getpwent.3.html

    Prototype:
        void endpwent(void)

    Description:
        The endpwent() function closes the user database, letting go of
        whatever the walk has been holding open. Calling it whether a walk
        happened or not costs nothing.

    Return Value:
        Nothing. There is no failure this can report and no way to ask
        whether it took.
    """
    _ = external_call["endpwent", NoneType]()


def getpwent() -> c_ptr[passwd]:
    """C library <pwd.h> function `getpwent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getpwent.3.html

    Prototype:
        struct passwd *getpwent(void)

    Description:
        The getpwent() function hands back the next user in the database,
        which walks it a row at a time. `setpwent` starts the walk over and
        `endpwent` closes it.

        The row it points at is one libc owns and reuses, so asking for the
        next one is also what takes the last one away: copy out anything
        wanted before moving on.

    Return Value:
        A pointer to the next user, or NULL once there are no more, which is
        how the walk ends rather than a failure. Test for it with `is_null`.
    """
    return external_call["getpwent", c_ptr[passwd]]()


def getpwnam(name: c_ptr[UInt8]) -> c_ptr[passwd]:
    """C library <pwd.h> function `getpwnam`.

    Reference:
        https://man7.org/linux/man-pages/man3/getpwnam.3.html

    Prototype:
        struct passwd *getpwnam(const char *name)

    Description:
        The getpwnam() function looks a user up by login name, which is the
        direction most things want: the name came from configuration or from
        whoever is typing, and the id belonging to it is what is needed.

    Arguments:
        name: The login name being asked about, NUL terminated. Build one
            from a `String` with `string_to_char_ptr`.

    Return Value:
        A pointer to that user's row, or NULL when there is no such user,
        which is an ordinary answer rather than a failure. errno is left
        alone either way, so nothing here explains why.
    """
    return external_call["getpwnam", c_ptr[passwd], c_ptr[UInt8]](name)


def getpwuid(uid: UInt32) -> c_ptr[passwd]:
    """C library <pwd.h> function `getpwuid`.

    Reference:
        https://man7.org/linux/man-pages/man3/getpwuid.3.html

    Prototype:
        struct passwd *getpwuid(uid_t uid)

    Description:
        The getpwuid() function looks a user up by id, which is the direction
        a file's owner needs it: `stat` answers with a number, and a name is
        what goes up on the screen. `getuid` in `libc.unistd` gives the id of
        whoever is running.

    Arguments:
        uid: The id being asked about.

    Return Value:
        A pointer to that user's row, or NULL when there is no such user,
        which is an ordinary answer rather than a failure. errno is left
        alone either way, so nothing here explains why.
    """
    return external_call["getpwuid", c_ptr[passwd], UInt32](uid)
