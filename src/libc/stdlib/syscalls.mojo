# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <stdlib.h>.
#
# Memory allocation, environment access, number conversion and process
# control. `qsort`/`bsearch` are left out because they take a C
# comparison callback, which has no safe equivalent in Mojo yet.
# ----------------------------------
from std.ffi import external_call
from std.memory import unsafe_stack_allocation

from libc.limits import LONG_MAX, LONG_MIN, PATH_MAX, ULLONG_MAX, ULONG_MAX
from libc.locale import locale_t

from libc.constant import (
    c_char,
    c_double,
    c_float,
    c_int,
    c_long,
    c_longlong,
    c_ptr,
    c_size_t,
    c_uint,
    c_ulong,
    c_ulonglong,
    c_ushort,
    c_void,
    c_wchar,
)

# `rand`'s ceiling, and the widest values the `strto*` family saturate at.
# `long` is 64 bits on both platforms, so these agree. The two `HUGE_*` are
# infinity, written as a literal past what a float can hold, which is the
# nearest Mojo has to a spelling for one.
comptime RAND_MAX: Int32 = 2147483647
comptime HUGE_VAL: Float64 = Float64(1e400)
comptime HUGE_VALF: Float32 = Float32(1e400)

# `LONG_MAX`, `LONG_MIN`, `ULONG_MAX`, `ULLONG_MAX` and `PATH_MAX` are
# imported from `libc.limits`, which is the module for `<limits.h>`. They
# are still exported from here, because this module's own docstrings are
# where a caller meets them: `strtol` overflows into `LONG_MAX`, `realpath`
# fills a `PATH_MAX` buffer. One copy, in the module whose header has them.


# -------------------------------------------------------
#  整数的绝对值与除法
# -------------------------------------------------------
def abs(j: c_int) -> c_int:
    """The absolute value of an `int`.

    What C calls `abs`, and what the language calls `abs` only for
    floating point: this is the whole-number one, and it is declared in
    `<stdlib.h>` rather than `<math.h>`, which is where `fabs` lives.

    Args:
        j: The number.

    Returns:
        `j` without its sign. `abs(INT_MIN)` has no answer -- the
        positive counterpart of the lowest `int` is not an `int` -- and
        C leaves it undefined; both platforms hand back `INT_MIN`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/abs.3.html).
        Fn signature: `int abs(int j)`.
    """
    return external_call["abs", c_int, c_int](j)


def labs(j: c_long) -> c_long:
    """The absolute value of a `long`.

    `abs` one width up. A `long` is eight bytes on both platforms, so
    this and `llabs` answer the same range.

    Args:
        j: The number.

    Returns:
        `j` without its sign, and `LONG_MIN` back as it came, for the
        reason `abs` gives.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/abs.3.html).
        Fn signature: `long labs(long j)`.
    """
    return external_call["labs", c_long, c_long](j)


struct div_t(TrivialRegisterPassable):
    """The quotient and the remainder of one `int` divided by another.

    Two `int`s, and nothing else: eight bytes, on both platforms.
    """

    var quot: Int32
    var rem: Int32


struct ldiv_t(TrivialRegisterPassable):
    """The quotient and the remainder of one `long` divided by another.

    A `long` is eight bytes on both platforms, so this is sixteen.
    """

    var quot: c_long
    var rem: c_long


struct lldiv_t(TrivialRegisterPassable):
    """The quotient and the remainder of one `long long` divided by
    another.

    Sixteen bytes, on both platforms.
    """

    var quot: c_longlong
    var rem: c_longlong


# -------------------------------------------------------
#  memory allocation
# -------------------------------------------------------
def malloc(size: c_size_t) -> c_ptr[c_void]:
    """C library <stdlib.h> function `malloc`.

    Reference:
        https://man7.org/linux/man-pages/man3/malloc.3.html

    Prototype:
        void *malloc(size_t size)

    Description:
        Allocates `size` bytes of uninitialized memory.

    Args:
        size: Number of bytes to allocate.

    Returns:
        A pointer to the allocated memory, or null when the allocation
        fails. Free it with `free`.
    """

    return external_call["malloc", c_ptr[c_void], c_size_t](size)


def calloc(nmemb: c_size_t, size: c_size_t) -> c_ptr[c_void]:
    """C library <stdlib.h> function `calloc`.

    Reference:
        https://man7.org/linux/man-pages/man3/calloc.3.html

    Prototype:
        void *calloc(size_t nmemb, size_t size)

    Description:
        Allocates memory for an array of `nmemb` elements of `size` bytes
        each and zero-fills it.

    Args:
        nmemb: Number of elements.
        size: Size of one element, in bytes.

    Returns:
        A pointer to the zeroed memory, or null when the allocation
        fails. Free it with `free`.
    """

    return external_call["calloc", c_ptr[c_void], c_size_t, c_size_t](
        nmemb, size
    )


def realloc(ptr: c_ptr[c_void], size: c_size_t) -> c_ptr[c_void]:
    """C library <stdlib.h> function `realloc`.

    Reference:
        https://man7.org/linux/man-pages/man3/realloc.3.html

    Prototype:
        void *realloc(void *ptr, size_t size)

    Description:
        Resizes the block at `ptr` to `size` bytes, preserving the
        contents up to the smaller of the old and new sizes.

    Args:
        ptr: The block to resize. A null pointer makes this behave like
            `malloc`.
        size: The new size, in bytes. Zero makes this behave like `free`.

    Returns:
        A pointer to the resized block, which may differ from `ptr`, or
        null when the allocation fails.
    """

    return external_call["realloc", c_ptr[c_void], c_ptr[c_void], c_size_t](
        ptr, size
    )


def free(ptr: c_ptr[c_void]) -> c_void:
    """C library <stdlib.h> function `free`.

    Reference:
        https://man7.org/linux/man-pages/man3/free.3.html

    Prototype:
        void free(void *ptr)

    Description:
        Releases a block previously returned by `malloc`, `calloc`,
        `realloc` or `aligned_alloc`.

    Args:
        ptr: The block to release. A null pointer is a no-op.
    """

    return external_call["free", c_void, c_ptr[c_void]](ptr)


def aligned_alloc(alignment: c_size_t, size: c_size_t) -> c_ptr[c_void]:
    """C library <stdlib.h> function `aligned_alloc`.

    Reference:
        https://man7.org/linux/man-pages/man3/aligned_alloc.3.html

    Prototype:
        void *aligned_alloc(size_t alignment, size_t size)

    Description:
        Allocates `size` bytes at an address that is a multiple of
        `alignment`.

    Args:
        alignment: A power of two; on glibc it must also be a multiple of
            `sizeof(void *)`.
        size: Number of bytes; on glibc it should be a multiple of
            `alignment`.

    Returns:
        A pointer to the aligned memory, or null on failure. Free it with
        `free`.
    """

    return external_call["aligned_alloc", c_ptr[c_void], c_size_t, c_size_t](
        alignment, size
    )


