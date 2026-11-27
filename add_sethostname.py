#!/usr/bin/env python3
"""Add sethostname binding (unistd) and its test."""

p = "src/libc/unistd/syscalls.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"
anchor = b'    return external_call["chroot", Int32, c_ptr[UInt8]](path)' + eol
assert anchor in s, "chroot return missing"
add = (eol + eol +
       b'def sethostname(name: c_ptr[UInt8], length: c_size_t) -> c_int:' + eol +
       b'    """Libc POSIX `sethostname` function.' + eol +
       b'' + eol +
       b'        int sethostname(const char *name, size_t length)' + eol +
       b'' + eol +
       b'    Reference:' + eol +
       b'        https://man7.org/linux/man-pages/man2/sethostname.2.html' + eol +
       b'' + eol +
       b'    Description:' + eol +
       b'        Who the machine says it is, said again -- the' + eol +
       b'        name the asking of a host comes back with is' + eol +
       b'        what the saying makes it, for the length that' + eol +
       b'        goes with it. Who may say it is the kernel\'s' + eol +
       b'        own keeping; a caller without it is refused' + eol +
       b'        with `errno` saying so, and the name is what' + eol +
       b'        it was. Said back where it already is, the' + eol +
       b'        machine keeps its name.' + eol +
       b'' + eol +
       b'    Args:' + eol +
       b'        name: The name the machine is said as.' + eol +
       b'        length: How much of `name` is the name.' + eol +
       b'' + eol +
       b'    Returns:' + eol +
       b'        0 on success, or -1 on error with `errno` set.' + eol +
       b'    """' + eol +
       b'    return external_call[' + eol +
       b'        "sethostname", c_int, c_ptr[UInt8], c_size_t' + eol +
       b'    ](name, length)' + eol)
s = s.replace(anchor, anchor + add, 1)
open(p, "wb").write(s)
print("sethostname binding added")

# test
p = "tests/test_unistd.mojo"
s = open(p, "rb").read()
add = '''


def test_the_machine_said_its_name_again() raises:
    """`sethostname` -- who the machine says it is,
    said again: the name the asking of a host comes
    back with is what the saying makes it, for the
    length that goes with it. The name as it stands
    is asked for first, and said back where it
    already is -- which, where the asking may say it,
    the machine keeps, coming back having said the
    same; and where the asking may not, the refusal
    is what is said, the name being what it was
    either way, which the asking of it after
    proves.
    """
    var room = unsafe_alloc[c_char](256)
    assert_equal(
        Int(gethostname(room, c_size_t(256))),
        0,
        "who the machine says it is is asked for first",
    )
    var said = sethostname(room, c_size_t(256))
    if said == 0:
        # the machine keeps its name, having said the same
        var again = unsafe_alloc[c_char](256)
        assert_equal(Int(gethostname(again, c_size_t(256))), 0, "the asking comes back")
        assert_equal(
            Int(strcmp(again, room)),
            0,
            "with the name the saying left, which is the one it had",
        )
    else:
        assert_equal(Int(get_errno()), Int(EPERM), "the saying is the kernel's own keeping")
        var again = unsafe_alloc[c_char](256)
        assert_equal(Int(gethostname(again, c_size_t(256))), 0, "the asking comes back after")
        assert_equal(
            Int(strcmp(again, room)),
            0,
            "and the name is what it was",
        )
'''
blob = add.encode().replace(b"\n", eol)
i = s.find(b"def main() raises:")
assert i > 0
s = s[:i] + blob + eol + s[i:]
# imports: sethostname from unistd; strcmp, gethostname check
o = b"    chroot," + eol
if o not in s:
    o = o.replace(b"\r\n", b"\n"); eol = b"\n"
assert o in s
s = s.replace(o, o + b"    sethostname," + eol, 1)
# strcmp from libc.string? check existing import
o2 = b"from libc.string import strcmp" + eol
if o2 not in s:
    i2 = s.find(b"from libc.string import")
    assert i2 > 0, "no libc.string import"
    s = s[:i2] + b"from libc.string import strcmp" + eol + s[i2:]
o3 = b"    test_the_root_said_again()" + eol
if o3 not in s:
    o3 = o3.replace(b"\r\n", b"\n"); eol = b"\n"
assert o3 in s
s = s.replace(o3, o3 + b"    test_the_machine_said_its_name_again()" + eol, 1)
open(p, "wb").write(s)
print("test added + wired")
