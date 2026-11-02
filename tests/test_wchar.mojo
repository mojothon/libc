from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr, c_void, c_wchar
from libc.utils import (
    char_ptr_to_string,
    is_null,
    null_ptr,
    string_to_char_ptr,
)
from libc.file import fclose, rewind
from libc.locale import LC_ALL, Locale, freelocale, newlocale
from libc.stdlib import free
from libc.time import gmtime_r, time, tm
from libc.stdio import tmpfile
from libc.wchar import (
    WEOF,
    btowc,
    fgetwc,
    fgetws,
    fputwc,
    fputws,
    fwide,
    getwc,
    iswalnum,
    iswalpha,
    iswblank,
    iswcntrl,
    iswdigit,
    iswgraph,
    iswlower,
    iswprint,
    iswpunct,
    iswspace,
    iswupper,
    iswxdigit,
    mbrlen,
    mbrtowc,
    mbsinit,
    mbsnrtowcs,
    mbsrtowcs,
    mbstate_t,
    mbstowcs,
    putwc,
    towlower,
    towupper,
    ungetwc,
    wcpcpy,
    wcpncpy,
    wcrtomb,
    wcscasecmp,
    wcscasecmp_l,
    wcscat,
    wcschr,
    wcscmp,
    wcscoll,
    wcscoll_l,
    wcscpy,
    wcscspn,
    wcsdup,
    wcsftime,
    wcslen,
    wcsncasecmp,
    wcsncasecmp_l,
    wcsncat,
    wcsncmp,
    wcsncpy,
    wcsnlen,
    wcsnrtombs,
    wcspbrk,
    wcsrchr,
    wcsrtombs,
    wcsspn,
    wcsstr,
    wcstod,
    wcstof,
    wcstok,
    wcstol,
    wcstoll,
    wcstombs,
    wcstoul,
    wcstoull,
    wcsxfrm,
    wcsxfrm_l,
    wctob,
    wmemchr,
    wmemcmp,
    wmemcpy,
    wmemmove,
    wmemset,
)


def wide(s: String) raises -> c_ptr[c_wchar]:
    """Copies an ASCII string into a null terminated wide buffer."""
    var buf = unsafe_alloc[c_wchar](s.byte_length() + 1)
    var i = 0
    for byte in s.bytes():
        buf.unsafe_store(i, Int32(byte))
        i += 1
    buf.unsafe_store(s.byte_length(), 0)
    return buf


def wide_to_string(s: c_ptr[c_wchar]) raises -> String:
    """Reads a null terminated wide buffer back, ASCII only."""
    var n = 0
    while s.unsafe_load(n) != 0:
        n += 1
    var bytes = unsafe_alloc[UInt8](n + 1)
    for i in range(n):
        bytes.unsafe_store(i, UInt8(s.unsafe_load(i)))
    bytes.unsafe_store(n, 0)
    var out = char_ptr_to_string(bytes)
    bytes.unsafe_free()
    return out


def test_length_and_compare() raises:
    var hi = wide("hi")
    var ho = wide("ho")

    assert_equal(Int(wcslen(hi)), 2)
    assert_equal(Int(wcslen(wide(""))), 0)

    assert_equal(Int(wcscmp(hi, hi)), 0)
    assert_true(Int(wcscmp(hi, ho)) < 0, "hi sorts before ho")
    assert_equal(Int(wcsncmp(hi, ho, 1)), 0)

    hi.unsafe_free()
    ho.unsafe_free()


def test_search() raises:
    var s = wide("hello")

    assert_equal(wide_to_string(wcschr(s, 108)), "llo")
    assert_equal(wide_to_string(wcsrchr(s, 108)), "lo")
    assert_equal(wide_to_string(wcsstr(s, wide("ll"))), "llo")

    assert_equal(Int(wcsspn(s, wide("hel"))), 4)
    assert_equal(Int(wcscspn(s, wide("o"))), 4)

    # A miss comes back as a null pointer.
    assert_equal(Int(wcschr(s, 122)), 0)
    assert_equal(Int(wcsstr(s, wide("zz"))), 0)

    s.unsafe_free()