def posix_memalign(
    memptr: c_ptr[c_ptr[c_void]], alignment: c_size_t, size: c_size_t
) -> c_int:
    """C library <stdlib.h> function `posix_memalign`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_memalign.3.html

    Prototype:
        int posix_memalign(void **memptr, size_t alignment, size_t size)

    Description:
        Allocates `size` bytes aligned to `alignment` and stores the
        address through `memptr`.

    Args:
        memptr: Where to store the allocated address.
        alignment: A power of two, and a multiple of `sizeof(void *)`.
        size: Number of bytes to allocate.

    Returns:
        0 on success, otherwise an error number (not -1, and `errno` is
        left unspecified).
    """

    return external_call[
        "posix_memalign", c_int, c_ptr[c_ptr[c_void]], c_size_t, c_size_t
    ](memptr, alignment, size)


# -------------------------------------------------------
#  process control
# -------------------------------------------------------
def exit(status: c_int) -> c_void:
    """C library <stdlib.h> function `exit`.

    Reference:
        https://man7.org/linux/man-pages/man3/exit.3.html

    Prototype:
        void exit(int status)

    Description:
        Terminates the process after flushing stdio streams and running
        the functions registered with `atexit`.

    Args:
        status: The exit status, conventionally 0 for success.
    """

    _ = external_call["exit", c_void, c_int](status)
    return 0


def _Exit(status: c_int) -> c_void:
    """C library <stdlib.h> function `_Exit`.

    Reference:
        https://man7.org/linux/man-pages/man3/exit.3.html

    Prototype:
        void _Exit(int status)

    Description:
        Terminates the process immediately, without flushing stdio or
        running `atexit` handlers.

    Args:
        status: The exit status.
    """

    _ = external_call["_Exit", c_void, c_int](status)
    return 0


def abort() -> c_void:
    """C library <stdlib.h> function `abort`.

    Reference:
        https://man7.org/linux/man-pages/man3/abort.3.html

    Prototype:
        void abort(void)

    Description:
        Terminates the calling process abnormally, without running
        atexit handlers or returning to the caller. C's `abort`
        raises `SIGABRT`; what is seen from a Mojo process is the
        run time ending the child with a different signal, which
        `test_abort_ends_the_child_and_not_us` checks by waiting
        and reading the status word rather than by guessing at
        the name.
    """

    _ = external_call["abort", c_void]()
    return 0


def system(command: c_ptr[c_char]) -> c_int:
    """C library <stdlib.h> function `system`.

    Reference:
        https://man7.org/linux/man-pages/man3/system.3.html

    Prototype:
        int system(const char *command)

    Description:
        Runs `command` with `/bin/sh -c`.

    Args:
        command: The shell command line.

    Returns:
        The wait status of the child, or -1 when the shell could not be
        started.
    """

    return external_call["system", c_int, c_ptr[c_char]](command)


# -------------------------------------------------------
#  environment
# -------------------------------------------------------
def getenv(name: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdlib.h> function `getenv`.

    Reference:
        https://man7.org/linux/man-pages/man3/getenv.3.html

    Prototype:
        char *getenv(const char *name)

    Description:
        Looks up the environment variable `name`.

    Args:
        name: The variable name, without a `=`.

    Returns:
        The value, or null when the variable is unset. Do not free or
        modify it.
    """

    return external_call["getenv", c_ptr[c_char], c_ptr[c_char]](name)


def secure_getenv(name: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdlib.h> function `secure_getenv`.

    Reference:
        https://man7.org/linux/man-pages/man3/getenv.3.html

    Prototype:
        char *secure_getenv(const char *name)

    Description:
        Like `getenv`, but returns null when the process is running with
        elevated privileges (glibc extension).

    Args:
        name: The variable name.

    Returns:
        The value, or null when unset or when privileges are elevated.
    """

    return external_call["secure_getenv", c_ptr[c_char], c_ptr[c_char]](name)


def setenv(
    name: c_ptr[c_char], value: c_ptr[c_char], overwrite: c_int
) -> c_int:
    """C library <stdlib.h> function `setenv`.

    Reference:
        https://man7.org/linux/man-pages/man3/setenv.3.html

    Prototype:
        int setenv(const char *name, const char *value, int overwrite)

    Description:
        Sets the environment variable `name` to `value`.

    Args:
        name: The variable name; must not contain `=`.
        value: The new value.
        overwrite: When 0 an existing value is left alone.

    Returns:
        0 on success, -1 on failure with `errno` set.
    """

    return external_call["setenv", c_int, c_ptr[c_char], c_ptr[c_char], c_int](
        name, value, overwrite
    )


def unsetenv(name: c_ptr[c_char]) -> c_int:
    """C library <stdlib.h> function `unsetenv`.

    Reference:
        https://man7.org/linux/man-pages/man3/unsetenv.3.html

    Prototype:
        int unsetenv(const char *name)

    Description:
        Removes the environment variable `name`.

    Args:
        name: The variable name.

    Returns:
        0 on success, -1 on failure with `errno` set.
    """

    return external_call["unsetenv", c_int, c_ptr[c_char]](name)


def putenv(string: c_ptr[c_char]) -> c_int:
    """C library <stdlib.h> function `putenv`.

    Reference:
        https://man7.org/linux/man-pages/man3/putenv.3.html

    Prototype:
        int putenv(char *string)

    Description:
        Adds or changes an environment variable using a `name=value`
        string. Unlike `setenv`, the string becomes part of the
        environment, so it must not be freed or modified afterwards.

    Args:
        string: A `name=value` string.

    Returns:
        0 on success, non-zero on failure.
    """

    return external_call["putenv", c_int, c_ptr[c_char]](string)


# -------------------------------------------------------
#  number conversion
# -------------------------------------------------------
def atoi(nptr: c_ptr[c_char]) -> c_int:
    """C library <stdlib.h> function `atoi`.

    Reference:
        https://man7.org/linux/man-pages/man3/atoi.3.html

    Prototype:
        int atoi(const char *nptr)

    Description:
        Converts the leading decimal integer of `nptr` to an `int`. No
        error is reported; prefer `strtol` when the input may be invalid.

    Args:
        nptr: The string to convert.

    Returns:
        The converted value, or 0 when no conversion was possible.
    """

    return external_call["atoi", c_int, c_ptr[c_char]](nptr)


def atol(nptr: c_ptr[c_char]) -> c_long:
    """C library <stdlib.h> function `atol`.

    Reference:
        https://man7.org/linux/man-pages/man3/atoi.3.html

    Prototype:
        long atol(const char *nptr)

    Description:
        Converts the leading decimal integer of `nptr` to a `long`.

    Args:
        nptr: The string to convert.

    Returns:
        The converted value, or 0 when no conversion was possible.
    """

    return external_call["atol", c_long, c_ptr[c_char]](nptr)


def atoll(nptr: c_ptr[c_char]) -> c_longlong:
    """C library <stdlib.h> function `atoll`.

    Reference:
        https://man7.org/linux/man-pages/man3/atoi.3.html

    Prototype:
        long long atoll(const char *nptr)

    Description:
        Converts the leading decimal integer of `nptr` to a `long long`.

    Args:
        nptr: The string to convert.

    Returns:
        The converted value, or 0 when no conversion was possible.
    """

    return external_call["atoll", c_longlong, c_ptr[c_char]](nptr)


def atof(nptr: c_ptr[c_char]) -> c_double:
    """C library <stdlib.h> function `atof`.

    Reference:
        https://man7.org/linux/man-pages/man3/atof.3.html

    Prototype:
        double atof(const char *nptr)

    Description:
        Converts the leading floating-point number of `nptr` to a
        `double`.

    Args:
        nptr: The string to convert.

    Returns:
        The converted value, or 0.0 when no conversion was possible.
    """

    return external_call["atof", c_double, c_ptr[c_char]](nptr)


def strtol(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], base: c_int
) -> c_long:
    """C library <stdlib.h> function `strtol`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        long strtol(const char *nptr, char **endptr, int base)

    Description:
        Converts the leading integer of `nptr` in the given base.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value. On overflow `LONG_MAX` or `LONG_MIN` is
        returned and `errno` is set to `ERANGE`.
    """

    return external_call[
        "strtol", c_long, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int
    ](nptr, endptr, base)


