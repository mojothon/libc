from std.testing import assert_equal, assert_true

from libc.constant import O_RDONLY
from libc.dirent import (
    closedir,
    dirfd,
    fdopendir,
    opendir,
    readdir,
    rewinddir,
    seekdir,
    telldir,
)
from libc.fcntl import open
from libc.utils import string_to_char_ptr


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

    rewinddir(dirp)
    assert_equal(telldir(dirp), start, "and rewinding does the same")

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


def main() raises:
    test_opendir_readdir()
    test_dirfd()
    test_telldir_and_seekdir()
    test_fdopendir()
    print("test_dirent: ok")
