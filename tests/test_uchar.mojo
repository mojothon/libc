"""Tests for the `libc.uchar` bindings.

Linux only: Darwin has no `<uchar.h>` at all, so everything here is made
behind a `comptime if`, which is what `test_epoll` does.

What makes these worth asking is that three of the four answers are not byte
counts. `mbrtoc16` on a character above U+FFFF consumes four bytes and writes
the high surrogate, and the low one comes back from the next call as
`(size_t) -3` with nothing read: a loop that takes every answer for a count
drops half of every character outside the BMP, and nothing about the binding
says so. `c16rtomb` has the same pair the other way round — the high half
answers 0 and writes nothing, and all four bytes arrive with the low half.
Both directions are asked, and so is the pair of them being joined by the
state rather than by anything the caller keeps.

The other two answers are why there is no character: `-2` is the state
holding the start of one, which is what a stream read in chunks hands it, and
`-1` with `EILSEQ` is a byte that is not one at all. The last test asks the
two things glibc does not do the way C11 says — a null output pointer and a
code point above U+10FFFF — because a caller who assumes the standard here
gets 1 where the length was wanted, and four bytes of something that is not
UTF-8 where a refusal was.
"""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import EILSEQ, c_ptr
from libc.errno import get_errno, set_errno
from libc.locale import LC_CTYPE, Locale, freelocale, newlocale, uselocale
from libc.string import memset
from libc.uchar import c16rtomb, c32rtomb, mbrtoc16, mbrtoc32
from libc.utils import null_ptr, string_to_char_ptr
from libc.wchar import mbstate_t

# `mbstate_t` here is four 64-bit slots, and zero is the initial state.
comptime STATE_BYTES = 32

# `newlocale` takes a mask and `setlocale` takes a category, and the two are
# not the same numbers: `LC_CTYPE` is 0, and `LC_CTYPE_MASK` is `1 << 0`. A
# category handed to `newlocale` gives back an object that changes nothing,
# without an error, which is what the first run of this test did.
comptime LC_CTYPE_MASK: Int32 = Int32(1) << LC_CTYPE


def _initial(ps: c_ptr[mbstate_t]):
    """Put the state back to the way a fresh thread finds it."""
    _ = memset(ps.unsafe_bitcast[NoneType](), 0, STATE_BYTES)


def test_utf32_round_trip() raises:
    """A one, three and four byte character, written out and read back."""
    var st = unsafe_alloc[mbstate_t](1)
    var bytes = unsafe_alloc[UInt8](8)
    var ch = unsafe_alloc[UInt32](1)

    _initial(st)
    assert_equal(Int(c32rtomb(bytes, 0x41, st)), 1, "A is one byte")
    assert_equal(Int(bytes.unsafe_load(0)), 0x41, "and the byte is A")

    _initial(st)
    assert_equal(Int(c32rtomb(bytes, 0x20AC, st)), 3, "the euro sign is three")
    assert_equal(Int(bytes.unsafe_load(0)), 0xE2, "E2 82 AC")
    assert_equal(Int(bytes.unsafe_load(1)), 0x82, "E2 82 AC")
    assert_equal(Int(bytes.unsafe_load(2)), 0xAC, "E2 82 AC")

    _initial(st)
    assert_equal(Int(c32rtomb(bytes, 0x1D11E, st)), 4, "and the clef is four")
    assert_equal(Int(bytes.unsafe_load(0)), 0xF0, "F0 9D 84 9E")
    assert_equal(Int(bytes.unsafe_load(1)), 0x9D, "F0 9D 84 9E")
    assert_equal(Int(bytes.unsafe_load(2)), 0x84, "F0 9D 84 9E")
    assert_equal(Int(bytes.unsafe_load(3)), 0x9E, "F0 9D 84 9E")

    # The same bytes back: four of them, and one character out.
    _initial(st)
    assert_equal(
        Int(mbrtoc32(ch, bytes, 4, st)), 4, "four bytes make one char32"
    )
    assert_equal(
        Int(ch.unsafe_load()), 0x1D11E, "and it is the one that went in"
    )

    bytes.unsafe_store(0, 0xE2)
    bytes.unsafe_store(1, 0x82)
    bytes.unsafe_store(2, 0xAC)
    _initial(st)
    assert_equal(
        Int(mbrtoc32(ch, bytes, 3, st)), 3, "three bytes for the euro sign"
    )
    assert_equal(
        Int(ch.unsafe_load()), 0x20AC, "and it is the one that went in"
    )

    st.unsafe_free()
    bytes.unsafe_free()
    ch.unsafe_free()