def strtoul(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], base: c_int
) -> c_ulong:
    """C library <stdlib.h> function `strtoul`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        unsigned long strtoul(const char *nptr, char **endptr, int base)

    Description:
        Converts the leading unsigned integer of `nptr` in the given
        base.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value; `ULONG_MAX` with `errno` set to `ERANGE` on
        overflow.
    """

    return external_call[
        "strtoul", c_ulong, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int
    ](nptr, endptr, base)


def strtoll(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], base: c_int
) -> c_longlong:
    """C library <stdlib.h> function `strtoll`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        long long strtoll(const char *nptr, char **endptr, int base)

    Description:
        Converts the leading integer of `nptr` to a `long long`.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value; clamped with `errno` set to `ERANGE` on
        overflow.
    """

    return external_call[
        "strtoll", c_longlong, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int
    ](nptr, endptr, base)


def strtoull(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], base: c_int
) -> c_ulonglong:
    """C library <stdlib.h> function `strtoull`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        unsigned long long strtoull(const char *nptr, char **endptr, int base)

    Description:
        Converts the leading unsigned integer of `nptr` to an
        `unsigned long long`.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value; `ULLONG_MAX` with `errno` set to `ERANGE` on
        overflow.
    """

    return external_call[
        "strtoull", c_ulonglong, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int
    ](nptr, endptr, base)


def strtod(nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]]) -> c_double:
    """C library <stdlib.h> function `strtod`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtod.3.html

    Prototype:
        double strtod(const char *nptr, char **endptr)

    Description:
        Converts the leading floating-point number of `nptr`.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.

    Returns:
        The converted value; `HUGE_VAL` with `errno` set to `ERANGE` on
        overflow.
    """

    return external_call[
        "strtod", c_double, c_ptr[c_char], c_ptr[c_ptr[c_char]]
    ](nptr, endptr)


def strtof(nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]]) -> c_float:
    """C library <stdlib.h> function `strtof`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtod.3.html

    Prototype:
        float strtof(const char *nptr, char **endptr)

    Description:
        Converts the leading floating-point number of `nptr` to a
        `float`.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.

    Returns:
        The converted value; `HUGE_VALF` with `errno` set to `ERANGE` on
        overflow.
    """

    return external_call[
        "strtof", c_float, c_ptr[c_char], c_ptr[c_ptr[c_char]]
    ](nptr, endptr)


def strtol_l(
    nptr: c_ptr[c_char],
    endptr: c_ptr[c_ptr[c_char]],
    base: c_int,
    loc: locale_t,
) -> c_long:
    """C library <stdlib.h> function `strtol_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        long strtol_l(const char *nptr, char **endptr, int base, locale_t loc)

    Description:
        Converts the leading integer of `nptr` in the given base, for a
        locale handed in rather than the one the thread is in.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.
        loc: The locale to read it in, as `newlocale` hands one out.

    Returns:
        The converted value. On overflow `LONG_MAX` or `LONG_MIN` is
        returned and `errno` is set to `ERANGE`.
    """

    return external_call[
        "strtol_l", c_long, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int, locale_t
    ](nptr, endptr, base, loc)


def strtoul_l(
    nptr: c_ptr[c_char],
    endptr: c_ptr[c_ptr[c_char]],
    base: c_int,
    loc: locale_t,
) -> c_ulong:
    """C library <stdlib.h> function `strtoul_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtoul.3.html

    Prototype:
        unsigned long strtoul_l(const char *nptr, char **endptr, int base,
            locale_t loc)

    Description:
        Converts the leading unsigned integer of `nptr` in the given
        base, for a locale handed in rather than the one the thread is
        in.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.
        loc: The locale to read it in, as `newlocale` hands one out.

    Returns:
        The converted value. On overflow `ULONG_MAX` is returned and
        `errno` is set to `ERANGE`.
    """

    return external_call[
        "strtoul_l",
        c_ulong,
        c_ptr[c_char],
        c_ptr[c_ptr[c_char]],
        c_int,
        locale_t,
    ](nptr, endptr, base, loc)


def strtoll_l(
    nptr: c_ptr[c_char],
    endptr: c_ptr[c_ptr[c_char]],
    base: c_int,
    loc: locale_t,
) -> c_longlong:
    """C library <stdlib.h> function `strtoll_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtoll.3.html

    Prototype:
        long long strtoll_l(const char *nptr, char **endptr, int base,
            locale_t loc)

    Description:
        Converts the leading long long integer of `nptr` in the given
        base, for a locale handed in rather than the one the thread is
        in.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.
        loc: The locale to read it in, as `newlocale` hands one out.

    Returns:
        The converted value. On overflow `LLONG_MAX` or `LLONG_MIN` is
        returned and `errno` is set to `ERANGE`.
    """

    return external_call[
        "strtoll_l",
        c_longlong,
        c_ptr[c_char],
        c_ptr[c_ptr[c_char]],
        c_int,
        locale_t,
    ](nptr, endptr, base, loc)


def strtoull_l(
    nptr: c_ptr[c_char],
    endptr: c_ptr[c_ptr[c_char]],
    base: c_int,
    loc: locale_t,
) -> c_ulonglong:
    """C library <stdlib.h> function `strtoull_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtoull.3.html

    Prototype:
        unsigned long long strtoull_l(const char *nptr, char **endptr,
            int base, locale_t loc)

    Description:
        Converts the leading unsigned long long integer of `nptr` in
        the given base, for a locale handed in rather than the one the
        thread is in.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        base: 0 for autodetection, or 2 through 36.
        loc: The locale to read it in, as `newlocale` hands one out.

    Returns:
        The converted value. On overflow `ULLONG_MAX` is returned and
        `errno` is set to `ERANGE`.
    """

    return external_call[
        "strtoull_l",
        c_ulonglong,
        c_ptr[c_char],
        c_ptr[c_ptr[c_char]],
        c_int,
        locale_t,
    ](nptr, endptr, base, loc)


def strtod_l(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], loc: locale_t
) -> c_double:
    """C library <stdlib.h> function `strtod_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtod.3.html

    Prototype:
        double strtod_l(const char *nptr, char **endptr, locale_t loc)

    Description:
        Converts the leading floating-point number of `nptr` to a
        `double`, for a locale handed in rather than the one the thread
        is in.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        loc: The locale to read it in, as `newlocale` hands one out.

    Returns:
        The converted value; `HUGE_VAL` with `errno` set to `ERANGE` on
        overflow.

    Notes:
        The decimal point is the locale's to say, and this is the one
        part of the reading the locale decides: in a locale that puts a
        comma there, `3.5` stops at the dot and reads as 3.
    """

    return external_call[
        "strtod_l", c_double, c_ptr[c_char], c_ptr[c_ptr[c_char]], locale_t
    ](nptr, endptr, loc)


