from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.time import (
    CLOCK_MONOTONIC,
    CLOCK_REALTIME,
    TIME_UTC,
    asctime_r,
    clock,
    clock_getres,
    clock_gettime,
    ctime_r,
    difftime,
    gmtime_r,
    localtime_r,
    nanosleep,
    strftime,
    strptime,
    time,
    timegm,
    timespec,
    timespec_get,
    tm,
    tzset,
)
from libc.utils import char_ptr_to_string, string_to_char_ptr, strlen


def test_clock_and_time() raises:
    var now = time()
    assert_true(now > 1700000000, "time() is after 2023")

    var slot = unsafe_alloc[Int64](1)
    slot[] = 0
    assert_true(time(slot) > 1700000000, "time(tloc) agrees")
    assert_true(slot[] > 1700000000, "time(tloc) stored it too")

    assert_equal(difftime(1_000_000_010, 1_000_000_000), 10.0)
    assert_equal(difftime(5, 10), -5.0)

    assert_true(clock() >= 0, "clock() is not negative")


def test_utc_round_trip() raises:
    # 2026-03-04 05:06:07 UTC, the way struct tm spells it.
    var want = tm(sec=7, minute=6, hour=5, mday=4, mon=2, year=126)
    var slot = unsafe_alloc[tm](1)
    slot[] = want

    var epoch = unsafe_alloc[Int64](1)
    epoch[] = timegm(slot)
    assert_true(
        epoch[] > 1_772_000_000 and epoch[] < 1_773_000_000,
        "timegm lands in March 2026",
    )

    var utc = unsafe_alloc[tm](1)
    utc[] = tm()
    assert_true(Int(gmtime_r(epoch, utc)) != 0, "gmtime_r returned a struct")

    var got = utc[]
    assert_equal(Int(got.tm_gmtoff), 0)
    if got.tm_zone != 0:
        assert_true(got.zone().byte_length() > 0, "the zone has a name")
    assert_equal(Int(got.tm_sec), 7)
    assert_equal(Int(got.tm_min), 6)
    assert_equal(Int(got.tm_hour), 5)
    assert_equal(Int(got.tm_mday), 4)
    assert_equal(Int(got.tm_mon), 2)
    assert_equal(Int(got.tm_year), 126)


def test_strftime() raises:
    var slot = unsafe_alloc[tm](1)
    slot[] = tm(sec=7, minute=6, hour=5, mday=4, mon=2, year=126)

    var buf = unsafe_alloc[UInt8](64)
    var n = strftime(buf, 64, string_to_char_ptr("%Y-%m-%d %H:%M:%S"), slot)
    assert_equal(Int(n), 19)
    assert_equal(char_ptr_to_string(buf), "2026-03-04 05:06:07")

    # Too small a buffer writes nothing and reports 0.
    var small = unsafe_alloc[UInt8](4)
    assert_equal(
        Int(strftime(small, 4, string_to_char_ptr("%Y-%m-%d"), slot)), 0
    )


def test_asctime_and_ctime() raises:
    var slot = unsafe_alloc[tm](1)
    slot[] = tm(sec=7, minute=6, hour=5, mday=4, mon=2, year=126)

    var buf = unsafe_alloc[UInt8](26)
    assert_true(Int(asctime_r(slot, buf)) != 0, "asctime_r returned a string")
    assert_equal(strlen(buf), 25)
    assert_true(
        char_ptr_to_string(buf).endswith("2026\n"), "asctime_r names the year"
    )

    var epoch = unsafe_alloc[Int64](1)
    epoch[] = 1_800_000_000
    assert_true(Int(ctime_r(epoch, buf)) != 0, "ctime_r returned a string")
    assert_equal(strlen(buf), 25)


def test_strptime() raises:
    var slot = unsafe_alloc[tm](1)
    slot[] = tm()

    var rest = strptime(
        string_to_char_ptr("2026-03-04 05:06:07"),
        string_to_char_ptr("%Y-%m-%d %H:%M:%S"),
        slot,
    )
    assert_true(Int(rest) != 0, "strptime consumed the whole format")

    var got = slot[]
    assert_equal(Int(got.tm_year), 126)
    assert_equal(Int(got.tm_mon), 2)
    assert_equal(Int(got.tm_mday), 4)
    assert_equal(Int(got.tm_hour), 5)
    assert_equal(Int(got.tm_min), 6)
    assert_equal(Int(got.tm_sec), 7)

    # A format that does not match reports failure.
    var bad = unsafe_alloc[tm](1)
    bad[] = tm()
    assert_true(
        Int(
            strptime(
                string_to_char_ptr("nope"),
                string_to_char_ptr("%Y-%m-%d"),
                bad,
            )
        )
        == 0
    )


def test_clocks() raises:
    var ts = unsafe_alloc[timespec](1)

    ts[] = timespec()
    assert_equal(Int(clock_gettime(CLOCK_REALTIME, ts)), 0)
    assert_true(ts[].tv_sec > 1_700_000_000, "realtime is now")

    ts[] = timespec()
    assert_equal(Int(clock_gettime(CLOCK_MONOTONIC, ts)), 0)
    assert_true(ts[].tv_sec > 0, "monotonic has been running")

    ts[] = timespec()
    assert_equal(Int(clock_getres(CLOCK_MONOTONIC, ts)), 0)

    # timespec_get is C11, which Darwin's libSystem only picked up recently.
    comptime if not CompilationTarget.is_macos():
        ts[] = timespec()
        assert_equal(Int(timespec_get(ts, TIME_UTC)), Int(TIME_UTC))
        assert_true(ts[].tv_sec > 1_700_000_000, "C11 time is now")


def test_nanosleep() raises:
    var req = unsafe_alloc[timespec](1)
    req[] = timespec(0, 1_000_000)
    var rem = unsafe_alloc[timespec](1)
    rem[] = timespec()
    assert_equal(Int(nanosleep(req, rem)), 0)


def test_localtime() raises:
    var epoch = unsafe_alloc[Int64](1)
    epoch[] = 1_800_000_000
    var slot = unsafe_alloc[tm](1)
    slot[] = tm()

    assert_true(Int(localtime_r(epoch, slot)) != 0, "localtime_r succeeded")
    # 1800000000 is 2027-01-15 wherever the machine is, give or take a day.
    assert_true(Int(slot[].tm_year) >= 126, "year is 2026 or later")

    # Re-reading TZ must not disturb the broken-down time already produced.
    tzset()


def main() raises:
    test_clock_and_time()
    test_utc_round_trip()
    test_strftime()
    test_asctime_and_ctime()
    test_strptime()
    test_clocks()
    test_nanosleep()
    test_localtime()
    print("test_time: ok")
