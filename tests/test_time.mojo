from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_long, c_ptr
from libc.unistd import geteuid
from libc.sys.stat import timeval
from libc.time import (
    CLOCK_MONOTONIC,
    CLOCK_REALTIME,
    ITIMER_REAL,
    TIME_UTC,
    adjtime,
    asctime,
    asctime_r,
    clock,
    clock_getres,
    clock_gettime,
    clock_settime,
    ctime,
    ctime_r,
    difftime,
    gettimeofday,
    getitimer,
    gmtime,
    gmtime_r,
    itimerval,
    localtime,
    localtime_r,
    mktime,
    nanosleep,
    setitimer,
    strftime,
    strptime,
    time,
    timegm,
    timelocal,
    timespec,
    timespec_get,
    tm,
    tzset,
)
from libc.utils import (
    char_ptr_to_string,
    null_ptr,
    string_to_char_ptr,
    strlen,
)


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


def test_the_ones_that_keep_their_own_buffer() raises:
    """Seven of these had never been called, and they are the ones that
    hand back a pointer into a buffer libc keeps for itself, which is
    why the ones ending in `_r` exist and why each of these is read
    straight away rather than held.

    They are asked about the epoch, because it is the one second that
    reads the same wherever the clock is: `gmtime` reads in Greenwich,
    so what it says about it does not depend on where this is running.
    """
    var zero = unsafe_alloc[c_long](1)
    zero.unsafe_offset(0)[] = 0

    var broken = gmtime(zero)
    assert_true(Int(UInt(broken)) != 0, "gmtime breaks the epoch down")
    var said = char_ptr_to_string(asctime(broken))
    assert_true(said.startswith("Thu Jan  1"), "and asctime reads it back out")
    assert_true(said.endswith("1970\n"), "in nineteen seventy")

    # `ctime` reads in the local time, so what it says about the epoch
    # depends on where this is; only its shape is being asked about.
    var local_said = char_ptr_to_string(ctime(zero))
    assert_true(
        local_said.endswith("\n"), "ctime ends its line as it always does"
    )

    var now = unsafe_alloc[c_long](1)
    now.unsafe_offset(0)[] = 1700000000
    var local = localtime(now)
    assert_true(Int(UInt(local)) != 0, "localtime breaks a time down")
    assert_equal(Int(mktime(local)), 1700000000, "and mktime puts it back")
    assert_equal(Int(timelocal(local)), 1700000000, "as does timelocal")

    var seconds = unsafe_alloc[Int64](2)
    seconds.unsafe_offset(0)[] = 0
    seconds.unsafe_offset(1)[] = 0
    assert_equal(
        gettimeofday(seconds, seconds.unsafe_offset(1)), 0, "gettimeofday"
    )
    assert_true(seconds.unsafe_offset(0)[] > 0, "and it says what time it is")

    now.unsafe_free()
    seconds.unsafe_free()
    zero.unsafe_free()


def test_clock_settime_is_refused_to_an_ordinary_process() raises:
    """`clock_settime` sets the clock, which is a thing only root may
    do, so an ordinary process is refused — and it is the refusing
    that is asked for here rather than the setting.

    It is asked only when whoever is running the tests is not root:
    root would be granted, and the clock of the machine running
    them would move.
    """
    if geteuid() != 0:
        var when = unsafe_alloc[timespec](1)
        when.unsafe_offset(0)[] = timespec(0, 0)
        assert_equal(
            Int(clock_settime(CLOCK_REALTIME, when)),
            -1,
            "an ordinary process is refused the clock",
        )
        when.unsafe_free()


def test_asking_the_clock_how_far_it_is_to_move() raises:
    """`adjtime` asks the system clock to run a little fast or slow
    until it has caught up, rather than to be put forward or back in
    one step.

    Moving the clock is the superuser's to do, and a test is not run
    as one, so what is asked here is only the asking after: a `delta`
    of nothing, which reads how far there is still to go without
    moving anything. That is the one thing about this call that may be
    asked without the right to move the clock, and it is asked twice
    over — once for whether it came back at all, and once for whether
    what it wrote is a time and not a happening.
    """
    var nothing = unsafe_alloc[timeval](1)
    nothing.unsafe_offset(0)[].tv_sec = 0
    nothing.unsafe_offset(0)[].tv_usec = 0

    var left = unsafe_alloc[timeval](1)
    left.unsafe_offset(0)[].tv_sec = 0
    left.unsafe_offset(0)[].tv_usec = 0

    var answered = adjtime(nothing, left)
    # Without the right to move the clock this is -1 with EPERM, which
    # is an answer too: the call was found and asked.
    assert_true(
        answered == 0 or answered == -1,
        "adjtime answers, whether or not the clock may be moved",
    )
    assert_true(
        left.unsafe_offset(0)[].tv_sec < 1000000,
        "and what it wrote down is a time and not a happening",
    )

    left.unsafe_free()
    nothing.unsafe_free()


