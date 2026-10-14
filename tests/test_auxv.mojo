"""Tests for `libc.sys.auxv`, which is Linux's and nobody else's.

`getauxval` reads the table the loader leaves on the stack for the
program to ask about once it is running. It had never been called.
"""
from std.sys import CompilationTarget
from std.testing import assert_equal

from libc.sys.auxv import AT_NULL, AT_PAGESZ, getauxval
from libc.unistd import getpagesize


def test_the_page_size_and_nothing_at_all() raises:
    """`AT_PAGESZ` asks how big a page is, which is a thing that
    `getpagesize` will say as well, so it can be asked both ways and
    the two answers set against each other. `AT_NULL` asks for
    nothing at all, and is given it.
    """
    comptime if not CompilationTarget.is_macos():
        assert_equal(
            getauxval(AT_PAGESZ),
            UInt64(Int(getpagesize())),
            "the page size, as the loader left it",
        )
        assert_equal(
            getauxval(AT_NULL), UInt64(0), "and AT_NULL asks for nothing"
        )


def main() raises:
    test_the_page_size_and_nothing_at_all()
    print("test_auxv: ok")