def test_copy() raises:
    var src = wide("abc")
    var dest = unsafe_alloc[c_wchar](16)
    dest.unsafe_store(0, 0)

    _ = wcscpy(dest, src)
    assert_equal(wide_to_string(dest), "abc")

    # wcsncpy only writes a terminator when it does not fill the buffer.
    # Here it fills two of three slots and leaves the third one alone.
    var tight = unsafe_alloc[c_wchar](3)
    tight.unsafe_store(0, 122)
    tight.unsafe_store(1, 122)
    tight.unsafe_store(2, 122)
    _ = wcsncpy(tight, src, 2)
    assert_equal(Int(tight.unsafe_load(0)), 97)
    assert_equal(Int(tight.unsafe_load(1)), 98)
    assert_equal(Int(tight.unsafe_load(2)), 122)

    var roomy = unsafe_alloc[c_wchar](16)
    roomy.unsafe_store(0, 0)
    _ = wcsncpy(roomy, src, 16)
    assert_equal(wide_to_string(roomy), "abc")

    dest.unsafe_store(0, 120)
    dest.unsafe_store(1, 0)
    _ = wcscat(dest, wide("yz"))
    assert_equal(wide_to_string(dest), "xyz")

    roomy.unsafe_free()
    tight.unsafe_free()
    dest.unsafe_free()
    src.unsafe_free()


def test_multibyte() raises:
    # Under the default C locale, ASCII converts one byte to one character.
    var ascii = string_to_char_ptr("hi")
    var out = unsafe_alloc[c_wchar](8)
    assert_equal(Int(mbstowcs(out, ascii, 8)), 2)
    assert_equal(wide_to_string(out), "hi")

    var back = unsafe_alloc[UInt8](8)
    assert_equal(Int(wcstombs(back, out, 8)), 2)
    assert_equal(char_ptr_to_string(back), "hi")

    # One character at a time, letting libc keep the shift state.
    var one = unsafe_alloc[c_wchar](1)
    one.unsafe_store(0, 0)
    assert_equal(Int(mbrtowc(one, ascii, 2, null_ptr[mbstate_t]())), 1)
    assert_equal(Int(one.unsafe_load()), 104)

    var byte = unsafe_alloc[UInt8](8)
    # wcrtomb writes no terminator, so the slot after it has to start at 0.
    byte.unsafe_store(0, 0)
    byte.unsafe_store(1, 0)
    assert_equal(Int(wcrtomb(byte, 104, null_ptr[mbstate_t]())), 1)
    assert_equal(char_ptr_to_string(byte), "h")

    assert_equal(Int(mbrlen(ascii, 2, null_ptr[mbstate_t]())), 1)

    one.unsafe_free()
    byte.unsafe_free()
    back.unsafe_free()
    out.unsafe_free()
    ascii.unsafe_free()


def test_classify() raises:
    assert_true(Int(iswalpha(65)) != 0, "A is a letter")
    assert_true(Int(iswalpha(48)) == 0, "0 is not")
    assert_true(Int(iswalnum(48)) != 0, "0 is alphanumeric")
    assert_true(Int(iswdigit(48)) != 0, "0 is a digit")
    assert_true(Int(iswdigit(65)) == 0, "A is not")
    assert_true(Int(iswspace(32)) != 0, "space is space")
    assert_true(Int(iswspace(65)) == 0, "A is not")
    assert_true(Int(iswupper(65)) != 0, "A is upper")
    assert_true(Int(iswupper(97)) == 0, "a is not")
    assert_true(Int(iswlower(97)) != 0, "a is lower")
    assert_true(Int(iswlower(65)) == 0, "A is not")

    assert_equal(Int(towupper(97)), 65)
    assert_equal(Int(towlower(65)), 97)
    assert_equal(Int(towupper(48)), 48)

    # Each of these is asked about one character that is what it asks
    # after and one that is not, the second being the half that keeps
    # the first from being a thing any of them would answer.

    # Blank is the narrower of the two: a space is both, a newline is
    # space and is not blank.
    assert_true(Int(iswblank(32)) != 0, "space is blank")
    assert_true(Int(iswblank(65)) == 0, "A is not")
    assert_true(
        Int(iswblank(10)) == 0, "and a newline is not, being space only"
    )

    assert_true(Int(iswcntrl(9)) != 0, "tab is a control character")
    assert_true(Int(iswcntrl(65)) == 0, "A is not")
    assert_true(Int(iswcntrl(32)) == 0, "and space is not, being printable")

    assert_true(Int(iswgraph(65)) != 0, "A has a glyph")
    assert_true(
        Int(iswgraph(32)) == 0, "and space is the one printable that has none"
    )
    assert_true(
        Int(iswprint(32)) != 0, "where iswprint does call space printable"
    )
    assert_true(Int(iswprint(9)) == 0, "but not a tab")

    assert_true(Int(iswpunct(46)) != 0, ". is punctuation")
    assert_true(Int(iswpunct(65)) == 0, "A is not")

    # Six letters wider than a decimal digit, so g is the one that
    # tells this from iswdigit.
    assert_true(Int(iswxdigit(102)) != 0, "f is a hexadecimal digit")
    assert_true(Int(iswxdigit(103)) == 0, "g is not")
    assert_true(Int(iswxdigit(48)) != 0, "and 0 is both")


