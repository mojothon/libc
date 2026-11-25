from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_size_t, c_ssize_t, c_void


def fsetxattr(
    fd: Int32,
    name: c_ptr[UInt8],
    value: c_ptr[c_void],
    size: c_size_t,
    flags: c_int,
) -> c_int:
    """C library <sys/xattr.h> function `fsetxattr`.

        int fsetxattr(int fd, const char *name, const void *value, size_t size, int flags)

    Reference:
        https://man7.org/linux/man-pages/man3/fsetxattr.3.html

    Description:
        Keeps a saying with the file `fd` opens, under the name
        the caller gives it -- a word of the caller's own the
        kernel keeps for the file, whatever the file itself
        says. A name already kept is refused unless the flag
        word says to take it over, and a name the kernel does
        not know the kind of is refused. The word is Linux's
        own; Darwin answers a different word with the sayings
        in the other order.

    Args:
        fd: A file, opened however the caller likes.
        name: The saying the kept word is kept under.
        value: The word to keep.
        size: How long the word is.
        flags: Whether a kept name may be taken over.

    Returns:
        0 on success, or -1 on error with `errno` set.
    """
    return external_call[
        "fsetxattr", c_int, Int32, c_ptr[UInt8], c_ptr[c_void], c_size_t, c_int
    ](fd, name, value, size, flags)


def fgetxattr(
    fd: Int32, name: c_ptr[UInt8], value: c_ptr[c_void], size: c_size_t
) -> c_ssize_t:
    """C library <sys/xattr.h> function `fgetxattr`.

        ssize_t fgetxattr(int fd, const char *name, void *value, size_t size)

    Reference:
        https://man7.org/linux/man-pages/man3/fgetxattr.3.html

    Description:
        Takes back the word kept with the file `fd` opens
        under the name the caller gives, into the room the
        caller gives; how big the room wants to be is asked
        with a null room, which the asking answers with the
        size and keeps nothing. A name nothing is kept under
        is refused with `errno` saying there is no word of
        it. The word is Linux's own; Darwin answers a
        different word with the sayings in the other order.

    Args:
        fd: A file, opened however the caller likes.
        name: The saying the word is kept under.
        value: The room for the word to come back into, or
            null to ask only for the size.
        size: How much room there is.

    Returns:
        How many bytes the word takes, or -1 on error with
        `errno` set.
    """
    return external_call[
        "fgetxattr", c_ssize_t, Int32, c_ptr[UInt8], c_ptr[c_void], c_size_t
    ](fd, name, value, size)


def flistxattr(fd: Int32, list: c_ptr[UInt8], size: c_size_t) -> c_ssize_t:
    """C library <sys/xattr.h> function `flistxattr`.

        ssize_t flistxattr(int fd, char *list, size_t size)

    Reference:
        https://man7.org/linux/man-pages/man3/flistxattr.3.html

    Description:
        Says the names of every word kept with the file `fd`
        opens, one after another and each ended before the
        next begins, into the room the caller gives. How big
        the room wants to be is asked with a null room. The
        word is Linux's own; Darwin answers a different word
        with the sayings in the other order.

    Args:
        fd: A file, opened however the caller likes.
        list: The room for the names to come back into, or
            null to ask only for the size.
        size: How much room there is.

    Returns:
        How many bytes the names take, or -1 on error with
        `errno` set.
    """
    return external_call[
        "flistxattr", c_ssize_t, Int32, c_ptr[UInt8], c_size_t
    ](fd, list, size)


def fremovexattr(fd: Int32, name: c_ptr[UInt8]) -> c_int:
    """C library <sys/xattr.h> function `fremovexattr`.

        int fremovexattr(int fd, const char *name)

    Reference:
        https://man7.org/linux/man-pages/man3/fremovexattr.3.html

    Description:
        Lets go of the word kept with the file `fd` opens
        under the name the caller gives; after it, asking
        for the word is refused, the way it would be if it
        had never been kept. The word is Linux's own; Darwin
        answers a different word with the sayings in the
        other order.

    Args:
        fd: A file, opened however the caller likes.
        name: The saying the word is kept under.

    Returns:
        0 on success, or -1 on error with `errno` set.
    """
    return external_call["fremovexattr", c_int, Int32, c_ptr[UInt8]](fd, name)
