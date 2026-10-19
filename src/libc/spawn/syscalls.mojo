# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <spawn.h>.
#
# Starting a process without `fork`: `posix_spawn` is handed the path,
# the arguments and the environment and hands back a pid. The two
# things that go with it -- a list of what to do to the new process's
# file descriptors, and a set of attributes -- are opaque handles here
# and are only ever passed by address.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_char, c_int, c_ptr, c_short, c_uint


# All six are the same number on both platforms, which is not the
# pattern here: `_PC_*`, `_SC_*` and `_CS_*` are numbered differently on
# each. These are plain bit flags, so they agree.
comptime POSIX_SPAWN_RESETIDS: Int32 = 1
comptime POSIX_SPAWN_SETPGROUP: Int32 = 2
comptime POSIX_SPAWN_SETSIGDEF: Int32 = 4
comptime POSIX_SPAWN_SETSIGMASK: Int32 = 8
comptime POSIX_SPAWN_SETSCHEDPARAM: Int32 = 16
comptime POSIX_SPAWN_SETSCHEDULER: Int32 = 32


struct posix_spawn_file_actions_t:
    """A C `posix_spawn_file_actions_t`: what to do to the new process's
    file descriptors before it starts.

    Opaque, and deliberately so: C names what is inside it under a name
    of its own, `_posix_spawn_file_actions`, and the two platforms do
    not agree on how much of it there is — eighty bytes on glibc,
    sixteen on Darwin. This holds more than either asks for, which
    costs memory and says nothing: the handle is only ever passed by
    address and the C side never looks past what it thinks it is, so
    a block larger than the truth is a block the truth fits in.

    `posix_spawn_file_actions_init` before it is used and
    `posix_spawn_file_actions_destroy` after, or the list inside it is
    leaked.
    """

    var _bytes: Array[UInt64, 16]

    def __init__(out self):
        """Zeroes the block, which is what `init` expects to be handed."""
        self._bytes = Array[UInt64, 16](fill=0)


struct posix_spawnattr_t:
    """A C `posix_spawnattr_t`: what else the new process should be.

    Opaque, like the file actions, and for the same reason: three
    hundred and thirty-six bytes on glibc and something smaller on
    Darwin, filled in only through `posix_spawnattr_set*`.

    `posix_spawnattr_init` before it is used and
    `posix_spawnattr_destroy` after.
    """

    var _bytes: Array[UInt64, 64]

    def __init__(out self):
        """Zeroes the block, which is what `init` expects to be handed."""
        self._bytes = Array[UInt64, 64](fill=0)


def posix_spawn(
    pid: c_ptr[c_int],
    path: c_ptr[c_char],
    file_actions: c_ptr[posix_spawn_file_actions_t],
    attrp: c_ptr[posix_spawnattr_t],
    argv: c_ptr[c_ptr[c_char]],
    envp: c_ptr[c_ptr[c_char]],
) -> c_int:
    """C library <spawn.h> function `posix_spawn`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn.3.html

    Prototype:
        int posix_spawn(pid_t *restrict pid, const char *restrict path,
                        const posix_spawn_file_actions_t *restrict
                        file_actions, const posix_spawnattr_t *restrict
                        attrp, char *const argv[restrict],
                        char *const envp[restrict])

    Description:
        Starts `path` as a new process with `argv` and `envp`, which is
        what `fork` and `execve` do between them. `path` is taken as
        written and is not looked for.

    Args:
        pid: Where the new process's id is written. Only written when
            the call answers 0.
        path: The program to run, with the directory it is in.
        file_actions: What to do to the file descriptors before the
            program starts, or null to inherit them as they are.
        attrp: What else the new process should be — its process group,
            its signal mask — or null for the usual.
        argv: The arguments, end to end, with a null where they end.
            `argv[0]` is what the program sees itself called.
        envp: The environment, end to end, with a null where it ends.

    Returns:
        0 when the process is started, or the error number itself —
        not -1, and `errno` is left alone.

    Notes:
        The error comes back as the return value, which is unlike
        nearly everything else here: there is no `errno` to read. Two
        of the four `POSIX_SPAWN_*` that take an argument are bound
        above.
    """
    return external_call[
        "posix_spawn",
        c_int,
        c_ptr[c_int],
        c_ptr[c_char],
        c_ptr[posix_spawn_file_actions_t],
        c_ptr[posix_spawnattr_t],
        c_ptr[c_ptr[c_char]],
        c_ptr[c_ptr[c_char]],
    ](pid, path, file_actions, attrp, argv, envp)


