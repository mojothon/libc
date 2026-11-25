from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_int, c_ptr, c_size_t, c_uint, c_void
from libc.search import (
    ENDORDER,
    ENTER,
    ENTRY,
    FIND,
    LEAF,
    POSTORDER,
    PREORDER,
    hcreate,
    hdestroy,
    hsearch,
    insque,
    lfind,
    lsearch,
    qelem,
    remque,
    tdelete,
    tfind,
    tsearch,
    twalk,
)
from libc.file import close, write
from libc.unistd import dup2, pipe, read
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


def by_number(a: c_ptr[c_void], b: c_ptr[c_void]) -> Int32:
    var x = a.unsafe_bitcast[c_int]()
    var y = b.unsafe_bitcast[c_int]()
    if x[] < y[]:
        return -1
    if x[] > y[]:
        return 1
    return 0


def test_the_table_that_keeps_no_order() raises:
    """`lfind` and `lsearch` -- the looking through a table
    that is kept in no order: `lfind` says where the key is
    or that it is not there, leaving the count as it was,
    and `lsearch` puts the key in when it is not there, the
    count coming back one more than it went in. A key the
    table already holds is found where it was, and is not
    written in again.
    """
    var keys = unsafe_alloc[c_int](8)
    keys.unsafe_store(0, 10)
    keys.unsafe_store(1, 20)
    keys.unsafe_store(2, 30)
    keys.unsafe_store(3, 40)
    keys.unsafe_store(4, 50)
    var count = unsafe_alloc[c_size_t](1)
    count.unsafe_offset(0)[] = 5

    var want = unsafe_alloc[c_int](1)
    want.unsafe_offset(0)[] = 30
    var hit = lfind(
        want.unsafe_bitcast[c_void](),
        keys.unsafe_bitcast[c_void](),
        count,
        4,
        by_number,
    )
    assert_true(Int(hit) != 0, "a member the table holds is found")
    assert_equal(
        (hit.unsafe_bitcast[c_int]())[],
        30,
        "and what is found is the member itself, not a copy of it",
    )
    assert_equal(
        Int(count.unsafe_offset(0)[]), 5, "and the count is left as it was"
    )

    want.unsafe_offset(0)[] = 35
    hit = lfind(
        want.unsafe_bitcast[c_void](),
        keys.unsafe_bitcast[c_void](),
        count,
        4,
        by_number,
    )
    assert_true(Int(hit) == 0, "a member the table does not hold is not found")
    assert_equal(
        Int(count.unsafe_offset(0)[]), 5, "and the looking left the count alone"
    )

    want.unsafe_offset(0)[] = 35
    hit = lsearch(
        want.unsafe_bitcast[c_void](),
        keys.unsafe_bitcast[c_void](),
        count,
        4,
        by_number,
    )
    assert_true(
        Int(hit) != 0, "the asking of a key the table does not hold puts it in"
    )
    assert_equal(
        Int(count.unsafe_offset(0)[]),
        6,
        "and the count is one more than it was",
    )
    assert_equal(
        keys.unsafe_load(5), 35, "and the key is the member written in"
    )

    want.unsafe_offset(0)[] = 10
    hit = lsearch(
        want.unsafe_bitcast[c_void](),
        keys.unsafe_bitcast[c_void](),
        count,
        4,
        by_number,
    )
    assert_equal(
        (hit.unsafe_bitcast[c_int]())[],
        10,
        "a key the table already holds is found where it was",
    )
    assert_equal(
        Int(count.unsafe_offset(0)[]), 6, "and nothing was written in again"
    )

    want.unsafe_free()
    count.unsafe_free()
    keys.unsafe_free()


def tree_by_number(a: c_ptr[c_void], b: c_ptr[c_void]) -> Int32:
    var x = a.unsafe_bitcast[c_int]()
    var y = b.unsafe_bitcast[c_int]()
    if x[] < y[]:
        return -1
    if x[] > y[]:
        return 1
    return 0


def tree_say(node: c_ptr[c_void], visit: Int32, level: Int32) -> None:
    var word = UInt8(80)
    if visit == Int32(POSTORDER):
        word = UInt8(84)
    if visit == Int32(ENDORDER):
        word = UInt8(69)
    if visit == Int32(LEAF):
        word = UInt8(76)
    var one = unsafe_alloc[UInt8](1)
    one.unsafe_offset(0)[] = word
    _ = write(Int32(42), one.unsafe_bitcast[c_void](), c_uint(1))
    one.unsafe_free()
    _ = level