def test_utf16_round_trip() raises:
    """A pair given one unit at a time, and the same pair read back."""
    var st = unsafe_alloc[mbstate_t](1)
    var bytes = unsafe_alloc[UInt8](8)
    var unit = unsafe_alloc[UInt16](1)

    # A BMP character is one unit and three bytes: the whole of it either way.
    _initial(st)
    assert_equal(Int(c16rtomb(bytes, 0x20AC, st)), 3, "the euro sign is three")
    assert_equal(Int(bytes.unsafe_load(0)), 0xE2, "E2 82 AC")
    assert_equal(Int(bytes.unsafe_load(1)), 0x82, "E2 82 AC")
    assert_equal(Int(bytes.unsafe_load(2)), 0xAC, "E2 82 AC")

    # U+1D11E is D834 DD1E, and the four bytes belong to the pair, not to
    # either half: the first call writes nothing at all.
    _initial(st)
    assert_equal(
        Int(c16rtomb(bytes, 0xD834, st)), 0, "the high half writes nothing"
    )
    assert_equal(
        Int(c16rtomb(bytes, 0xDD1E, st)), 4, "the low half writes all four"
    )
    assert_equal(Int(bytes.unsafe_load(0)), 0xF0, "F0 9D 84 9E")
    assert_equal(Int(bytes.unsafe_load(1)), 0x9D, "F0 9D 84 9E")
    assert_equal(Int(bytes.unsafe_load(2)), 0x84, "F0 9D 84 9E")
    assert_equal(Int(bytes.unsafe_load(3)), 0x9E, "F0 9D 84 9E")

    # And back: the first call consumes all four bytes and writes the high
    # half, the second writes the low half and reads nothing.
    unit.unsafe_store(0, 0xFFFF)
    _initial(st)
    assert_equal(
        Int(mbrtoc16(unit, bytes, 4, st)), 4, "four bytes made a char16"
    )
    assert_equal(Int(unit.unsafe_load()), 0xD834, "the high half first")
    assert_equal(
        Int(mbrtoc16(unit, bytes.unsafe_offset(4), 0, st)),
        -3,
        "then the low half, with nothing read",
    )
    assert_equal(Int(unit.unsafe_load()), 0xDD1E, "which is the other half")

    st.unsafe_free()
    bytes.unsafe_free()
    unit.unsafe_free()


def test_the_state_carries_the_rest_of_a_character() raises:
    """A character split across two reads, which is what a chunk gives it."""
    var st = unsafe_alloc[mbstate_t](1)
    var bytes = unsafe_alloc[UInt8](4)
    var unit = unsafe_alloc[UInt16](1)
    var ch = unsafe_alloc[UInt32](1)

    bytes.unsafe_store(0, 0xE2)
    bytes.unsafe_store(1, 0x82)
    bytes.unsafe_store(2, 0xAC)

    unit.unsafe_store(0, 0xFFFF)
    _initial(st)
    assert_equal(
        Int(mbrtoc16(unit, bytes, 1, st)), -2, "one byte is the start of it"
    )
    assert_equal(Int(unit.unsafe_load()), 0xFFFF, "and nothing was written yet")
    assert_equal(
        Int(mbrtoc16(unit, bytes.unsafe_offset(1), 2, st)),
        2,
        "the other two finish it, and only they are counted",
    )
    assert_equal(
        Int(unit.unsafe_load()), 0x20AC, "the character is the whole of it"
    )

    ch.unsafe_store(0, 0xFFFF)
    _initial(st)
    assert_equal(
        Int(mbrtoc32(ch, bytes, 1, st)), -2, "the same in the 32 bit call"
    )
    assert_equal(Int(ch.unsafe_load()), 0xFFFF, "and nothing was written yet")
    assert_equal(
        Int(mbrtoc32(ch, bytes.unsafe_offset(1), 2, st)),
        2,
        "the other two finish it, and only they are counted",
    )
    assert_equal(
        Int(ch.unsafe_load()), 0x20AC, "the character is the whole of it"
    )

    st.unsafe_free()
    bytes.unsafe_free()
    unit.unsafe_free()
    ch.unsafe_free()


