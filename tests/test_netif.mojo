"""Tests for the `libc.netif` bindings.

The four calls ask the kernel which interfaces it has and what numbers
and names it gives them. Nothing here opens a socket, and no test
writes an interface's name down: `lo` on glibc is `lo0` on Darwin, and
the names are the kernel's to choose.
"""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.netif import (
    IF_NAMESIZE,
    IfNameindex,
    if_freenameindex,
    if_indextoname,
    if_nameindex,
    if_nametoindex,
)
from libc.utils import char_ptr_to_string, is_null, string_to_char_ptr

# No machine has sixty-four interfaces, and an array with no end would
# otherwise be walked forever.
comptime MOST_WE_WILL_WALK = 64


def _fresh_buffer() -> c_ptr[UInt8]:
    """Sixteen zeroed bytes, which is room for the longest name there
    is and a NUL after it.
    """
    var buf = unsafe_alloc[UInt8](IF_NAMESIZE)
    for i in range(IF_NAMESIZE):
        buf.unsafe_offset(i)[] = 0
    return buf


def test_the_array_ends_in_the_zero_and_null_pair() raises:
    """`if_nameindex` hands back an array with no count to go with it,
    and the end is the one entry whose number is 0 and whose name is
    null. The test walks to that pair and asks for a name from every
    entry before it, which is the part each real interface has.
    """
    var array = if_nameindex()
    assert_true(not is_null(array), "the array of interfaces comes back")

    var seen = 0
    var ended = False
    while seen < MOST_WE_WILL_WALK:
        var one = array.unsafe_offset(seen)
        if Int(one[].if_index()) == 0:
            assert_true(
                one[].if_name().byte_length() == 0,
                "the pair that ends it has no name either",
            )
            ended = True
            break
        assert_true(
            one[].if_name().byte_length() > 0, "and every interface is named"
        )
        seen += 1

    assert_true(seen > 0, "there is at least one interface")
    assert_true(ended, "and the array ends where it says it does")
    assert_true(seen < MOST_WE_WILL_WALK, "before the walk gives up")

    if_freenameindex(array)


def test_a_name_round_trips_through_its_number() raises:
    """Whichever interface the kernel puts first — and it is a
    different one on each platform — its name asks for its own number
    and that number asks the name back. Nothing is written down, so
    what is compared is what the kernel said against itself.
    """
    var array = if_nameindex()
    assert_true(not is_null(array), "the array of interfaces comes back")

    var first = array.unsafe_offset(0)
    var name = first[].if_name()
    var number = Int(first[].if_index())
    assert_true(number > 0, "the first entry is an interface, not the end")

    var asked = string_to_char_ptr(name)
    assert_equal(
        Int(if_nametoindex(asked)), number, "the name asks for its own number"
    )
    asked.unsafe_free()

    var buf = _fresh_buffer()
    var back = if_indextoname(UInt32(number), buf)
    assert_true(not is_null(back), "the number asks for its own name")
    assert_equal(char_ptr_to_string(back), name, "and it is the same name")
    buf.unsafe_free()

    if_freenameindex(array)


def test_a_name_no_interface_has_answers_nothing() raises:
    """Two questions with no answer, and the way both are answered: a
    name no interface has asks for the number 0, and the number 0 —
    which no interface is ever given — asks for a null name.
    """
    var asked = string_to_char_ptr("no-interface-by-this-name")
    assert_equal(
        Int(if_nametoindex(asked)), 0, "a name no interface has asks for 0"
    )
    asked.unsafe_free()

    var buf = _fresh_buffer()
    var back = if_indextoname(UInt32(0), buf)
    assert_true(is_null(back), "and no interface is ever the number 0")
    buf.unsafe_free()


def main() raises:
    test_the_array_ends_in_the_zero_and_null_pair()
    test_a_name_round_trips_through_its_number()
    test_a_name_no_interface_has_answers_nothing()
    print("test_netif: ok")