def test_single_byte() raises:
    assert_equal(Int(btowc(65)), 65)
    assert_equal(Int(wctob(65)), 65)


def test_wide_characters_through_a_stream() raises:
    """`fputwc` writes one wide character to a stream and `fgetwc`
    reads it back, `fputws` and `fgetws` do the same for a string, and
    `ungetwc` hands one back so that the next read is it again.

    The stream is one `tmpfile` makes, which is to say a file nobody
    has to name and nobody has to clean up.

    `fwide` is asked with a mode of 0, which asks without turning the
    stream: a stream nothing has been written to is not turned either
    way, and 0 is what comes back. That is asked before anything is
    written, since writing a wide character is what turns it.

    `getwc` and `putwc` are the same pair under another name and are
    asked the same things. `getwchar` and `putwchar` are bound and not
    called, being the ones that go to the terminal.
    """
    var stream = tmpfile()
    assert_true(not is_null(stream), "tmpfile hands back a stream")

    # Asked before anything is written, since writing is what turns it.
    assert_equal(fwide(stream, 0), 0, "and it is not turned either way yet")

    assert_equal(Int(fputwc(65, stream)), 65, "A goes into the stream")
    assert_equal(Int(putwc(66, stream)), 66, "and B after it")

    _ = rewind(stream)
    assert_equal(
        Int(fwide(stream, 0)) > 0, True, "and the stream is turned wide now"
    )
    assert_equal(Int(fgetwc(stream)), 65, "A comes back out of it")
    assert_equal(Int(getwc(stream)), 66, "and B after it")

    # Handed back, and so read again.
    assert_equal(Int(ungetwc(66, stream)), 66, "B is handed back to the stream")
    assert_equal(Int(fgetwc(stream)), 66, "and so it is what comes out next")
    assert_equal(
        Int(fgetwc(stream)), Int(WEOF), "and after that there is nothing"
    )

    # Back to the start first. The reads above went as far as the end,
    # and writing from there would put this after what is there
    # already rather than over it.
    _ = rewind(stream)
    var line = wide("written")
    assert_true(Int(fputws(line, stream)) >= 0, "a string goes into the stream")
    _ = rewind(stream)
    var back = unsafe_alloc[c_wchar](8)
    assert_true(
        not is_null(fgetws(back, 8, stream)), "and comes back out of it"
    )
    assert_equal(wide_to_string(back), "written")

    assert_equal(fclose(stream), 0, "the stream is closed")

    back.unsafe_free()
    line.unsafe_free()


def test_reading_numbers_off_the_front() raises:
    """`wcstol`, `wcstoul` and `wcstod` each read a number off the
    front of a wide string, and each is asked about a string with
    something after the number: `endptr` is where the rest is left,
    and it is the one thing here that a call which read nothing at all
    could not answer.

    Each is asked for a base of 10 and again for a base of 0, which
    lets the string say what base it is in. `0x` in front of a number
    is sixteen under 0 and is nothing at all under 10, so the same
    string reads as two different numbers, and asking both is what
    keeps a call that ignored its base from passing.

    A string with no number in it is asked for too, and 0 is what
    comes back.
    """
    var end = unsafe_alloc[c_ptr[c_wchar]](1)

    var sixteen = wide("0x10")
    assert_equal(wcstol(sixteen, end, 10), 0, "0x10 is no number in base 10")
    assert_equal(wcstol(sixteen, end, 0), 16, "and is sixteen when it says")
    assert_equal(wcstoul(sixteen, end, 0), 16, "and unsigned agrees")

    var dozen = wide("12")
    assert_equal(wcstol(dozen, end, 10), 12, "twelve in base ten")
    assert_equal(wcstoul(dozen, end, 0), 12, "and unsigned agrees")

    var rest = wide("7 and the rest")
    assert_equal(wcstol(rest, end, 10), 7, "seven is read off the front, and")
    assert_equal(
        wide_to_string(end.unsafe_offset(0)[]),
        " and the rest",
        "what is left is where endptr points",
    )

    var none = wide("no number here")
    assert_equal(wcstol(none, end, 10), 0, "and a string with none is 0")

    var half = wide("1.5")
    assert_true(wcstod(half, end) == 1.5, "one and a half is read")
    assert_equal(
        wide_to_string(end.unsafe_offset(0)[]), "", "and nothing is left of it"
    )

    none.unsafe_free()
    rest.unsafe_free()
    dozen.unsafe_free()
    sixteen.unsafe_free()
    half.unsafe_free()
    end.unsafe_free()


