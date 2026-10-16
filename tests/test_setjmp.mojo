"""Tests for `libc.setjmp`, which had no test at all.

`setjmp` records where execution is; `longjmp` jumps back to that
point and makes the `setjmp` look as though it had returned the
value the jump was given. The return value is the only handle on
the second trip: the first time around it is 0, the second time
it is what `longjmp` was asked to put there.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal

from libc.setjmp import longjmp, setjmp


def test_setjmp_comes_back_with_the_longjmp_value() raises:
    """The first time `setjmp` is asked, it returns 0, and the
    code that follows runs. From that code, `longjmp(env, val)`
    is given the same buffer and a value; control jumps back to
    the `setjmp` line, which returns the value as if the call
    had ended normally. The two returns are what make a non-local
    jump useful, and what `setjmp` is for.
    """
    # `jmp_buf` is 200 bytes on x86-64 glibc and a different size
    # elsewhere; 256 is enough everywhere libc runs.
    var env = unsafe_alloc[UInt8](256)
    var val: Int32 = setjmp(env)
    if val != 0:
        assert_equal(
            val,
            42,
            "the second time setjmp returns the value longjmp was given",
        )
        env.unsafe_free()
        return
    longjmp(env, 42)
    # longjmp does not return here, so a failure would land in the
    # branch above with the wrong value, not as a hang.


def main() raises:
    test_setjmp_comes_back_with_the_longjmp_value()
    print("test_setjmp: ok")
