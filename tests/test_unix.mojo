"""Tests for the `libc.sys.un` binding, which is one struct and nothing
else: an `AF_UNIX` address, whose whole content is a path.

Everything here binds a socket to a file under `/tmp` and takes the file
away again, so nothing outlives the run; the file's name carries the
process id so that two runs at once do not meet on the same name.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import AF_UNIX, EADDRINUSE, SOCK_STREAM
from libc.errno import get_errno
from libc.sys.socket import accept, bind, connect, listen, recv, send, socket
from libc.sys.un import (
    SOCKADDR_UN_BYTES,
    SOCKADDR_UN_PATH_BYTES,
    SOCKADDR_UN_PATH_OFFSET,
    sockaddr_un,
)
from libc.unistd import close, getpid, unlink
from libc.utils import string_to_char_ptr


def a_name_for(this_run: String) -> String:
    """A path under `/tmp` that no other run is using.

    Args:
        this_run: What to call this one, so a file left behind says which
            test it was.

    Returns:
        The path.
    """
    return "/tmp/libc-" + this_run + "-" + String(Int(getpid())) + ".sock"


def test_the_path_is_written_where_c_keeps_it() raises:
    """`set_path` puts the text where C's `sun_path` sits, ends it with a
    NUL, and `path` reads back exactly what went in.

    The NUL is the claim worth checking twice: a path written without one
    reads back as itself only by finding a zero that was already there,
    and a shorter path written over a longer one reads back as the longer
    one with its tail still on.
    """
    var block = unsafe_alloc[UInt8](SOCKADDR_UN_BYTES)
    var address = sockaddr_un(block)
    var here = "/tmp/first.sock"
    address.set_path(here)
    assert_equal(address.path(), here, "the path comes back as it went in")
    assert_equal(
        Int(address.byte(SOCKADDR_UN_PATH_OFFSET)),
        Int(UInt8(ord("/"))),
        "and it starts where the field starts",
    )

    # A shorter path over a longer one ends where it ends.
    var shorter = "/tmp/b.sock"
    address.set_path(shorter)
    assert_equal(address.path(), shorter, "and a shorter one does not inherit")
    assert_equal(
        Int(address.byte(SOCKADDR_UN_PATH_OFFSET + shorter.byte_length())),
        0,
        "because the byte after it is the NUL",
    )

    assert_equal(
        Int(address.length()),
        SOCKADDR_UN_BYTES,
        "the whole struct is the address",
    )

    comptime if CompilationTarget.is_macos():
        assert_equal(
            Int(address.byte(0)),
            SOCKADDR_UN_BYTES,
            "and Darwin's sun_len says the same",
        )
        assert_equal(Int(address.byte(1)), AF_UNIX, "with the family after it")
    else:
        assert_equal(
            address.byte(0), UInt8(AF_UNIX), "and the family leads on glibc"
        )
        # Two bytes of family, and the second is the half that has to be
        # zero: a block that came back carrying a byte there made the
        # kernel read a family of 0x2001 and refuse the bind, which is
        # how this assertion came to be written.
        assert_equal(Int(address.byte(1)), 0, "with a zero after it")
    block.unsafe_free()


def test_a_path_too_long_to_be_a_name_is_refused() raises:
    """A path that does not fit is refused rather than truncated.

    Truncating it would bind the socket to a different file with
    confidence, which is the kind of mistake that shows up later as a
    client that cannot find the server.
    """
    var block = unsafe_alloc[UInt8](SOCKADDR_UN_BYTES)
    var address = sockaddr_un(block)
    var fits = String("/tmp/") + String("x") * (SOCKADDR_UN_PATH_BYTES - 1 - 5)
    address.set_path(fits)
    assert_equal(
        address.path().byte_length(),
        SOCKADDR_UN_PATH_BYTES - 1,
        "the longest name fits, NUL and all",
    )
    var too_long = fits + "x"
    var refused = False
    try:
        address.set_path(too_long)
    except error:
        refused = True
    assert_true(refused, "and one byte more is refused")
    block.unsafe_free()


def test_a_socket_bound_to_a_name_is_reached_through_it() raises:
    """The whole of what the struct is for: `bind` creates the file,
    `connect` asks for it by name, and `accept` takes what asked.

    The second `bind` to the same name is the asymmetric half. It is
    refused with `EADDRINUSE`, which only happens if the first call
    really did put that path into the kernel's table: a struct that wrote
    the path somewhere else would bind twice and answer 0 twice.
    """
    var name = a_name_for("connect")
    _ = unlink(string_to_char_ptr(name))

    var here_block = unsafe_alloc[UInt8](SOCKADDR_UN_BYTES)
    var here = sockaddr_un(here_block)
    here.set_path(name)
    var server = socket(AF_UNIX, SOCK_STREAM, 0)
    assert_true(server >= 0, "a socket to listen on")
    assert_equal(
        bind(server, here.as_socketaddr(), here.length()),
        0,
        "it is bound to the name",
    )
    assert_equal(listen(server, 1), 0, "and it is listening")

    # The name is a file now, so the same name cannot be taken twice.
    var again_block = unsafe_alloc[UInt8](SOCKADDR_UN_BYTES)
    var again = sockaddr_un(again_block)
    again.set_path(name)
    var second = socket(AF_UNIX, SOCK_STREAM, 0)
    assert_equal(
        bind(second, again.as_socketaddr(), again.length()),
        -1,
        "and the name is taken",
    )
    assert_equal(Int(get_errno()), EADDRINUSE, "which is why it is refused")
    _ = close(second)

    var caller = socket(AF_UNIX, SOCK_STREAM, 0)
    assert_equal(
        connect(caller, here.as_socketaddr(), here.length()),
        0,
        "a second socket reaches it by name",
    )

    # `accept` writes the caller's address into a struct of its own. The
    # caller never bound a name, so there is nothing in it -- which is
    # what most callers of a pathname socket look like.
    var who_block = unsafe_alloc[UInt8](SOCKADDR_UN_BYTES)
    var who = sockaddr_un(who_block)
    var length = unsafe_alloc[UInt32](1)
    length.unsafe_offset(0)[] = who.length()
    var taken = accept(server, who.as_socketaddr(), length)
    assert_true(taken >= 0, "and the connection is taken")
    # How much of the struct a caller with no name comes back as is the
    # platform's answer and not this package's: glibc answers the family
    # alone, two bytes, and Darwin answers sixteen, the size of a bare
    # `struct sockaddr`. Both were read off a runner rather than guessed,
    # and neither leaves a byte of the path behind.
    comptime EMPTY_CALLER: UInt32 = (
        16 if CompilationTarget.is_macos() else UInt32(SOCKADDR_UN_PATH_OFFSET)
    )
    assert_equal(length.unsafe_offset(0)[], EMPTY_CALLER, "with no name in it")
    assert_equal(who.path(), "", "so the path is empty")

    var said = string_to_char_ptr("hello")
    assert_equal(
        Int(send(caller, said, 5, 0)), 5, "a word goes in at the caller"
    )
    var heard = string_to_char_ptr("")
    var got = recv(taken, heard, 5, 0)
    assert_equal(Int(got), 5, "and comes out of what was taken")

    _ = close(caller)
    _ = close(taken)
    _ = close(server)
    # The file outlives the socket, which is the caller's to clean up.
    assert_equal(
        unlink(string_to_char_ptr(name)), 0, "the name can be taken away"
    )
    length.unsafe_free()
    who_block.unsafe_free()
    again_block.unsafe_free()
    here_block.unsafe_free()


def main() raises:
    test_the_path_is_written_where_c_keeps_it()
    test_a_path_too_long_to_be_a_name_is_refused()
    test_a_socket_bound_to_a_name_is_reached_through_it()
    print("unix ok")
