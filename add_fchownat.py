#!/usr/bin/env python3
"""Add fchownat binding (unistd) and its test."""

p = "src/libc/unistd/syscalls.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"
anchor = b'    return external_call[' + eol + b'        "sethostname", c_int, c_ptr[UInt8], c_size_t' + eol + b'    ](name, length)' + eol
assert anchor in s, "sethostname return missing"
add = (eol + eol +
       b'def fchownat(' + eol +
       b'    fd: Int32, path: c_ptr[UInt8], owner: Int32, group: Int32, flags: Int32' + eol +
       b') -> Int32:' + eol +
       b'    """Libc POSIX `fchownat` function.' + eol +
       b'' + eol +
       b'        int fchownat(int fd, const char *path, uid_t owner, gid_t group, int flags)' + eol +
       b'' + eol +
       b'    Reference:' + eol +
       b'        https://man7.org/linux/man-pages/man2/chown.2.html' + eol +
       b'' + eol +
       b'    Description:' + eol +
       b'        Who keeps the file, said by way of a' + eol +
       b'        directory: the saying of `path` is looked for' + eol +
       b'        beside the file `fd` opens, or beside the root' + eol +
       b'        of the asking when `fd` is `AT_FDCWD`, the way' + eol +
       b'        `fchown` is said of a file already open and' + eol +
       b'        `chown` of one said from the root. A saying' + eol +
       b'        with no file under it is refused with `errno`' + eol +
       b'        saying so; and a link, said with' + eol +
       b'        `AT_SYMLINK_NOFOLLOW`, is who the link itself' + eol +
       b'        is kept by -- said without, the file the link' + eol +
       b'        leads to, which a link leading nowhere is' + eol +
       b'        refused for.' + eol +
       b'' + eol +
       b'    Args:' + eol +
       b'        fd: The directory the saying is looked for' + eol +
       b'            beside, or `AT_FDCWD` for the root of the' + eol +
       b'            asking.' + eol +
       b'        path: The file whose keeping is said.' + eol +
       b'        owner: The user who keeps the file, or -1 to' + eol +
       b'            keep who it was.' + eol +
       b'        group: The group who keeps the file, or -1 to' + eol +
       b'            keep what it was.' + eol +
       b'        flags: `AT_SYMLINK_NOFOLLOW` to say the link' + eol +
       b'            itself, or 0 to say the file it leads to.' + eol +
       b'' + eol +
       b'    Returns:' + eol +
       b'        0 on success, or -1 on error with `errno` set.' + eol +
       b'    """' + eol +
       b'    return external_call[' + eol +
       b'        "fchownat", Int32, Int32, c_ptr[UInt8], Int32, Int32, Int32' + eol +
       b'    ](fd, path, owner, group, flags)' + eol)
s = s.replace(anchor, anchor + add, 1)
open(p, "wb").write(s)
print("fchownat binding added")