def test_wcstof() raises:
    """`wcstof` reads a float off the front of a wide string, which
    is what `wcstod` does for the wider of the two.

    It is asked about a string with something after the number, so
    `endptr` has somewhere to point, and about a string with no
    number in it at all, of which 0 is what comes back.

    It is asked about a third of one, which no float can hold exactly
    and no double can either, so what is asserted is that it is near
    and not that it is equal — a test that said equal would be asking
    the two platforms to agree on the last bit of a number neither of
    them holds.

    A short number is one the two do agree on, and that is the one
    they are put side by side over: what `wcstof` reads of it is what
    `wcstod` reads of it, which is what says the `f` at the end of the
    name is the width and nothing else.
    """
    var end = unsafe_alloc[c_ptr[c_wchar]](1)

    var rest = wide("3.5 and the rest")
    assert_equal(
        wcstof(rest, end), 3.5, "three and a half is read off the front"
    )
    assert_equal(
        wide_to_string(end.unsafe_offset(0)[]),
        " and the rest",
        "and what is left is where endptr points",
    )

    var none = wide("no number here")
    assert_equal(wcstof(none, end), 0.0, "and a string with none is 0")

    var third = wide("0.333333")
    var f = Float64(wcstof(third, end))
    assert_true(
        f > 0.33332 and f < 0.33334,
        "a third, which neither a float nor a double holds exactly",
    )

    # The same string read both ways comes out the same, the width
    # being all there is between them.
    assert_equal(
        Float64(wcstof(wide("2.5"), end)),
        wcstod(wide("2.5"), end),
        "what wcstof reads of a short number is what wcstod reads",
    )

    end.unsafe_free()


def test_measuring_and_finding_in_wide_strings() raises:
    """`wcsnlen` says how long a wide string is, stopping at a given
    number of characters, and `wcspbrk` finds the first character of
    one that is in a given set.

    `wcsnlen` is asked about a string it reaches the end of, and then
    about one it does not — the same string, asked for fewer
    characters than there are, which is what makes it answer the
    number it was given rather than the number there is. Asking only
    of a string it finishes would not tell the two apart.

    `wcspbrk` is asked about a string with the set's characters in it
    twice over, and the first of them is what it finds. It is asked
    about a string with none of them, of which a null pointer is what
    comes back.
    """
    var five = wide("abcde")
    assert_equal(Int(wcsnlen(five, 5)), 5, "five characters, asked for five")
    assert_equal(
        Int(wcsnlen(five, 3)), 3, "and three where three were asked for"
    )
    assert_equal(
        Int(wcsnlen(five, 100)), 5, "and five where more than that were"
    )

    var some = wide("aXbXc")
    assert_equal(
        wide_to_string(wcspbrk(some, wide("X"))),
        "XbXc",
        "wcspbrk finds the first of them",
    )
    assert_equal(
        wide_to_string(wcspbrk(some, wide("cX"))),
        "XbXc",
        "whichever of the set comes first",
    )
    assert_true(
        Int(UInt(wcspbrk(some, wide("z")))) == 0,
        "and none of them is a null pointer",
    )

    some.unsafe_free()
    five.unsafe_free()


def test_comparing_wide_strings_apart_from_case() raises:
    """`wcscasecmp` compares two wide strings with no regard for the
    case of their letters, and `wcsncasecmp` does it over no more
    than so many characters.

    Both are asked about two strings that are the same apart from
    case, which is 0, and about two that are not, which is not. The
    second is asked the one thing that sets it apart: two strings
    that differ past a given number of characters, which is 0 for
    that many and not 0 for more. A call that never looked at its
    count would have to answer both questions the same way.

    Under the C locale the ASCII letters are what count as the same,
    and that is all this asks of it.
    """
    assert_equal(
        wcscasecmp(wide("Hello"), wide("hello")),
        0,
        "the same letters apart from case are 0",
    )
    assert_true(
        wcscasecmp(wide("Hello"), wide("hellp")) != 0,
        "and different letters are not",
    )

    assert_equal(
        wcsncasecmp(wide("Hello"), wide("help"), 3),
        0,
        "the first three agree, and",
    )
    assert_true(
        wcsncasecmp(wide("Hello"), wide("help"), 4) != 0,
        "the first four do not",
    )