def strtof_l(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], loc: locale_t
) -> c_float:
    """C library <stdlib.h> function `strtof_l`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtod.3.html

    Prototype:
        float strtof_l(const char *nptr, char **endptr, locale_t loc)

    Description:
        Converts the leading floating-point number of `nptr` to a
        `float`, for a locale handed in rather than the one the thread
        is in.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted character.
        loc: The locale to read it in, as `newlocale` hands one out.

    Returns:
        The converted value; `HUGE_VALF` with `errno` set to `ERANGE` on
        overflow.
    """

    return external_call[
        "strtof_l", c_float, c_ptr[c_char], c_ptr[c_ptr[c_char]], locale_t
    ](nptr, endptr, loc)


def strtol(nptr: c_ptr[c_char], base: c_int) -> c_long:
    """Overload of `strtol` for callers that do not need `endptr`.

    Args:
        nptr: The string to convert.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value.
    """

    var end = unsafe_stack_allocation[1, c_ptr[c_char]]()
    return strtol(nptr, end, base)


def strtod(nptr: c_ptr[c_char]) -> c_double:
    """Overload of `strtod` for callers that do not need `endptr`.

    Args:
        nptr: The string to convert.

    Returns:
        The converted value.
    """

    var end = unsafe_stack_allocation[1, c_ptr[c_char]]()
    return strtod(nptr, end)


# -------------------------------------------------------
#  pseudo-random numbers
# -------------------------------------------------------
def rand() -> c_int:
    """C library <stdlib.h> function `rand`.

    Reference:
        https://man7.org/linux/man-pages/man3/rand.3.html

    Prototype:
        int rand(void)

    Description:
        Returns the next number of the process-wide pseudo-random
        sequence, in the range 0 to `RAND_MAX`.

    Returns:
        A pseudo-random non-negative `int`.
    """

    return external_call["rand", c_int]()


def srand(seed: c_uint) -> c_void:
    """C library <stdlib.h> function `srand`.

    Reference:
        https://man7.org/linux/man-pages/man3/rand.3.html

    Prototype:
        void srand(unsigned int seed)

    Description:
        Seeds the sequence returned by `rand`.

    Args:
        seed: The seed value.
    """

    return external_call["srand", c_void, c_uint](seed)


def rand_r(seedp: c_ptr[c_uint]) -> c_int:
    """C library <stdlib.h> function `rand_r`.

    Reference:
        https://man7.org/linux/man-pages/man3/rand.3.html

    Prototype:
        int rand_r(unsigned int *seedp)

    Description:
        Like `rand`, but reentrant: the state lives in the caller's
        variable.

    Args:
        seedp: The seed, updated in place on each call.

    Returns:
        A pseudo-random non-negative `int`.
    """

    return external_call["rand_r", c_int, c_ptr[c_uint]](seedp)


# -------------------------------------------------------
#  temporary files
# -------------------------------------------------------
def mkstemps(template: c_ptr[c_char], suffixlen: c_int) -> c_int:
    """C library <stdlib.h> function `mkstemps`.

    Reference:
        https://man7.org/linux/man-pages/man3/mkstemp.3.html

    Prototype:
        int mkstemps(char *template, int suffixlen)

    Description:
        `mkstemp` told that the last `suffixlen` bytes of `template`
        are a suffix and not part of the name to make up: those are
        left as they are, and the six `X`s that get replaced are the
        six before them rather than the six at the end.

    Args:
        template: A mutable string of at least six `X`s followed by
            `suffixlen` bytes of suffix; modified in place.
        suffixlen: How many bytes at the end to leave alone.

    Returns:
        The open file descriptor, or -1 on failure with `errno` set.

    Notes:
        What the six `X`s are replaced with is what makes the name
        unique, so a count that leaves fewer than six of them, or
        that leaves six somewhere other than just before the suffix,
        is refused rather than made unique some other way.

        The suffix is how a program says which kind of file it wants
        and still gets a name nobody else has: `mkstemp` cannot, the
        `X`s having to be at the very end.
    """

    return external_call["mkstemps", c_int, c_ptr[c_char], c_int](
        template, suffixlen
    )


def mkstemp(template: c_ptr[c_char]) -> c_int:
    """C library <stdlib.h> function `mkstemp`.

    Reference:
        https://man7.org/linux/man-pages/man3/mkstemp.3.html

    Prototype:
        int mkstemp(char *template)

    Description:
        Replaces the last six characters of `template`, which must be
        `XXXXXX`, to form a unique file name, then creates and opens it.

    Args:
        template: A mutable string ending in `XXXXXX`; modified in place.

    Returns:
        The open file descriptor, or -1 on failure with `errno` set.
    """

    return external_call["mkstemp", c_int, c_ptr[c_char]](template)


