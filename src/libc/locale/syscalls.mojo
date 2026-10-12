# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory.alloc import unsafe_alloc

from libc.constant import c_ptr

comptime NUM_LOCALE_CATEGORIES = 6


struct LocaleData(TrivialRegisterPassable):
    pass


struct Locale(TrivialRegisterPassable):
    var data: c_ptr[LocaleData]

    def __init__(out self):
        self.data = unsafe_alloc[LocaleData](NUM_LOCALE_CATEGORIES)


comptime locale_t = Locale


def duplocale(locobj: locale_t) -> locale_t:
    """C library <locale.h> function `duplocale`.

    Reference:
        https://man7.org/linux/man-pages/man3/duplocale.3.html

    Prototype:
        locale_t duplocale(locale_t locobj)

    Description:
        Returns a copy of the locale object locobj.

    Return value:
        A new locale object that is a copy of locobj. If locobj is NULL, returns NULL.
    """

    return external_call["duplocale", locale_t, locale_t](locobj)


def freelocale(locobj: locale_t) -> Int8:
    """C library <locale.h> function `freelocale`.

    Reference:
        https://man7.org/linux/man-pages/man3/freelocale.3.html

    Prototype:
        void freelocale(locale_t locobj)

    Description:
        Frees the memory associated with the locale object locobj.

    Return value:
        None.
    """
    return external_call["freelocale", Int8, locale_t](locobj)


def newlocale(
    category_mask: Int32, locale: c_ptr[UInt8], base: locale_t
) -> locale_t:
    """C library <locale.h> function `newlocale`.

    Reference:
        https://man7.org/linux/man-pages/man3/newlocale.3.html

    Prototype:
        locale_t newlocale(int category_mask, const char *locale, locale_t base)

    Description:
        Creates a new locale object from the locale string locale.

    Return value:
        On success, the new locale object is returned. On error, NULL is returned.
    """
    return external_call["newlocale", locale_t, Int32, c_ptr[UInt8], locale_t](
        category_mask, locale, base
    )


def uselocale(locobj: locale_t) -> locale_t:
    """C library <locale.h> function `uselocale`.

    Reference:
        https://man7.org/linux/man-pages/man3/uselocale.3.html

    Prototype:
        locale_t uselocale(locale_t locobj)

    Description:
        Sets the current locale object to locobj, and returns the previous locale object.

    Return value:
        The previous locale object.
    """
    return external_call["uselocale", locale_t, locale_t](locobj)


def setlocale(category: Int32, locale: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <locale.h> function `setlocale`.

    Reference:
        https://man7.org/linux/man-pages/man3/setlocale.3.html

    Prototype:
        char *setlocale(int category, const char *locale)

    Description:
        Sets the locale for the specified category to the locale string locale.

    Return value:
        On success, the locale string is returned. On error, NULL is returned.
    """
    return external_call["setlocale", c_ptr[UInt8], Int32, c_ptr[UInt8]](
        category, locale
    )


def localeconv(locobj: locale_t) -> c_ptr[LocaleData]:
    """C library <locale.h> function `localeconv`.

    Reference:
        https://man7.org/linux/man-pages/man3/localeconv.3.html

    Prototype:
        struct lconv:

    Description:
        Returns a pointer to a structure containing numeric and monetary information appropriate for the current locale.

    Return value:
        On success, a pointer to a structure containing numeric and monetary information appropriate for the current locale. On error, NULL is returned.
    """
    return external_call["localeconv", c_ptr[LocaleData]](locobj)
