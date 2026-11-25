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


def setxattr(
    path: c_ptr[UInt8],
    name: c_ptr[UInt8],
    value: c_ptr[c_void],
    size: c_size_t,
    flags: c_int,
) -> c_int:
    """C library <sys/xattr.h> function `setxattr`.

        int setxattr(const char *path, const char *name, const void *value, size_t size, int flags)

    Reference:
        https://man7.org/linux/man-pages/man3/setxattr.3.html

    Description:
        What `fsetxattr` keeps, said by way of a path --
        and by way of a symlink followed to the file it
        says, the word kept with what the path really
        opens. The word is Linux's own; Darwin answers a
        different word with the sayings in the other
        order.

    Args:
        path: A path, symlinks followed.
        name: The saying the kept word is kept under.
        value: The word to keep.
        size: How long the word is.
        flags: Whether a kept name may be taken over.

    Returns:
        0 on success, or -1 on error with `errno` set.
    """
    return external_call[
        "setxattr",
        c_int,
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[c_void],
        c_size_t,
        c_int,
    ](path, name, value, size, flags)


def lsetxattr(
    path: c_ptr[UInt8],
    name: c_ptr[UInt8],
    value: c_ptr[c_void],
    size: c_size_t,
    flags: c_int,
) -> c_int:
    """C library <sys/xattr.h> function `lsetxattr`.

        int lsetxattr(const char *path, const char *name, const void *value, size_t size, int flags)

    Reference:
        https://man7.org/linux/man-pages/man3/lsetxattr.3.html

    Description:
        What `fsetxattr` keeps, said by way of a path
        whose symlinks are not followed -- the word kept
        with the link itself, where the kernel keeps
        none of the caller's kind, and refuses the
        asking. The word is Linux's own; Darwin answers
        a different word with the sayings in the other
        order.

    Args:
        path: A path, symlinks not followed.
        name: The saying the kept word is kept under.
        value: The word to keep.
        size: How long the word is.
        flags: Whether a kept name may be taken over.

    Returns:
        0 on success, or -1 on error with `errno` set.
    """
    return external_call[
        "lsetxattr",
        c_int,
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[c_void],
        c_size_t,
        c_int,
    ](path, name, value, size, flags)


def getxattr(
    path: c_ptr[UInt8], name: c_ptr[UInt8], value: c_ptr[c_void], size: c_size_t
) -> c_ssize_t:
    """C library <sys/xattr.h> function `getxattr`.

        ssize_t getxattr(const char *path, const char *name, void *value, size_t size)

    Reference:
        https://man7.org/linux/man-pages/man3/getxattr.3.html

    Description:
        What `fgetxattr` takes back, said by way of a
        path whose symlinks are followed to the file the
        path really opens. The word is Linux's own;
        Darwin answers a different word with the sayings
        in the other order.

    Args:
        path: A path, symlinks followed.
        name: The saying the word is kept under.
        value: The room for the word to come back into,
            or null to ask only for the size.
        size: How much room there is.

    Returns:
        How many bytes the word takes, or -1 on error
        with `errno` set.
    """
    return external_call[
        "getxattr",
        c_ssize_t,
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[c_void],
        c_size_t,
    ](path, name, value, size)


def lgetxattr(
    path: c_ptr[UInt8], name: c_ptr[UInt8], value: c_ptr[c_void], size: c_size_t
) -> c_ssize_t:
    """C library <sys/xattr.h> function `lgetxattr`.

        ssize_t lgetxattr(const char *path, const char *name, void *value, size_t size)

    Reference:
        https://man7.org/linux/man-pages/man3/lgetxattr.3.html

    Description:
        What `fgetxattr` takes back, said by way of a
        path whose symlinks are not followed -- the word
        asked of the link itself, which the kernel keeps
        none of the caller's kind on, and answers with
        nothing and `errno` saying why. The word is
        Linux's own; Darwin answers a different word with
        the sayings in the other order.

    Args:
        path: A path, symlinks not followed.
        name: The saying the word is kept under.
        value: The room for the word to come back into,
            or null to ask only for the size.
        size: How much room there is.

    Returns:
        How many bytes the word takes, or -1 on error
        with `errno` set.
    """
    return external_call[
        "lgetxattr",
        c_ssize_t,
        c_ptr[UInt8],
        c_ptr[UInt8],
        c_ptr[c_void],
        c_size_t,
    ](path, name, value, size)


