"""Tests for the `libc.limits` constants.

A constant is the one thing a test cannot really catch: the number and the
assertion both come from whoever wrote them down, so a test that repeats
`INT_MAX == 2147483647` is a second copy of the same chance of being wrong.
`scripts/check-constants.py` is what catches a wrong value, by asking the C
compiler on each platform; these tests ask what the numbers *mean*.

Three kinds of that. The relations that have to hold whichever numbers are
right: every unsigned max is `2 * signed_max + 1`, every signed min is
`-signed_max - 1`, and the arithmetic is done one type wider so that the
check cannot overflow the way the constants themselves could. The pairs
that two platforms could part and these do not: `long` and `long long` are
both 8 bytes, and `char` is signed. And the two calls the file limits are
for — a `PATH_MAX` buffer holds the working directory, and `PIPE_BUF` bytes
go into a pipe in one `write` that neither blocks nor gets split.

The numbers that do differ between Linux and Darwin are the interesting
ones, and they are deliberately not written out here: `PATH_MAX`,
`PIPE_BUF`, `MAX_CANON`, `MAX_INPUT` and `NGROUPS_MAX` are asserted to be
usable, not to be a particular value, because a value in a test is a value
that has to be kept in step with the one in the module.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_size_t, c_uint
from libc.limits import (
    CHAR_BIT,
    CHAR_MAX,
    CHAR_MIN,
    INT_MAX,
    INT_MIN,
    LLONG_MAX,
    LLONG_MIN,
    LONG_MAX,
    LONG_MIN,
    MAX_CANON,
    MAX_INPUT,
    NAME_MAX,
    NGROUPS_MAX,
    PATH_MAX,
    PIPE_BUF,
    SCHAR_MAX,
    SCHAR_MIN,
    SHRT_MAX,
    SHRT_MIN,
    UCHAR_MAX,
    UINT_MAX,
    ULLONG_MAX,
    ULONG_MAX,
    USHRT_MAX,
)
from libc.stdlib import PATH_MAX as STDLIB_PATH_MAX
from libc.stdlib import free, malloc
from libc.string import memset
from libc.unistd import close, getcwd, getgroups, pipe, write
from libc.utils import null_ptr


def test_every_unsigned_max_is_the_signed_one_doubled() raises:
    """`UCHAR_MAX`, `USHRT_MAX`, ... are `2 * max + 1`, one type wider."""
    assert_equal(CHAR_BIT, 8, "a byte is 8 bits")
    assert_equal(2 * Int64(SCHAR_MAX) + 1, Int64(UCHAR_MAX), "char is 8 bits")
    assert_equal(2 * Int64(SHRT_MAX) + 1, Int64(USHRT_MAX), "short is 16 bits")
    assert_equal(2 * Int64(INT_MAX) + 1, Int64(UINT_MAX), "int is 32 bits")

    # In `UInt64`, because `2 * LONG_MAX + 1` is one more than an `Int64`
    # holds — which is the point of the assertion.
    assert_equal(UInt64(LONG_MAX) * 2 + 1, UInt64(ULONG_MAX), "long is 64 bits")
    assert_equal(UInt64(LLONG_MAX) * 2 + 1, UInt64(ULLONG_MAX))


def test_every_signed_min_is_one_below_the_negated_max() raises:
    """Two's complement, and nothing else: `MIN == -MAX - 1` at every width."""
    assert_equal(Int64(SCHAR_MIN), -Int64(SCHAR_MAX) - 1)
    assert_equal(Int64(SHRT_MIN), -Int64(SHRT_MAX) - 1)
    assert_equal(Int64(INT_MIN), -Int64(INT_MAX) - 1)
    assert_equal(Int64(LONG_MIN), -Int64(LONG_MAX) - 1)
    assert_equal(Int64(LLONG_MIN), -Int64(LLONG_MAX) - 1)


def test_the_choices_that_could_have_gone_either_way() raises:
    """Where C leaves something to the implementation, both took the same side.
    """
    assert_equal(Int64(CHAR_MIN), Int64(SCHAR_MIN), "char is signed")
    assert_equal(Int64(CHAR_MAX), Int64(SCHAR_MAX))
    assert_equal(
        Int64(LONG_MAX), Int64(LLONG_MAX), "long is as wide as long long"
    )
    assert_equal(UInt64(ULONG_MAX), UInt64(ULLONG_MAX))
    assert_true(Int64(INT_MAX) < Int64(LONG_MAX), "and int is not")
    assert_true(Int64(INT_MIN) < -1, "`EOF` is the lowest value ctype accepts")


def test_a_path_max_buffer_holds_the_working_directory() raises:
    """The number `getcwd` and `realpath` want, spent on `getcwd`."""
    assert_true(NAME_MAX >= 1)
    assert_true(
        PATH_MAX > NAME_MAX, "a path is a name with directories around it"
    )
    assert_equal(
        PATH_MAX, STDLIB_PATH_MAX, "one number, wherever it is imported from"
    )

    var buf = malloc(c_size_t(PATH_MAX))
    var cwd = getcwd(buf, UInt64(PATH_MAX))
    assert_equal(
        Int(cwd), Int(buf), "a buffer of PATH_MAX is enough for the path"
    )
    assert_equal(
        Int(buf.unsafe_load(0)),
        0x2F,
        "and the path it holds starts at the root",
    )
    _ = free(buf)


def test_a_pipe_takes_a_pipe_buf_in_one_write() raises:
    """`PIPE_BUF` is a promise about one `write`, so ask one to keep it."""
    var fds = unsafe_alloc[Int32](2)
    assert_equal(pipe(fds), 0, "two ends of a pipe")

    var chunk = malloc(c_size_t(PIPE_BUF))
    _ = memset(chunk.unsafe_bitcast[NoneType](), 0x41, UInt64(PIPE_BUF))

    # The write is one write of exactly the number the constant names: a
    # pipe that is empty takes it whole, and the answer is the whole count
    # rather than a short write.
    var written = write(fds.unsafe_load(1), chunk, UInt32(PIPE_BUF))
    assert_equal(written, Int(PIPE_BUF), "PIPE_BUF bytes, written once")

    _ = close(fds.unsafe_load(0))
    _ = close(fds.unsafe_load(1))
    _ = free(chunk)
    fds.unsafe_free()


def test_the_limits_a_terminal_and_a_group_list_have() raises:
    """The three that are about something other than a buffer of bytes."""
    assert_true(MAX_CANON > 0, "a line of terminal input has some room")
    assert_true(MAX_INPUT > 0)

    # `getgroups(0, NULL)` answers how many there are without writing any,
    # and the constant is the most it can answer.
    var count = getgroups(0, null_ptr[c_uint]())
    assert_true(count >= 0, "asking costs nothing")
    assert_true(count <= NGROUPS_MAX, "and is never more than NGROUPS_MAX")


def main() raises:
    test_every_unsigned_max_is_the_signed_one_doubled()
    test_every_signed_min_is_one_below_the_negated_max()
    test_the_choices_that_could_have_gone_either_way()
    test_a_path_max_buffer_holds_the_working_directory()
    test_a_pipe_takes_a_pipe_buf_in_one_write()
    test_the_limits_a_terminal_and_a_group_list_have()
    print("test_limits: ok")
