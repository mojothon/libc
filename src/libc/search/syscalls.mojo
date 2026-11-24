# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer

from libc.constant import c_int, c_ptr, c_size_t, c_void


comptime FIND: c_int = 0
comptime ENTER: c_int = 1


struct ENTRY(TrivialRegisterPassable):
    """A C `struct entry`: one row of an `hsearch` table.

    `hsearch` compares rows by `key` with `strcmp`, so the bytes it points at
    have to outlive every call that uses them — and if `hdestroy` will run,
    they have to come from `malloc`, because BSD frees them.
    """

    var key: c_ptr[UInt8]
    var data: c_ptr[NoneType]

    def __init__(out self, key: c_ptr[UInt8], data: c_ptr[NoneType]):
        """Builds a row.

        Args:
            key: The key `hsearch` compares on, a null terminated string.
            data: Whatever the row should carry.
        """
        self.key = key
        self.data = data


def hcreate(nel: c_size_t) -> c_int:
    """Libc POSIX `hcreate` function.

    Args:
        nel: An upper bound on how many rows the table will hold.

    Returns:
        Non-zero on success, else 0.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/hcreate.3.html).
        Fn signature: `int hcreate(size_t nel)`.

        There is one table per process, hidden inside libc, so two independent
        users of this function collide. `hdestroy` releases it.
    """
    return external_call["hcreate", c_int, c_size_t](nel)


def hdestroy() -> None:
    """Libc POSIX `hdestroy` function.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/hcreate.3.html).
        Fn signature: `void hdestroy(void)`.

        Frees the table `hcreate` made. It never frees the data, but the keys
        are another matter: BSD, Darwin included, calls `free` on every key in
        the table, while glibc leaves them alone. So keys have to come from
        `malloc`, and portable code cannot free them itself either way.
    """
    external_call["hdestroy", NoneType]()


def hsearch(item: ENTRY, action: c_int) -> c_ptr[ENTRY]:
    """Libc POSIX `hsearch` function.

    Args:
        item: The row to look for. With `ENTER` it is the row to insert.
        action: `FIND` to look up, `ENTER` to insert or update.

    Returns:
        With `FIND`, a pointer to the matching row, or a null pointer if there
        is none. With `ENTER`, a pointer to the row now in the table, or a
        null pointer if the table is full.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/hsearch.3.html).
        Fn signature: `ENTRY *hsearch(ENTRY item, ACTION action)`.

        `ENTER` on an existing key keeps the old key and stores `item.data`.
        The returned pointer points into the table, not at `item`.
    """
    return external_call["hsearch", c_ptr[ENTRY], ENTRY, c_int](item, action)


def insque(elem: c_ptr[NoneType], pred: c_ptr[NoneType]) -> None:
    """Libc POSIX `insque` function.

    Args:
        elem: The node to insert, whose first two pointer sized members are
            the forward and backward links.
        pred: The node to insert after, or a null pointer to put `elem` at
            the head of a queue of its own.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/insque.3.html).
        Fn signature: `void insque(void *elem, void *pred)`.

        libc only touches the two links, so any struct with two pointers at
        the front will do; see `qelem`.
    """
    external_call["insque", NoneType, c_ptr[NoneType], c_ptr[NoneType]](
        elem, pred
    )


def remque(elem: c_ptr[NoneType]) -> None:
    """Libc POSIX `remque` function.

    Args:
        elem: The node to unlink from the queue it sits in.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/insque.3.html).
        Fn signature: `void remque(void *elem)`.

        The node's own links are left dangling. Call it on a node `insque`
        put in a queue, and only once.
    """
    external_call["remque", NoneType, c_ptr[NoneType]](elem)


