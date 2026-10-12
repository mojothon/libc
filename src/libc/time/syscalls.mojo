# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from libc.constant import c_ptr


def asctime(s: c_ptr[Int8]) -> c_ptr[Int8]:
    """C library <time.h> function `asctime`.

    Reference:
        https://man7.org/linux/man-pages/man3/asctime.3.html

    Args:
        s: Pointer to the time string to be converted.

    Returns:
        Pointer to the converted time string.
    """
    return external_call["asctime", c_ptr[Int8], c_ptr[Int8]](s)


def asctime_r(s: c_ptr[Int8], tm: c_ptr[Int8]) -> c_ptr[Int8]:
    """C library <time.h> function `asctime_r`.

    Reference:
        https://man7.org/linux/man-pages/man3/asctime_r.3.html

    Args:
        s: Pointer to the time string to be converted.
        tm: Pointer to the buffer to store the converted time string.

    Returns:
        Pointer to the converted time string.
    """
    return external_call["asctime_r", c_ptr[Int8], c_ptr[Int8], c_ptr[Int8]](
        s, tm
    )


def clock() -> Int64:
    """C library <time.h> function `clock`.

    Reference:
        https://man7.org/linux/man-pages/man2/clock.2.html

    Prototype:
        clock_t clock()

    Description:
        Returns the current time in clock ticks.
    """
    return external_call["clock", Int64]()


def clock_gettime(clockid: Int32, tp: c_ptr[Int64]) -> Int32:
    """C library <time.h> function `clock_gettime`.

    Reference:
        https://man7.org/linux/man-pages/man2/clock_gettime.2.html

    Args:
        clockid: Clock identifier.
        tp: Pointer to the buffer to store the time value.

    Returns:
        0 on success, or -1 on error.
    """
    return external_call["clock_gettime", Int32, Int32, c_ptr[Int64]](
        clockid, tp
    )


def ctime(s: c_ptr[Int8]) -> c_ptr[Int8]:
    """C library <time.h> function `ctime`.

    Reference:
        https://man7.org/linux/man-pages/man3/ctime.3.html

    Args:
        s: Pointer to the time value to be converted.

    Returns:
        Pointer to the converted time string.
    """
    return external_call["ctime", c_ptr[Int8], c_ptr[Int8]](s)


def ctime_r(s: c_ptr[Int8], tm: c_ptr[Int8]) -> c_ptr[Int8]:
    """C library <time.h> function `ctime_r`.

    Reference:
        https://man7.org/linux/man-pages/man3/ctime_r.3.html

    Args:
        s: Pointer to the time value to be converted.
        tm: Pointer to the buffer to store the converted time string.

    Returns:
        Pointer to the converted time string.
    """
    return external_call["ctime_r", c_ptr[Int8], c_ptr[Int8], c_ptr[Int8]](
        s, tm
    )


def difftime(time1: Int64, time0: Int64) -> Float64:
    """C library <time.h> function `difftime`.

    Reference:
        https://man7.org/linux/man-pages/man3/difftime.3.html

    Args:
        time1: The later time value.
        time0: The earlier time value.

    Returns:
        The difference between the two time values in seconds.
    """
    return external_call["difftime", Float64, Int64, Int64](time1, time0)


def gettimeofday(tv: c_ptr[Int64], tz: c_ptr[Int64]) -> Int32:
    """C library <time.h> function `gettimeofday`.

    Reference:
        https://man7.org/linux/man-pages/man2/gettimeofday.2.html

    Args:
        tv: Pointer to the buffer to store the time value.
        tz: Pointer to the buffer to store the timezone information.

    Returns:
        0 on success, or -1 on error.
    """
    return external_call["gettimeofday", Int32, c_ptr[Int64], c_ptr[Int64]](
        tv, tz
    )


def gmtime(s: c_ptr[Int64]) -> c_ptr[Int64]:
    """C library <time.h> function `gmtime`.

    Reference:
        https://man7.org/linux/man-pages/man3/gmtime.3.html

    Args:
        s: Pointer to the time value to be converted.

    Returns:
        Pointer to the converted time string.
    """
    return external_call["gmtime", c_ptr[Int64], c_ptr[Int64]](s)


def gmtime_r(s: c_ptr[Int64], tm: c_ptr[Int64]) -> c_ptr[Int64]:
    """C library <time.h> function `gmtime_r`.

    Reference:
        https://man7.org/linux/man-pages/man3/gmtime_r.3.html

    Args:
        s: Pointer to the time value to be converted.
        tm: Pointer to the buffer to store the converted time string.

    Returns:
        Pointer to the converted time string.
    """
    return external_call["gmtime_r", c_ptr[Int64], c_ptr[Int64], c_ptr[Int64]](
        s, tm
    )


def mktime(tm: c_ptr[Int64]) -> Int64:
    """C library <time.h> function `mktime`.

    Reference:
        https://man7.org/linux/man-pages/man3/mktime.3.html

    Args:
        tm: Pointer to the time value to be converted.

    Returns:
        The time value in seconds since the Epoch.
    """
    return external_call["mktime", Int64, c_ptr[Int64]](tm)


def nanosleep(rqtp: c_ptr[Int64], rmtp: c_ptr[Int64]) -> Int32:
    """C library <time.h> function `nanosleep`.

    Reference:
        https://man7.org/linux/man-pages/man2/nanosleep.2.html

    Args:
        rqtp: Pointer to the time value to be slept.
        rmtp: Pointer to the buffer to store the remaining time value.

    Returns:
        0 on success, or -1 on error.
    """
    return external_call["nanosleep", Int32, c_ptr[Int64], c_ptr[Int64]](
        rqtp, rmtp
    )


def strftime(
    s: c_ptr[Int8], maxsize: Int32, format: c_ptr[Int8], tm: c_ptr[Int64]
) -> Int32:
    """C library <time.h> function `strftime`.

    Reference:
        https://man7.org/linux/man-pages/man3/strftime.3.html

    Args:
        s: Pointer to the buffer to store the formatted time string.
        maxsize: The maximum size of the buffer.
        format: Pointer to the format string.
        tm: Pointer to the time value to be converted.

    Returns:
        The length of the formatted time string.
    """
    return external_call[
        "strftime", Int32, c_ptr[Int8], Int32, c_ptr[Int8], c_ptr[Int64]
    ](s, maxsize, format, tm)


def time(tp: c_ptr[Int64]) -> Int64:
    """C library <time.h> function `time`.

    Reference:
        https://man7.org/linux/man-pages/man3/time.3.html

    Args:
        tp: Pointer to the time value to be converted.

    Returns:
        The time value in seconds since the Epoch.
    """
    return external_call["time", Int64, c_ptr[Int64]](tp)


def timegm(tm: c_ptr[Int64]) -> Int64:
    """C library <time.h> function `timegm`.

    Reference:
        https://man7.org/linux/man-pages/man3/timegm.3.html

    Args:
        tm: Pointer to the time value to be converted.

    Returns:
        The time value in seconds since the Epoch.
    """
    return external_call["timegm", Int64, c_ptr[Int64]](tm)


def timelocal(tm: c_ptr[Int64]) -> Int64:
    """C library <time.h> function `timelocal`.

    Reference:
        https://man7.org/linux/man-pages/man3/timelocal.3.html

    Args:
        tm: Pointer to the time value to be converted.

    Returns:
        The time value in seconds since the Epoch.
    """
    return external_call["timelocal", Int64, c_ptr[Int64]](tm)
