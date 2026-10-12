from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr, c_void
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
from libc.stdlib import free, malloc
from libc.string import strcpy
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def malloc_string(s: String) raises -> c_ptr[UInt8]:
    """Copies a string into memory libc's own allocator owns.

    Keys have to live in `malloc` memory because BSD's `hdestroy` frees them,
    and Mojo allocations are not free-able by libc.
    """
    var dest = malloc(UInt64(s.byte_length() + 1)).unsafe_bitcast[UInt8]()
    var src = string_to_char_ptr(s)
    _ = strcpy(dest, src)
    src.unsafe_free()
    return dest


def test_hsearch() raises:
    # One table per process, so this test owns it from hcreate to hdestroy.
    assert_true(Int(hcreate(16)) != 0, "the table was created")

    var one = malloc_string("one")
    var two = malloc_string("two")
    var data_one = malloc_string("1")

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
    var missing = malloc_string("nope")
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

    # hdestroy always leaves the data alone. It frees the keys on BSD only,
    # so on glibc they are still ours to release.
    _ = free(data_one.unsafe_bitcast[c_void]())
    _ = free(missing.unsafe_bitcast[c_void]())

    comptime if not CompilationTarget.is_macos():
        _ = free(one.unsafe_bitcast[c_void]())
        _ = free(two.unsafe_bitcast[c_void]())


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
