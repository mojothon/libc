# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from libc.constant import c_int, c_ptr, c_wchar


struct imaxdiv_t(TrivialRegisterPassable):
    var quot: Int64
    var rem: Int64


def imaxabs(j: Int64) -> Int64:
    """Libc <inttypes.h> function `imaxabs`.

    Link:
        https://man7.org/linux/man-pages/man3/imaxabs.3.html

    Prototype:
        intmax_t imaxabs(intmax_t j)

    Description:
        Computes the absolute value of j.

    Arguments:
        j: The number for which the absolute value is to be computed.

    Return value:
        The absolute value of j.
    """
    return external_call["imaxabs", Int64, Int64](j)


def imaxdiv(numer: Int64, denom: Int64) -> imaxdiv_t:
    """Libc <inttypes.h> function `imaxdiv`.

    Link:
        https://man7.org/linux/man-pages/man3/ldiv.3.html

    Prototype:
        imaxdiv_t imaxdiv(intmax_t numer, intmax_t denom)

    Description:
        Computes the quotient and remainder of  the division of the numerator numer by the denominator denom.

    Arguments:
        numer: the numerator
        denom: the denominator

    Return value:
        The quotient and remainder of  the division of the numerator numer by the denominator denom.
    """
    return external_call["imaxdiv", imaxdiv_t, Int64, Int64](numer, denom)


def strtoimax(
    nptr: c_ptr[UInt8], endptr: c_ptr[c_ptr[UInt8]], base: Int32
) -> Int64:
    """Libc <inttypes.h> function `strtoimax`.

    Link:
        https://man7.org/linux/man-pages/man3/strtoimax.3.html

    Prototype:
        intmax_t strtoimax(const char *nptr, char **endptr, int base)

    Description:
        Converts the initial part of the string pointed to by nptr to a signed integer value using the given base, which must be between 2 and 36 inclusive.
    Arguments:
        nptr: a pointer to the string to be converted
        endptr: a pointer to a pointer to the first invalid character in the string
        base: the base to be used for the conversion

    Return value:
        On success, the converted value is returned. On error, -1 is returned.
    """
    return external_call[
        "strtoimax", Int64, c_ptr[UInt8], c_ptr[c_ptr[UInt8]], Int32
    ](nptr, endptr, base)


def strtoumax(
    nptr: c_ptr[UInt8], endptr: c_ptr[c_ptr[UInt8]], base: Int32
) -> UInt64:
    """Libc <inttypes.h> function `strtoumax`.

    Link:
        https://man7.org/linux/man-pages/man3/strtoumax.3.html

    Prototype:
        uintmax_t strtoumax(const char *nptr, char **endptr, int base)

    Description:
        Converts the initial part of the string pointed to by nptr to a signed integer value using the given base, which must be between 2 and 36 inclusive.
    Arguments:
        nptr: a pointer to the string to be converted
        endptr: a pointer to a pointer to the first invalid character in the string
        base: the base to be used for the conversion

    Return value:
        On success, the converted value is returned. On error, -1 is returned.
    """
    return external_call[
        "strtoumax", UInt64, c_ptr[UInt8], c_ptr[c_ptr[UInt8]], Int32
    ](nptr, endptr, base)


def wcstoimax(
    nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]], base: c_int
) -> Int64:
    """Libc <inttypes.h> function `wcstoimax`.

    Args:
        nptr: The wide string to convert.
        endptr: Where to store the address of the first wide character that
            did not convert, or a null pointer if you do not care.
        base: The base to convert in, 2 to 36, or 0 to take it from the
            prefix.

    Returns:
        The converted value, clamped on overflow, with `errno` set to `ERANGE`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstoimax.3.html).
        Fn signature: `intmax_t wcstoimax(const wchar_t *nptr, wchar_t **endptr, int base)`.
    """
    return external_call[
        "wcstoimax", Int64, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]], c_int
    ](nptr, endptr, base)


def wcstoumax(
    nptr: c_ptr[c_wchar], endptr: c_ptr[c_ptr[c_wchar]], base: c_int
) -> UInt64:
    """Libc <inttypes.h> function `wcstoumax`.

    Args:
        nptr: The wide string to convert.
        endptr: Where to store the address of the first wide character that
            did not convert, or a null pointer if you do not care.
        base: The base to convert in, 2 to 36, or 0 to take it from the
            prefix.

    Returns:
        The converted value, clamped on overflow, with `errno` set to `ERANGE`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/wcstoimax.3.html).
        Fn signature: `uintmax_t wcstoumax(const wchar_t *nptr, wchar_t **endptr, int base)`.
    """
    return external_call[
        "wcstoumax", UInt64, c_ptr[c_wchar], c_ptr[c_ptr[c_wchar]], c_int
    ](nptr, endptr, base)
