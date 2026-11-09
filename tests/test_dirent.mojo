from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import O_CREAT, O_RDONLY, O_TRUNC, O_WRONLY, c_ptr, c_void
from libc.dirent import (
    DT_DIR,
    DT_REG,
    DIRENT_BYTES,
    DIRENT_NAME_OFFSET,
    alphasort,
    closedir,
    dirent,
    dirfd,
    fdopendir,
    opendir,
    readdir,
    readdir_r,
    rewinddir,
    scandir,
    seekdir,
    telldir,
)
from libc.fcntl import open
from libc.stdlib import free
from libc.string import strcmp
from libc.sys.stat import Stat, mkdir, stat
from libc.unistd import close, rmdir, unlink
from libc.utils import is_null, null_ptr, string_to_char_ptr


def test_opendir_readdir() raises:
    """A stream handed every entry until there are none left.

    Which entries there are is the directory's business, but two of them
    are not: `.` and `..` are in every directory, which is the one thing
    that can be asserted about a listing without knowing what is being
    listed. Reaching the end and finding them there is what says the loop
    walked the stream, and the `NULL` that ends it is what says when.
    """
    var path = string_to_char_ptr("/tmp")
    var dirp = opendir(path)
    assert_true(not is_null(dirp), "/tmp opens")

    var dot = string_to_char_ptr(".")
    var dotdot = string_to_char_ptr("..")
    var seen_dot = False
    var seen_dotdot = False
    var count = 0
    # The inode in the `.` entry is the directory's own, which `stat`
    # answers independently: two readers of one fact, so a layout constant
    # that names the wrong byte gives a number that disagrees with the one
    # the kernel wrote. Comparing two `readdir` reads against each other
    # would not: they read through the same constant, and would agree on
    # being wrong.
    var about = unsafe_alloc[Stat](1)
    assert_equal(stat(path, about), 0, "and /tmp can be asked about, so")
    var seen_ino = False
    while True:
        var entry = readdir(dirp)
        if is_null(entry):
            break
        count += 1
        var name = entry.unsafe_bitcast[UInt8]().unsafe_offset(
            DIRENT_NAME_OFFSET
        )
        if Int(strcmp(name, dot)) == 0:
            seen_dot = True
            assert_equal(
                Int(entry.unsafe_offset(0)[].ino()),
                Int(about[].ino()),
                "the inode it carries is the one stat gives",
            )
            seen_ino = True
        if Int(strcmp(name, dotdot)) == 0:
            seen_dotdot = True
    assert_true(seen_ino, "and the entry it was read from was there")

    assert_true(count > 0, "and it has entries in it, and")
    assert_true(seen_dot, "the one every directory has, and")
    assert_true(seen_dotdot, "the other one every directory has")

    assert_equal(closedir(dirp), 0)
    dot.unsafe_free()
    dotdot.unsafe_free()
    path.unsafe_free()


def test_dirfd() raises:
    """`dirfd` answers with the descriptor the stream reads through.

    For a stream made by `fdopendir` that is the descriptor it was handed
    and not a copy of it — taking ownership is exactly that — so the
    number is known in advance and is asked for exactly. What follows from
    it is asked as well: `closedir` closes that descriptor, which the
    `close` after it says, since a descriptor already closed is one `close`
    refuses.
    """
    var path = string_to_char_ptr("/tmp")
    var fd = open(path, O_RDONLY)
    assert_true(fd >= 0, "/tmp opens")

    var dirp = fdopendir(fd)
    assert_true(not is_null(dirp), "and makes a stream of it")
    assert_equal(
        dirfd(dirp), fd, "which reads through that descriptor and no other"
    )

    assert_equal(closedir(dirp), 0, "and closing the stream closes it, so")
    assert_equal(close(fd), -1, "the descriptor it took is not there any more")
    path.unsafe_free()


def test_telldir_and_seekdir() raises:
    var path = string_to_char_ptr("/tmp")
    var dirp = opendir(path)

    var start = telldir(dirp)
    assert_true(start >= 0, "a fresh stream is somewhere")

    _ = readdir(dirp)
    assert_true(telldir(dirp) != start, "reading an entry moves it on")

    seekdir(dirp, start)
    assert_equal(telldir(dirp), start, "seekdir goes back to where it was")

    # What rewinding promises is that the stream is at the beginning
    # again. What it does not promise is the number `telldir` gives for
    # that: on Darwin it is not the one it gave before the rewind, so
    # asking for the same number is asking for more than POSIX says.
    rewinddir(dirp)
    assert_true(Int(UInt(readdir(dirp))) != 0, "there is an entry to read")

    assert_equal(closedir(dirp), 0)
    path.unsafe_free()


