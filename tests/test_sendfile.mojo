"""Tests for `libc.sys.sendfile`, which had never been called.

It moves bytes from one descriptor to another without their coming
into the process at all, which is the whole of why it is worth having.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.fcntl import O_CREAT, O_RDONLY, O_RDWR, O_WRONLY, open
from libc.sys.sendfile import sendfile
from libc.unistd import close, read, write
from libc.utils import string_to_char_ptr

comptime FROM = "/tmp/mojo_libc_sendfile_from"
comptime TO = "/tmp/mojo_libc_sendfile_to"


def test_sendfile_moves_bytes_and_says_where_it_got_to() raises:
    """`sendfile` hands back how many bytes it moved, and writes how
    far into the file it got into the offset it was given, which is
    how it is asked to carry on from where it left off.

    Five bytes are moved into a file that had none, and read back out
    afterwards, since a number alone would not say they arrived.
    """
    comptime if not CompilationTarget.is_macos():
        var source = open(string_to_char_ptr(FROM), O_CREAT | O_RDWR, 0o644)
        assert_true(source >= 0, "there is a file to move bytes out of")

        var going = unsafe_alloc[UInt8](6)
        for i in range(5):
            going.unsafe_store(i, UInt8(104 + i))  # h, e, l, l, o
        assert_equal(write(source, going, 5), 5, "and five bytes are in it")

        var sink = open(string_to_char_ptr(TO), O_CREAT | O_WRONLY, 0o644)
        assert_true(sink >= 0, "there is a file to move them into")

        var at = unsafe_alloc[Int64](1)
        at.unsafe_offset(0)[] = 0
        assert_equal(
            Int(sendfile(sink, source, at, 5)),
            5,
            "sendfile answers with how many",
        )
        assert_equal(
            Int(at.unsafe_load()), 5, "and says it got five bytes into the file"
        )

        _ = close(source)
        _ = close(sink)

        var back = open(string_to_char_ptr(TO), O_RDONLY)
        var got = unsafe_alloc[UInt8](6)
        assert_equal(
            read(back, got, 5), 5, "and five bytes are in the other one"
        )
        for i in range(5):
            assert_equal(
                Int(got.unsafe_load(i)),
                104 + i,
                "and they are the ones that went in",
            )

        at.unsafe_free()
        going.unsafe_free()
        got.unsafe_free()
        _ = close(back)


def main() raises:
    test_sendfile_moves_bytes_and_says_where_it_got_to()
    print("test_sendfile: ok")