def mkdtemp(template: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdlib.h> function `mkdtemp`.

    Reference:
        https://man7.org/linux/man-pages/man3/mkdtemp.3.html

    Prototype:
        char *mkdtemp(char *template)

    Description:
        Creates a unique directory from `template`, whose last six
        characters must be `XXXXXX`.

    Args:
        template: A mutable string ending in `XXXXXX`; modified in place.

    Returns:
        `template` on success, or null on failure with `errno` set.
    """

    return external_call["mkdtemp", c_ptr[c_char], c_ptr[c_char]](template)


def realpath(
    path: c_ptr[c_char], resolved_path: c_ptr[c_char]
) -> c_ptr[c_char]:
    """C library <stdlib.h> function `realpath`.

    Reference:
        https://man7.org/linux/man-pages/man3/realpath.3.html

    Prototype:
        char *realpath(const char *path, char *resolved_path)

    Description:
        Resolves every symlink and `.`/`..` component in `path`.

    Args:
        path: The path to resolve.
        resolved_path: A buffer of at least `PATH_MAX` bytes, or null to
            have libc allocate one.

    Returns:
        The canonicalized absolute path, or null on failure with `errno`
        set.
    """

    return external_call[
        "realpath", c_ptr[c_char], c_ptr[c_char], c_ptr[c_char]
    ](path, resolved_path)


def srandom(seed: UInt32):
    """C library <stdlib.h> function `srandom`.

    Reference:
        https://man7.org/linux/man-pages/man3/srandom.3.html

    Prototype:
        void srandom(unsigned int seed)

    Description:
        Sets the seed that `random` draws from, so that the same seed gives
        the same run of numbers again.

    Args:
        seed: The seed to start from.

    Notes:
        There is no result: C declares this one `void`. This is the seed
        for `random` and not for `rand`, which `srand` sets.
    """
    external_call["srandom", NoneType, UInt32](seed)


def random() -> Int64:
    """C library <stdlib.h> function `random`.

    Reference:
        https://man7.org/linux/man-pages/man3/random.3.html

    Prototype:
        long random(void)

    Description:
        Returns the next number from a generator with a long period.

    Returns:
        A number from 0 to `RAND_MAX`, which is 2**31 - 1 on both glibc and
        Darwin.

    Notes:
        Not the same generator as `rand`, and a better one: `srandom` is
        what sets its seed, not `srand`. Which numbers a seed gives is up
        to the C library, so the same seed does not give the same run on
        both platforms — only the same run twice on one of them.
    """
    return external_call["random", Int64]()


def initstate(seed: UInt32, state: c_ptr[c_char], n: UInt64) -> c_ptr[c_char]:
    """C library <stdlib.h> function `initstate`.

    Reference:
        https://man7.org/linux/man-pages/man3/initstate.3.html

    Prototype:
        char *initstate(unsigned int seed, char *state, size_t n)

    Description:
        Starts a generator of its own in a buffer of your choosing.

    Args:
        seed: The seed to start from.
        state: A buffer for the generator to keep its state in, which has
            to stay alive for as long as the generator is in use.
        n: How many bytes the buffer is. 8, 32, 64, 128 or 256, where a
            bigger one draws from a better generator.

    Returns:
        The state that was in use before, or null on failure with `errno`
        set.

    Notes:
        Handing what this gives back to `setstate` goes back to the
        generator that was in use before, which is how two of them take
        turns from the same process.
    """
    return external_call[
        "initstate", c_ptr[c_char], UInt32, c_ptr[c_char], UInt64
    ](seed, state, n)


def setstate(state: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdlib.h> function `setstate`.

    Reference:
        https://man7.org/linux/man-pages/man3/setstate.3.html

    Prototype:
        char *setstate(char *state)

    Description:
        Goes back to a generator that `initstate` started.

    Args:
        state: A state that `initstate` gave back.

    Returns:
        The state that was in use before, or null on failure with `errno`
        set.

    Notes:
        Handing the result back to `setstate` again switches to whichever
        generator was in use before that one.
    """
    return external_call["setstate", c_ptr[c_char], c_ptr[c_char]](state)


def getsubopt(
    optionp: c_ptr[c_ptr[c_char]],
    tokens: c_ptr[c_ptr[c_char]],
    valuep: c_ptr[c_ptr[c_char]],
) -> Int32:
    """C library <stdlib.h> function `getsubopt`.

    Reference:
        https://man7.org/linux/man-pages/man3/getsubopt.3.html

    Prototype:
        int getsubopt(char **optionp, char *const *tokens, char **valuep)

    Description:
        Takes a comma-separated option string apart and says which of
        `tokens` each piece is.

    Args:
        optionp: A pointer to the rest of the string, which is moved past
            each piece as it is taken.
        tokens: A null-terminated list of the sub-options to look for.
        valuep: Set to point at the value after an `=`, if the piece has
            one, or to null if it does not.

    Returns:
        Which of `tokens` it was, by position, or -1 when the string is
        finished. A piece that is not in the list also gives -1, with
        `optionp` left pointing at it so you can say which it was.

    Notes:
        The commas in the string are overwritten with null bytes, so the
        string is changed and cannot be taken apart twice.
    """
    return external_call[
        "getsubopt",
        Int32,
        c_ptr[c_ptr[c_char]],
        c_ptr[c_ptr[c_char]],
        c_ptr[c_ptr[c_char]],
    ](optionp, tokens, valuep)


def getloadavg(loadavg: c_ptr[c_double], nelem: c_int) -> c_int:
    """C library <stdlib.h> function `getloadavg`.

    Reference:
        https://man7.org/linux/man-pages/man3/getloadavg.3.html

    Prototype:
        int getloadavg(double loadavg[], int nelem)

    Description:
        How busy the machine has been: how many things were waiting to
        run, taken as an average over three periods of time — the last
        minute, the last five and the last fifteen — and written into
        `loadavg` in that order.

    Args:
        loadavg: Where the averages are written. Room for three
            `double` is what they take; more room than that is filled
            up to three and no further.
        nelem: How many of them to write. Three is all there are, so
            anything more is answered with three.

    Returns:
        How many were written: as many as were asked for, up to three,
        or -1 with `errno` set when they could not be had.

    Notes:
        The averages are not integers. 0.0 is an idle machine, and one
        with four cores running flat out reads about 4.0 — the number
        counts things waiting to run, not cores.
    """
    return external_call["getloadavg", c_int, c_ptr[c_double], c_int](
        loadavg, nelem
    )


def div(numer: c_int, denom: c_int) -> div_t:
    """Libc C89 `div` function.

    Description:
        Divides one int by another and hands back the quotient and
        the remainder of it together.

    Args:
        numer: The number to divide.
        denom: What to divide it by.

    Returns:
        The quotient in `quot` and the remainder in `rem`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/div.3.html).
        Fn signature: `div_t div(int numer, int denom)`.

        The quotient is rounded towards zero and the remainder takes
        the sign of the numerator, which is what C asks of `/` and
        `%` too. `imaxdiv` is this same call for the widest integer
        there is.
    """
    return external_call["div", div_t, c_int, c_int](numer, denom)


def ldiv(numer: c_long, denom: c_long) -> ldiv_t:
    """Libc C89 `ldiv` function.

    Description:
        Divides one long by another and hands back the quotient and
        the remainder of it together.

    Args:
        numer: The number to divide.
        denom: What to divide it by.

    Returns:
        The quotient in `quot` and the remainder in `rem`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ldiv.3.html).
        Fn signature: `ldiv_t ldiv(long numer, long denom)`.

        Rounded towards zero, with the remainder taking the sign of
        the numerator, as `div` does.
    """
    return external_call["ldiv", ldiv_t, c_long, c_long](numer, denom)


def lldiv(numer: c_longlong, denom: c_longlong) -> lldiv_t:
    """Libc C99 `lldiv` function.

    Description:
        Divides one long long by another and hands back the quotient
        and the remainder of it together.

    Args:
        numer: The number to divide.
        denom: What to divide it by.

    Returns:
        The quotient in `quot` and the remainder in `rem`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/lldiv.3.html).
        Fn signature: `lldiv_t lldiv(long long numer, long long denom)`.

        Rounded towards zero, with the remainder taking the sign of
        the numerator, as `div` does.
    """
    return external_call["lldiv", lldiv_t, c_longlong, c_longlong](numer, denom)


def drand48() -> Float64:
    """Libc POSIX `drand48` function.

    Description:
        Hands back the next number of a sequence of doubles spread
        evenly over the half-open range from 0 to 1.

    Returns:
        A double no less than 0 and less than 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/drand48.3.html).
        Fn signature: `double drand48(void)`.

        The sequence is the same one every time a programme starts,
        `srand48` being what picks a different place in it, and it is
        one the standard says how to work out — so what comes out is
        the same on both platforms. What a test may hold it to is
        that, and not the numbers themselves.

        `lrand48` and `mrand48` go over the same sequence and hand
        back integers instead, and `erand48` takes its own state
        rather than the one this keeps.
    """
    return external_call["drand48", Float64]()


def erand48(xsubi: c_ptr[c_ushort]) -> Float64:
    """Libc POSIX `erand48` function.

    Description:
        Hands back the next number of a sequence of doubles, keeping
        the state of that sequence in an array the caller owns.

    Args:
        xsubi: Three shorts holding where in the sequence this is.
            They are moved on before this hands anything back.

    Returns:
        A double no less than 0 and less than 1.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/erand48.3.html).
        Fn signature: `double erand48(unsigned short xsubi[3])`.

        This is the one to reach for where a sequence is wanted that
        nothing else can move on: `drand48` keeps one state for the
        whole programme, and `erand48` keeps as many as there are
        arrays to keep them in. The three shorts are written to, and
        the array has to be three long and to outlive the calling.
    """
    return external_call["erand48", Float64, c_ptr[c_ushort]](xsubi)


def lrand48() -> c_long:
    """Libc POSIX `lrand48` function.

    Description:
        Hands back the next number of a sequence of integers, spread
        evenly over the half-open range from 0 to 2 to the 31.

    Returns:
        A long no less than 0 and less than 2147483648.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/lrand48.3.html).
        Fn signature: `long lrand48(void)`.

        The same sequence `drand48` walks, read as integers.
    """
    return external_call["lrand48", c_long]()


def mrand48() -> c_long:
    """Libc POSIX `mrand48` function.

    Description:
        Hands back the next number of a sequence of integers, spread
        evenly over the signed range of a 32-bit number.

    Returns:
        A long no less than -2147483648 and less than 2147483648.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mrand48.3.html).
        Fn signature: `long mrand48(void)`.

        The same sequence `drand48` walks, read as integers that may
        come out negative, which is the one way it is not `lrand48`.
    """
    return external_call["mrand48", c_long]()


def srand48(seedval: c_long):
    """Libc POSIX `srand48` function.

    Description:
        Says where in the sequence `drand48` and the rest are to
        start.

    Args:
        seedval: The seed. The bottom 32 bits of it are used and the
            rest are not.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/srand48.3.html).
        Fn signature: `void srand48(long seedval)`.

        There is one state for the whole programme and this sets it,
        so one call here moves every one of the others. `seed48` and
        `lcong48` set it too, the first of them handing the old state
        back and the second taking the numbers the sequence is worked
        out from.
    """
    external_call["srand48", NoneType, c_long](seedval)


def seed48(seed16v: c_ptr[c_ushort]) -> c_ptr[c_ushort]:
    """Libc POSIX `seed48` function.

    Description:
        Says where in the sequence `drand48` and the rest are to
        start, taking three shorts to do it and handing the state
        they displace back.

    Args:
        seed16v: Three shorts to start from. The top one is set to a
            fixed value before it is used.

    Returns:
        A pointer to three shorts holding the state that was in use
        before this call, kept somewhere that is not to be freed.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/seed48.3.html).
        Fn signature: `unsigned short *seed48(unsigned short seed16v[3])`.

        What is handed back points into the library's own storage, so
        it is copied out before the next call here rather than kept.
    """
    return external_call["seed48", c_ptr[c_ushort], c_ptr[c_ushort]](seed16v)


def lcong48(param: c_ptr[c_ushort]):
    """Libc POSIX `lcong48` function.

    Description:
        Sets the numbers the sequence `drand48` and the rest are
        worked out from, rather than where in it to start.

    Args:
        param: Seven shorts: the three the state is kept in, then
            the multiplier, then the amount added, then the modulus.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/lcong48.3.html).
        Fn signature: `void lcong48(unsigned short param[7])`.

        Seven shorts it has to be, and this one is not for the
        ordinary wanting of a different sequence: `srand48` is that.
    """
    external_call["lcong48", NoneType, c_ptr[c_ushort]](param)


def l64a(value: c_long) -> c_ptr[c_char]:
    """Libc POSIX `l64a` function.

    Description:
        Writes a long in the 64-character alphabet the `a64l` family
        uses.

    Args:
        value: The number to write. Whether it is taken as signed is
            not something the standard settles, and 32 bits is as
            much as is read of it.

    Returns:
        A pointer to the characters, kept somewhere that is not to be
        freed and that the next call here writes over.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/a64l.3.html).
        Fn signature: `char *l64a(long value)`.

        The alphabet is the one POSIX gives: a full stop for 0, a
        slash for 1, then the digits, then the capitals, then the
        small letters. What comes back is not to be kept past the
        next call, and `a64l` is what reads it back.
    """
    return external_call["l64a", c_ptr[c_char], c_long](value)


def a64l(s: c_ptr[c_char]) -> c_long:
    """Libc POSIX `a64l` function.

    Description:
        Reads a long written in the 64-character alphabet the `l64a`
        function writes.

    Args:
        s: The characters to read. Reading stops at one that is not
            in the alphabet.

    Returns:
        The number, as a long.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/a64l.3.html).
        Fn signature: `long a64l(const char *s)`.

        `l64a` is what writes these. Reading past six characters is
        not a thing the standard says anything about, so six is as
        many as are worth handing it.
    """
    return external_call["a64l", c_long, c_ptr[c_char]](s)


def mblen(s: c_ptr[c_char], n: c_size_t) -> c_int:
    """Libc C89 `mblen` function.

    Description:
        Says how many bytes the next multibyte character takes.

    Args:
        s: The bytes to look at, or a null pointer to ask whether the
            encoding has state.
        n: The most bytes to look at. More than a whole
            character's worth is not read.

    Returns:
        How many bytes it takes, or 0 where `s` points at the end of
        the string, or -1 where what is there is not a whole
        character.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mblen.3.html).
        Fn signature: `int mblen(const char *s, size_t n)`.

        Which characters take more than one byte, and how many they
        take, is the locale's to say; under the C locale every one
        takes one. This is `mbtowc` without the converting, and it
        shares the conversion state that one keeps — so the two are
        not to be used on the same string turn about.
    """
    return external_call["mblen", c_int, c_ptr[c_char], c_size_t](s, n)


def mbtowc(pwc: c_ptr[c_wchar], s: c_ptr[c_char], n: c_size_t) -> c_int:
    """Libc C89 `mbtowc` function.

    Description:
        Reads the next multibyte character out into a wide character.

    Args:
        pwc: Where to put it, or a null pointer where the converting
            is not wanted.
        s: The bytes to read, or a null pointer to put the state back
            at its beginning.
        n: The most bytes to read. More than a whole
            character's worth is not read.

    Returns:
        How many bytes it took, or 0 where `s` points at the end of
        the string, or -1 where what is there is not a whole
        character.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mbtowc.3.html).
        Fn signature: `int mbtowc(wchar_t *pwc, const char *s,
            size_t n)`.

        The state this keeps is the library's own and there is one of
        it, so two strings cannot be read turn about, and a null `s`
        is how it is put back at the beginning. `mbrtowc` is the one
        that takes the state from the caller, and is the one to
        reach for where that matters.

        Which characters take more than one byte is the locale's to
        say, and under the C locale every one takes one.
    """
    return external_call[
        "mbtowc", c_int, c_ptr[c_wchar], c_ptr[c_char], c_size_t
    ](pwc, s, n)


def wctomb(s: c_ptr[c_char], wc: c_wchar) -> c_int:
    """Libc C89 `wctomb` function.

    Description:
        Writes a wide character out as bytes.

    Args:
        s: Where to write them, or a null pointer to ask whether the
            encoding has state.
        wc: The character to write.

    Returns:
        How many bytes it took, or -1 where the character cannot be
        written out at all.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wctomb.3.html).
        Fn signature: `int wctomb(char *s, wchar_t wc)`.

        Like `mbtowc` it keeps one state of its own, and a null `s` is
        how that is put back at the beginning. `wcrtomb` is the one
        that takes the state from the caller.

        No terminator is written. Which characters take more than one
        byte is the locale's to say, and under the C locale every one
        takes one.
    """
    return external_call["wctomb", c_int, c_ptr[c_char], c_wchar](s, wc)


def rpmatch(response: c_ptr[c_char]) -> c_int:
    """C library <stdlib.h> function `rpmatch`.

    Reference:
        https://man7.org/linux/man-pages/man3/rpmatch.3.html

    Prototype:
        int rpmatch(const char *response)

    Description:
        Says whether what was written in answer to a question was
        yes or was no.

    Args:
        response: The answer to be read.

    Returns:
        1 where the answer was yes, 0 where it was no, and -1 where
        it was neither.

    Notes:
        What counts as yes and what counts as no is the current
        locale's to say, being the regular expressions its `YESEXPR`
        and `NOEXPR` hold, and a caller that wants the same answer
        everywhere is a caller that hands in `y` or `n` and nothing
        longer.

        It is a GNU function, and is on Darwin too, but not in POSIX.
    """
    return external_call["rpmatch", c_int, c_ptr[c_char]](response)


def valloc(size: c_size_t) -> c_ptr[c_void]:
    """C library <stdlib.h> function `valloc`.

    Reference:
        https://man7.org/linux/man-pages/man3/valloc.3.html

    Prototype:
        void *valloc(size_t size)

    Description:
        Gives room for `size` bytes on a page boundary.

    Args:
        size: How many bytes of room are wanted.

    Returns:
        A pointer to the room, or a null pointer with `errno` set to
        `ENOMEM` where there is none to give.

    Notes:
        This is `malloc` that hands back an address a whole page is
        the start of, which is what some old code wanted and is not
        what anything wants now: `posix_memalign` is the one to call,
        being the one in POSIX and the one that says which alignment
        it is asked for.

        The room is given back with `free`, the same as `malloc`'s is,
        and is not zeroed.

        It is on both platforms, though not in POSIX, and its
        prototype lives in `<stdlib.h>` on Darwin and in `<malloc.h>`
        on glibc.
    """
    return external_call["valloc", c_ptr[c_void], c_size_t](size)


def mktemp(template: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdlib.h> function `mktemp`.

    Reference:
        https://man7.org/linux/man-pages/man3/mktemp.3.html

    Prototype:
        char *mktemp(char *template)

    Description:
        Makes a name that is not taken by writing over the last six
        characters of what was handed in, which have to be `XXXXXX`.

    Args:
        template: The name to be finished, ending in six `X`s, which
            is written to.

    Returns:
        `template` where a name was made, or an empty string where
        one could not be.

    Notes:
        This makes a name and not a file, and the gap between the
        two is the whole of what is wrong with it: another process
        can make the same name and get there first. `mkstemp` is the
        one to call, being the one that makes the file on the way
        and so leaves no gap.

        The six `X`s are the last six characters and not any six:
        a name with `XXXXXX` in the middle is handed back untouched.

        It is on both platforms, though not in POSIX, and it is
        deprecated in POSIX as of its 2008 edition.
    """
    return external_call["mktemp", c_ptr[c_char], c_ptr[c_char]](template)


def strtoq(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], base: c_int
) -> c_longlong:
    """C library <stdlib.h> function `strtoq`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        long long strtoq(const char *nptr, char **endptr, int base)

    Description:
        Converts the leading integer of `nptr` to a `long long`.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted
            character.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value, or the closest it could come with
        `errno` set to `ERANGE` where it does not fit.

    Notes:
        This is `strtoll` under its older name, the `q` being for
        quad, and `strtouq` is `strtoull` the same way. The newer
        names are the ones in C99 and the ones to call; these are
        kept in the header so that code written to the old names
        still builds.
    """
    return external_call[
        "strtoq", c_longlong, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int
    ](nptr, endptr, base)


def strtouq(
    nptr: c_ptr[c_char], endptr: c_ptr[c_ptr[c_char]], base: c_int
) -> c_ulonglong:
    """C library <stdlib.h> function `strtouq`.

    Reference:
        https://man7.org/linux/man-pages/man3/strtol.3.html

    Prototype:
        unsigned long long strtouq(const char *nptr,
            char **endptr, int base)

    Description:
        Converts the leading integer of `nptr` to an `unsigned long
        long`.

    Args:
        nptr: The string to convert.
        endptr: Receives the address of the first unconverted
            character.
        base: 0 for autodetection, or 2 through 36.

    Returns:
        The converted value, or the closest it could come with
        `errno` set to `ERANGE` where it does not fit.

    Notes:
        This is `strtoull` under its older name, the `q` being for
        quad, and `strtoq` is `strtoll` the same way. The newer
        names are the ones in C99 and the ones to call; these are
        kept in the header so that code written to the old names
        still builds.

        A leading minus is not refused: it is negated into the
        unsigned, so `-1` comes back as the largest it can hold.
    """
    return external_call[
        "strtouq", c_ulonglong, c_ptr[c_char], c_ptr[c_ptr[c_char]], c_int
    ](nptr, endptr, base)


def jrand48(xsubi: c_ptr[c_ushort]) -> c_long:
    """Libc POSIX `jrand48` function.

    Description:
        Hands back the next number of a sequence of signed longs,
        keeping the state of that sequence in an array the caller
        owns.

    Args:
        xsubi: Three shorts holding where in the sequence this is.
            They are moved on before this hands anything back.

    Returns:
        A long no less than -2^31 and less than 2^31.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/erand48.3.html).
        Fn signature: `long jrand48(unsigned short xsubi[3])`.

        The three shorts are written to, and the array has to be
        three long and to outlive the calling.

        `nrand48` is the same step of the same sequence read as a
        number that is never negative, and `mrand48` is the same
        step of the one sequence the whole programme shares. Which
        of the three is wanted is a question about how the number
        is to be read, not about which sequence it comes from:
        given the same three shorts, the three hand back the same
        bits, and differ only in whether the top one is read as a
        sign.

        What a given three shorts hand back is fixed by POSIX and
        so is the same on every machine, which is the whole of why
        a test can be written for it at all.
    """
    return external_call["jrand48", c_long, c_ptr[c_ushort]](xsubi)


def nrand48(xsubi: c_ptr[c_ushort]) -> c_long:
    """Libc POSIX `nrand48` function.

    Description:
        Hands back the next number of a sequence of non-negative
        longs, keeping the state of that sequence in an array the
        caller owns.

    Args:
        xsubi: Three shorts holding where in the sequence this is.
            They are moved on before this hands anything back.

    Returns:
        A long no less than 0 and less than 2^31.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/erand48.3.html).
        Fn signature: `long nrand48(unsigned short xsubi[3])`.

        The three shorts are written to, and the array has to be
        three long and to outlive the calling.

        `jrand48` is the same step of the same sequence read as a
        number that may be negative, and `mrand48` is the same step
        of the one sequence the whole programme shares. Which of the
        three is wanted is a question about how the number is to be
        read, not about which sequence it comes from: given the same
        three shorts, the three hand back the same bits, and differ
        only in whether the top one is read as a sign.

        What a given three shorts hand back is fixed by POSIX and
        so is the same on every machine, which is the whole of why
        a test can be written for it at all.
    """
    return external_call["nrand48", c_long, c_ptr[c_ushort]](xsubi)


def ecvt(
    value: Float64, ndigit: Int32, decpt: c_ptr[Int32], sign: c_ptr[Int32]
) -> c_ptr[c_char]:
    """C library <stdlib.h> function `ecvt`.

    Reference:
        https://man7.org/linux/man-pages/man3/ecvt.3.html

    Prototype:
        char *ecvt(double value, int ndigit, int *decpt, int *sign)

    Description:
        Writes a number out as digits and nothing else: no point, no
        sign, no exponent. `ndigit` says how many digits, counted
        from the first one that is not a zero, and where the point
        really goes is written to `decpt` instead — 1 for
        `1.25`'s `"125"`, 2 for `12.5`'s, 0 for a number that
        starts with one. Whether it was negative is written to
        `sign`, the digits themselves being the same either way.

    Args:
        value: The number to write out.
        ndigit: How many digits to write, counted from the left.
        decpt: Where the number of digits before the point is put.
        sign: Where 1 is put for a negative number and 0 for one that
            is not.

    Returns:
        The digits, as a string the library owns, or null if `ndigit`
        asked for more than the number has.

    Notes:
        The string is one the library keeps, not one it makes for
        this call: it is written over by the next of the three that
        is called, and it is shared by every thread that calls them.

        Marked legacy in the man pages, and not in C99, but it is on
        both platforms and has no successor: `snprintf` with `%e`
        and a width is the nearest thing, and says the exponent
        whether it is wanted or not.
    """

    return external_call[
        "ecvt", c_ptr[c_char], Float64, Int32, c_ptr[Int32], c_ptr[Int32]
    ](value, ndigit, decpt, sign)


def fcvt(
    value: Float64, ndigit: Int32, decpt: c_ptr[Int32], sign: c_ptr[Int32]
) -> c_ptr[c_char]:
    """C library <stdlib.h> function `fcvt`.

    Reference:
        https://man7.org/linux/man-pages/man3/ecvt.3.html

    Prototype:
        char *fcvt(double value, int ndigit, int *decpt, int *sign)

    Description:
        The same three things as `ecvt` writes, with `ndigit`
        counted from the other end: from the point rather than from
        the first digit, so it is how many digits are kept after the
        point and not how many are written in all. `1.25` asked for
        three gives `"1250"`, where `ecvt` gives `"125"`.

    Args:
        value: The number to write out.
        ndigit: How many digits to keep, counted from the point.
        decpt: Where the number of digits before the point is put.
        sign: Where 1 is put for a negative number and 0 for one that
            is not.

    Returns:
        The digits, as a string the library owns.

    Notes:
        The two differ in one thing only, and the value and the count
        can be the same in both: what changes is where the count is
        counted from.

        The string is one the library keeps, not one it makes for
        this call: it is written over by the next of the three that
        is called, and it is shared by every thread that calls them.
    """

    return external_call[
        "fcvt", c_ptr[c_char], Float64, Int32, c_ptr[Int32], c_ptr[Int32]
    ](value, ndigit, decpt, sign)


def gcvt(value: Float64, ndigit: Int32, buf: c_ptr[c_char]) -> c_ptr[c_char]:
    """C library <stdlib.h> function `gcvt`.

    Reference:
        https://man7.org/linux/man-pages/man3/ecvt.3.html

    Prototype:
        char *gcvt(double value, int ndigit, char *buf)

    Description:
        Writes a number out the way it would be written by hand:
        point, sign and all, in as few characters as `ndigit`
        significant digits can be had in, and an exponent only where
        there is no room without one. The one of the three that
        writes into a buffer of the caller's, and the one that writes
        a number a person can read.

    Args:
        value: The number to write out.
        ndigit: How many significant digits to write, which is what
            the width of a `%g` is.
        buf: Where to write it, which must have room for the number
            and the byte that ends it.

    Returns:
        `buf`, the same pointer that was given.

    Notes:
        How many bytes `buf` needs is up to the number: the digits, a
        sign, a point, an `e` with its exponent where one is needed,
        and the byte that ends it.

        `ndigit` is significant digits and not places: `1.25` asked
        for four is `"1.25"` and asked for two is `"1.2"`, which is
        a different number, the count being one that rounds off
        rather than one that pads out.
    """

    return external_call["gcvt", c_ptr[c_char], Float64, Int32, c_ptr[c_char]](
        value, ndigit, buf
    )


def posix_openpt(oflag: Int32) -> Int32:
    """Libc POSIX `posix_openpt` function.

    Description:
        Opens the master end of a pseudo-terminal.

    Args:
        oflag: `O_RDWR`, and `O_NOCTTY` as well where the caller does
            not want the terminal it is given to become the controlling
            one.

    Returns:
        A descriptor for the master end, or -1 with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/posix_openpt.3.html).
        Fn signature: `int posix_openpt(int oflag)`.

        A pseudo-terminal is a pair of descriptors that carry bytes
        between them the way a terminal carries them to a program: what
        is written at the master is read at the far end as input, and
        what is written at the far end is read at the master as output.
        This opens one of the two; `ptsname` says where the other is,
        and `grantpt` and `unlockpt` are what make that name usable.

        The far end does not exist until its name is opened, and opening
        it is what a terminal session would do rather than what a
        terminal driver does: nothing is read or written until the
        caller has opened both ends.
    """
    return external_call["posix_openpt", Int32, Int32](oflag)


def grantpt(fildes: Int32) -> Int32:
    """Libc POSIX `grantpt` function.

    Description:
        Sets the owner and permissions the far end of a pseudo-terminal
        needs to be opened.

    Args:
        fildes: The descriptor `posix_openpt` answered with.

    Returns:
        0 where it worked, or -1 with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/grantpt.3.html).
        Fn signature: `int grantpt(int fildes)`.

        This has to be done before the far end is opened and after it is
        created, and doing it twice is not an error. Darwin does nothing
        here and answers 0 anyway, because its pseudo-terminals are
        created with the right owner already; a caller that skips this
        on Darwin works, and one that skips it on glibc gets a
        permission error when it opens the far end.
    """
    return external_call["grantpt", Int32, Int32](fildes)


def unlockpt(fildes: Int32) -> Int32:
    """Libc POSIX `unlockpt` function.

    Description:
        Clears the lock that keeps the far end of a pseudo-terminal from
        being opened.

    Args:
        fildes: The descriptor `posix_openpt` answered with.

    Returns:
        0 where it worked, or -1 with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/unlockpt.3.html).
        Fn signature: `int unlockpt(int fildes)`.

        A pseudo-terminal is born locked, and this is the only thing
        that unlocks it: without it `ptsname` still answers a name and
        opening it fails. It is what `grantpt` is not -- one sets who
        may open the far end, the other says that anyone who may now
        can.
    """
    return external_call["unlockpt", Int32, Int32](fildes)


def ptsname(fildes: Int32) -> c_ptr[c_char]:
    """Libc POSIX `ptsname` function.

    Description:
        Answers the name of the far end of a pseudo-terminal.

    Args:
        fildes: The descriptor `posix_openpt` answered with.

    Returns:
        The path to open for the far end, or a null pointer where the
        descriptor is not the master of a pseudo-terminal.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ptsname.3.html).
        Fn signature: `char *ptsname(int fildes)`.

        The string is libc's rather than the caller's, and the next call
        to this overwrites it: copy it out before asking again. It is
        also not a constant across platforms -- glibc answers
        `/dev/pts/13` where Darwin answers `/dev/ttys013` -- so a name
        written down in a program is right on one of them.

        This does not open anything, and the name it answers is not
        usable until `grantpt` and `unlockpt` have both been called.
    """
    return external_call["ptsname", c_ptr[c_char], Int32](fildes)