def listxattr(
    path: c_ptr[UInt8], list: c_ptr[UInt8], size: c_size_t
) -> c_ssize_t:
    """C library <sys/xattr.h> function `listxattr`.

        ssize_t listxattr(const char *path, char *list, size_t size)

    Reference:
        https://man7.org/linux/man-pages/man3/listxattr.3.html

    Description:
        What `flistxattr` says, said by way of a path
        whose symlinks are followed to the file the path
        really opens. The word is Linux's own; Darwin
        answers a different word with the sayings in the
        other order.

    Args:
        path: A path, symlinks followed.
        list: The room for the names to come back into,
            or null to ask only for the size.
        size: How much room there is.

    Returns:
        How many bytes the names take, or -1 on error
        with `errno` set.
    """
    return external_call[
        "listxattr", c_ssize_t, c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](path, list, size)


def llistxattr(
    path: c_ptr[UInt8], list: c_ptr[UInt8], size: c_size_t
) -> c_ssize_t:
    """C library <sys/xattr.h> function `llistxattr`.

        ssize_t llistxattr(const char *path, char *list, size_t size)

    Reference:
        https://man7.org/linux/man-pages/man3/llistxattr.3.html

    Description:
        What `flistxattr` says, said by way of a path
        whose symlinks are not followed -- the names
        asked of the link itself, which the kernel keeps
        none of the caller's kind on, and answers with
        none. The word is Linux's own; Darwin answers a
        different word with the sayings in the other
        order.

    Args:
        path: A path, symlinks not followed.
        list: The room for the names to come back into,
            or null to ask only for the size.
        size: How much room there is.

    Returns:
        How many bytes the names take, or -1 on error
        with `errno` set.
    """
    return external_call[
        "llistxattr", c_ssize_t, c_ptr[UInt8], c_ptr[UInt8], c_size_t
    ](path, list, size)


def removexattr(path: c_ptr[UInt8], name: c_ptr[UInt8]) -> c_int:
    """C library <sys/xattr.h> function `removexattr`.

        int removexattr(const char *path, const char *name)

    Reference:
        https://man7.org/linux/man-pages/man3/removexattr.3.html

    Description:
        What `fremovexattr` lets go, said by way of a
        path whose symlinks are followed to the file the
        path really opens. The word is Linux's own;
        Darwin answers a different word with the sayings
        in the other order.

    Args:
        path: A path, symlinks followed.
        name: The saying the word is kept under.

    Returns:
        0 on success, or -1 on error with `errno` set.
    """
    return external_call["removexattr", c_int, c_ptr[UInt8], c_ptr[UInt8]](
        path, name
    )


def lremovexattr(path: c_ptr[UInt8], name: c_ptr[UInt8]) -> c_int:
    """C library <sys/xattr.h> function `lremovexattr`.

        int lremovexattr(const char *path, const char *name)

    Reference:
        https://man7.org/linux/man-pages/man3/lremovexattr.3.html

    Description:
        What `fremovexattr` lets go, said by way of a
        path whose symlinks are not followed -- the
        word asked of the link itself. The word is
        Linux's own; Darwin answers a different word
        with the sayings in the other order.

    Args:
        path: A path, symlinks not followed.
        name: The saying the word is kept under.

    Returns:
        0 on success, or -1 on error with `errno` set.
    """
    return external_call["lremovexattr", c_int, c_ptr[UInt8], c_ptr[UInt8]](
        path, name
    )