def posix_spawnp(
    pid: c_ptr[c_int],
    file: c_ptr[c_char],
    file_actions: c_ptr[posix_spawn_file_actions_t],
    attrp: c_ptr[posix_spawnattr_t],
    argv: c_ptr[c_ptr[c_char]],
    envp: c_ptr[c_ptr[c_char]],
) -> c_int:
    """C library <spawn.h> function `posix_spawnp`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn.3.html

    Prototype:
        int posix_spawnp(pid_t *restrict pid, const char *restrict file,
                         const posix_spawn_file_actions_t *restrict
                         file_actions, const posix_spawnattr_t *restrict
                         attrp, char *const argv[restrict],
                         char *const envp[restrict])

    Description:
        The same as `posix_spawn`, except that a `file` with no slash in
        it is looked for along `PATH`, the way a shell finds a command.

    Args:
        pid: Where the new process's id is written.
        file: The program to run, either the whole path or a name to be
            looked for along `PATH`.
        file_actions: What to do to the file descriptors first, or null.
        attrp: What else the new process should be, or null.
        argv: The arguments, null where they end.
        envp: The environment, null where it ends.

    Returns:
        0 when the process is started, or the error number itself.

    Notes:
        A `file` with a slash in it is used as it stands, without being
        looked for.
    """
    return external_call[
        "posix_spawnp",
        c_int,
        c_ptr[c_int],
        c_ptr[c_char],
        c_ptr[posix_spawn_file_actions_t],
        c_ptr[posix_spawnattr_t],
        c_ptr[c_ptr[c_char]],
        c_ptr[c_ptr[c_char]],
    ](pid, file, file_actions, attrp, argv, envp)


def posix_spawn_file_actions_init(
    file_actions: c_ptr[posix_spawn_file_actions_t],
) -> c_int:
    """C library <spawn.h> function `posix_spawn_file_actions_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn_file_actions_init.3.html

    Prototype:
        int posix_spawn_file_actions_init(posix_spawn_file_actions_t
                                          *file_actions)

    Args:
        file_actions: The handle, which is emptied.

    Returns:
        0, or the error number itself.

    Notes:
        `posix_spawn_file_actions_destroy` is the other half; without it
        whatever the handle is holding inside is leaked.
    """
    return external_call[
        "posix_spawn_file_actions_init",
        c_int,
        c_ptr[posix_spawn_file_actions_t],
    ](file_actions)


def posix_spawn_file_actions_destroy(
    file_actions: c_ptr[posix_spawn_file_actions_t],
) -> c_int:
    """C library <spawn.h> function `posix_spawn_file_actions_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn_file_actions_init.3.html

    Prototype:
        int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t
                                             *file_actions)

    Args:
        file_actions: A handle `init` was called on.

    Returns:
        0, or the error number itself.

    Notes:
        Calling it twice on one handle is not defined. It does not close
        anything: the entries are only a list of things the new process
        is to do, and it is the new process that does them.
    """
    return external_call[
        "posix_spawn_file_actions_destroy",
        c_int,
        c_ptr[posix_spawn_file_actions_t],
    ](file_actions)


def posix_spawn_file_actions_addopen(
    file_actions: c_ptr[posix_spawn_file_actions_t],
    fd: c_int,
    path: c_ptr[c_char],
    oflag: c_int,
    mode: c_uint,
) -> c_int:
    """C library <spawn.h> function `posix_spawn_file_actions_addopen`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn_file_actions_addopen.3.html

    Prototype:
        int posix_spawn_file_actions_addopen(
            posix_spawn_file_actions_t *restrict file_actions, int fd,
            const char *restrict path, int oflag, mode_t mode)

    Args:
        file_actions: The list to add to, one `init` has emptied.
        fd: Which descriptor in the new process `open` is to land on.
        path: What to open.
        oflag: How to open it — `O_RDONLY`, `O_WRONLY`, `O_CREAT` and
            the rest, from `libc.fcntl`.
        mode: The permissions to give a file that is being made. Only
            asked for when `O_CREAT` is among `oflag`; give 0
            otherwise, since C reads it in either case.

    Returns:
        0, or the error number itself.

    Notes:
        Nothing is opened yet. `open` runs in the new process, after
        `fork` and before `exec`.
    """
    return external_call[
        "posix_spawn_file_actions_addopen",
        c_int,
        c_ptr[posix_spawn_file_actions_t],
        c_int,
        c_ptr[c_char],
        c_int,
        c_uint,
    ](file_actions, fd, path, oflag, mode)


