from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.search import (
    ENTER,
    ENTRY,
    FIND,
    hcreate,
    hdestroy,
    hsearch,
    insque,
    qelem,
    remque,
)
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def test_hsearch() raises:
    # One table per process, so this test owns it from hcreate to hdestroy.
    assert_true(Int(hcreate(16)) != 0, "the table was created")

    var one = string_to_char_ptr("one")
    var two = string_to_char_ptr("two")
    var data_one = string_to_char_ptr("1")

    assert_true(
        Int(hsearch(ENTRY(one, data_one.unsafe_bitcast[NoneType]()), ENTER))
        != 0,
        "the first row went in",
    )

    var found = hsearch(ENTRY(one, null_ptr[NoneType]()), FIND)
    assert_true(Int(found) != 0, "the key is there after ENTER")
    assert_equal(char_ptr_to_string(found[].key), "one")
    assert_equal(char_ptr_to_string(found[].data.unsafe_bitcast[UInt8]()), "1")

    # A key that was never entered comes back as a null pointer.
    var missing = string_to_char_ptr("nope")
    assert_equal(Int(hsearch(ENTRY(missing, null_ptr[NoneType]()), FIND)), 0)

    assert_true(
        Int(hsearch(ENTRY(two, null_ptr[NoneType]()), ENTER)) != 0,
        "the second row went in",
    )
    assert_true(
        Int(hsearch(ENTRY(two, null_ptr[NoneType]()), FIND)) != 0,
        "both keys survive",
    )
    assert_true(
        Int(hsearch(ENTRY(one, null_ptr[NoneType]()), FIND)) != 0, "so does one"
    )

    hdestroy()

    missing.unsafe_free()
    data_one.unsafe_free()
    two.unsafe_free()
    one.unsafe_free()


def test_queue() raises:
    var first = unsafe_alloc[qelem](1)
    var second = unsafe_alloc[qelem](1)
    var third = unsafe_alloc[qelem](1)
    first[] = qelem(null_ptr[UInt8](), null_ptr[UInt8]())
    second[] = qelem(null_ptr[UInt8](), null_ptr[UInt8]())
    third[] = qelem(null_ptr[UInt8](), null_ptr[UInt8]())

    # A lone node links to nobody.
    insque(first.unsafe_bitcast[NoneType](), null_ptr[NoneType]())
    assert_equal(Int(first[].q_forw), 0)
    assert_equal(Int(first[].q_back), 0)

    # Inserting after a node puts the new one in front of what followed.
    insque(second.unsafe_bitcast[NoneType](), first.unsafe_bitcast[NoneType]())
    assert_equal(Int(first[].q_forw), Int(second))
    assert_equal(Int(second[].q_back), Int(first))
    assert_equal(Int(second[].q_forw), 0)

    insque(third.unsafe_bitcast[NoneType](), first.unsafe_bitcast[NoneType]())
    assert_equal(Int(first[].q_forw), Int(third))
    assert_equal(Int(third[].q_forw), Int(second))
    assert_equal(Int(second[].q_back), Int(third))

    # Unlinking the middle node stitches the other two back together.
    remque(third.unsafe_bitcast[NoneType]())
    assert_equal(Int(first[].q_forw), Int(second))
    assert_equal(Int(second[].q_back), Int(first))

    third.unsafe_free()
    second.unsafe_free()
    first.unsafe_free()


def main() raises:
    test_hsearch()
    test_queue()
    print("test_search: ok")
