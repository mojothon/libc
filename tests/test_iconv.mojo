"""Tests for the `libc.iconv` bindings.

Converting between encodings is arithmetic on bytes, so nothing here
touches a file: the input is a string in memory and the output is a
buffer in memory. The conversion asked for is UTF-8 to UTF-8, which
every platform has and which copies byte for byte, so the answer is
known without asking what a particular iconv supports.

The failures are the interesting half and both are tested: an encoding
libc does not know, and an output too small for the input.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.iconv import iconv, iconv_close, iconv_open
from libc.utils import char_ptr_to_string, string_to_char_ptr

# `(size_t) -1`, which is how `iconv` says it stopped short. It is not
# an error code in the usual sense — it is the largest number there is.
comptime ICONV_STOPPED = UInt64(0xFFFFFFFFFFFFFFFF)


def test_converting_to_the_encoding_it_is_already_in_copies_the_bytes() raises:
    """UTF-8 in and UTF-8 out is the conversion that does nothing, which
    is the one whose answer is known before asking: five bytes in, five
    the same bytes out, and nothing converted irreversibly.

    What is checked beyond the bytes is that the call moves the caller's
    own four things along: both pointers and both counts, which is how a
    conversion too big for one buffer is done in more than one call.
    """
    var to = string_to_char_ptr("UTF-8")
    var source = string_to_char_ptr("UTF-8")
    var cd = iconv_open(to, source)
    assert_true(Int(UInt(cd)) != -1, "UTF-8 to UTF-8 opens")

    var text = string_to_char_ptr("hello")
    var in_ptr = unsafe_alloc[c_ptr[UInt8]](1)
    in_ptr.unsafe_offset(0)[] = text
    var in_left = unsafe_alloc[UInt64](1)
    in_left.unsafe_offset(0)[] = 5

    var out_bytes = unsafe_alloc[UInt8](16)
    for i in range(16):
        out_bytes.unsafe_offset(i)[] = 0
    var out_ptr = unsafe_alloc[c_ptr[UInt8]](1)
    out_ptr.unsafe_offset(0)[] = out_bytes
    var out_left = unsafe_alloc[UInt64](1)
    out_left.unsafe_offset(0)[] = 16

    var moved = iconv(cd, in_ptr, in_left, out_ptr, out_left)
    assert_equal(moved, UInt64(0), "nothing was converted irreversibly")
    assert_equal(Int(in_left.unsafe_offset(0)[]), 0, "the whole input went")
    assert_equal(
        Int(out_left.unsafe_offset(0)[]), 11, "of sixteen bytes, five used"
    )
    assert_equal(
        char_ptr_to_string(out_bytes), "hello", "and they are the same five"
    )

    assert_equal(iconv_close(cd), 0, "and the conversion closes")

    to.unsafe_free()
    source.unsafe_free()
    text.unsafe_free()
    in_ptr.unsafe_free()
    in_left.unsafe_free()
    out_bytes.unsafe_free()
    out_ptr.unsafe_free()
    out_left.unsafe_free()


def test_an_encoding_libc_does_not_know_is_minus_one() raises:
    """The way `iconv_open` says it has no such encoding is `(iconv_t) -1`
    and not NULL, which is the one thing about this handle that is easy
    to get wrong: `is_null` is asking the wrong question, because an
    address of -1 is not a null address.
    """
    var to = string_to_char_ptr("NO_SUCH_ENCODING_ZZZ")
    var source = string_to_char_ptr("UTF-8")
    var cd = iconv_open(to, source)
    assert_true(Int(UInt(cd)) == -1, "an unknown encoding is -1, not NULL")

    to.unsafe_free()
    source.unsafe_free()


def test_an_output_too_small_stops_the_conversion_where_it_ran_out() raises:
    """Given two bytes of room for five, `iconv` converts two and says
    it stopped: `(size_t) -1` out, and the caller's own counts moved to
    show three bytes of input left and no room at all in the output.

    That is what makes a conversion bigger than a buffer possible — the
    state is kept, so the next call carries on from here.
    """
    var to = string_to_char_ptr("UTF-8")
    var source = string_to_char_ptr("UTF-8")
    var cd = iconv_open(to, source)
    assert_true(Int(UInt(cd)) != -1, "UTF-8 to UTF-8 opens")

    var text = string_to_char_ptr("hello")
    var in_ptr = unsafe_alloc[c_ptr[UInt8]](1)
    in_ptr.unsafe_offset(0)[] = text
    var in_left = unsafe_alloc[UInt64](1)
    in_left.unsafe_offset(0)[] = 5

    var out_bytes = unsafe_alloc[UInt8](2)
    for i in range(2):
        out_bytes.unsafe_offset(i)[] = 0
    var out_ptr = unsafe_alloc[c_ptr[UInt8]](1)
    out_ptr.unsafe_offset(0)[] = out_bytes
    var out_left = unsafe_alloc[UInt64](1)
    out_left.unsafe_offset(0)[] = 2

    var moved = iconv(cd, in_ptr, in_left, out_ptr, out_left)
    assert_equal(moved, ICONV_STOPPED, "two bytes of room is not enough")
    assert_equal(
        Int(in_left.unsafe_offset(0)[]), 3, "three bytes of input left"
    )
    assert_equal(
        Int(out_left.unsafe_offset(0)[]), 0, "and no room in the output"
    )

    assert_equal(iconv_close(cd), 0, "and the conversion closes")

    to.unsafe_free()
    source.unsafe_free()
    text.unsafe_free()
    in_ptr.unsafe_free()
    in_left.unsafe_free()
    out_bytes.unsafe_free()
    out_ptr.unsafe_free()
    out_left.unsafe_free()


def main() raises:
    test_converting_to_the_encoding_it_is_already_in_copies_the_bytes()
    test_an_encoding_libc_does_not_know_is_minus_one()
    test_an_output_too_small_stops_the_conversion_where_it_ran_out()
    print("test_iconv: ok")
