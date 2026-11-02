"""Tests for the `libc.sys.sysinfo` bindings.

`<sys/sysinfo.h>` is Linux's and nobody else's — Darwin has no such
header and no such calls — so every one of these is made only where
there is something to call, and the file says so rather than quietly
passing.

What the tests lean on is that two of these calls answer the same
question as two already bound: `get_nprocs` is what `sysconf` says for
`SC_NPROCESSORS_ONLN`, and the memory `get_phys_pages` counts is the
`totalram` that `sysinfo` writes down, a page at a time. Those are the
only checks here that do not need a machine of a known size, and they
are the reason a wrong argument or a struct read at the wrong offset
cannot pass unnoticed.

The rest are facts about the moment: memory free is memory free right
now, and how much there is was somebody else's to change.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.sys.sysinfo import (
    Sysinfo,
    get_avphys_pages,
    get_nprocs,
    get_nprocs_conf,
    get_phys_pages,
    sysinfo,
)
from libc.unistd import SC_NPROCESSORS_ONLN, SC_PAGESIZE, sysconf


def test_the_number_of_processors_is_the_one_sysconf_gives() raises:
    """Two bindings for one number: `get_nprocs` counts the processors
    that are online, and `sysconf` asked for `SC_NPROCESSORS_ONLN`
    counts the same ones. A machine that has taken a processor offline
    is the only kind on which the two could differ, and neither this
    call nor that one is the place to look for it.
    """
    comptime if not CompilationTarget.is_macos():
        var online = Int(get_nprocs())
        assert_true(online >= 1, "there is at least one processor")
        assert_equal(
            online,
            Int(sysconf(SC_NPROCESSORS_ONLN)),
            "which is what sysconf says is online",
        )

        assert_true(
            Int(get_nprocs_conf()) >= online,
            "and the machine was configured with at least that many",
        )


def test_the_memory_pages_and_the_memory_bytes_are_one_amount() raises:
    """The one check on these numbers that needs nothing of the
    machine: `get_phys_pages` counts memory in pages, `sysinfo` writes
    `totalram` down in units of `mem_unit` bytes, and the two are the
    same amount of memory arrived at two ways.

    Which makes it a check on the struct as well as on the call — a
    `totalram` read at the wrong offset, or a `mem_unit` read as eight
    bytes instead of four, is a different number than the one the
    pages come to.
    """
    comptime if not CompilationTarget.is_macos():
        var pages = Int(get_phys_pages())
        var pagesize = Int(sysconf(SC_PAGESIZE))
        var available = Int(get_avphys_pages())
        assert_true(pages > 0, "the machine has memory")
        assert_true(available > 0, "and some of it can be had")
        assert_true(
            available <= pages,
            "but no more than there is, which is the whole of it",
        )

        var info = unsafe_alloc[Sysinfo](1)
        info[] = Sysinfo()
        assert_equal(
            Int(sysinfo(info)), 0, "sysinfo writes the whole of it down"
        )

        var got = info
        assert_true(got[].mem_unit() >= 1, "a unit of memory is some bytes")
        assert_equal(
            pages * pagesize,
            got[].totalram() * got[].mem_unit(),
            "the same memory, counted in pages and counted in bytes",
        )


def test_what_sysinfo_says_about_the_moment() raises:
    """The numbers in here that are about right now rather than about
    the machine: how long it has been up, how many processes are
    running on it, and how much of its memory and swap are going
    unused. Nothing of it can be written down ahead of time, so what
    is asked is that each is a number a machine could honestly give —
    an uptime that is not negative, a process count that is not zero,
    and a swap that is not more full than it is large.
    """
    comptime if not CompilationTarget.is_macos():
        var info = unsafe_alloc[Sysinfo](1)
        info[] = Sysinfo()
        assert_equal(Int(sysinfo(info)), 0, "sysinfo writes it down")

        var got = info
        assert_true(got[].uptime() > 0, "the machine has been up a while")
        assert_true(got[].procs() > 0, "and is running processes")
        assert_true(got[].totalram() > 0, "with memory in it")
        assert_true(
            got[].freeram() <= got[].totalram(), "no more free than there is"
        )
        assert_true(
            got[].freeswap() <= got[].totalswap(),
            "and no more swap free than there is swap",
        )

        # The loads are scaled: three of them, the minute, the five
        # minutes and the quarter hour, and none of them negative.
        for i in range(3):
            assert_true(
                got[].loads(i) >= 0, "a load average is not a negative number"
            )

        # High memory is what a 64-bit machine has none of, and the two
        # that count it say so rather than failing.
        assert_equal(got[].totalhigh(), 0, "there is no high memory here")


def main() raises:
    test_the_number_of_processors_is_the_one_sysconf_gives()
    test_the_memory_pages_and_the_memory_bytes_are_one_amount()
    test_what_sysinfo_says_about_the_moment()
    print("test_sysinfo: ok")
