from std.testing import assert_equal

from libc import __version__


def test_version_is_pinned() raises:
    var version = String(__version__)
    assert_equal(version, "0.7.0")


def main() raises:
    test_version_is_pinned()
    print("test_version: ok")