def test_fdopendir() raises:
    """A stream from a descriptor rather than from a path."""
    var path = string_to_char_ptr("/tmp")
    var fd = open(path, O_RDONLY)
    assert_true(fd >= 0, "/tmp opens")

    var dirp = fdopendir(fd)
    assert_true(Int(UInt(dirp)) != 0, "and the descriptor opens a stream")

    # `closedir` closes the descriptor that came with it, so this is the
    # last thing to do with either of them.
    assert_equal(closedir(dirp), 0)
    path.unsafe_free()


def test_scandir() raises:
    """A whole directory in one call: the entries come back as a vector
    of their own, every one of them readable at once rather than one
    buffer used over and over as `readdir` does it.
    """
    var path = string_to_char_ptr("/tmp")
    var list = unsafe_alloc[c_ptr[c_ptr[dirent]]](1)
    list.unsafe_offset(0)[] = null_ptr[c_ptr[dirent]]()

    var n = scandir(path, list, null_ptr[UInt8](), null_ptr[UInt8]())
    assert_true(n > 0, "/tmp has entries in it")

    var vector = list[]
    for i in range(Int(n)):
        var entry = vector.unsafe_offset(i)[]
        assert_true(entry[].name().byte_length() > 0, "and each one is named")

    # The vector and every entry in it were allocated for this call, so
    # releasing them is on the caller and on nothing else.
    for i in range(Int(n)):
        _ = free(vector.unsafe_offset(i)[].unsafe_bitcast[c_void]())
    _ = free(vector.unsafe_bitcast[c_void]())

    list.unsafe_free()
    path.unsafe_free()


def test_scandir_on_something_that_is_not_a_directory() raises:
    """A file is not a directory, and the way this says so is -1 rather
    than a vector of nothing: a zero-length answer means an empty
    directory, which is not the same thing at all.
    """
    var path = string_to_char_ptr("/dev/null")
    var list = unsafe_alloc[c_ptr[c_ptr[dirent]]](1)
    list.unsafe_offset(0)[] = null_ptr[c_ptr[dirent]]()

    assert_equal(
        scandir(path, list, null_ptr[UInt8](), null_ptr[UInt8]()),
        -1,
        "a file is not a directory",
    )

    list.unsafe_free()
    path.unsafe_free()


def test_alphasort_puts_two_names_where_strcmp_puts_them() raises:
    """The comparator `scandir` would have used, asked of two entries it
    actually handed back. `/dev` is the directory because a pair is
    wanted and that one always has one; nothing else about it is assumed.

    Asked by name rather than by the number, since which number comes
    back is the platform's business — only the sign is promised, and
    `strcmp` on the same two names is what it is checked against.
    """
    var path = string_to_char_ptr("/dev")
    var list = unsafe_alloc[c_ptr[c_ptr[dirent]]](1)
    list.unsafe_offset(0)[] = null_ptr[c_ptr[dirent]]()

    var n = scandir(path, list, null_ptr[UInt8](), null_ptr[UInt8]())
    assert_true(n >= 2, "/dev has a pair of entries in it")

    var vector = list[]
    var a = vector.unsafe_offset(0)
    var b = vector.unsafe_offset(1)
    var name_a = a[].unsafe_bitcast[UInt8]().unsafe_offset(DIRENT_NAME_OFFSET)
    var name_b = b[].unsafe_bitcast[UInt8]().unsafe_offset(DIRENT_NAME_OFFSET)

    var by_name = Int(strcmp(name_a, name_b))
    var by_sort = Int(alphasort(a, b))
    assert_true(
        (by_name < 0 and by_sort < 0)
        or (by_name > 0 and by_sort > 0)
        or (by_name == 0 and by_sort == 0),
        "the two names sort the way strcmp puts them",
    )

    for i in range(Int(n)):
        _ = free(vector.unsafe_offset(i)[].unsafe_bitcast[c_void]())
    _ = free(vector.unsafe_bitcast[c_void]())

    list.unsafe_free()
    path.unsafe_free()


