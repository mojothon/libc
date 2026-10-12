# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.memory import Pointer

from libc.constant import c_int, c_ptr, c_size_t


comptime FIND: c_int = 0
comptime ENTER: c_int = 1


struct ENTRY(TrivialRegisterPassable):
    """A C `struct entry`: one row of an `hsearch` table.

    The table owns neither member. `hsearch` compares rows by `key`, so the
    bytes it points at have to outlive every call that uses them.
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

        Frees the table `hcreate` made. It does not free the keys or the data
        the rows point at; that is the caller's job.
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

    The C original is `struct qelem { struct qelem *q_forw, *q_back; }`, which
    Mojo cannot spell because the struct refers to itself. The links are
    pointers to the next and previous node, whatever type those nodes are, so
    they are untyped here; compare them against node addresses.
    """

    var q_forw: c_ptr[UInt8]
    var q_back: c_ptr[UInt8]

    def __init__(out self, q_forw: c_ptr[UInt8], q_back: c_ptr[UInt8]):
        """Builds a node with the given links.

        Args:
            q_forw: The forward link, the next node.
            q_back: The backward link, the previous node.
        """
        self.q_forw = q_forw
        self.q_back = q_back