struct qelem(TrivialRegisterPassable):
    """A node for `insque` and `remque`: two links libc owns.

    The C original is `struct qelem { struct qelem *q_forw, *q_back; char
    q_data[1]; }`, which Mojo cannot spell because the struct refers to
    itself. The links are pointers to the next and previous node, whatever
    type those nodes are, so they are untyped here; compare them against
    node addresses.

    `q_data` is the payload slot C leaves hanging off the end, one byte
    asked for and eight given by alignment. It was left out here once, which
    made this sixteen bytes against C's twenty-four: walkable node by node,
    since whatever follows one of these in memory is where the next eight
    bytes go, and `insque` has no way of knowing they belong to somebody.

    It is a word and not an array because this travels by value in places,
    which an `Array` field would rule out; the eight bytes are opaque here
    either way.
    """

    var q_forw: c_ptr[UInt8]
    var q_back: c_ptr[UInt8]
    var q_data: UInt64

    def __init__(out self, q_forw: c_ptr[UInt8], q_back: c_ptr[UInt8]):
        """Builds a node with the given links.

        Args:
            q_forw: The forward link, the next node.
            q_back: The backward link, the previous node.
        """
        self.q_forw = q_forw
        self.q_back = q_back
        self.q_data = 0


def lfind(
    key: c_ptr[c_void],
    base: c_ptr[c_void],
    count: c_ptr[c_size_t],
    width: c_size_t,
    compare: def(c_ptr[c_void], c_ptr[c_void]) thin -> Int32,
) -> c_ptr[c_void]:
    """C library <search.h> function `lfind`.

    Reference:
        https://man7.org/linux/man-pages/man3/lsearch.3.html

    Prototype:
        void *lfind(const void *key, const void *base, size_t *nelp, size_t width, int (*compar)(const void *, const void *))

    Description:
        Looks a key up in a table that is kept in no order:
        the members are handed to the comparing function one
        after the other, and the first the function calls a
        match is what comes back -- a pointer to the member
        itself, not a copy of it. A key that is no member of
        the table comes back as nothing, and the count the
        table is said to hold is left as it was: the looking
        does not change what it looks through.

    Args:
        key: The key to look up.
        base: The first member of the table.
        count: Where the table's member count is read from.
        width: The width of one member, in bytes.
        compare: What two members are to be compared by.

    Returns:
        A pointer to the first member the comparing function
        calls a match with the key, or a null pointer when
        the table holds no such member.

    Notes:
        The looking is linear -- one member after the other,
        in the order they are kept -- which is why the table
        is under no obligation to be sorted, and why the
        asking costs what `bsearch` does not: a table of many
        members is looked through the whole way when the key
        is no member of it. The comparing function is the
        same word `bsearch` takes, and the member it points
        at is the one to read, whatever the count beside it
        says the table holds.
    """
    return external_call[
        "lfind",
        c_ptr[c_void],
        c_ptr[c_void],
        c_ptr[c_void],
        c_ptr[c_size_t],
        c_size_t,
        def(c_ptr[c_void], c_ptr[c_void]) thin -> Int32,
    ](key, base, count, width, compare)


def lsearch(
    key: c_ptr[c_void],
    base: c_ptr[c_void],
    count: c_ptr[c_size_t],
    width: c_size_t,
    compare: def(c_ptr[c_void], c_ptr[c_void]) thin -> Int32,
) -> c_ptr[c_void]:
    """C library <search.h> function `lsearch`.

    Reference:
        https://man7.org/linux/man-pages/man3/lsearch.3.html

    Prototype:
        void *lsearch(const void *key, void *base, size_t *nelp, size_t width, int (*compar)(const void *, const void *))

    Description:
        Looks a key up in a table that is kept in no order,
        and puts the key in when it is not there: what comes
        back is a pointer to the member found or to the slot
        the key was written into, and the count the table is
        said to hold is one more than it was when the key was
        not a member. A key the table already holds is left
        where it is, and the count is left as it was.

    Args:
        key: The key to look up, and to write in when the
            table holds no such member.
        base: The first member of the table, and the slot the
            next member is written into when the key is not
            there.
        count: Where the table's member count is read from
            and written to.
        width: The width of one member, in bytes.
        compare: What two members are to be compared by.

    Returns:
        A pointer to the member found or to the member
        written in.

    Notes:
        The writing in is done by copying the key the width
        of a member into the slot after the last member the
        table was said to hold, so the room has to be there
        before the asking is made -- the asking does not find
        a place to put the key, it takes the one the count
        points past. The count is written back one more than
        it was read, which is what makes the next asking look
        past the member written this time.
    """
    return external_call[
        "lsearch",
        c_ptr[c_void],
        c_ptr[c_void],
        c_ptr[c_void],
        c_ptr[c_size_t],
        c_size_t,
        def(c_ptr[c_void], c_ptr[c_void]) thin -> Int32,
    ](key, base, count, width, compare)