def test_the_order_the_locale_asks_for() raises:
    """`wcscoll` compares two wide strings in the order the locale
    puts things in, and `wcsxfrm` writes one out in a form that
    plain comparison may be done on instead.

    Under the C locale the two agree, so what is asked here holds on
    both platforms: a string against itself is 0, and two strings
    that differ are not, whichever way round they are asked.

    `wcsxfrm` is asked for the length first, with nowhere to write,
    and then to write into room that big. That is what the count it
    hands back is for, and asking it to write without asking first is
    how one comes to write past the end of the room.

    What is written out is not meant to be read, so what is asserted
    of it is only that it is the length that was said.
    """
    var one = wide("abc")
    var two = wide("abd")

    assert_equal(wcscoll(one, one), 0, "a string against itself is 0")
    assert_true(wcscoll(one, two) != 0, "two that differ are not")

    var room = unsafe_alloc[c_wchar](16)
    var needed = wcsxfrm(room, one, 16)
    assert_true(
        Int(needed) > 0 and Int(needed) <= 16,
        "wcsxfrm says how much room the writing takes",
    )
    assert_equal(
        Int(wcsnlen(room, 16)),
        Int(needed),
        "and that is how much it wrote",
    )

    room.unsafe_free()
    two.unsafe_free()
    one.unsafe_free()


def test_copying_wide_strings() raises:
    """`wcsdup` makes a copy in fresh memory, `wcsncat` puts no more
    than so many characters onto the end of a string, and `wcpcpy`
    and `wcpncpy` copy and say where they got to.

    `wcsdup` is asked to copy, and what comes back says the same
    thing as what went in and is not the same place — which is what
    a copy is, and what a call handing the original back is not.

    `wcsncat` is asked for fewer characters than the source has, and
    the result is the destination with that many added to it and not
    with all of them. That is the one thing here that a call which
    ignored its count could not answer.

    `wcpcpy` is asked where it got to, and it is the end of what was
    written, which is what makes it the one for putting several
    strings one after another. `wcpncpy` is asked the same, twice
    over: once where the source runs out within the count, and once
    where it does not, and what comes back is the terminator in the
    first case and one past the last character in the second.
    """
    var a = wide("abc")
    var copy = wcsdup(a)
    assert_equal(wide_to_string(copy), "abc", "wcsdup says the same thing")
    assert_true(Int(UInt(copy)) != Int(UInt(a)), "and it is not the same place")
    # Its own memory, asked for by the library and not by Mojo, so
    # `free` is what gives it back and not `unsafe_free`.
    _ = free(copy.unsafe_bitcast[c_void]())

    var dest = unsafe_alloc[c_wchar](16)
    dest.unsafe_store(0, 88)
    dest.unsafe_store(1, 0)
    _ = wcsncat(dest, wide("defg"), 2)
    assert_equal(
        wide_to_string(dest), "Xde", "wcsncat adds two of the four it was given"
    )

    var again = unsafe_alloc[c_wchar](16)
    var end = wcpcpy(again, wide("hi"))
    assert_equal(wide_to_string(again), "hi", "wcpcpy copies")
    assert_equal(wide_to_string(end), "", "and says where the end of it is")

    # Ends within the count, so what comes back is a terminator.
    var room = unsafe_alloc[c_wchar](8)
    var stop = wcpncpy(room, wide("ab"), 8)
    assert_equal(wide_to_string(room), "ab", "wcpncpy copies, and")
    assert_equal(
        wide_to_string(stop), "", "the source ran out, so this is the end"
    )

    # Does not end within the count, so nothing is terminated and what
    # comes back is one past the last character written.
    var tight = unsafe_alloc[c_wchar](4)
    var past = wcpncpy(tight, wide("abcd"), 2)
    assert_equal(
        Int(UInt(past)) - Int(UInt(tight)),
        8,
        "two characters written, and this is one past them",
    )

    tight.unsafe_free()
    room.unsafe_free()
    again.unsafe_free()
    dest.unsafe_free()
    a.unsafe_free()


