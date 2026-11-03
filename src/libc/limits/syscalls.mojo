# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <limits.h> limits.
#
# Two kinds of number live in this header, and they are worth telling apart.
# The first are the widths of the integer types — what an `Int32` can hold,
# what an `Int64` can — which are the same on both platforms this package
# runs on and are the numbers a caller reads to decide what to cast into.
# The second are the limits the system puts on a process, and those are not
# the same: `PATH_MAX` is 4096 on Linux and 1024 on Darwin, `PIPE_BUF` is
# 4096 and 512, `NGROUPS_MAX` is 65536 and 16. A buffer sized from the
# Linux answer is a buffer that overflows on Darwin, which is why these are
# worth asking for rather than writing down.
#
# Every number here is checked against C on the machine the check runs on,
# by `scripts/check-constants.py`. That matters more here than in most
# modules: these are the constants a caller never reads twice, so a wrong
# one would be wrong silently for as long as it is not exercised.
#
# `MB_LEN_MAX` is the one macro of the header deliberately left out. It
# bounds the bytes a multibyte character can take, 16 on glibc and 6 on
# Darwin, and it is not a number a caller can size anything from — the
# answer for the encoding actually in use is `MB_CUR_MAX`, which is a call
# and not a constant.
from std.sys import CompilationTarget

from libc.constant import (
    c_int,
    c_long,
    c_longlong,
    c_schar,
    c_short,
    c_uchar,
    c_uint,
    c_ulong,
    c_ulonglong,
    c_ushort,
)


# -------------------------------------------------------
#  what a byte is, and what a char holds
# -------------------------------------------------------
comptime CHAR_BIT: c_int = 8
"""Bits in a `char`, and in a byte: 8 on both platforms."""

comptime SCHAR_MIN: c_schar = -128
"""The lowest signed char, `-2**7`."""

comptime SCHAR_MAX: c_schar = 127
"""The highest signed char, `2**7 - 1`."""

comptime UCHAR_MAX: c_uchar = 255
"""The largest unsigned char, `2**8 - 1`."""

comptime CHAR_MIN: c_int = -128
"""The lowest plain `char`.

`char` is signed on both platforms this package runs on, so this is
`SCHAR_MIN` and not 0. C leaves the choice to the implementation, and the
two that matter here both took the same side.
"""

comptime CHAR_MAX: c_int = 127
"""The highest plain `char`, which is `SCHAR_MAX` for the same reason."""


# -------------------------------------------------------
#  the other integer widths
# -------------------------------------------------------
comptime SHRT_MIN: c_short = -32768
"""The lowest `short`, `-2**15`."""

comptime SHRT_MAX: c_short = 32767
"""The highest `short`, `2**15 - 1`."""

comptime USHRT_MAX: c_ushort = 65535
"""The largest `unsigned short`, `2**16 - 1`."""

comptime INT_MIN: c_int = -2147483648
"""The lowest `int`, `-2**31`.

It is worth having for one thing on its own: `EOF` is -1, and the `ctype`
functions are defined for an argument that is an `unsigned char` value or
`EOF` and for nothing else. Every `int` outside `0..255` and -1 is
undefined behaviour there, and this is the far end of that outside.
"""

comptime INT_MAX: c_int = 2147483647
"""The highest `int`, `2**31 - 1`."""

comptime UINT_MAX: c_uint = 4294967295
"""The largest `unsigned int`, `2**32 - 1`."""

comptime LONG_MIN: c_long = -9223372036854775808
"""The lowest `long`, `-2**63`: `long` is 8 bytes on both platforms."""

comptime LONG_MAX: c_long = 9223372036854775807
"""The highest `long`, `2**63 - 1`."""

comptime ULONG_MAX: c_ulong = 18446744073709551615
"""The largest `unsigned long`, `2**64 - 1`."""

comptime LLONG_MIN: c_longlong = -9223372036854775808
"""The lowest `long long`, which is the same number as `LONG_MIN` here.

Darwin and Linux both count `long` as 64 bits, so the two types are the
same width; a platform where `long` is 32 bits would part them.
"""

comptime LLONG_MAX: c_longlong = 9223372036854775807
"""The highest `long long`, the same number as `LONG_MAX` here."""

comptime ULLONG_MAX: c_ulonglong = 18446744073709551615
"""The largest `unsigned long long`, the same number as `ULONG_MAX`."""


# -------------------------------------------------------
#  what the system allows a process
# -------------------------------------------------------
comptime PATH_MAX: c_int = 1024 if CompilationTarget.is_macos() else 4096
"""Bytes in the longest path name, including the terminator.

4096 on Linux and 1024 on Darwin, and it is the size `getcwd` and
`realpath` are asking for: a buffer of this many bytes is enough for any
path the system will hand back, and a smaller one is a call that fails
with `ERANGE` on the one path that happens to be long.
"""

comptime NAME_MAX: c_int = 255
"""Bytes in one file name, not counting the directories above it: 255 on
both platforms."""

comptime PIPE_BUF: c_int = 512 if CompilationTarget.is_macos() else 4096
"""The most that can be written to a pipe in one `write` and still arrive
whole.

4096 on Linux and 512 on Darwin. Two processes each writing no more than
this never interleave their bytes in the pipe; anything larger can be
split, and the pieces of two writers can meet in the middle.
"""

comptime MAX_CANON: c_int = 1024 if CompilationTarget.is_macos() else 255
"""Bytes in a line of terminal input in canonical mode.

255 on Linux and 1024 on Darwin. In canonical mode the line is held until
the newline arrives, and a line longer than this is not held: the terminal
is what has the limit here, not the program, and the difference between
the two platforms is four times over.
"""

comptime MAX_INPUT: c_int = 1024 if CompilationTarget.is_macos() else 255
"""Bytes of terminal input the system will hold before the program reads
any: 255 on Linux and 1024 on Darwin."""

comptime NGROUPS_MAX: c_int = 16 if CompilationTarget.is_macos() else 65536
"""How many supplementary groups `getgroups` can report.

65536 on Linux and 16 on Darwin, which is 4096 times apart and the widest
gap in this file. A `getgroups` buffer sized from the Darwin answer is a
call that fails with `EINVAL` on a Linux machine where the process is in
more than sixteen groups, and one sized from the Linux answer is 256 KB of
`gid_t` where 64 bytes would do.
"""
