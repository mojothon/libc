# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer


# The `prctl` options, all Linux's own — there is no <sys/prctl.h> on
# Darwin, so nothing there needs them. The values were read out of
# <sys/prctl.h>.
comptime PR_SET_PDEATHSIG: Int32 = 1
comptime PR_GET_PDEATHSIG: Int32 = 2
comptime PR_GET_DUMPABLE: Int32 = 3
comptime PR_SET_DUMPABLE: Int32 = 4
comptime PR_GET_UNALIGN: Int32 = 5
comptime PR_SET_UNALIGN: Int32 = 6
comptime PR_GET_TIMING: Int32 = 13
comptime PR_SET_TIMING: Int32 = 14
comptime PR_SET_NAME: Int32 = 15
comptime PR_GET_NAME: Int32 = 16
comptime PR_GET_SECCOMP: Int32 = 21
comptime PR_SET_SECCOMP: Int32 = 22
comptime PR_GET_TSC: Int32 = 25
comptime PR_SET_TSC: Int32 = 26
comptime PR_GET_SECUREBITS: Int32 = 27
comptime PR_SET_SECUREBITS: Int32 = 28
comptime PR_SET_TIMERSLACK: Int32 = 29
comptime PR_GET_TIMERSLACK: Int32 = 30


def prctl(
    option: Int32, arg2: UInt64, arg3: UInt64, arg4: UInt64, arg5: UInt64
) -> Int32:
    """C library <sys/prctl.h> function `prctl`.

    Reference:
        https://man7.org/linux/man-pages/man2/prctl.2.html

    Args:
        option: The operation, as a number.
        arg2: The first thing the operation asks for, or nothing at all:
            what it means is up to the one chosen.
        arg3: The second, or nothing at all.
        arg4: The third, or nothing at all.
        arg5: The fourth, or nothing at all. All four are `UInt64` because
            enough of the operations take a pointer, or a value that is
            one, that a narrower type would not hold them.

    Description:
        prctl() performs a privileged operation on the calling process.
        It is used to get and set various options controlling the behavior of the kernel.
        The operation is specified in the `option` argument, and additional arguments may be required depending on the operation.
        The `option` argument is a number, and no `PR_*` constant is bound
        here. On Linux `PR_SET_PDEATHSIG` is 1, `PR_GET_PDEATHSIG` 2,
        `PR_GET_DUMPABLE` 3, `PR_SET_DUMPABLE` 4, `PR_GET_UNALIGN` 5,
        `PR_SET_UNALIGN` 6, `PR_GET_TIMING` 13, `PR_SET_TIMING` 14,
        `PR_SET_NAME` 15, `PR_GET_NAME` 16, `PR_GET_SECCOMP` 21,
        `PR_SET_SECCOMP` 22, `PR_GET_TSC` 25, `PR_SET_TSC` 26,
        `PR_GET_SECUREBITS` 27, `PR_SET_SECUREBITS` 28, `PR_SET_TIMERSLACK`
        29 and `PR_GET_TIMERSLACK` 30, and there are more besides, so the
        header is the place to check.

        `prctl` is Linux's own: there is no `<sys/prctl.h>` on Darwin, and
        a call there does not link.

    Return Value:
        The return value of the function is 0 on success, or -1 on error.
    """

    return external_call["prctl", Int32, Int32, UInt64, UInt64, UInt64, UInt64](
        option, arg2, arg3, arg4, arg5
    )
