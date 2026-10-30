from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import O_RDONLY, c_ptr, c_void
from libc.dirent import (
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
from libc.utils import is_null, null_ptr, string_to_char_ptr


def test_opendir_readdir() raises:
    var path = string_to_char_ptr("/tmp")
    var dirp = opendir(path)
    assert_true(Int(UInt(dirp)) != 0)

    var entry = readdir(dirp)
    assert_true(Int(UInt(entry)) != 0)
    assert_true(entry[].name().byte_length() > 0)

    assert_equal(closedir(dirp), 0)
    path.unsafe_free()


def test_dirfd() raises:
    var path = string_to_char_ptr("/tmp")
    var dirp = opendir(path)
    assert_true(dirfd(dirp) >= 0)
    assert_equal(closedir(dirp), 0)
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


def main() raises:
    test_opendir_readdir()
    test_dirfd()
    test_telldir_and_seekdir()
    test_fdopendir()
    test_scandir()
    test_scandir_on_something_that_is_not_a_directory()
    test_alphasort_puts_two_names_where_strcmp_puts_them()
    test_readdir_r_reads_what_readdir_reads()
    print("test_dirent: ok")