def posix_spawn_file_actions_addclose(
    file_actions: c_ptr[posix_spawn_file_actions_t], fd: c_int
) -> c_int:
    """C library <spawn.h> function `posix_spawn_file_actions_addclose`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn_file_actions_addclose.3.html

    Prototype:
        int posix_spawn_file_actions_addclose(
        posix_spawn_file_actions_t *file_actions, int fd)

    Args:
        file_actions: The list to add to.
        fd: The descriptor to close in the new process.

    Returns:
        0, or the error number itself.

    Notes:
        The descriptor is left alone here: only the new process closes
        its copy, and whatever was open here stays open.
    """
    return external_call[
        "posix_spawn_file_actions_addclose",
        c_int,
        c_ptr[posix_spawn_file_actions_t],
        c_int,
    ](file_actions, fd)


def posix_spawn_file_actions_adddup2(
    file_actions: c_ptr[posix_spawn_file_actions_t],
    fildes: c_int,
    newfildes: c_int,
) -> c_int:
    """C library <spawn.h> function `posix_spawn_file_actions_adddup2`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawn_file_actions_adddup2.3.html

    Prototype:
        int posix_spawn_file_actions_adddup2(
            posix_spawn_file_actions_t *restrict file_actions,
            int fildes, int newfildes)

    Args:
        file_actions: The list to add to.
        fildes: The descriptor here whose meaning is to be carried over.
        newfildes: Which descriptor it is to become over there.

    Returns:
        0, or the error number itself.

    Notes:
        `newfildes` is closed first if it is open, the way `dup2` does
        it. This is the piece that turns a pipe into another process's
        standard output; the test does exactly that.
    """
    return external_call[
        "posix_spawn_file_actions_adddup2",
        c_int,
        c_ptr[posix_spawn_file_actions_t],
        c_int,
        c_int,
    ](file_actions, fildes, newfildes)


def posix_spawnattr_init(attr: c_ptr[posix_spawnattr_t]) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_init`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_init.3.html

    Prototype:
        int posix_spawnattr_init(posix_spawnattr_t *attr)

    Args:
        attr: The handle, which is set to the usual attributes.

    Returns:
        0, or the error number itself.

    Notes:
        `posix_spawnattr_destroy` is the other half.
    """
    return external_call[
        "posix_spawnattr_init", c_int, c_ptr[posix_spawnattr_t]
    ](attr)


def posix_spawnattr_destroy(attr: c_ptr[posix_spawnattr_t]) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_destroy`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_init.3.html

    Prototype:
        int posix_spawnattr_destroy(posix_spawnattr_t *attr)

    Args:
        attr: A handle `init` was called on.

    Returns:
        0, or the error number itself.
    """
    return external_call[
        "posix_spawnattr_destroy", c_int, c_ptr[posix_spawnattr_t]
    ](attr)


def posix_spawnattr_getflags(
    attr: c_ptr[posix_spawnattr_t], flags: c_ptr[c_short]
) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_getflags`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_getflags.3.html

    Prototype:
        int posix_spawnattr_getflags(const posix_spawnattr_t *restrict
                                     attr, short *restrict flags)

    Args:
        attr: The handle to read.
        flags: Where the flags are written.

    Returns:
        0, or the error number itself.

    Notes:
        The flags are a `short` here as C has them, so the six
        `POSIX_SPAWN_*` above all fit and then some.
    """
    return external_call[
        "posix_spawnattr_getflags",
        c_int,
        c_ptr[posix_spawnattr_t],
        c_ptr[c_short],
    ](attr, flags)


