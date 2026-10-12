from std.testing import assert_equal, assert_true

from libc.dirent import closedir, dirfd, opendir, readdir
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


def main() raises:
    test_opendir_readdir()
    test_dirfd()
    print("test_dirent: ok")
