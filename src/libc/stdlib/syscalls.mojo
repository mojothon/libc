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
    c_void,
)


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
        Raises `SIGABRT`, terminating the process abnormally. Does not
        return.
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
