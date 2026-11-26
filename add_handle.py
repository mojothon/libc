#!/usr/bin/env python3
"""Add name_to_handle_at + open_by_handle_at (fcntl) and their test."""

p = "src/libc/fcntl/syscalls.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"
# append at end of file
tail = s.rstrip(eol + b" \t")
add = (eol + eol +
       b'def name_to_handle_at(' + eol +
       b'    dirfd: Int32, pathname: c_ptr[UInt8], handle: c_ptr[c_void], mount_id: c_ptr[Int32], flags: Int32' + eol +
       b') -> Int32:' + eol +
       b'    """C library <fcntl.h> function `name_to_handle_at`.' + eol +
       b'' + eol +
       b'        int name_to_handle_at(int dirfd, const char *pathname,' + eol +
       b'            struct file_handle *handle, int *mount_id, int flags)' + eol +
       b'' + eol +
       b'    Reference:' + eol +
       b'        https://man7.org/linux/man-pages/man2/open_by_handle_at.2.html' + eol +
       b'' + eol +
       b'    Description:' + eol +
       b'        A handle said of a file, kept by the filesystem' + eol +
       b'        itself -- not a saying the caller makes, but the' + eol +
       b'        filesystem\'s own name of the file, as long as the' + eol +
       b'        filesystem says. How long that is is asked with a' + eol +
       b'        room too small, which the asking refuses with' + eol +
       b'        `errno` saying so and the size said in `handle_bytes`' + eol +
       b'        where the answer will fit. Which mount the file is on' + eol +
       b'        is said beside it, for the saying back by handle is' + eol +
       b'        made on the mount the handle came from. The word is' + eol +
       b'        Linux\'s own, and Darwin has no call that takes it.' + eol +
       b'' + eol +
       b'    Args:' + eol +
       b'        dirfd: The directory the saying is looked for in, or' + eol +
       b'            `AT_FDCWD` for the caller\'s own.' + eol +
       b'        pathname: The saying of the file.' + eol +
       b'        handle: The room for the handle, led by `handle_bytes`' + eol +
       b'            and `handle_type`.' + eol +
       b'        mount_id: Where the mount\'s own number is said.' + eol +
       b'        flags: The words the asking is said with.' + eol +
       b'' + eol +
       b'    Returns:' + eol +
       b'        0 on success, or -1 on error with `errno` set.' + eol +
       b'    """' + eol +
       b'    return external_call[' + eol +
       b'        "name_to_handle_at", Int32, Int32, c_ptr[UInt8], c_ptr[c_void],' + eol +
       b'        c_ptr[Int32], Int32' + eol +
       b'    ](dirfd, pathname, handle, mount_id, flags)' + eol +
       eol + eol +
       b'def open_by_handle_at(' + eol +
       b'    mount_fd: Int32, handle: c_ptr[c_void], flags: Int32' + eol +
       b') -> Int32:' + eol +
       b'    """C library <fcntl.h> function `open_by_handle_at`.' + eol +
       b'' + eol +
       b'        int open_by_handle_at(int mount_fd, struct file_handle *handle,' + eol +
       b'            int flags)' + eol +
       b'' + eol +
       b'    Reference:' + eol +
       b'        https://man7.org/linux/man-pages/man2/open_by_handle_at.2.html' + eol +
       b'' + eol +
       b'    Description:' + eol +
       b'        What `open` does of a path, said by way of the' + eol +
       b'        handle the filesystem itself keeps -- the file on' + eol +
       b'        the mount `mount_fd` opens that the handle is the' + eol +
       b'        name of, said without a path at all. The saying' + eol +
       b'        back is the cap the kernel keeps for the privileged,' + eol +
       b'        and a caller without it is refused. The word is' + eol +
       b'        Linux\'s own, and Darwin has no call that takes it.' + eol +
       b'' + eol +
       b'    Args:' + eol +
       b'        mount_fd: Any file or directory on the mount the' + eol +
       b'            handle came from.' + eol +
       b'        handle: The handle the filesystem said.' + eol +
       b'        flags: The words the opening is said with.' + eol +
       b'' + eol +
       b'    Returns:' + eol +
       b'        A descriptor, or -1 on error with `errno` set.' + eol +
       b'    """' + eol +
       b'    return external_call[' + eol +
       b'        "open_by_handle_at", Int32, Int32, c_ptr[c_void], Int32' + eol +
       b'    ](mount_fd, handle, flags)' + eol)
s = tail + add
open(p, "wb").write(s)
print("2 bindings appended")

