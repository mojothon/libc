#!/usr/bin/env python3
"""Add sigset test to test_signal.mojo. Run once; verifies every anchor."""

import sys

p = "tests/test_signal.mojo"
s = open(p, "rb").read()
eol = b"\r\n" if s.count(b"\r\n") > 50 else b"\n"

if b"test_the_saying_comes_back_as_the_answer" in s:
    print("already inserted")
    sys.exit(0)

# 1) import
o = b"    sigignore," + eol
if o not in s:
    o = o.replace(b"\r\n", b"\n"); eol = b"\n"
assert o in s, "sigignore import missing"
s = s.replace(o, o + b"    sigset," + eol, 1)

# 2) test
add = '''


def test_the_saying_comes_back_as_the_answer() raises:
    """`sigset` -- what standing before the saying
    was, comes back as the answer: the action said
    for a signal is what the saying makes it, and
    the answer is the action that was there. Said
    with the ignoring, the answer is how the signal
    stood before, which is as the default; said
    again, the answer is what the last saying left,
    which is the ignoring; and said back to the
    default, the answer is what the saying between
    them made. A signal no kernel knows is refused
    with `errno` saying so. The word is System V's
    own, and Darwin has no call that says it.
    """
    comptime if not CompilationTarget.is_macos():
        # said with the ignoring: the answer is how it stood
        var was = sigset(Int32(SIGUSR1), c_ptr[UInt8](1))
        assert_equal(Int(was), 0, "the signal stood as the default before")
        # said again: the answer is what the last saying left
        var again = sigset(Int32(SIGUSR1), c_ptr[UInt8](1))
        assert_equal(Int(again), 1, "what the last saying left is the ignoring")
        # said back to the default: the answer is the ignoring
        var back = sigset(Int32(SIGUSR1), c_ptr[UInt8](0))
        assert_equal(Int(back), 1, "said back, the answer is what the saying made")
        # a signal no kernel knows
        set_errno(0)
        assert_equal(
            Int(sigset(Int32(9999), c_ptr[UInt8](1))),
            -1,
            "a signal no kernel knows is refused",
        )
        assert_equal(Int(get_errno()), Int(EINVAL), "with errno saying so")
'''
blob = add.encode().replace(b"\n", eol)
i = s.find(b"def main() raises:")
assert i > 0, "main missing"
s = s[:i] + blob + eol + s[i:]

# 3) wire
o3 = b'    print("test_signal: ok")' + eol
if o3 not in s:
    o3 = o3.replace(b"\r\n", b"\n"); eol = b"\n"
assert o3 in s, "wire anchor missing"
s = s.replace(o3, b"    test_the_saying_comes_back_as_the_answer()" + eol + o3, 1)

open(p, "wb").write(s)
print("test inserted + wired")
