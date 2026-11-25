from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import ENODATA, c_void
from libc.errno import get_errno, set_errno
from libc.fcntl import O_CREAT, O_RDWR
from libc.fcntl import open as open_with_mode
from libc.sys.xattr import fgetxattr, flistxattr, fremovexattr, fsetxattr
from libc.unistd import close, unlink
from libc.utils import null_ptr, string_to_char_ptr


def test_the_words_a_caller_keeps_with_a_file() raises:
    """`fsetxattr`, `fgetxattr`, `flistxattr` and
    `fremovexattr` -- the words a caller keeps with a
    file, under names of the caller's own: a word is
    kept, taken back the same, counted, read by its
    size alone, and let go, after which asking for it
    is refused the way it would be if it had never been
    kept. All four are Linux's own words; Darwin
    answers different words with the sayings in the
    other order.
    """
    comptime if not CompilationTarget.is_macos():
        var path = string_to_char_ptr("/tmp/mojo_xattr.txt")
        _ = unlink(path)
        var fd = open_with_mode(path, O_CREAT | O_RDWR, 0o600)
        assert_true(fd >= 0, "a file for the words to be kept with")
        # a word kept, under a name of the caller's own
        var name = string_to_char_ptr("user.mojo_test")
        var word = unsafe_alloc[UInt8](6)
        var said = "saying"
        for i in range(6):
            word.unsafe_offset(i)[] = UInt8(ord(said[byte=i]))
        assert_equal(
            Int(
                fsetxattr(
                    fd,
                    name.unsafe_bitcast[UInt8](),
                    word.unsafe_bitcast[c_void](),
                    6,
                    0,
                )
            ),
            0,
            "the word is kept",
        )
        # taken back the same, into a room of the caller's own
        var room = unsafe_alloc[UInt8](64)
        var got = Int(
            fgetxattr(
                fd,
                name.unsafe_bitcast[UInt8](),
                room.unsafe_bitcast[c_void](),
                64,
            )
        )
        assert_equal(got, 6, "and the word comes back six long")
        for i in range(6):
            assert_equal(
                Int(room.unsafe_offset(i)[]),
                Int(word.unsafe_offset(i)[]),
                "the same bytes, kept and taken back",
            )
        # how big the room wants to be, asked with a null room
        assert_equal(
            Int(
                fgetxattr(
                    fd, name.unsafe_bitcast[UInt8](), null_ptr[c_void](), 0
                )
            ),
            6,
            "the size is said by an asking that keeps nothing",
        )
        # the names kept with the file: this one is among them
        var names = unsafe_alloc[UInt8](256)
        var listed = Int(flistxattr(fd, names, 256))
        assert_true(listed > 0, "the names are said")
        var found = False
        var want = "user.mojo_test"
        for start in range(listed):
            var matched = True
            for j in range(14):
                if names.unsafe_offset(start + j)[] != UInt8(ord(want[byte=j])):
                    matched = False
            if matched:
                found = True
        assert_true(found, "and the name kept is among them")
        # a name already kept is refused unless the flag word
        # says to take it over
        assert_equal(
            Int(
                fsetxattr(
                    fd,
                    name.unsafe_bitcast[UInt8](),
                    word.unsafe_bitcast[c_void](),
                    6,
                    1,
                )
            ),
            -1,
            "a kept name is not taken over unasked",
        )
        assert_equal(
            Int(
                fsetxattr(
                    fd,
                    name.unsafe_bitcast[UInt8](),
                    word.unsafe_bitcast[c_void](),
                    6,
                    0,
                )
            ),
            0,
            "but is, with the flag word that says so",
        )
        # the word let go, after which it is as if never kept
        assert_equal(
            Int(fremovexattr(fd, name.unsafe_bitcast[UInt8]())),
            0,
            "the word is let go",
        )
        set_errno(0)
        assert_equal(
            Int(
                fgetxattr(
                    fd,
                    name.unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    64,
                )
            ),
            -1,
            "and asking for it is refused",
        )
        assert_equal(
            Int(get_errno()),
            Int(ENODATA),
            "with errno saying there is no word of it",
        )
        _ = close(fd)
        _ = unlink(path)
        word.unsafe_free()
        room.unsafe_free()
        names.unsafe_free()


def main() raises:
    test_the_words_a_caller_keeps_with_a_file()
    print("test_xattr: ok")
