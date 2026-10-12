# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget

from libc.constant import c_int, c_long, c_ptr, c_size_t
from libc.utils import char_ptr_to_string


comptime CLOCK_REALTIME: c_int = 0
comptime CLOCK_MONOTONIC: c_int = 6 if CompilationTarget.is_macos() else 1
comptime TIME_UTC: c_int = 1


struct tm(TrivialRegisterPassable):
    """A C `struct tm`: a broken-down calendar time.

    The first nine members are the C90 ones; `tm_gmtoff` and `tm_zone` are
    the BSD/glibc extensions, and both platforms this package targets have
    them at the same offsets, so one layout covers Linux and Darwin.
    """

    var tm_sec: c_int
    var tm_min: c_int
    var tm_hour: c_int
    var tm_mday: c_int
    var tm_mon: c_int
    var tm_year: c_int
    var tm_wday: c_int
    var tm_yday: c_int
    var tm_isdst: c_int
    var tm_gmtoff: c_long
    # The address of the timezone abbreviation, kept as an integer because a
    # `Pointer` field cannot be null and libc leaves this one null whenever
    # the broken-down time carries no zone.
    var tm_zone: Int

    def __init__(out self):
        """Zeroes every member; `tm_zone` starts out null."""
        self.tm_sec = 0
        self.tm_min = 0
        self.tm_hour = 0
        self.tm_mday = 0
        self.tm_mon = 0
        self.tm_year = 0
        self.tm_wday = 0
        self.tm_yday = 0
        self.tm_isdst = 0
        self.tm_gmtoff = 0
        self.tm_zone = 0

    def __init__(
        out self,
        sec: c_int,
        minute: c_int,
        hour: c_int,
        mday: c_int,
        mon: c_int,
        year: c_int,
    ):
        """Builds a broken-down time; `tm_wday`, `tm_yday` and `tm_isdst`
        are left at 0, which `mktime` and `timegm` recompute anyway.

        Args:
            sec: Seconds after the minute, 0 to 60.
            minute: Minutes after the hour.
            hour: Hours since midnight.
            mday: Day of the month.
            mon: Months since January.
            year: Years since 1900.
        """
        self.tm_sec = sec
        self.tm_min = minute
        self.tm_hour = hour
        self.tm_mday = mday
        self.tm_mon = mon
        self.tm_year = year
        self.tm_wday = 0
        self.tm_yday = 0
        self.tm_isdst = 0
        self.tm_gmtoff = 0
        self.tm_zone = 0

    def zone(self) -> String:
        """Returns the timezone abbreviation `tm_zone` points at.

        Returns:
            The abbreviation, such as `GMT` or `CET`, or an empty string when
            libc left `tm_zone` null.
        """
        if self.tm_zone == 0:
            return ""
        return char_ptr_to_string(
            c_ptr[UInt8](unsafe_from_address=self.tm_zone)
        )


struct timespec(TrivialRegisterPassable):
    """A C `struct timespec`: seconds plus nanoseconds."""

    var tv_sec: c_long
    var tv_nsec: c_long

    def __init__(out self):
        """Zeroes both members."""
        self.tv_sec = 0
        self.tv_nsec = 0

    def __init__(out self, sec: c_long, nsec: c_long):
        """Builds `sec` seconds plus `nsec` nanoseconds.

        Args:
            sec: Whole seconds.
            nsec: Nanoseconds, normally below 1_000_000_000.
        """
        self.tv_sec = sec
        self.tv_nsec = nsec


def clock() -> Int64:
    """Libc C89 `clock` function.

    Returns:
        The processor time consumed by the program so far, in `CLOCKS_PER_SEC`
        ticks. Divide by `CLOCKS_PER_SEC` to get seconds.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/clock.3.html).
        Fn signature: `clock_t clock(void)`.
    """
    return external_call["clock", Int64]()