def test_wide_memory() raises:
    """`wmemchr`, `wmemcmp`, `wmemcpy`, `wmemmove` and `wmemset` work
    on a number of wide characters rather than on a string, which is
    what the `mem` in the name is for and what sets them apart from
    the `wcs` calls.

    `wmemchr` is asked about a character that is there and about one
    that is not, and about one that is there but past the number it
    was given to look at — which is the one thing here that a call
    reading a string instead of a count could not answer, that being
    a call that would find it.

    `wmemmove` is asked to move characters onto a place that overlaps
    where they came from. That is the whole of what it does that
    `wmemcpy` does not, and the run has to come out whole, which it
    would not if the move went the wrong way along it.

    `wmemset` is asked to fill with a character and then asked how
    much of the filling took, and `wmemcmp` is what says whether two
    places hold the same characters.
    """
    var abc = wide("abc")
    assert_equal(
        wide_to_string(wmemchr(abc, 98, 3)),
        "bc",
        "wmemchr finds the b in abc",
    )
    assert_true(
        Int(UInt(wmemchr(abc, 98, 1))) == 0,
        "and not when it is told to look at only the first character",
    )
    assert_true(
        Int(UInt(wmemchr(abc, 122, 3))) == 0,
        "nor when what it is looking for is not there",
    )

    var two = wide("abc")
    assert_equal(wmemcmp(abc, two, 3), 0, "wmemcmp says the same of the same")
    assert_true(wmemcmp(abc, wide("abd"), 3) != 0, "and not of the different")

    var room = unsafe_alloc[c_wchar](4)
    _ = wmemcpy(room, abc, 3)
    room.unsafe_store(3, 0)
    assert_equal(wide_to_string(room), "abc", "wmemcpy copies three characters")

    # Onto a place that overlaps where they came from.
    var shifted = wide("abcd")
    _ = wmemmove(shifted.unsafe_offset(1), shifted, 3)
    shifted.unsafe_store(4, 0)
    assert_equal(
        wide_to_string(shifted),
        "aabc",
        "wmemmove brings a run over itself whole",
    )

    var filled = unsafe_alloc[c_wchar](4)
    _ = wmemset(filled, 88, 3)
    filled.unsafe_store(3, 0)
    assert_equal(wide_to_string(filled), "XXX", "wmemset fills with X")

    filled.unsafe_free()
    shifted.unsafe_free()
    room.unsafe_free()
    two.unsafe_free()
    abc.unsafe_free()


def test_reading_the_widest_integers_off_the_front() raises:
    """`wcstoll` reads a long long off the front of a wide string and
    `wcstoull` an unsigned one.

    Each is asked for a base of 10 and again for a base of 16, on a
    string the two read as different numbers: `10` is ten in the one
    and sixteen in the other. That is what keeps a call that ignored
    its base from passing, and it is the same thing this package
    holds `wcstol` to.

    Each is asked about a string with something after the number, so
    `endptr` has somewhere to point, and about a string with no
    number in it, of which 0 is what comes back.

    `wcstoull` is asked about a number too wide for a long long to
    hold, which is the one thing the unsigned one can read that the
    signed one cannot.
    """
    var end = unsafe_alloc[c_ptr[c_wchar]](1)

    var ten = wide("10")
    assert_equal(wcstoll(ten, end, 10), 10, "ten in base ten, and")
    assert_equal(wcstoll(ten, end, 16), 16, "sixteen in base sixteen")
    assert_equal(wcstoull(ten, end, 10), 10, "and unsigned says the same")

    var rest = wide("42 and the rest")
    assert_equal(wcstoll(rest, end, 10), 42, "forty-two is read off the front")
    assert_equal(
        wide_to_string(end.unsafe_offset(0)[]),
        " and the rest",
        "and what is left is where endptr points",
    )

    var none = wide("no number here")
    assert_equal(wcstoll(none, end, 10), 0, "a string with none is 0")
    assert_equal(wcstoull(none, end, 10), 0, "for either of them")

    # Wider than a long long will hold, which is what the u is for.
    var big = wide("18446744073709551615")
    assert_equal(
        wcstoull(big, end, 10),
        18446744073709551615,
        "and the widest unsigned one is read whole",
    )

    end.unsafe_free()