def test_the_tree_that_keeps_the_order() raises:
    """`tsearch`, `tfind`, `tdelete` and `twalk` -- the tree
    that is kept in the order the comparing function says.
    The asking that looks up puts in when it has to, the
    looking finds the node or says nothing is there, the
    taking out unhooks the node and says what the tree's
    keeping went through, and the walking hands every node
    over -- three times for a node with children and once
    for a leaf, the times being named preorder, postorder,
    endorder and leaf.
    """
    var keys = unsafe_alloc[c_int](6)
    keys.unsafe_offset(0)[] = 50
    keys.unsafe_offset(1)[] = 30
    keys.unsafe_offset(2)[] = 70
    keys.unsafe_offset(3)[] = 20
    keys.unsafe_offset(4)[] = 40
    keys.unsafe_offset(5)[] = 60
    var rootp = unsafe_alloc[c_ptr[c_void]](1)
    rootp.unsafe_offset(0)[] = null_ptr[c_void]()

    for i in range(6):
        var node = tsearch(
            keys.unsafe_offset(i).unsafe_bitcast[c_void](),
            rootp,
            tree_by_number,
        )
        assert_true(Int(node) != 0, "a key gone in comes back as a node")

    var want = unsafe_alloc[c_int](1)
    want.unsafe_offset(0)[] = 40
    var found = tfind(want.unsafe_bitcast[c_void](), rootp, tree_by_number)
    assert_true(Int(found) != 0, "a member the tree holds is found")
    var node_key = found.unsafe_bitcast[c_ptr[c_int]]()[]
    assert_equal(
        node_key.unsafe_bitcast[c_int]()[],
        40,
        "and the key is what the node points at",
    )

    want.unsafe_offset(0)[] = 99
    var miss = tfind(want.unsafe_bitcast[c_void](), rootp, tree_by_number)
    assert_true(Int(miss) == 0, "a member the tree does not hold is not found")

    # again asking for a member it holds writes nothing new
    want.unsafe_offset(0)[] = 40
    var again = tsearch(want.unsafe_bitcast[c_void](), rootp, tree_by_number)
    assert_equal(
        Int(again), Int(found), "a key the tree holds is the node already there"
    )

    # the walk, said through a pipe so the handing-overs can be read
    var fds = unsafe_alloc[Int32](2)
    assert_equal(Int(pipe(fds)), 0, "a pipe for the walk to say into")
    assert_equal(
        dup2(fds.unsafe_offset(1)[], Int32(42)), 42, "the saying end takes 42"
    )
    _ = twalk(rootp.unsafe_offset(0)[], tree_say)
    _ = close(Int32(42))
    var said = unsafe_alloc[UInt8](16)
    var total = Int32(0)
    while total < Int32(12):
        total += Int32(
            read(
                fds.unsafe_offset(0)[],
                said.unsafe_offset(total),
                c_uint(Int(12 - Int(total))),
            )
        )
    var words = ""
    for i in range(12):
        words += String(chr(Int(said.unsafe_offset(i)[])))
    assert_equal(
        words,
        "PPLTLETPLTEE",
        (
            "the walk says pre, post and end for a node with children and leaf"
            " for one without"
        ),
    )
    _ = close(fds.unsafe_offset(0)[])
    _ = close(fds.unsafe_offset(1)[])
    fds.unsafe_free()
    said.unsafe_free()

    # taking a leaf out: the parent is what the keeping went through
    want.unsafe_offset(0)[] = 20
    var parent = tdelete(want.unsafe_bitcast[c_void](), rootp, tree_by_number)
    assert_true(Int(parent) != 0, "a leaf taken out says its parent")
    want.unsafe_offset(0)[] = 20
    var gone = tfind(want.unsafe_bitcast[c_void](), rootp, tree_by_number)
    assert_true(Int(gone) == 0, "and the member taken out is no member after")

    want.unsafe_offset(0)[] = 20
    var nothing = tdelete(want.unsafe_bitcast[c_void](), rootp, tree_by_number)
    assert_true(
        Int(nothing) == 0, "a member the tree does not hold is not taken out"
    )

    # a tree that holds nothing: the taking says so
    var empty_root = unsafe_alloc[c_ptr[c_void]](1)
    empty_root.unsafe_offset(0)[] = null_ptr[c_void]()
    want.unsafe_offset(0)[] = 1
    var empty = tdelete(
        want.unsafe_bitcast[c_void](), empty_root, tree_by_number
    )
    assert_true(Int(empty) == 0, "a tree that holds nothing gives up nothing")
    empty_root.unsafe_free()
    want.unsafe_free()
    rootp.unsafe_free()
    keys.unsafe_free()


def main() raises:
    test_the_tree_that_keeps_the_order()
    test_the_table_that_keeps_no_order()
    test_hsearch()
    test_queue()
    print("test_search: ok")
