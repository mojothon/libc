# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_ptr
from libc.utils import char_ptr_to_string


struct group:
    """A C `struct group`: one row of the group database.

    Four members and nothing to disagree about: `gr_name`, `gr_passwd`,
    `gr_gid` and `gr_mem` sit at 0, 8, 16 and 24 on glibc and on Darwin
    both, thirty-two bytes and eight-aligned either way. `gr_gid` is a
    `gid_t` here and an `int` there, and both are four bytes in the same
    place. This is the one struct in the package that needs no reading at
    the offset of whoever is compiling.

    libc owns the object this points at, and may hand every caller the
    same one: two calls overwrite each other's answer, and nothing here
    frees it. `gr_mem` is a `char **` the same allocator owns, a list of
    login names ended by a null, and it comes with the row.
    """

    var _bytes: Array[UInt64, 4]

    def __init__(out self):
        """Zeroes the block, which is the state of one nothing has filled."""
        self._bytes = Array[UInt64, 4](fill=0)

    def _member(self, offset: Int) -> UInt64:
        """The eight bytes at `offset`, where each of these members begins."""
        return self._bytes[offset // 8]

    def _text_at(self, offset: Int) raises -> String:
        """What the `char *` stored at `offset` points at."""
        var held = self._member(offset)
        if held == 0:
            return String("")
        return char_ptr_to_string(c_ptr[UInt8](unsafe_from_address=Int(held)))

    def gr_name(self) raises -> String:
        """The group's name, as in `wheel` or `staff`."""
        return self._text_at(0)

    def gr_passwd(self) raises -> String:
        """The password field, which has held nothing but a placeholder
        for decades — `x` on Linux, `*` on Darwin.
        """
        return self._text_at(8)

    def gr_gid(self) raises -> UInt32:
        """The group's id, which is what files are owned by and what
        `getgrgid` looks one up by. Zero is `root` on Linux and `wheel`
        on Darwin.
        """
        return UInt32(self._member(16) & 0xFFFFFFFF)

    def gr_mem(self) -> c_ptr[c_ptr[UInt8]]:
        """The group's members: a vector of login names, ended by a null
        pointer, each one readable with `char_ptr_to_string`. An empty
        group is one null and nothing before it.
        """
        return c_ptr[c_ptr[UInt8]](unsafe_from_address=Int(self._member(24)))


def setgrent() -> None:
    """C library <grp.h> function `setgrent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getgrent.3.html

    Description:
        Winds the group database back to the top, so the next `getgrent`
        is the first row again.

    Notes:
        Fn signature:
        `void setgrent(void)`.
    """
    external_call["setgrent", NoneType]()


def endgrent() -> None:
    """C library <grp.h> function `endgrent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getgrent.3.html

    Description:
        Ends the walk through the group database and releases whatever it
        was holding open. Not asking is not a leak of anything permanent,
        but this is what tells libc the walk is over.

    Notes:
        Fn signature:
        `void endgrent(void)`.
    """
    external_call["endgrent", NoneType]()


def getgrent() -> c_ptr[group]:
    """C library <grp.h> function `getgrent`.

    Reference:
        https://man7.org/linux/man-pages/man3/getgrent.3.html

    Description:
        The next row of the group database, from the top if `setgrent`
        just rewound it and from wherever the last call left off
        otherwise.

    Returns:
        The row, or null when the database is at its end. `is_null` from
        `libc.utils` is how to ask, and the two questions — end or
        failure — are not answered apart here.

    Notes:
        Fn signature:
        `struct group *getgrent(void)`.

        What it points at belongs to libc and the next call overwrites
        it, so take what is wanted out of it before asking again.
    """
    return external_call["getgrent", c_ptr[group]]()


def getgrnam(name: c_ptr[UInt8]) -> c_ptr[group]:
    """C library <grp.h> function `getgrnam`.

    Reference:
        https://man7.org/linux/man-pages/man3/getgrnam.3.html

    Description:
        The row of the group database for one name, which is what a
        username in `/etc/group` is looked up by.

    Args:
        name: The group name to look for, NUL terminated. Build one from
            a `String` with `string_to_char_ptr`.

    Returns:
        The row, or null when no group of that name is there — a name
        that does not exist is not an error. `is_null` from `libc.utils`
        is how to ask. The same warning as `getgrent`: what it points at
        belongs to libc and the next call overwrites it.

    Notes:
        Fn signature:
        `struct group *getgrnam(const char *name)`.
    """
    return external_call["getgrnam", c_ptr[group], c_ptr[UInt8]](name)


def getgrgid(gid: UInt32) -> c_ptr[group]:
    """C library <grp.h> function `getgrgid`.

    Reference:
        https://man7.org/linux/man-pages/man3/getgrgid.3.html

    Description:
        The row of the group database for one id, which is what the
        number a file is owned by is looked up by.

    Args:
        gid: The group id to look for. It is a `gid_t`, four bytes of it,
            and the same number is what `group.gr_gid` answers.

    Returns:
        The row, or null when no group of that id is there. `is_null`
        from `libc.utils` is how to ask, and what it points at is
        libc's, as with `getgrnam`.

    Notes:
        Fn signature:
        `struct group *getgrgid(gid_t gid)`.
    """
    return external_call["getgrgid", c_ptr[group], UInt32](gid)
