# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
"""`key_t`, the `IPC_*` numbers and `ftok` from `<sys/ipc.h>`.

System V shared objects — message queues, shared memory and semaphore
sets — are not opened by name. They are named by a key, which is a
`key_t`: a plain four-byte number chosen by whoever asks first, and
looked up by number afterwards. `ftok` is one way of choosing one, and
the only way this header offers: it takes a path that has to exist and
a byte, and mixes them into a number.

Two processes that call `ftok` with the same path and the same byte get
the same key, which is the whole of the meeting arrangement. Nothing
keeps two different pairs from arriving at the same number, and nothing
records who owns a key, so a caller that wants to know it is talking to
its own object rather than somebody else's has to pass `IPC_CREAT | IPC_EXCL`
and be told that the object is already there.
"""

from std.ffi import external_call

from libc.constant import c_int, c_ptr

# The key type. glibc's <sys/ipc.h> reaches it through `__key_t`, which is
# an `int`; Darwin's <sys/_types/_key_t.h> defines `key_t` as `__int32_t`
# outright. Four bytes either way, and signed either way.
comptime key_t = Int32

# The six numbers this header is worth binding: the flags creation is
# given and the commands the control calls are given. All six are the
# same on both platforms, which is rare enough in System V IPC to be
# worth saying — the members of the structs beside them are not.
comptime IPC_PRIVATE: Int32 = 0
comptime IPC_CREAT: Int32 = 512
comptime IPC_EXCL: Int32 = 1024
comptime IPC_RMID: Int32 = 0
comptime IPC_SET: Int32 = 1
comptime IPC_STAT: Int32 = 2

# The one flag the calls share as well: do not wait. It is 04000 on both
# platforms, and it is the only flag that all three kinds of object read
# the same way.
comptime IPC_NOWAIT: Int32 = 2048


def ftok(path: c_ptr[UInt8], id: c_int) -> key_t:
    """Libc POSIX `ftok` function.

    Description:
        Mixes a path and a byte into a key that two processes can agree
        on without either of them having been told it.

    Args:
        path: A path that exists, as bytes with a nil on the end. Only
            its identity is used — the device it is on and the number it
            has — so two paths to the same file give the same answer.
        id: A byte's worth of choice, so that one file can name more
            than one object. Only the low eight bits are used.

    Returns:
        A key, or -1 where the path could not be looked at, with `errno`
        saying why.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/ftok.3.html).
        Fn signature: `key_t ftok(const char *path, int id)`.

        The number is not guaranteed to be new: it is sixteen bits of the
        file's number and eight bits of `id` put together, so a busy
        machine can hand two different pairs the same key. It is a way of
        agreeing on a name, not a way of reserving one.

        The path has to be one the process can see. A path in a directory
        it cannot search is a -1 and `EACCES`, which says nothing about
        whether the file is there.
    """
    return external_call["ftok", key_t, c_ptr[UInt8], c_int](path, id)
