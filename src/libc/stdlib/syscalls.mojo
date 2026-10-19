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
from std.sys import CompilationTarget
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

# `rand`'s ceiling, and the widest values the `strto*` family saturate at.
# `long` is 64 bits on both platforms, so these agree. The two `HUGE_*` are
# infinity, written as a literal past what a float can hold, which is the
# nearest Mojo has to a spelling for one.
comptime RAND_MAX: Int32 = 2147483647
comptime LONG_MAX: c_long = 9223372036854775807
comptime LONG_MIN: c_long = -9223372036854775807 - 1
comptime ULONG_MAX: c_ulong = 18446744073709551615
comptime ULLONG_MAX: c_ulonglong = 18446744073709551615
comptime HUGE_VAL: Float64 = Float64(1e400)
comptime HUGE_VALF: Float32 = Float32(1e400)

# How long a path `realpath` wants room for: 4096 here and 1024 there.
comptime PATH_MAX: Int32 = 1024 if CompilationTarget.is_macos() else 4096


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