def test_what_is_not_a_character() raises:
    """The three ways there is nothing to write, and the one that is not."""
    var st = unsafe_alloc[mbstate_t](1)
    var bytes = unsafe_alloc[UInt8](8)
    var ch = unsafe_alloc[UInt32](1)
    var bad = unsafe_alloc[UInt8](1)

    # 0xFF is not a byte any UTF-8 character starts with, and the character
    # the caller pointed at is left as it was.
    bad.unsafe_store(0, 0xFF)
    ch.unsafe_store(0, 0xFFFF)
    _initial(st)
    set_errno(0)
    assert_equal(
        Int(mbrtoc32(ch, bad, 1, st)), -1, "the byte is not a character"
    )
    assert_equal(Int(get_errno()), EILSEQ, "and errno says which way it failed")
    assert_equal(Int(ch.unsafe_load()), 0xFFFF, "with nothing written")

    # A low surrogate with no high one before it in the state.
    _initial(st)
    set_errno(0)
    assert_equal(Int(c16rtomb(bytes, 0xDC00, st)), -1, "half a pair on its own")
    assert_equal(Int(get_errno()), EILSEQ, "and errno says which way it failed")

    # A surrogate is not a character for the 32 bit call either.
    _initial(st)
    set_errno(0)
    assert_equal(Int(c32rtomb(bytes, 0xD834, st)), -1, "a surrogate is not one")
    assert_equal(Int(get_errno()), EILSEQ, "and errno says which way it failed")

    # U+110000 is out of range and glibc encodes it anyway, as the four byte
    # form F4 90 80 80, which no UTF-8 decoder will read back. A caller with
    # a number from somewhere untrusted has to check it, because this does
    # not: the call is only wrong for the two surrogate ranges.
    _initial(st)
    assert_equal(Int(c32rtomb(bytes, 0x110000, st)), 4, "out of range, encoded")
    assert_equal(Int(bytes.unsafe_load(0)), 0xF4, "F4 90 80 80")
    assert_equal(Int(bytes.unsafe_load(1)), 0x90, "F4 90 80 80")
    assert_equal(Int(bytes.unsafe_load(2)), 0x80, "F4 90 80 80")
    assert_equal(Int(bytes.unsafe_load(3)), 0x80, "F4 90 80 80")

    st.unsafe_free()
    bytes.unsafe_free()
    ch.unsafe_free()
    bad.unsafe_free()


def test_a_null_output_pointer_is_not_a_question() raises:
    """C11 says a null output asks the length; glibc answers 1 and resets."""
    var st = unsafe_alloc[mbstate_t](1)
    var bytes = unsafe_alloc[UInt8](8)

    _initial(st)
    assert_equal(
        Int(c32rtomb(null_ptr[UInt8](), 0x1D11E, st)),
        1,
        "not the four bytes it would take",
    )

    # And the reset is real: it is how a half-finished pair is thrown away.
    _initial(st)
    assert_equal(
        Int(c16rtomb(bytes, 0xD834, st)), 0, "a high half is remembered"
    )
    assert_equal(
        Int(c32rtomb(null_ptr[UInt8](), 0x41, st)), 1, "a null output clears it"
    )
    set_errno(0)
    assert_equal(
        Int(c16rtomb(bytes, 0xDD1E, st)),
        -1,
        "so the low half has no high half left to finish",
    )
    assert_equal(Int(get_errno()), EILSEQ, "and errno says so")

    st.unsafe_free()
    bytes.unsafe_free()


def main() raises:
    comptime if not CompilationTarget.is_macos():
        # These conversions read the calling thread's locale, and the suite
        # runs in `C`, where nothing above ASCII converts. `newlocale` makes
        # the object and `uselocale` moves this thread alone, so what the
        # other tests see does not change and nothing is left behind.
        var name = string_to_char_ptr("C.UTF-8")
        var loc = newlocale(LC_CTYPE_MASK, name, null_ptr[Locale]())
        name.unsafe_free()
        assert_true(
            Int(loc) != 0, "this machine has a C.UTF-8 locale to convert under"
        )
        var previous = uselocale(loc)

        test_utf32_round_trip()
        test_utf16_round_trip()
        test_the_state_carries_the_rest_of_a_character()
        test_what_is_not_a_character()
        test_a_null_output_pointer_is_not_a_question()

        _ = uselocale(previous)
        freelocale(loc)
    print("test_uchar: ok")