def posix_spawnattr_setflags(
    attr: c_ptr[posix_spawnattr_t], flags: c_short
) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_setflags`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_setflags.3.html

    Prototype:
        int posix_spawnattr_setflags(posix_spawnattr_t *attr, short flags)

    Args:
        attr: The handle.
        flags: Which of the six to honour, added together. Only what is
        set here is looked at: `POSIX_SPAWN_SETPGROUP` with a group of 0
        means its own group, while leaving it out means ours.

    Returns:
        0, or the error number itself.

    Notes:
        The round trip is the test — set a flag, read it back, and get
        the same one.
    """
    return external_call[
        "posix_spawnattr_setflags", c_int, c_ptr[posix_spawnattr_t], c_short
    ](attr, flags)


def posix_spawnattr_getpgroup(
    attr: c_ptr[posix_spawnattr_t], pgroup: c_ptr[c_int]
) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_getpgroup`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_getpgroup.3.html

    Prototype:
        int posix_spawnattr_getpgroup(const posix_spawnattr_t *restrict
                                      attr, pid_t *restrict pgroup)

    Args:
        attr: The handle to read.
        pgroup: Where the process group is written.

    Returns:
        0, or the error number itself.

    Notes:
        Only read when `POSIX_SPAWN_SETPGROUP` is among the flags;
        otherwise what the handle holds is not what will happen.
    """
    return external_call[
        "posix_spawnattr_getpgroup",
        c_int,
        c_ptr[posix_spawnattr_t],
        c_ptr[c_int],
    ](attr, pgroup)


def posix_spawnattr_setpgroup(
    attr: c_ptr[posix_spawnattr_t], pgroup: c_int
) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_setpgroup`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_setpgroup.3.html

    Prototype:
        int posix_spawnattr_setpgroup(posix_spawnattr_t *attr,
                                      pid_t pgroup)

    Args:
        attr: The handle.
        pgroup: The process group the new process is to be put in, or 0
        for one of its own.

    Returns:
        0, or the error number itself.

    Notes:
        Says nothing unless `POSIX_SPAWN_SETPGROUP` is set with
        `posix_spawnattr_setflags`; the two are read together.
    """
    return external_call[
        "posix_spawnattr_setpgroup", c_int, c_ptr[posix_spawnattr_t], c_int
    ](attr, pgroup)


def posix_spawnattr_setsigdefault(
    attr: c_ptr[posix_spawnattr_t], sigdefault: c_ptr[UInt8]
) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_setsigdefault`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_setsigdefault.3.html

    Prototype:
        int posix_spawnattr_setsigdefault(
            posix_spawnattr_t *restrict attr,
            const sigset_t *restrict sigdefault)

    Args:
        attr: The handle.
        sigdefault: The set of signals to put back to their default in
        the new process, as bytes the way `libc.signal` writes a
        `sigset_t`.

    Returns:
        0, or the error number itself.

    Notes:
        Needs `POSIX_SPAWN_SETSIGDEF` among the flags to be honoured.
        Handlers are dropped across `exec` on their own; this is for
        signals that were ignored, which `exec` leaves alone.
    """
    return external_call[
        "posix_spawnattr_setsigdefault",
        c_int,
        c_ptr[posix_spawnattr_t],
        c_ptr[UInt8],
    ](attr, sigdefault)


def posix_spawnattr_setsigmask(
    attr: c_ptr[posix_spawnattr_t], sigmask: c_ptr[UInt8]
) -> c_int:
    """C library <spawn.h> function `posix_spawnattr_setsigmask`.

    Reference:
        https://man7.org/linux/man-pages/man3/posix_spawnattr_setsigmask.3.html

    Prototype:
        int posix_spawnattr_setsigmask(
            posix_spawnattr_t *restrict attr,
            const sigset_t *restrict sigmask)

    Args:
        attr: The handle.
        sigmask: The mask the new process is to start with, as bytes.

    Returns:
        0, or the error number itself.

    Notes:
        Needs `POSIX_SPAWN_SETSIGMASK` among the flags to be honoured.
        Without it the new process starts with whatever is masked here.
    """
    return external_call[
        "posix_spawnattr_setsigmask",
        c_int,
        c_ptr[posix_spawnattr_t],
        c_ptr[UInt8],
    ](attr, sigmask)
