# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr

# The exception bits and the rounding modes are macros in C, so there is no
# call that would tell you what they are. They are not the same everywhere:
#
#   exceptions   x86-64, both platforms: the x87 status word, 1 4 8 10 20
#                arm64:                  the AArch64 FPSR,    1 2 4 8 10
#
#   rounding     x86-64, both platforms: the x87 control word, 0 400 800 c00
#                arm64, both platforms:  the FPCR mode bits, 0 400000 800000 c00000
#
# The arm64 ones were measured on Darwin rather than guessed: `fesetround`
# returns non-zero for 1, 2, 3, 400, 800 and c00 there, and 0 for 400000,
# 800000 and c00000, which is the FPCR bit for each mode.
comptime FE_INVALID: Int32 = 0x01
comptime FE_DIVBYZERO: Int32 = (
    Int32(0x04) if CompilationTarget.is_x86() else Int32(0x02)
)
comptime FE_OVERFLOW: Int32 = (
    Int32(0x08) if CompilationTarget.is_x86() else Int32(0x04)
)
comptime FE_UNDERFLOW: Int32 = (
    Int32(0x10) if CompilationTarget.is_x86() else Int32(0x08)
)
comptime FE_INEXACT: Int32 = (
    Int32(0x20) if CompilationTarget.is_x86() else Int32(0x10)
)
comptime FE_ALL_EXCEPT: Int32 = (
    FE_INVALID | FE_DIVBYZERO | FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT
)
comptime FE_TONEAREST: Int32 = 0
comptime FE_UPWARD: Int32 = (
    Int32(0x800) if CompilationTarget.is_x86() else Int32(0x400000)
)
comptime FE_DOWNWARD: Int32 = (
    Int32(0x400) if CompilationTarget.is_x86() else Int32(0x800000)
)
comptime FE_TOWARDZERO: Int32 = (
    Int32(0xC00) if CompilationTarget.is_x86() else Int32(0xC00000)
)


struct fenv_t:
    """A C `fenv_t`: the whole floating-point environment.

    glibc's is 32 bytes and Darwin's arm64 one is 16, so this holds 32 and the
    rest is padding: every call takes it by pointer and libc only ever writes
    into it. The members are not exposed on purpose — they are x87 state on
    x86-64 and a pair of AArch64 system registers elsewhere, and a binding
    cannot say which it is looking at.

    Not `FE_DFL_ENV`, which is `(const fenv_t *) -1` on glibc. What Darwin
    uses for it is not something I have been able to check, and a wrong guess
    here is undefined behaviour rather than an error, so nothing is exposed
    for it: take a copy with `fegetenv` at the start of your program and hand
    that to `fesetenv` when you want the default back.
    """

    var _opaque: Array[UInt8, 32]

    def __init__(out self):
        """Zeroes the object, which is what `memset` would leave behind."""
        self._opaque = Array[UInt8, 32](fill=0)


struct fexcept_t:
    """A C `fexcept_t`: which floating-point exceptions are raised.

    A 2-byte `unsigned short` on x86-64 and a 64-bit word on arm64, so this
    holds eight bytes and the callers pass it by pointer. Nothing reads its
    bytes; `fegetexceptflag` fills it and `fesetexceptflag` hands it back.
    """

    var _opaque: Array[UInt8, 8]

    def __init__(out self):
        """Zeroes the object."""
        self._opaque = Array[UInt8, 8](fill=0)


def feclearexcept(excepts: Int32) -> Int32:
    """Libc `feclearexcept`, which clears the given exception flags.

    Args:
        excepts: A bitwise OR of the `FE_*` exception macros, or
            `FE_ALL_EXCEPT`.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feclearexcept.3.html).
        Fn signature: `int feclearexcept(int excepts)`.
    """
    return external_call["feclearexcept", Int32, Int32](excepts)


def feraiseexcept(excepts: Int32) -> Int32:
    """Libc `feraiseexcept`, which raises the given exceptions.

    Args:
        excepts: A bitwise OR of the `FE_*` exception macros.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feraiseexcept.3.html).
        Fn signature: `int feraiseexcept(int excepts)`.
    """
    return external_call["feraiseexcept", Int32, Int32](excepts)


def fetestexcept(excepts: Int32) -> Int32:
    """Libc `fetestexcept`, which reports which of these flags are raised.

    Args:
        excepts: A bitwise OR of the `FE_*` exception macros to ask about.

    Returns:
        The subset of `excepts` that is currently raised, or 0 if none is.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fetestexcept.3.html).
        Fn signature: `int fetestexcept(int excepts)`.
    """
    return external_call["fetestexcept", Int32, Int32](excepts)


def fegetexceptflag(flagp: c_ptr[fexcept_t], excepts: Int32) -> Int32:
    """Libc `fegetexceptflag`, which saves the state of the given flags.

    Args:
        flagp: Where to store the flags, to hand to `fesetexceptflag` later.
        excepts: A bitwise OR of the `FE_*` exception macros to save.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fegetexceptflag.3.html).
        Fn signature: `int fegetexceptflag(fexcept_t *flagp, int excepts)`.
    """
    return external_call["fegetexceptflag", Int32, c_ptr[fexcept_t], Int32](
        flagp, excepts
    )