def test_a_timer_that_is_set_and_taken_back() raises:
    """`setitimer` sets one timer per clock and replaces whatever was
    there, so the setting that comes back through its third argument is
    what is worth reading: it is the call's only way of saying what it
    displaced.

    The repeat is asked for exactly and comes back exactly — it is a
    number that is stored, not a countdown. The time until the first go
    does not: it is already running, so a timer set to ten seconds reads
    back as ten or as nine and a fraction of one.

    Ten seconds and not one, because a test that leaks a timer leaks a
    `SIGALRM`, whose default is to end the process in the middle of
    whatever the suite is doing next. Everything here is set back to
    nothing before it returns, and the reading afterwards is the proof.

    `settimeofday` is in the same header and is not tested: moving the
    wall clock is not something this could put back.
    """
    var nothing = unsafe_alloc[itimerval](1)
    nothing.unsafe_offset(0)[] = itimerval()

    assert_equal(
        setitimer(ITIMER_REAL, nothing, null_ptr[itimerval]()),
        0,
        "a timer set to nothing is a timer that is off",
    )

    var wanted = unsafe_alloc[itimerval](1)
    wanted.unsafe_offset(0)[] = itimerval()
    wanted.unsafe_offset(0)[].it_value_sec = 10
    wanted.unsafe_offset(0)[].it_interval_sec = 3

    var previous = unsafe_alloc[itimerval](1)
    previous.unsafe_offset(0)[] = itimerval()
    assert_equal(
        setitimer(ITIMER_REAL, wanted, previous),
        0,
        "and one set to ten seconds",
    )
    assert_equal(
        previous.unsafe_offset(0)[].it_value_sec,
        0,
        "what it displaced was nothing, which is the whole of what the third",
    )
    assert_equal(
        previous.unsafe_offset(0)[].it_interval_sec, 0, "argument is for"
    )

    var current = unsafe_alloc[itimerval](1)
    current.unsafe_offset(0)[] = itimerval()
    assert_equal(
        getitimer(ITIMER_REAL, current), 0, "and what is set reads back"
    )
    assert_equal(
        current.unsafe_offset(0)[].it_interval_sec,
        3,
        "the repeat as the number it was given",
    )
    assert_equal(
        current.unsafe_offset(0)[].it_interval_usec,
        0,
        "microseconds and all, because nothing counts it down",
    )
    assert_true(
        current.unsafe_offset(0)[].it_value_sec > 0
        and current.unsafe_offset(0)[].it_value_sec <= 10,
        "and the time left is ten seconds or a little less of them",
    )

    assert_equal(
        setitimer(ITIMER_REAL, nothing, previous), 0, "which is then taken back"
    )
    assert_true(
        previous.unsafe_offset(0)[].it_value_sec >= 9
        and previous.unsafe_offset(0)[].it_value_sec <= 10,
        "and the ten seconds that were left come back through the old setting",
    )
    assert_equal(
        previous.unsafe_offset(0)[].it_interval_sec,
        3,
        "along with the repeat, which had not begun to count",
    )

    assert_equal(getitimer(ITIMER_REAL, current), 0, "and it is off afterwards")
    assert_equal(
        current.unsafe_offset(0)[].it_value_sec,
        0,
        "with nothing left to wait for, so no `SIGALRM` is on its way",
    )

    assert_equal(
        setitimer(99, nothing, null_ptr[itimerval]()),
        -1,
        "and a clock that is not a timer is refused rather than guessed at",
    )

    nothing.unsafe_free()
    wanted.unsafe_free()
    previous.unsafe_free()
    current.unsafe_free()


def main() raises:
    test_clock_settime_is_refused_to_an_ordinary_process()
    test_clock_and_time()
    test_utc_round_trip()
    test_strftime()
    test_asctime_and_ctime()
    test_strptime()
    test_clocks()
    test_nanosleep()
    test_localtime()
    test_the_ones_that_keep_their_own_buffer()
    test_a_timer_that_is_set_and_taken_back()
    print("test_time: ok")