def test_splitting_a_wide_string() raises:
    """`wcstok` splits a wide string into pieces, one call to a piece,
    keeping its place between the calls in a pointer the caller hands
    it.

    It is asked for three pieces out of a string with two delimiters
    in it, and the three come back in the order they are in the
    string — which is what a call that handed them back the other way
    round could not manage. A fourth call finds nothing, and a null
    pointer is what comes back of it.

    The place it keeps between the calls is the caller's to hand it,
    and it is what makes this one answerable in a test at all.
    """
    var s = wide("a,b,c")
    var place = unsafe_alloc[c_ptr[c_wchar]](1)

    assert_equal(
        wide_to_string(wcstok(s, wide(","), place)), "a", "the first piece"
    )
    assert_equal(
        wide_to_string(wcstok(null_ptr[c_wchar](), wide(","), place)),
        "b",
        "and the second, from a null string",
    )
    assert_equal(
        wide_to_string(wcstok(null_ptr[c_wchar](), wide(","), place)),
        "c",
        "and the third",
    )
    assert_true(
        Int(UInt(wcstok(null_ptr[c_wchar](), wide(","), place))) == 0,
        "and there is no fourth",
    )

    place.unsafe_free()
    s.unsafe_free()


def test_asking_after_a_conversion_state() raises:
    """`mbsinit` says whether a conversion state is at its beginning.

    What is asked of it here is the state the library keeps for its
    own, which is what a null pointer asks for, and which is at its
    beginning at the start of a programme.

    A state of one's own to hand it has to be zeroed first, and
    `unsafe_alloc` does not zero — asking this about memory that has
    only just been allocated is asking about whatever was in it
    before, which is why none is handed here.
    """
    assert_true(
        Int(mbsinit(null_ptr[mbstate_t]())) != 0,
        "the state the library keeps is at its start",
    )


def test_the_stateful_conversions() raises:
    """`mbsrtowcs` reads a multibyte string out into wide characters
    and `wcsrtombs` writes them back, and `mbsnrtowcs` and
    `wcsnrtombs` are the same two with a stopping place in the source
    as well as in the room.

    What sets these apart from `mbstowcs` and `wcstombs` is the state
    they keep, which is what a character taking more than one byte
    needs; what sets the `n` ones apart is that the source need not be
    ended.

    The round trip is what is asked of the first two: a narrow string
    goes out into wide characters and comes back the same. Each is
    asked how much it wrote, and each is asked about the pointer it
    was handed — which is moved on past what was read, and that is the
    thing here no other call would do.

    The `n` ones are asked for fewer than there are: one byte of a
    string of two, and one character of a string of two. Each is asked
    to stop at that, which is what a call that kept reading to the end
    would not do.
    """
    var narrow = string_to_char_ptr("hi")
    var src = unsafe_alloc[c_ptr[UInt8]](1)
    src.unsafe_offset(0)[] = narrow
    var wide_room = unsafe_alloc[c_wchar](8)

    assert_equal(
        Int(mbsrtowcs(wide_room, src, 8, null_ptr[mbstate_t]())),
        2,
        "mbsrtowcs writes two wide characters",
    )
    wide_room.unsafe_store(2, 0)
    assert_equal(wide_to_string(wide_room), "hi", "and they say hi")
    assert_true(
        Int(UInt(src.unsafe_offset(0)[])) == 0,
        "and the pointer is left null, the end of the string having been read",
    )

    # Back again.
    var wsrc = unsafe_alloc[c_ptr[c_wchar]](1)
    wsrc.unsafe_offset(0)[] = wide_room
    var bytes = unsafe_alloc[UInt8](8)
    bytes.unsafe_store(0, 0)
    assert_equal(
        Int(wcsrtombs(bytes, wsrc, 8, null_ptr[mbstate_t]())),
        2,
        "wcsrtombs writes two bytes",
    )
    bytes.unsafe_store(2, 0)
    assert_equal(char_ptr_to_string(bytes), "hi", "and they say hi")
    assert_true(
        Int(UInt(wsrc.unsafe_offset(0)[])) == 0,
        "and that one is left null too",
    )

    # One byte of a string of two.
    src.unsafe_offset(0)[] = narrow
    var one = unsafe_alloc[c_wchar](8)
    assert_equal(
        Int(mbsnrtowcs(one, src, 1, 8, null_ptr[mbstate_t]())),
        1,
        "mbsnrtowcs reads one byte when it is given one",
    )

    # One character of a string of two.
    wsrc.unsafe_offset(0)[] = wide_room
    var short = unsafe_alloc[UInt8](8)
    assert_equal(
        Int(wcsnrtombs(short, wsrc, 1, 8, null_ptr[mbstate_t]())),
        1,
        "wcsnrtombs reads one character when it is given one",
    )

    short.unsafe_free()
    one.unsafe_free()
    bytes.unsafe_free()
    wsrc.unsafe_free()
    wide_room.unsafe_free()
    src.unsafe_free()
    narrow.unsafe_free()