def fesetexceptflag(flagp: c_ptr[fexcept_t], excepts: Int32) -> Int32:
    """Libc `fesetexceptflag`, which restores flags `fegetexceptflag` saved.

    Args:
        flagp: Flags from an earlier `fegetexceptflag` call.
        excepts: A bitwise OR of the `FE_*` exception macros to restore.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fegetexceptflag.3.html).
        Fn signature: `int fesetexceptflag(const fexcept_t *flagp, int excepts)`.
    """
    return external_call["fesetexceptflag", Int32, c_ptr[fexcept_t], Int32](
        flagp, excepts
    )


def fegetround() -> Int32:
    """Libc `fegetround`, which reports the current rounding mode.

    Returns:
        One of `FE_TONEAREST`, `FE_UPWARD`, `FE_DOWNWARD`, `FE_TOWARDZERO`, or
        a negative value if the mode cannot be determined.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fegetround.3.html).
        Fn signature: `int fegetround(void)`.
    """
    return external_call["fegetround", Int32]()


def fesetround(round: Int32) -> Int32:
    """Libc `fesetround`, which sets the rounding mode.

    Args:
        round: One of `FE_TONEAREST`, `FE_UPWARD`, `FE_DOWNWARD`,
            `FE_TOWARDZERO`.

    Returns:
        0 if the mode was set, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fesetround.3.html).
        Fn signature: `int fesetround(int round)`.
    """
    return external_call["fesetround", Int32, Int32](round)


def fegetenv(envp: c_ptr[fenv_t]) -> Int32:
    """Libc `fegetenv`, which saves the whole floating-point environment.

    Args:
        envp: Where to store it, to hand to `fesetenv` or `feupdateenv` later.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fegetenv.3.html).
        Fn signature: `int fegetenv(fenv_t *envp)`.
    """
    return external_call["fegetenv", Int32, c_ptr[fenv_t]](envp)


def fesetenv(envp: c_ptr[fenv_t]) -> Int32:
    """Libc `fesetenv`, which restores an environment `fegetenv` saved.

    Args:
        envp: An environment from an earlier `fegetenv` or `feholdexcept`
            call.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fegetenv.3.html).
        Fn signature: `int fesetenv(const fenv_t *envp)`.

        C also lets this take `FE_DFL_ENV`. See `fenv_t` for why this package
        does not offer it.
    """
    return external_call["fesetenv", Int32, c_ptr[fenv_t]](envp)


def feholdexcept(envp: c_ptr[fenv_t]) -> Int32:
    """Libc `feholdexcept`, which saves the environment and clears the flags.

    Args:
        envp: Where to store the environment, for `feupdateenv` later.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feholdexcept.3.html).
        Fn signature: `int feholdexcept(fenv_t *envp)`.

        After it returns, exceptions are raised without trapping, so the
        caller can finish a computation and let `feupdateenv` report them.
    """
    return external_call["feholdexcept", Int32, c_ptr[fenv_t]](envp)


def feupdateenv(envp: c_ptr[fenv_t]) -> Int32:
    """Libc `feupdateenv`, which restores an environment and keeps the flags.

    Args:
        envp: An environment from an earlier `fegetenv` or `feholdexcept`
            call.

    Returns:
        0 on success, non-zero otherwise.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feupdateenv.3.html).
        Fn signature: `int feupdateenv(const fenv_t *envp)`.

        The flags raised since the matching `feholdexcept` are OR-ed into
        whatever the saved environment had, so none are lost.
    """
    return external_call["feupdateenv", Int32, c_ptr[fenv_t]](envp)


def feenableexcept(excepts: Int32) -> Int32:
    """Libc `feenableexcept`, which makes the given exceptions trap.

    Args:
        excepts: A bitwise OR of the `FE_*` exception macros.

    Returns:
        The set that was enabled before, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feenableexcept.3.html).
        Fn signature: `int feenableexcept(int excepts)`.

        A glibc extension, not standard C: Darwin has no such call, so
        importing it there will not link. Trapping means the process gets
        `SIGFPE`, which Mojo has no handler for.
    """
    return external_call["feenableexcept", Int32, Int32](excepts)


def fedisableexcept(excepts: Int32) -> Int32:
    """Libc `fedisableexcept`, which stops the given exceptions trapping.

    Args:
        excepts: A bitwise OR of the `FE_*` exception macros.

    Returns:
        The set that was enabled before, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feenableexcept.3.html).
        Fn signature: `int fedisableexcept(int excepts)`.

        A glibc extension; Darwin has no such call, so importing it there will
        not link.
    """
    return external_call["fedisableexcept", Int32, Int32](excepts)


def fegetexcept() -> Int32:
    """Libc `fegetexcept`, which reports which exceptions trap.

    Returns:
        The set of `FE_*` exceptions that are enabled to trap, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/feenableexcept.3.html).
        Fn signature: `int fegetexcept(void)`.

        A glibc extension; Darwin has no such call, so importing it there will
        not link.
    """
    return external_call["fegetexcept", Int32]()