def time(tloc: c_ptr[c_long]) -> c_long:
    """Libc C89 `time` function.

    Args:
        tloc: Where to store the time as well, or a null pointer.

    Returns:
        Seconds since the Epoch, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/time.2.html).
        Fn signature: `time_t time(time_t *tloc)`.
    """
    return external_call["time", c_long, c_ptr[c_long]](tloc)


def time() -> c_long:
    """Libc C89 `time` function, without a destination.

    Returns:
        Seconds since the Epoch, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/time.2.html).
        Fn signature: `time_t time(time_t *tloc)`.
    """
    var slot = unsafe_alloc[Int64](1)
    slot[] = 0
    return time(slot)


def difftime(time1: c_long, time0: c_long) -> Float64:
    """Libc C89 `difftime` function.

    Args:
        time1: The later time.
        time0: The earlier time.

    Returns:
        `time1 - time0`, in seconds.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/difftime.3.html).
        Fn signature: `double difftime(time_t time1, time_t time0)`.
    """
    return external_call["difftime", Float64, c_long, c_long](time1, time0)


def gmtime(timep: c_ptr[c_long]) -> c_ptr[tm]:
    """Libc C89 `gmtime` function.

    Args:
        timep: Seconds since the Epoch.

    Returns:
        A pointer to a static broken-down time in UTC, overwritten by the
        next call, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/gmtime.3.html).
        Fn signature: `struct tm *gmtime(const time_t *timep)`.
    """
    return external_call["gmtime", c_ptr[tm], c_ptr[c_long]](timep)


def gmtime_r(timep: c_ptr[c_long], result: c_ptr[tm]) -> c_ptr[tm]:
    """Libc POSIX `gmtime_r` function.

    Args:
        timep: Seconds since the Epoch.
        result: Where to store the broken-down time.

    Returns:
        `result`, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/gmtime.3.html).
        Fn signature: `struct tm *gmtime_r(const time_t *timep, struct tm *result)`.
    """
    return external_call["gmtime_r", c_ptr[tm], c_ptr[c_long], c_ptr[tm]](
        timep, result
    )


def localtime(timep: c_ptr[c_long]) -> c_ptr[tm]:
    """Libc C89 `localtime` function.

    Args:
        timep: Seconds since the Epoch.

    Returns:
        A pointer to a static broken-down time in local time, overwritten by
        the next call, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/localtime.3.html).
        Fn signature: `struct tm *localtime(const time_t *timep)`.
    """
    return external_call["localtime", c_ptr[tm], c_ptr[c_long]](timep)


def localtime_r(timep: c_ptr[c_long], result: c_ptr[tm]) -> c_ptr[tm]:
    """Libc POSIX `localtime_r` function.

    Args:
        timep: Seconds since the Epoch.
        result: Where to store the broken-down time.

    Returns:
        `result`, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/localtime.3.html).
        Fn signature: `struct tm *localtime_r(const time_t *timep, struct tm *result)`.
    """
    return external_call["localtime_r", c_ptr[tm], c_ptr[c_long], c_ptr[tm]](
        timep, result
    )


def mktime(broken: c_ptr[tm]) -> c_long:
    """Libc C89 `mktime` function.

    Args:
        broken: A broken-down time, read as local time. `tm_wday` and `tm_yday`
            are ignored on input and written on output.

    Returns:
        Seconds since the Epoch, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/mktime.3.html).
        Fn signature: `time_t mktime(struct tm *tm)`.
    """
    return external_call["mktime", c_long, c_ptr[tm]](broken)


def timegm(broken: c_ptr[tm]) -> c_long:
    """Libc BSD `timegm` function.

    Args:
        broken: A broken-down time, read as UTC.

    Returns:
        Seconds since the Epoch, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/timegm.3.html).
        Fn signature: `time_t timegm(struct tm *tm)`.

        Unlike `mktime`, this ignores `TZ` and the `tm_gmtoff` member, which
        is what makes its result deterministic.
    """
    return external_call["timegm", c_long, c_ptr[tm]](broken)


