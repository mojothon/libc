"""The `tms` struct and the `times` function of `<sys/times.h>`.

This header holds one call and the struct it fills in: how much
processor time this process has had, and how much its children have
had that it has already waited for. It is the older of the two ways of
asking — `clock_gettime` being the newer and the one that can name
which clock it wants — but it is the one that says all four numbers
at once.
"""

from std.ffi import external_call

from libc.constant import c_ptr


struct tms:
    """A C `struct tms`: the processor time `times` reports.

    Four `clock_t`s — this process's user time, its system time, and
    the same two for children it has waited for — at 0, 8, 16 and 24
    on glibc and on Darwin both, thirty-two bytes and eight-aligned
    either way.

    The unit is not a second and is not fixed: it is however many
    clock ticks go into a second, which `sysconf` with `_SC_CLK_TCK`
    is what says. A number here is worth comparing with another
    number here, and not much else.

    The two children's numbers are time used by children this process
    has already waited for. A child that has not been waited for yet
    has its time in nobody's count.
    """

    var tms_utime: Int64
    var tms_stime: Int64
    var tms_cutime: Int64
    var tms_cstime: Int64

    def __init__(out self):
        """Zeroes every member, which is what no time spent looks like."""
        self.tms_utime = 0
        self.tms_stime = 0
        self.tms_cutime = 0
        self.tms_cstime = 0


def times(buffer: c_ptr[tms]) -> Int64:
    """Libc POSIX `times` function.

    Description:
        Says how much processor time this process has had, and how
        much its children have had that it has waited for.

    Args:
        buffer: The `tms` to fill in, which is written to.

    Returns:
        How many clock ticks since some fixed point in the past, or
        -1 where it could not be said, with `errno` saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man2/times.2.html).
        Fn signature: `clock_t times(struct tms *buffer)`.

        What comes back and what goes into `buffer` are not the same
        thing: the number handed back is wall-clock ticks since a
        point this call will not say, and is good only for taking a
        difference with. The four numbers in `buffer` are processor
        time, which is the part worth asking for.

        The tick is not a second. `sysconf` with `_SC_CLK_TCK` says
        how many go into one, and it is not the same number on every
        machine, so a count here is worth comparing with another
        count here and not with a count of seconds.

        `clock` in `libc.time` is the same question in microseconds
        and about this process only; `clock_gettime` is the one that
        names which clock it is asking about.
    """
    return external_call["times", Int64, c_ptr[tms]](buffer)
