from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import ENODATA, EPERM, c_void
from libc.errno import get_errno, set_errno
from libc.fcntl import O_CREAT, O_RDWR
from libc.fcntl import open as open_with_mode
from libc.sys.xattr import (
    fgetxattr,
    flistxattr,
    fremovexattr,
    fsetxattr,
    getxattr,
    lgetxattr,
    llistxattr,
    lremovexattr,
    listxattr,
    lsetxattr,
    removexattr,
    setxattr,
)
from libc.unistd import close, symlink, unlink
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


def test_the_sayings_by_way_of_a_path() raises:
    """`setxattr`, `getxattr`, `listxattr`, `removexattr`
    and their `l` twins -- the same words kept with a
    file, said by way of a path whose symlinks are
    followed, or not. A word kept by way of the link is
    kept with the file the link really says, and taken
    back the same; the sayings that ask the link itself
    answer with nothing, the kernel keeping none of the
    caller's kind on a link. All are Linux's own words;
    Darwin answers different words with the sayings in
    the other order.
    """
    comptime if not CompilationTarget.is_macos():
        var target = string_to_char_ptr("/tmp/mojo_xattr_target.txt")
        var link = string_to_char_ptr("/tmp/mojo_xattr_link")
        _ = unlink(link)
        _ = unlink(target)
        var fd = open_with_mode(target, O_CREAT | O_RDWR, 0o600)
        assert_true(fd >= 0, "the file the link will say")
        _ = close(fd)
        # the link that says the file
        assert_equal(Int(symlink(target, link)), 0, "a link to say the file by")
        var name = string_to_char_ptr("user.by_path")
        var word = unsafe_alloc[UInt8](5)
        var said = "there"
        for i in range(5):
            word.unsafe_offset(i)[] = UInt8(ord(said[byte=i]))
        # kept by way of the link: it lands on what the link says
        assert_equal(
            Int(
                setxattr(
                    link.unsafe_bitcast[UInt8](),
                    name.unsafe_bitcast[UInt8](),
                    word.unsafe_bitcast[c_void](),
                    5,
                    0,
                )
            ),
            0,
            "the word is kept by way of the link",
        )
        # and taken back by way of the link, and by way of the file
        var room = unsafe_alloc[UInt8](64)
        assert_equal(
            Int(
                getxattr(
                    link.unsafe_bitcast[UInt8](),
                    name.unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    64,
                )
            ),
            5,
            "and taken back by way of the link",
        )
        assert_equal(
            Int(
                getxattr(
                    target.unsafe_bitcast[UInt8](),
                    name.unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    64,
                )
            ),
            5,
            "the same word, taken back by way of the file",
        )
        for i in range(5):
            assert_equal(
                Int(room.unsafe_offset(i)[]),
                Int(word.unsafe_offset(i)[]),
                "the same bytes, kept and taken back",
            )
        # the sayings that ask the link itself: the kernel keeps
        # none of the caller's kind on a link, and says so
        set_errno(0)
        assert_equal(
            Int(
                lgetxattr(
                    link.unsafe_bitcast[UInt8](),
                    name.unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    64,
                )
            ),
            -1,
            "the link itself has no word of the caller's kind",
        )
        assert_equal(Int(get_errno()), Int(ENODATA), "with errno saying so")
        set_errno(0)
        assert_equal(
            Int(
                lsetxattr(
                    link.unsafe_bitcast[UInt8](),
                    name.unsafe_bitcast[UInt8](),
                    word.unsafe_bitcast[c_void](),
                    5,
                    0,
                )
            ),
            -1,
            "and none can be kept on it",
        )
        assert_equal(Int(get_errno()), Int(EPERM), "with errno saying why")
        # the names said by way of the file: this one is among them
        var names = unsafe_alloc[UInt8](256)
        var listed = Int(listxattr(target.unsafe_bitcast[UInt8](), names, 256))
        assert_true(listed > 0, "the names are said by way of the file")
        var found = False
        var want = "user.by_path"
        for start in range(listed):
            var matched = True
            for j in range(12):
                if names.unsafe_offset(start + j)[] != UInt8(ord(want[byte=j])):
                    matched = False
            if matched:
                found = True
        assert_true(found, "and the name kept is among them")
        # the names asked of the link itself: none, and no error
        var listed_on_link = Int(
            llistxattr(link.unsafe_bitcast[UInt8](), names, 256)
        )
        assert_equal(listed_on_link, 0, "the link itself keeps nothing")
        # the word let go by way of the link, after which it is
        # refused by way of the file as well
        assert_equal(
            Int(
                removexattr(
                    link.unsafe_bitcast[UInt8](), name.unsafe_bitcast[UInt8]()
                )
            ),
            0,
            "the word is let go by way of the link",
        )
        set_errno(0)
        assert_equal(
            Int(
                getxattr(
                    target.unsafe_bitcast[UInt8](),
                    name.unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    64,
                )
            ),
            -1,
            "and asking for it is refused by way of the file",
        )
        assert_equal(
            Int(get_errno()),
            Int(ENODATA),
            "with errno saying there is no word of it",
        )
        # the saying of the link itself let go: nothing there to
        # let go of, and errno says so
        set_errno(0)
        assert_equal(
            Int(
                lremovexattr(
                    link.unsafe_bitcast[UInt8](), name.unsafe_bitcast[UInt8]()
                )
            ),
            -1,
            "the link itself has nothing to let go of",
        )
        assert_equal(Int(get_errno()), Int(EPERM), "with errno saying why")
        _ = unlink(link)
        _ = unlink(target)
        word.unsafe_free()
        room.unsafe_free()
        names.unsafe_free()


def main() raises:
    test_the_words_a_caller_keeps_with_a_file()
    test_the_sayings_by_way_of_a_path()
    print("test_xattr: ok")
