# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <sys/inotify.h>.
#
# Linux only: watching files and directories for what happens to them,
# read out of a descriptor as a stream of small events. The BSDs have
# kqueue and FSEvents and nothing of this shape, so the four here are
# not on the other side, and neither is the header.
#
# The descriptor is a queue, and what comes off it is a `struct
# inotify_event` followed by the name of whatever it is about when it
# is about something inside a watched directory: `len` says how many
# bytes of name follow, and 0 means there is no name at all.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_uint


# What can be watched for. Twelve of them are things that happen to a
# file, and the rest are what the queue itself says: that the queue
# overflowed and events were dropped, that a watch was taken off, or
# that what is being watched is a directory.
comptime IN_ACCESS: c_uint = 1
comptime IN_MODIFY: c_uint = 2
comptime IN_ATTRIB: c_uint = 4
comptime IN_CLOSE_WRITE: c_uint = 8
comptime IN_CLOSE_NOWRITE: c_uint = 16
comptime IN_OPEN: c_uint = 32
comptime IN_MOVED_FROM: c_uint = 64
comptime IN_MOVED_TO: c_uint = 128
comptime IN_CREATE: c_uint = 256
comptime IN_DELETE: c_uint = 512
comptime IN_DELETE_SELF: c_uint = 1024
comptime IN_MOVE_SELF: c_uint = 2048
comptime IN_UNMOUNT: c_uint = 8192
comptime IN_Q_OVERFLOW: c_uint = 16384
comptime IN_IGNORED: c_uint = 32768
comptime IN_ISDIR: c_uint = 1073741824

# Every one of the twelve above, which is what a program that wants
# the lot asks for.
comptime IN_ALL_EVENTS: c_uint = 4095

# And the two that are `open` flags by another name, which belong to
# `inotify_init1` rather than to a watch.
comptime IN_CLOEXEC: c_int = 524288
comptime IN_NONBLOCK: c_int = 2048


struct inotify_event:
    """One thing that happened: which watch it was under, what it
    was, and how many bytes of name follow this.

    The name is not in here. It starts where this ends, and `len`
    says how long it is: 0 for something that happened to the file or
    directory itself, and the length of the name, rounded up so the
    next event is aligned, for something that happened inside a
    watched directory.
    """

    # Which watch this came from: the number `inotify_add_watch`
    # answered with.
    var wd: Int32

    # What happened, one or more of the `IN_*` bits.
    var mask: UInt32

    # Pairs a rename: the `IN_MOVED_FROM` and the `IN_MOVED_TO` of one
    # rename share a cookie, which is the only way to tell which went
    # where.
    var cookie: UInt32

    # How many bytes of name follow this, 0 when there is none.
    var len: UInt32


def inotify_init() -> c_int:
    """C library <sys/inotify.h> function `inotify_init`.

    Reference:
        https://man7.org/linux/man-pages/man2/inotify_init.2.html

    Prototype:
        int inotify_init(void)

    Description:
        Makes a queue: a descriptor that events are read off of,
        empty at first, with nothing being watched yet. What is
        watched, and what is watched for, is `inotify_add_watch`.

    Returns:
        The descriptor, or -1 with `errno` set.

    Notes:
        Reads wait: a `read` on an empty queue does not come back
        until something happens, which is `inotify_init1` with
        `IN_NONBLOCK` if that is not wanted.

        Linux-specific. The BSDs watch files through kqueue and
        FSEvents, and there is no equivalent on the other side:
        calling this there will not link.

        The queue is of events and not of files: nothing is in it
        until a watch is added, and what is in it is read once and
        then gone.
    """
    return external_call["inotify_init", c_int]()


def inotify_init1(flags: c_int) -> c_int:
    """C library <sys/inotify.h> function `inotify_init1`.

    Reference:
        https://man7.org/linux/man-pages/man2/inotify_init.2.html

    Prototype:
        int inotify_init1(int flags)

    Description:
        The same queue as `inotify_init`, with the two flags a
        descriptor is usually wanted with: `IN_NONBLOCK` so that a
        read of an empty queue answers rather than waits, and
        `IN_CLOEXEC` so that it does not survive an `exec`.

    Args:
        flags: `IN_NONBLOCK`, `IN_CLOEXEC`, or both.

    Returns:
        The descriptor, or -1 with `errno` set.

    Notes:
        The two are `open`'s `O_NONBLOCK` and `O_CLOEXEC` by another
        name, and worth the same numbers as those here.

        Which of the two is worth having depends on how the queue is
        read: a program that reads it only when `poll` says there is
        something there wants `IN_NONBLOCK` anyway, because a queue
        can be emptied by another read between the two.
    """
    return external_call["inotify_init1", c_int, c_int](flags)


def inotify_add_watch(fd: c_int, pathname: c_ptr[UInt8], mask: c_uint) -> c_int:
    """C library <sys/inotify.h> function `inotify_add_watch`.

    Reference:
        https://man7.org/linux/man-pages/man7/inotify.7.html

    Prototype:
        int inotify_add_watch(int fd, const char *pathname, uint32_t mask)

    Description:
        Puts a file or a directory under the queue: from here on, the
        things named in `mask` that happen to it are added to the
        queue as they happen. Watching a directory is watching what
        happens to the files in it, which is the usual reason to
        watch one.

    Args:
        fd: An inotify descriptor.
        pathname: The file or directory to watch.
        mask: What to watch for, any combination of the twelve `IN_*`
            bits, or `IN_ALL_EVENTS` for the lot.

    Returns:
        The watch descriptor, a number of its own that is not the
        file's and not the queue's, or -1 with `errno` set.

    Notes:
        One watch per thing: asking again about a path already
        watched does not make a second one, it changes the mask of
        the first and answers with the watch descriptor it already
        had.

        The number answers two questions, and is worth keeping: it is
        what comes back in every event, which is how a queue watching
        twenty things says which of them an event is about, and it is
        what `inotify_rm_watch` takes.

        What is watched is the file itself and not its name — it
        keeps being watched after a rename, and until the last
        descriptor for it is closed.
    """
    return external_call[
        "inotify_add_watch", c_int, c_int, c_ptr[UInt8], c_uint
    ](fd, pathname, mask)


def inotify_rm_watch(fd: c_int, wd: c_int) -> c_int:
    """C library <sys/inotify.h> function `inotify_rm_watch`.

    Reference:
        https://man7.org/linux/man-pages/man2/inotify_rm_watch.2.html

    Prototype:
        int inotify_rm_watch(int fd, int wd)

    Description:
        Takes a watch off the queue: nothing more is added to it for
        that file or directory, and the watch descriptor goes out of
        use.

    Args:
        fd: The inotify descriptor the watch was added to.
        wd: The watch descriptor `inotify_add_watch` answered with.

    Returns:
        0, or -1 with `errno` set.

    Notes:
        Taking a watch off is itself an event: one with `IN_IGNORED`
        set is put on the queue, and is the last thing that watch
        ever says. So a queue is not necessarily empty just because
        nothing is happening to anything watched.

        Already gone answers -1: a watch descriptor that has been
        removed, or one that belongs to another queue, is not one
        this has. Closing the queue takes every watch off it at once,
        and no `IN_IGNORED` is put on it then, there being nowhere
        left to put one.
    """
    return external_call["inotify_rm_watch", c_int, c_int, c_int](fd, wd)