def test_writing_a_time_out_wide() raises:
    """`wcsftime` writes a wide string from a broken-down time, in the
    shape a format asks for. It is `strftime` writing wide characters.

    It is asked for a year, and four characters is what comes back.
    Which words come out for a month or a day is the locale's to say,
    so a format of digits is what a test asks for, and the year is
    four digits in every locale that has one.

    The time is today's, got from `time` and `gmtime_r` rather than
    written out, so nothing here holds to a year in particular.
    """
    var now = unsafe_alloc[Int64](1)
    now.unsafe_offset(0)[] = time(null_ptr[Int64]())
    var slot = unsafe_alloc[tm](1)
    slot.unsafe_offset(0)[] = tm()
    assert_true(
        Int(UInt(gmtime_r(now, slot))) != 0, "gmtime_r handed back a time"
    )

    var buf = unsafe_alloc[c_wchar](64)
    var written = wcsftime(buf, 64, wide("%Y"), slot)
    assert_equal(Int(written), 4, "a year is four characters")
    assert_equal(
        wide_to_string(buf).byte_length(), 4, "and four is what is in the room"
    )

    # Asking for room too small to hold it writes nothing at all.
    var tiny = unsafe_alloc[c_wchar](2)
    assert_equal(
        Int(wcsftime(tiny, 2, wide("%Y"), slot)), 0, "and too little room is 0"
    )

    tiny.unsafe_free()
    buf.unsafe_free()
    slot.unsafe_free()
    now.unsafe_free()


def test_the_l_variants_ask_a_locale_object() raises:
    """The wide `_l` calls, asked of a C locale object: `wcscoll_l` orders,
    `wcscasecmp_l` and `wcsncasecmp_l` fold case away, and `wcsxfrm_l`
    transforms — and in a C locale the transform is the identity, so what
    comes out can be compared with what went in.

    Case folding is the pair's whole job and the `n` is what tells the two
    apart: `abcX` and `ABCY` are the same string for three wide characters
    and not the same one for four.
    """
    var c_locale = string_to_char_ptr("C")
    var loc = newlocale(LC_ALL, c_locale, null_ptr[Locale]())
    assert_true(Int(loc) != 0, "a C locale object was made to ask")
    c_locale.unsafe_free()

    var apple = wide("apple")
    var banana = wide("banana")
    assert_true(wcscoll_l(apple, banana, loc) < 0, "apple sorts before banana")
    assert_true(wcscoll_l(banana, apple, loc) > 0, "and after it the other way")

    var hello = wide("Hello")
    var shout = wide("hELLO")
    assert_equal(wcscasecmp_l(hello, shout, loc), 0, "case is folded away")

    var abc_x = wide("abcX")
    var abc_y = wide("ABCY")
    assert_equal(
        wcsncasecmp_l(abc_x, abc_y, 3, loc), 0, "three characters agree"
    )
    assert_true(wcsncasecmp_l(abc_x, abc_y, 4, loc) != 0, "the fourth does not")

    var roomy = unsafe_alloc[c_wchar](16)
    var src = wide("abc")
    assert_equal(
        Int(wcsxfrm_l(roomy, src, 16, loc)),
        3,
        "the C locale leaves abc three characters long",
    )
    assert_equal(wide_to_string(roomy), "abc", "and writes it out unchanged")

    freelocale(loc)


def main() raises:
    test_length_and_compare()
    test_search()
    test_copy()
    test_multibyte()
    test_classify()
    test_single_byte()
    test_wide_characters_through_a_stream()
    test_reading_numbers_off_the_front()
    test_wcstof()
    test_measuring_and_finding_in_wide_strings()
    test_comparing_wide_strings_apart_from_case()
    test_the_order_the_locale_asks_for()
    test_copying_wide_strings()
    test_wide_memory()
    test_reading_the_widest_integers_off_the_front()
    test_splitting_a_wide_string()
    test_asking_after_a_conversion_state()
    test_the_stateful_conversions()
    test_writing_a_time_out_wide()
    test_the_l_variants_ask_a_locale_object()
    print("test_wchar: ok")