def test_readdir_r_reads_what_readdir_reads() raises:
    """`readdir_r` reads the next entry of a directory into room the
    caller gives, rather than into one of its own.

    It is asked about the same directory `readdir` is asked about,
    and what is asked of the two is that they name the same file:
    two entries read one after the other from the top of a directory
    that is not empty carry the same inode. A call that filled the
    wrong room, or read the number out of the wrong place in it,
    names a different file or none at all.

    `/dev` is the directory, being one every machine has and one
    that is never empty.
    """
    var path = string_to_char_ptr("/dev")

    var plain = opendir(path)
    assert_true(not is_null(plain), "/dev opens, and")
    var first = readdir(plain)
    assert_true(not is_null(first), "readdir reads an entry in it")

    var again = opendir(path)
    assert_true(not is_null(again), "and opened again, readdir_r reads one too")

    var entry = unsafe_alloc[dirent](1)
    var result = unsafe_alloc[c_ptr[dirent]](1)
    assert_equal(
        readdir_r(again, entry, result), 0, "without anything going wrong, and"
    )
    assert_true(
        not is_null(result.unsafe_offset(0)[]),
        "there was an entry to read, and",
    )
    assert_equal(
        entry.unsafe_offset(0)[].ino(),
        first.unsafe_offset(0)[].ino(),
        "it is the same file readdir named",
    )

    path.unsafe_free()
    entry.unsafe_free()
    result.unsafe_free()


def test_the_type_of_each_entry_and_the_room_its_record_takes() raises:
    """Two more members of the record, and one of them is answered by
    a room this test builds: a directory made in `/tmp` with an
    ordinary file in it, walked with the accessors rather than with
    raw offsets.

    The type byte of the `.` and the `..` every directory carries is
    `DT_DIR`, and the file the test puts there answers `DT_REG` —
    which is what says the type reader is over the type byte and not
    over the name. The room the record takes is asked of every entry:
    it has to hold the header in front of the name and the name
    itself, and — on glibc, whose records are packed — it cannot hold
    much more than that, which is the bound that keeps `reclen`
    reading its own two bytes and not some other member's. Darwin's
    filesystems pad the record to a grain of their own, so the only
    bound asked of it there is that it fit the buffer it was read
    into.
    """
    comptime ROOM = "/tmp/libc_dirent_room"
    var room = string_to_char_ptr(ROOM)
    _ = mkdir(room, 0o755)
    var inside = string_to_char_ptr(ROOM + "/inside")
    var made = open(inside, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    assert_true(made >= 0, "the ordinary file is put in the room")
    assert_equal(close(made), 0, "and is closed")

    var dirp = opendir(room)
    assert_true(not is_null(dirp), "the room opens")

    var seen_the_file = False
    var count = 0
    while True:
        var entry = readdir(dirp)
        if is_null(entry):
            break
        count += 1

        var named = entry[].name()
        var held = named.byte_length()
        var takes = Int(entry[].reclen())
        assert_true(
            takes >= DIRENT_NAME_OFFSET + held,
            "the record holds the header and the name",
        )
        comptime if CompilationTarget.is_macos():
            assert_true(
                takes <= DIRENT_BYTES,
                "and it fits the buffer, APFS padding records to its "
                + "own grain",
            )
        else:
            assert_true(takes <= held + 28, "and not much more than that")

        if named == "." or named == "..":
            assert_equal(
                Int(entry[].type()),
                Int(DT_DIR),
                "the two every directory has are directories",
            )
        if named == "inside":
            assert_equal(
                Int(entry[].type()),
                Int(DT_REG),
                "and the file the test put there is an ordinary file",
            )
            seen_the_file = True

    assert_true(seen_the_file, "the file is among the entries")
    assert_true(count >= 3, "and there were the dots and the file to walk")

    assert_equal(closedir(dirp), 0, "the room is closed again")
    assert_equal(unlink(inside), 0, "the file is taken out")
    assert_equal(rmdir(room), 0, "and the room with it")


def main() raises:
    test_opendir_readdir()
    test_dirfd()
    test_telldir_and_seekdir()
    test_fdopendir()
    test_scandir()
    test_scandir_on_something_that_is_not_a_directory()
    test_alphasort_puts_two_names_where_strcmp_puts_them()
    test_readdir_r_reads_what_readdir_reads()
    test_the_type_of_each_entry_and_the_room_its_record_takes()
    print("test_dirent: ok")