def timelocal(broken: c_ptr[tm]) -> c_long:
    """Libc BSD `timelocal` function.

    Args:
        broken: A broken-down time, read as local time.

    Returns:
        Seconds since the Epoch, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/timelocal.3.html).
        Fn signature: `time_t timelocal(struct tm *tm)`.

        An alias for `mktime` that glibc and Darwin both keep for
        compatibility. Prefer `mktime`.
    """
    return external_call["timelocal", c_long, c_ptr[tm]](broken)


def asctime(broken: c_ptr[tm]) -> c_ptr[UInt8]:
    """Libc C89 `asctime` function.

    Args:
        broken: A broken-down time.

    Returns:
        A pointer to a static 26-byte string ending in a newline, overwritten
        by the next call.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/asctime.3.html).
        Fn signature: `char *asctime(const struct tm *tm)`.
    """
    return external_call["asctime", c_ptr[UInt8], c_ptr[tm]](broken)


def asctime_r(broken: c_ptr[tm], buf: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc POSIX `asctime_r` function.

    Args:
        broken: A broken-down time.
        buf: Where to write the string; 26 bytes is enough.

    Returns:
        `buf`, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/asctime.3.html).
        Fn signature: `char *asctime_r(const struct tm *tm, char *buf)`.
    """
    return external_call["asctime_r", c_ptr[UInt8], c_ptr[tm], c_ptr[UInt8]](
        broken, buf
    )


def ctime(timep: c_ptr[c_long]) -> c_ptr[UInt8]:
    """Libc C89 `ctime` function.

    Args:
        timep: Seconds since the Epoch.

    Returns:
        A pointer to a static string in local time, ending in a newline.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ctime.3.html).
        Fn signature: `char *ctime(const time_t *timep)`.
    """
    return external_call["ctime", c_ptr[UInt8], c_ptr[c_long]](timep)


def ctime_r(timep: c_ptr[c_long], buf: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """Libc POSIX `ctime_r` function.

    Args:
        timep: Seconds since the Epoch.
        buf: Where to write the string; 26 bytes is enough.

    Returns:
        `buf`, or a null pointer on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ctime.3.html).
        Fn signature: `char *ctime_r(const time_t *timep, char *buf)`.
    """
    return external_call["ctime_r", c_ptr[UInt8], c_ptr[c_long], c_ptr[UInt8]](
        timep, buf
    )


def strftime(
    buf: c_ptr[UInt8],
    maxsize: c_size_t,
    format: c_ptr[UInt8],
    broken: c_ptr[tm],
) -> c_size_t:
    """Libc C89 `strftime` function.

    Args:
        buf: Where to write the formatted string.
        maxsize: The size of `buf`, including room for the null byte.
        format: A `strftime` format string.
        broken: A broken-down time.

    Returns:
        The number of bytes written, excluding the null byte, or 0 if the
        result did not fit.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strftime.3.html).
        Fn signature: `size_t strftime(char *buf, size_t maxsize, const char *format, const struct tm *tm)`.
    """
    return external_call[
        "strftime", c_size_t, c_ptr[UInt8], c_size_t, c_ptr[UInt8], c_ptr[tm]
    ](buf, maxsize, format, broken)


def strptime(
    buf: c_ptr[UInt8], format: c_ptr[UInt8], broken: c_ptr[tm]
) -> c_ptr[UInt8]:
    """Libc POSIX `strptime` function.

    Args:
        buf: The string to parse.
        format: A `strftime`-style format string.
        broken: Where to store the parsed time. Members the format does not
            mention are left alone, so zero `tm` first.

    Returns:
        A pointer to the first byte of `buf` that was not consumed, or a null
        pointer if the format did not match.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/strptime.3.html).
        Fn signature: `char *strptime(const char *buf, const char *format, struct tm *tm)`.
    """
    return external_call[
        "strptime", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8], c_ptr[tm]
    ](buf, format, broken)


def clock_gettime(clockid: c_int, tp: c_ptr[timespec]) -> c_int:
    """Libc POSIX `clock_gettime` function.

    Args:
        clockid: A clock id, such as `CLOCK_REALTIME` or `CLOCK_MONOTONIC`.
        tp: Where to store the time.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/clock_gettime.3.html).
        Fn signature: `int clock_gettime(clockid_t clockid, struct timespec *tp)`.
    """
    return external_call["clock_gettime", c_int, c_int, c_ptr[timespec]](
        clockid, tp
    )


def clock_getres(clockid: c_int, tp: c_ptr[timespec]) -> c_int:
    """Libc POSIX `clock_getres` function.

    Args:
        clockid: A clock id, such as `CLOCK_REALTIME` or `CLOCK_MONOTONIC`.
        tp: Where to store the clock's resolution.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/clock_getres.3.html).
        Fn signature: `int clock_getres(clockid_t clockid, struct timespec *res)`.
    """
    return external_call["clock_getres", c_int, c_int, c_ptr[timespec]](
        clockid, tp
    )


def clock_settime(clockid: c_int, tp: c_ptr[timespec]) -> c_int:
    """Libc POSIX `clock_settime` function.

    Args:
        clockid: A clock id, such as `CLOCK_REALTIME`.
        tp: The time to set.

    Returns:
        0 on success, or -1 on error. `EPERM` unless the caller is privileged.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/clock_settime.3.html).
        Fn signature: `int clock_settime(clockid_t clockid, const struct timespec *tp)`.
    """
    return external_call["clock_settime", c_int, c_int, c_ptr[timespec]](
        clockid, tp
    )


def nanosleep(rqtp: c_ptr[timespec], rmtp: c_ptr[timespec]) -> c_int:
    """Libc POSIX `nanosleep` function.

    Args:
        rqtp: How long to sleep.
        rmtp: Where to store the time left if a signal interrupts the sleep,
            or a null pointer.

    Returns:
        0 once the sleep completes, or -1 if a signal interrupted it.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/nanosleep.2.html).
        Fn signature: `int nanosleep(const struct timespec *rqtp, struct timespec *rmtp)`.
    """
    return external_call["nanosleep", c_int, c_ptr[timespec], c_ptr[timespec]](
        rqtp, rmtp
    )


def timespec_get(ts: c_ptr[timespec], base: c_int) -> c_int:
    """Libc C11 `timespec_get` function.

    Args:
        ts: Where to store the current time.
        base: The time base; `TIME_UTC` is the only one the standard defines.

    Returns:
        `base` on success, or 0 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/timespec_get.3.html).
        Fn signature: `int timespec_get(struct timespec *ts, int base)`.
    """
    return external_call["timespec_get", c_int, c_ptr[timespec], c_int](
        ts, base
    )


def tzset() raises:
    """Libc POSIX `tzset` function.

    Reads `TZ` and sets the `timezone`, `daylight` and `tzname` globals that
    `localtime` and friends consult, so call it after changing `TZ`.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/tzset.3.html).
        Fn signature: `void tzset(void)`.
    """
    external_call["tzset", NoneType]()


def gettimeofday(tv: c_ptr[Int64], tz: c_ptr[Int64]) -> c_int:
    """Libc POSIX `gettimeofday` function.

    Args:
        tv: Two slots, holding `tv_sec` and then `tv_usec`.
        tz: Obsolete timezone slot; pass a null pointer.

    Returns:
        0 on success, or -1 on error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/gettimeofday.2.html).
        Fn signature: `int gettimeofday(struct timeval *tv, struct timezone *tz)`.

        `struct timeval` is modelled as two slots rather than a struct because
        `tv_usec` is a 32-bit `suseconds_t` on Darwin and a 64-bit `long` on
        Linux; on Darwin only the low half of the second slot is meaningful.
    """
    return external_call["gettimeofday", c_int, c_ptr[Int64], c_ptr[Int64]](
        tv, tz
    )
