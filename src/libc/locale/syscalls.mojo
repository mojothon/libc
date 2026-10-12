# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget

from libc.constant import c_ptr

# The categories are numbered differently on the two platforms: glibc counts
# from `LC_CTYPE` and Darwin from `LC_ALL`.
comptime LC_CTYPE: Int32 = Int32(
    0
) if not CompilationTarget.is_macos() else Int32(2)
comptime LC_NUMERIC: Int32 = Int32(
    1
) if not CompilationTarget.is_macos() else Int32(5)
comptime LC_TIME: Int32 = Int32(
    2
) if not CompilationTarget.is_macos() else Int32(6)
comptime LC_COLLATE: Int32 = Int32(
    3
) if not CompilationTarget.is_macos() else Int32(1)
comptime LC_MONETARY: Int32 = Int32(
    4
) if not CompilationTarget.is_macos() else Int32(4)
comptime LC_MESSAGES: Int32 = Int32(
    5
) if not CompilationTarget.is_macos() else Int32(3)
comptime LC_ALL: Int32 = Int32(
    6
) if not CompilationTarget.is_macos() else Int32(0)


struct Locale:
    """An opaque C locale object, the thing a `locale_t` points at.

    Empty on purpose: C never lets you see inside one, only hand the pointer
    back to `uselocale`, `duplocale`, `freelocale` and friends. Nothing here
    allocates one — `newlocale` does, and it gives you the pointer.
    """

    pass


comptime locale_t = c_ptr[Locale]


struct lconv:
    """A C `struct lconv`: how the current locale writes numbers and money.

    POSIX fixes the order of these members and both platforms follow it, so the
    bytes are read as fields rather than through accessors. The ten strings
    come first, then fourteen `char`s; libc owns the object this points at and
    this declaration is only ever used to read it.

    The `char` members are `CHAR_MAX` when the locale has nothing to say — in
    the `C` locale every one of them is 127.
    """

    var decimal_point: c_ptr[UInt8]
    var thousands_sep: c_ptr[UInt8]
    var grouping: c_ptr[UInt8]
    var int_curr_symbol: c_ptr[UInt8]
    var currency_symbol: c_ptr[UInt8]
    var mon_decimal_point: c_ptr[UInt8]
    var mon_thousands_sep: c_ptr[UInt8]
    var mon_grouping: c_ptr[UInt8]
    var positive_sign: c_ptr[UInt8]
    var negative_sign: c_ptr[UInt8]
    var int_frac_digits: UInt8
    var frac_digits: UInt8
    var p_cs_precedes: UInt8
    var p_sep_by_space: UInt8
    var n_cs_precedes: UInt8
    var n_sep_by_space: UInt8
    var p_sign_posn: UInt8
    var n_sign_posn: UInt8
    var int_p_cs_precedes: UInt8
    var int_p_sep_by_space: UInt8
    var int_p_sign_posn: UInt8
    var int_n_cs_precedes: UInt8
    var int_n_sep_by_space: UInt8
    var int_n_sign_posn: UInt8


def setlocale(category: Int32, locale: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc `setlocale`, which sets or reports the process's locale.

    Args:
        category: One of the `LC_*` macros, the part of the locale to change.
        locale: The locale name, such as `"C"`, `"en_US.UTF-8"`, or `""` for
            whatever the environment asks for. A null pointer reports the
            current one without changing it.

    Returns:
        The name of the locale now in effect, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/setlocale.3.html).
        Fn signature: `char *setlocale(int category, const char *locale)`.

        The string comes from libc's own storage and is overwritten by the next
        call, so copy it if you want to keep it.
    """
    return external_call["setlocale", c_ptr[UInt8], Int32, c_ptr[UInt8]](
        category, locale
    )


def localeconv() -> c_ptr[lconv]:
    """Libc `localeconv`, which reports how the locale formats numbers.

    Returns:
        A pointer to libc's own `struct lconv`, which the next `setlocale` or
        `localeconv` call may overwrite. Copy what you need.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/localeconv.3.html).
        Fn signature: `struct lconv *localeconv(void)`.

        It takes no arguments. C's declaration is `struct lconv
        *localeconv(void)`, and a caller that passes one is handing libc a
        value it will ignore, not asking about a locale.
    """
    return external_call["localeconv", c_ptr[lconv]]()


def newlocale(
    category_mask: Int32, locale: c_ptr[UInt8], base: locale_t
) -> locale_t:
    """Libc `newlocale`, which builds a locale object you can pass around.

    Args:
        category_mask: A bitwise OR of the `LC_*` macros, the parts to take
            from `locale`.
        locale: The locale name to read those parts from.
        base: An existing object to start from, or `null_ptr[Locale]()` to
            build on the current global locale.

    Returns:
        The new object, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/newlocale.3.html).
        Fn signature:
            `locale_t newlocale(int category_mask, const char *locale,
            locale_t base)`.
    """
    return external_call["newlocale", locale_t, Int32, c_ptr[UInt8], locale_t](
        category_mask, locale, base
    )


def duplocale(locobj: locale_t) -> locale_t:
    """Libc `duplocale`, which copies a locale object.

    Args:
        locobj: The object to copy.

    Returns:
        The copy, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/duplocale.3.html).
        Fn signature: `locale_t duplocale(locale_t locobj)`.

        `freelocale` is what gives the copy back.
    """
    return external_call["duplocale", locale_t, locale_t](locobj)


def freelocale(locobj: locale_t) raises:
    """Libc `freelocale`, which gives back an object `newlocale` made.

    Args:
        locobj: The object to free.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/freelocale.3.html).
        Fn signature: `void freelocale(locale_t locobj)`.

        Undefined if the object is still in use by a thread, or if it came from
        anywhere but `newlocale` or `duplocale`.
    """
    external_call["freelocale", NoneType, locale_t](locobj)


def uselocale(locobj: locale_t) -> locale_t:
    """Libc `uselocale`, which sets the calling thread's locale.

    Args:
        locobj: The object to use, `null_ptr[Locale]()` to use none, or
            `LC_GLOBAL_LOCALE` for the process-wide one.

    Returns:
        The locale the thread was using before, or a null pointer on error.
        Hand it back to restore it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/uselocale.3.html).
        Fn signature: `locale_t uselocale(locale_t locobj)`.

        `LC_GLOBAL_LOCALE` is `(locale_t) -1` in C, which a Mojo pointer cannot
        hold; use `null_ptr[Locale]()` and `setlocale` instead.
    """
    return external_call["uselocale", locale_t, locale_t](locobj)
