"""Tests for the `libc.getopt` bindings.

Taking a command line apart. Each test hands `getopt_long` a small
`argv` of its own and asks which option it said, what argument went
with it, and where it stopped. The state lives in four C globals,
which is the one thing here that is not a function call.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.getopt import (
    Option,
    getopt_long,
    getopt_long_only,
    no_argument,
    optarg,
    opterr,
    optind,
    optopt,
    optional_argument,
    required_argument,
    set_opterr,
    set_optind,
)
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def _short_and_long_options() -> c_ptr[Option]:
    """Two long options -- one taking an argument, one not -- and the
    entry of zeroes that ends the list.
    """
    var longopts = unsafe_alloc[Option](3)
    var one = longopts.unsafe_offset(0)
    one[].name = string_to_char_ptr("output")
    one[].has_arg = required_argument
    one[].flag = null_ptr[Int32]()
    one[].val = Int32(ord("L"))

    var two = longopts.unsafe_offset(1)
    two[].name = string_to_char_ptr("loud")
    two[].has_arg = no_argument
    two[].flag = null_ptr[Int32]()
    two[].val = Int32(ord("V"))

    var end = longopts.unsafe_offset(2)
    end[].name = null_ptr[UInt8]()
    end[].has_arg = 0
    end[].flag = null_ptr[Int32]()
    end[].val = 0
    return longopts


def test_getopt_long_reads_a_short_option() raises:
    """`-o out`: the letter comes back, and the argument is left in
    `optarg`, which is a global and not a return value.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](3)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("-o")
    argv.unsafe_offset(2)[] = string_to_char_ptr("out")

    var longopts = _short_and_long_options()
    set_optind(1)

    var letter = getopt_long(
        3, argv, string_to_char_ptr("o:"), longopts, null_ptr[Int32]()
    )
    assert_equal(Int(letter), ord("o"), "the letter it was asked for")
    assert_equal(char_ptr_to_string(optarg()), "out", "and its argument")

    argv.unsafe_free()
    longopts.unsafe_free()


def test_getopt_long_reads_a_long_option_with_an_equals_sign() raises:
    """`--output=x`: the long option matches, `val` comes back, and the
    part after the `=` is the argument.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](2)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("--output=x")

    var longopts = _short_and_long_options()
    var which = unsafe_alloc[Int32](1)
    set_optind(1)

    var letter = getopt_long(2, argv, string_to_char_ptr("o:"), longopts, which)
    assert_equal(Int(letter), ord("L"), "the val of the option that matched")
    assert_equal(char_ptr_to_string(optarg()), "x", "and the part after the =")
    assert_equal(Int(which[]), 0, "and which of the long options it was")

    argv.unsafe_free()
    longopts.unsafe_free()
    which.unsafe_free()


def test_getopt_long_answers_minus_one_when_there_are_no_more() raises:
    """Once the options have been taken, the next call answers -1 and
    `optind` points at what is left.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](3)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("-o")
    argv.unsafe_offset(2)[] = string_to_char_ptr("out")

    var longopts = _short_and_long_options()
    set_optind(1)

    assert_equal(
        Int(
            getopt_long(
                3, argv, string_to_char_ptr("o:"), longopts, null_ptr[Int32]()
            )
        ),
        ord("o"),
        "the one option there is",
    )
    assert_equal(
        Int(
            getopt_long(
                3, argv, string_to_char_ptr("o:"), longopts, null_ptr[Int32]()
            )
        ),
        -1,
        "and then there is nothing more",
    )
    assert_equal(Int(optind()), 3, "with optind past the end of it")

    argv.unsafe_free()
    longopts.unsafe_free()


def test_getopt_long_reports_an_option_it_was_not_told_about() raises:
    """`-z`, which was never asked for: `?` comes back and `optopt`
    says which letter it was. The complaining is switched off for the
    length of this one call, so that the test says only what it means
    to say.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](2)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("-z")

    var longopts = _short_and_long_options()
    set_optind(1)
    var was = opterr()
    set_opterr(0)

    var letter = getopt_long(
        2, argv, string_to_char_ptr("o:"), longopts, null_ptr[Int32]()
    )
    assert_equal(Int(letter), ord("?"), "not an option it was told about")
    assert_equal(Int(optopt()), ord("z"), "and it says which letter")

    set_opterr(was)

    argv.unsafe_free()
    longopts.unsafe_free()


def test_getopt_long_only_takes_one_dash_for_a_long_option() raises:
    """`-output x` rather than `--output x`, which is the whole
    difference: a single dash is taken for a long option too.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](3)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("-output")
    argv.unsafe_offset(2)[] = string_to_char_ptr("x")

    var longopts = _short_and_long_options()
    var which = unsafe_alloc[Int32](1)
    set_optind(1)

    var letter = getopt_long_only(
        3, argv, string_to_char_ptr("o:"), longopts, which
    )
    assert_equal(Int(letter), ord("L"), "the long option, one dash")
    assert_equal(char_ptr_to_string(optarg()), "x", "and its argument")
    assert_equal(Int(which[]), 0, "and which of the long options it was")

    argv.unsafe_free()
    longopts.unsafe_free()
    which.unsafe_free()


def test_optind_moves_and_can_be_put_back() raises:
    """`optind` is where the next call is to look. It is 1 at the
    start, and putting it back to 1 is how a second command line is
    parsed -- the only way on glibc, which has no `optreset`.
    """
    var argv = unsafe_alloc[c_ptr[UInt8]](3)
    argv.unsafe_offset(0)[] = string_to_char_ptr("prog")
    argv.unsafe_offset(1)[] = string_to_char_ptr("-o")
    argv.unsafe_offset(2)[] = string_to_char_ptr("out")

    var longopts = _short_and_long_options()
    set_optind(1)
    assert_equal(Int(optind()), 1, "it starts at the first word")

    _ = getopt_long(
        3, argv, string_to_char_ptr("o:"), longopts, null_ptr[Int32]()
    )
    assert_equal(Int(optind()), 3, "and moves past the option and its argument")

    set_optind(1)
    assert_equal(Int(optind()), 1, "and it can be put back")

    argv.unsafe_free()
    longopts.unsafe_free()


def main() raises:
    test_getopt_long_reads_a_short_option()
    test_getopt_long_reads_a_long_option_with_an_equals_sign()
    test_getopt_long_answers_minus_one_when_there_are_no_more()
    test_getopt_long_reports_an_option_it_was_not_told_about()
    test_getopt_long_only_takes_one_dash_for_a_long_option()
    test_optind_moves_and_can_be_put_back()
    print("test_getopt: ok")