# test
p = "tests/test_fcntl.mojo"
s = open(p, "rb").read()
add = '''


def test_the_handle_the_filesystem_itself_keeps() raises:
    """`name_to_handle_at` and `open_by_handle_at` -- a
    handle said of a file, kept by the filesystem
    itself: not a saying the caller makes, but the
    filesystem's own name of the file, as long as the
    filesystem says. A room too small is refused with
    the size said where the answer will fit; the
    asking made again into a room the size the
    refusing said is answered; and the file said back
    by the handle alone is the cap the kernel keeps
    for the privileged, which a caller without is
    refused with `errno` saying so. Both are Linux's
    own words, and Darwin has no call that takes
    either.
    """
    comptime if not CompilationTarget.is_macos():
        # a room led by handle_bytes and handle_type, with the
        # handle after them: a room too small is refused with the
        # size said where the answer will fit
        var room = unsafe_alloc[UInt8](8 + 128)
        var handle_bytes = room.unsafe_bitcast[c_uint]()
        var mount_id = unsafe_alloc[Int32](1)
        mount_id.unsafe_offset(0)[] = 0
        handle_bytes.unsafe_offset(0)[] = 0
        set_errno(0)
        assert_equal(
            Int(
                name_to_handle_at(
                    Int32(AT_FDCWD),
                    string_to_char_ptr("/bin/sh").unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    mount_id,
                    Int32(0),
                )
            ),
            -1,
            "a room too small is refused",
        )
        assert_equal(Int(get_errno()), Int(EOVERFLOW), "with errno saying so")
        var wants = Int(handle_bytes.unsafe_offset(0)[])
        assert_true(wants > 0, "and the size said where the answer will fit")
        assert_true(Int(mount_id.unsafe_offset(0)[]) != 0, "the mount said even so")
        # the asking made again into a room the size said is answered
        handle_bytes.unsafe_offset(0)[] = UInt32(wants)
        set_errno(0)
        assert_equal(
            Int(
                name_to_handle_at(
                    Int32(AT_FDCWD),
                    string_to_char_ptr("/bin/sh").unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    mount_id,
                    Int32(0),
                )
            ),
            0,
            "the asking made again is answered",
        )
        assert_equal(Int(get_errno()), 0, "with no word of refusal")
        var kind = Int(room.unsafe_offset(4).unsafe_load[c_int]())
        assert_true(kind >= 0, "the filesystem says what kind it keeps")
        # the file said back by the handle alone: the cap the kernel
        # keeps for the privileged, and a caller without it is refused
        var root = open_with_mode(string_to_char_ptr("/").unsafe_bitcast[UInt8](), O_RDONLY | O_DIRECTORY)
        assert_true(root >= 0, "the mount said by any file on it")
        set_errno(0)
        var said_back = open_by_handle_at(
            root, room.unsafe_bitcast[c_void](), O_RDONLY
        )
        assert_equal(Int(said_back), -1, "the saying back is refused")
        assert_equal(Int(get_errno()), Int(EPERM), "with errno saying it is the cap kept for the privileged")
        _ = close(root)
        # a saying that is not there: refused with errno saying so
        handle_bytes.unsafe_offset(0)[] = UInt32(wants)
        set_errno(0)
        assert_equal(
            Int(
                name_to_handle_at(
                    Int32(AT_FDCWD),
                    string_to_char_ptr("/no/such/path/at/all").unsafe_bitcast[UInt8](),
                    room.unsafe_bitcast[c_void](),
                    mount_id,
                    Int32(0),
                )
            ),
            -1,
            "a saying that is not there is refused",
        )
        assert_equal(Int(get_errno()), Int(ENOENT), "with errno saying so")
        room.unsafe_free()
        mount_id.unsafe_free()
'''
blob = add.encode().replace(b"\n", eol)
i = s.find(b"def main() raises:")
assert i > 0
s = s[:i] + blob + eol + s[i:]
# imports: name_to_handle_at, open_by_handle_at from libc.fcntl; EOVERFLOW/ENOENT from constant
o = b"from libc.fcntl import (" + eol
assert o in s
# insert after the opening paren
i = s.find(o) + len(o)
s = s[:i] + b"    name_to_handle_at," + eol + b"    open_by_handle_at," + eol + s[i:]
# EOVERFLOW, ENOENT: check existing constant imports
o2 = b"from libc.constant import (" + eol
assert o2 in s
i2 = s.find(o2) + len(o2)
s = s[:i2] + b"    ENOENT," + eol + b"    EOVERFLOW," + eol + s[i2:]
# wire into main
o3 = b'    print("test_fcntl: ok")' + eol
if o3 not in s:
    o3 = o3.replace(b"\r\n", b"\n"); eol = b"\n"
assert o3 in s
s = s.replace(o3, b"    test_the_handle_the_filesystem_itself_keeps()" + eol + o3, 1)
open(p, "wb").write(s)
print("test added + wired")
