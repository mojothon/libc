#!/usr/bin/env python3
"""Add getdents64 binding (dirent) and its test. Run once; verifies every anchor."""

import sys

# ---- 1) binding ----
p = "src/libc/dirent/syscalls.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"

if b"def getdents64" in s:
    print("binding already present")
else:
    o = (b'    return external_call[' + eol +
         b'        "readdir_r", Int32, c_ptr[DIR], c_ptr[dirent], c_ptr[c_ptr[dirent]]' + eol +
         b'    ](arg, entry, result)' + eol)
    assert o in s, "readdir_r return anchor missing"
    add = (eol + eol +
           b'def getdents64(fd: Int32, buf: c_ptr[UInt8], count: UInt64) -> Int64:' + eol +
           b'    """Libc Linux `getdents64` function.' + eol +
           b'' + eol +
           b'        ssize_t getdents64(unsigned int fd, void *buffer, size_t count)' + eol +
           b'' + eol +
           b'    Reference:' + eol +
           b'        https://man7.org/linux/man-pages/man2/getdents.2.html' + eol +
           b'' + eol +
           b'    Description:' + eol +
           b'        What a directory keeps, read raw: the room' + eol +
           b'        the asking gives is filled with the saying' + eol +
           b'        the directory keeps itself, entry after' + eol +
           b'        entry, each with the length that takes the' + eol +
           b'        asking to the next -- the asking of the' + eol +
           b'        names walking the room by saying how far' + eol +
           b'        each stands from where it starts, which the' + eol +
           b'        asking proves by walking it. The word' + eol +
           b'        `readdir` says is what the library makes of' + eol +
           b'        this; this is what the kernel says, and' + eol +
           b'        what the asking reads when the library\'s' + eol +
           b'        room is not what it wants. A fd that is not' + eol +
           b'        a directory is refused with `errno` saying' + eol +
           b'        so; a room read to the end says nothing the' + eol +
           b'        second time. The word is Linux\'s own, and' + eol +
           b'        Darwin has no call that says it.' + eol +
           b'' + eol +
           b'    Args:' + eol +
           b'        fd: The directory, open for the reading.' + eol +
           b'        buf: The room the saying fills, entry after' + eol +
           b'            entry.' + eol +
           b'        count: How much room the asking gives.' + eol +
           b'' + eol +
           b'    Returns:' + eol +
           b'        How many bytes the saying filled, or -1 on' + eol +
       b'            error with `errno` set. A directory read' + eol +
           b'            to the end comes back with 0.' + eol +
           b'    """' + eol +
           b'    return external_call[' + eol +
           b'        "getdents64", Int64, Int32, c_ptr[UInt8], UInt64' + eol +
           b'    ](fd, buf, count)' + eol)
    s = s.replace(o, o + add, 1)
    open(p, "wb").write(s)
    print("binding added")

# ---- 2) test ----
p = "tests/test_dirent.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"

if b"test_what_the_directory_says_raw" in s:
    print("test already inserted")
    sys.exit(0)

o = b"from libc.sys.stat import Stat, mkdir, stat" + eol
assert o in s
s = s.replace(o, o + b"from libc.errno import get_errno, set_errno\n" + b"from libc.constant import ENOTDIR\n" + b"from std.sys import CompilationTarget\n", 1)

add = '''


struct Dirent64:
    """What the kernel says of one entry, raw: the
    number of the file it is, where the saying of
    the next one starts from this one, how far it
    stands, what kind of file it is, and the name --
    which is where the saying stops being layout and
    starts being words.
    """
    var d_ino: UInt64
    var d_off: Int64
    var d_reclen: UInt16
    var d_type: UInt8

    fn name_ptr(self) -> c_ptr[UInt8]:
        return c_ptr[UInt8](unsafe_from_address=Int(self.d_reclen) - 0) + 19
'''

# Simpler test body without fancy struct walking; keep the walk with offsets.
add = '''


def test_what_the_directory_says_raw() raises:
    """`getdents64` -- what a directory keeps, read
    raw: the room the asking gives is filled with
    the saying the directory keeps itself, entry
    after entry, each with the length that takes
    the asking to the next. The asking walks the
    room by that length and proves the walk comes
    out even at the byte the saying said it filled.
    The names it said are there, and the kinds the
    saying gives are the ones the files are. A room
    read to the end says nothing the second time.
    A fd that is not a directory is refused with
    `errno` saying so. The word is Linux's own, and
    Darwin has no call that says it.
    """
    comptime if not CompilationTarget.is_macos():
        # a directory of the asking's own, with names said in it
        _ = mkdir(string_to_char_ptr("/tmp/mojo_gd64"), Int32(0o700))
        var made = string_to_char_ptr("/tmp/mojo_gd64/alpha")
        var a = open(made, O_CREAT | O_RDWR, 0o600)
        assert_true(a >= 0, "a name said into the directory")
        _ = close(a)
        var fd = open(string_to_char_ptr("/tmp/mojo_gd64"), O_RDONLY | O_DIRECTORY, 0)
        assert_true(fd >= 0, "the directory, open for the reading")
        var room = unsafe_alloc[UInt8](4096)
        var said = Int(getdents64(Int32(fd), room, 4096))
        assert_true(said > 0, "the saying fills the room with what the directory keeps")
        # walk by the length each entry says, and find the names
        var walked = 0
        var names = 0
        var off = 0
        var found_alpha = False
        while off < said:
            var at = room.unsafe_offset(off).unsafe_bitcast[c_ptr[UInt16]]().unsafe_offset(8)[]
            var reclen = Int(at)
            assert_true(reclen >= 24, "an entry is at least the room the saying says")
            var kind = room.unsafe_offset(off).unsafe_bitcast[c_ptr[UInt8]]().unsafe_offset(18)[]
            var nm = room.unsafe_offset(off).unsafe_offset(19).unsafe_bitcast[c_ptr[UInt8]]()
            if strcmp(nm, string_to_char_ptr("alpha")) == 0:
                found_alpha = True
                assert_equal(Int(kind), 8, "the name said as a file is said as one")
            names += 1
            walked += reclen
            off += reclen
        assert_true(found_alpha, "the name said into it comes back out of it")
        assert_equal(walked, said, "the walk comes out even where the saying stopped")
        # a room read to the end says nothing the second time
        var second = Int(getdents64(Int32(fd), room, 4096))
        assert_equal(second, 0, "a room read to the end says nothing the second time")
        _ = close(fd)
        # a fd that is not a directory
        var plain = open(string_to_char_ptr("/etc/hostname"), O_RDONLY, 0)
        assert_true(plain >= 0, "a file that is not a directory, open")
        set_errno(0)
        assert_equal(
            Int(getdents64(Int32(plain), room, 4096)),
            -1,
            "a fd that is not a directory is refused",
        )
        assert_equal(Int(get_errno()), Int(ENOTDIR), "with errno saying so")
        _ = close(plain)
        _ = unlink(made)
        _ = rmdir(string_to_char_ptr("/tmp/mojo_gd64"))
'''
blob = add.encode().replace(b"\n", eol)
i = s.find(b"def main() raises:")
assert i > 0, "main missing"
s = s[:i] + blob + eol + s[i:]

# imports
o2 = b"from std.sys import CompilationTarget" + eol
assert o2 in s
# wire
o3 = b'    print("dirent ok")' + eol
if o3 not in s:
    o3 = o3.replace(b"\r\n", b"\n"); eol = b"\n"
assert o3 in s, "wire anchor missing"
s = s.replace(o3, b"    test_what_the_directory_says_raw()" + eol + o3, 1)
open(p, "wb").write(s)
print("test inserted + wired")
