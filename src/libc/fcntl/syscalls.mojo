# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.memory import Pointer
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import AT_FDCWD, c_ptr
from libc.sys.socket import iovec


# What `open` is given. The three access modes are the same everywhere and
# almost nothing else is: both number the flags from bit 0 and assign them
# differently, so O_CREAT is 64 here and 512 there, and O_APPEND is 1024 here
# and 8 there. The Linux values were read out of <fcntl.h> and the Darwin ones
# out of XNU's bsd/sys/fcntl.h. Three are Linux's own and have no number on
# Darwin at all.
#
# Four of the Linux numbers are the x86-64 ones alone, because the ARM ABI
# inherited its fcntl.h from 32-bit ARM and numbers those four differently:
# O_DIRECTORY is 040000 there and 0200000 on x86-64, O_NOFOLLOW is the other
# way round, O_DIRECT swaps with O_DIRECTORY's x86-64 bit, and O_TMPFILE is
# O_DIRECTORY added to its own bit, so it moves with it. `check-constants`
# reads the header on every machine in the matrix, which is where this was
# found.
comptime O_RDONLY: Int32 = 0
comptime O_WRONLY: Int32 = 1
comptime O_RDWR: Int32 = 2
comptime O_ACCMODE: Int32 = 3
comptime O_CREAT: Int32 = 512 if CompilationTarget.is_macos() else 64
comptime O_EXCL: Int32 = 2048 if CompilationTarget.is_macos() else 128
comptime O_NOCTTY: Int32 = 131072 if CompilationTarget.is_macos() else 256
comptime O_TRUNC: Int32 = 1024 if CompilationTarget.is_macos() else 512
comptime O_APPEND: Int32 = 8 if CompilationTarget.is_macos() else 1024
comptime O_NONBLOCK: Int32 = 4 if CompilationTarget.is_macos() else 2048
comptime O_DSYNC: Int32 = 4194304 if CompilationTarget.is_macos() else 4096
comptime O_DIRECTORY: Int32 = 1048576 if CompilationTarget.is_macos() else (
    Int32(16384) if (
        CompilationTarget.is_linux() and CompilationTarget.is_arm()
    ) else 65536
)
comptime O_NOFOLLOW: Int32 = 256 if CompilationTarget.is_macos() else (
    Int32(32768) if (
        CompilationTarget.is_linux() and CompilationTarget.is_arm()
    ) else 131072
)
comptime O_CLOEXEC: Int32 = 16777216 if CompilationTarget.is_macos() else 524288
comptime O_SYNC: Int32 = 128 if CompilationTarget.is_macos() else 1052672
# Linux's own: Darwin's <fcntl.h> has no number for these.
comptime O_DIRECT: Int32 = Int32(65536) if (
    CompilationTarget.is_linux() and CompilationTarget.is_arm()
) else 16384
comptime O_NOATIME: Int32 = 262144
comptime O_PATH: Int32 = 2097152

# The `fcntl` commands. The first five are the same on both platforms, and the
# rest are not: Linux numbers the lock commands 5, 6 and 7 and the ownership
# ones 8 and 9, where Darwin does it the other way round.
comptime F_DUPFD: Int32 = 0
comptime F_GETFD: Int32 = 1
comptime F_SETFD: Int32 = 2
comptime F_GETFL: Int32 = 3
comptime F_SETFL: Int32 = 4
comptime F_GETLK: Int32 = 7 if CompilationTarget.is_macos() else 5
comptime F_SETLK: Int32 = 8 if CompilationTarget.is_macos() else 6
comptime F_SETLKW: Int32 = 9 if CompilationTarget.is_macos() else 7
comptime F_GETOWN: Int32 = 5 if CompilationTarget.is_macos() else 9
comptime F_SETOWN: Int32 = 6 if CompilationTarget.is_macos() else 8

# What a descriptor's own flags can be, and what a lock is asked to be. Both
# the same on the two platforms.
comptime FD_CLOEXEC: Int32 = 1
comptime F_RDLCK: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime F_UNLCK: Int32 = 2
comptime F_WRLCK: Int32 = 3 if CompilationTarget.is_macos() else 1

# What `flock` is given, also the same on both.
comptime LOCK_SH: Int32 = 1
comptime LOCK_EX: Int32 = 2
comptime LOCK_NB: Int32 = 4
comptime LOCK_UN: Int32 = 8

# What `lockf` is asked for. The same numbers on both platforms.
comptime F_ULOCK: Int32 = 0
comptime F_LOCK: Int32 = 1
comptime F_TLOCK: Int32 = 2
comptime F_TEST: Int32 = 3

# Linux's own, and glibc only says so under _GNU_SOURCE: Darwin's <fcntl.h>
# has no O_TMPFILE. The number is its own bit added to O_DIRECTORY, so it
# moves where O_DIRECTORY moves.
comptime O_TMPFILE: Int32 = Int32(4210688) if (
    CompilationTarget.is_linux() and CompilationTarget.is_arm()
) else 4259840


def creat(path: c_ptr[UInt8], mode: UInt32) -> Int32:
    """Libc POSIX `creat` function.

    Args:
        path: A path to a file.
        mode: A mode to open the file with.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/creat.3p.html).
        Fn signature: `int creat(const char *path, mode_t mode)`.
    """
    return external_call["creat", Int32, c_ptr[UInt8], UInt32](path, mode)


def fcntl(fildes: Int32, cmd: Int32, arg: Int32) -> Int32:
    """Libc POSIX `fcntl` function, with the argument the call always takes.

    C's is variadic and `external_call` wants each type written out, so what
    is bound is the int-argument form: it covers `F_GETFD` and `F_GETFL`,
    which are the two that ask a descriptor what is set on it, and the
    commands that set something. A command that wants a pointer, a lock or
    a descriptor to fill in has nothing here to give it one.

    There is no two-argument form, and the reason is not C's. C does not
    mind being called with two, and the commands that read nothing are
    happy that way -- but a program that makes both calls cannot be built:
    one symbol ends up declared twice with two different signatures, and
    the compiler stops with `existing function with conflicting signature`
    when the module is lowered rather than at the second call. So there is
    one form, every command is given three arguments, and the ones that
    read nothing are given 0. `F_GETFD` and `F_GETFL` are asked that way
    in the tests.

    On Apple silicon the value in that third argument does not arrive, and
    the reason is the ABI rather than the command: arm64 hands a variadic
    callee its anonymous arguments on the stack, `external_call` emits a
    call whose arguments are all in registers, and what the callee reads is
    a stack slot nobody wrote. A `F_SETFL` made that way returns 0 and the
    flag is not there afterwards -- `F_GETFL` came back without it when
    this was asked on a runner -- so a command that *sets* something
    arrives only where the slot happens to hold what was meant. The
    commands that only read are unaffected, because they never look at the
    argument at all.

    Args:
        fildes: A File Descriptor to ask about, or to set something on.
        cmd: A command to execute.
        arg: What the command works on, a flags word for `F_SETFL`, and
            ignored by the commands that take nothing -- 0 is the honest
            thing to pass to those.

    Returns:
        Whatever the command asked for, which is a different thing each
        time: duplicating answers with the new descriptor, asking for the
        flags answers with them, and the commands that only set something
        answer 0 for having done it. Only -1 is failure, with `errno` set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/fcntl.3p.html).
        Fn signature: `int fcntl(int fildes, int cmd, ...)`.
    """
    return external_call["fcntl", Int32, Int32, Int32, Int32](fildes, cmd, arg)


def open(path: c_ptr[UInt8], oflag: Int32) -> Int32:
    """Libc POSIX `open` function.

    Args:
        path: A path to a file.
        oflag: A flag to open the file with.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int open(const char *path, int oflag, ...)`.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        AT_FDCWD, path, oflag, 0
    )


def open(path: c_ptr[UInt8], oflag: Int32, mode: Int32) -> Int32:
    """Libc POSIX `open`, with the mode that `O_CREAT` and `O_TMPFILE` need.

    Args:
        path: A path to a file.
        oflag: A flag to open the file with.
        mode: The permissions to create the file with, such as 0o644.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int open(const char *path, int oflag, ...)`.

        C's `open` is variadic, and it reads the mode whether a creating flag
        is set or not, so the two-argument form is unusable with `O_CREAT`.
        Two things follow, and both are why these call `openat` instead: two
        `external_call`s under the one name do not agree on a signature, and
        arm64 Darwin passes variadic arguments on the stack, which an external
        call cannot express at all.

        `openat` takes the same arguments with the directory descriptor in
        front, so `open(path, oflag, mode)` is `openat(AT_FDCWD, path, oflag,
        mode)`. That is an improvement and not a cure, `openat` being
        variadic in the same way: on macOS the mode does not arrive, and a
        file asked for with 0o644 came out as 0o150, which is no umask of
        0o644 but a different number — whatever was on the stack where the
        argument should have been. Ask with `fchmod` afterwards when the
        permissions matter, which is what the test for this does.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        AT_FDCWD, path, oflag, mode
    )


def openat(fd: Int32, path: c_ptr[UInt8], oflag: Int32) -> Int32:
    """Libc POSIX `openat` function.

    Description:
        Opens `path` relative to a directory rather than to where the
        process stands, `fd` being that directory's descriptor. `open` is
        the special case of this where nothing is given to be relative to.

    Args:
        fd: A File Descriptor to open the file with.
        path: A path to a file.
        oflag: A flag to open the file with.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int openat(int fd, const char *path, int oflag, ...)`.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        fd, path, oflag, 0
    )


def openat(fd: Int32, path: c_ptr[UInt8], oflag: Int32, mode: Int32) -> Int32:
    """Libc POSIX `openat`, with the mode that `O_CREAT` needs.

    Args:
        fd: A File Descriptor to open the file with.
        path: A path to a file.
        oflag: A flag to open the file with.
        mode: The permissions to create the file with, such as 0o644.

    Returns:
        A File Descriptor. Otherwise -1 and `errno` is set.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/open.3p.html).
        Fn signature: `int openat(int fd, const char *path, int oflag, ...)`.

        Variadic, and so is `open`, and the mode is the argument after the
        named ones: on macOS it does not arrive, and the file comes out with
        whatever was on the stack instead. `fchmod` afterwards is the way to
        be sure of the permissions. `open` says more about this.
    """
    return external_call["openat", Int32, Int32, c_ptr[UInt8], Int32, Int32](
        fd, path, oflag, mode
    )


def lockf(fd: Int32, cmd: Int32, len: Int64) -> Int32:
    """Libc POSIX `lockf` function.

    Reference:
        https://man7.org/linux/man-pages/man3/lockf.3.html

    Description:
        lockf() takes a lock on part of an open file, gives one up, or asks
        whether one is free.

    Args:
        fd: A descriptor for the file, which has to be open for writing to
            take a lock on it.
        cmd: `F_LOCK` to take one and wait, `F_TLOCK` to take one and fail
            instead of waiting, `F_ULOCK` to give it up, or `F_TEST` to ask
            whether it is free.
        len: How many bytes from the current position, which can be
            negative to reach backwards, or 0 for the rest of the file.

    Returns:
        0 on success, -1 on error with `errno` set. `F_TEST` answers 0 when
        the range is free and -1 when somebody has it.

    Notes:
        This is `fcntl` over the same locks, with `F_LOCK` meaning wait and
        `F_TLOCK` meaning do not. The lock belongs to the file and not to
        the descriptor, so closing any descriptor for the file lets go of
        every lock this process holds on it.
    """
    return external_call["lockf", Int32, Int32, Int32, Int64](fd, cmd, len)


def flock(fd: Int32, operation: Int32) -> Int32:
    """Libc BSD `flock` function.

    Reference:
        https://man7.org/linux/man-pages/man2/flock.2.html

    Args:
        fd: A descriptor for the file to lock, which only has to be open.
        operation: `LOCK_SH` for a lock shared with other readers,
            `LOCK_EX` for one nobody else may hold, `LOCK_UN` to give it
            up, and `LOCK_NB` added to either of the first two to fail
            rather than wait.

    Returns:
        0 where the lock was taken or given up, or -1 with `errno` set —
        `EWOULDBLOCK` for `LOCK_NB` when somebody else has it.

    Notes:
        A whole-file lock, and a different thing from `lockf` even
        though both are advisory: this one is taken on the open file and
        not on a range of it, and it is given up by closing the
        descriptor or by asking for `LOCK_UN`.

        It belongs to the open file rather than to the process, which is
        where it differs from `lockf` in the other direction: two
        descriptors opened separately on the same path are two things
        that can refuse each other, while two descriptors for the same
        open file share the lock they have.
    """
    return external_call["flock", Int32, Int32, Int32](fd, operation)


# What the flags are worth. The move one is a hint the kernel has
# taken to ignoring -- pages have gone the way it asks for years --
# and the gift one is vmsplice's own: a page handed over that the
# caller promises not to touch again.
comptime SPLICE_F_MOVE: UInt32 = 1
comptime SPLICE_F_NONBLOCK: UInt32 = 2
comptime SPLICE_F_MORE: UInt32 = 4
comptime SPLICE_F_GIFT: UInt32 = 8


def splice(
    fd_in: Int32,
    off_in: c_ptr[Int64],
    fd_out: Int32,
    off_out: c_ptr[Int64],
    count: UInt64,
    flags: UInt32,
) -> Int:
    """Libc Linux `splice` function.

    Reference:
        https://man7.org/linux/man-pages/man2/splice.2.html

    Description:
        splice() moves count bytes from the file associated with fd_in to
        the file associated with fd_out, through a pipe the kernel owns:
        at least one of the two ends has to be the pipe, and the bytes
        the pipe holds are handed over rather than copied -- nothing
        comes up to the caller and nothing goes back down.

    Args:
        fd_in: The file to move bytes out of, one end of the pipe
            being moved through.
        off_in: Where the position to move from is, and where the
            position that was moved to is put back; null means the
            file's own position is used and advanced instead.
        fd_out: The file to move bytes into, the other end of the pipe
            the bytes go through.
        off_out: The same, for the file being written.
        count: Number of bytes to move.
        flags: `SPLICE_F_NONBLOCK` for the ends that would otherwise
            wait, `SPLICE_F_MORE` to tell the kernel there is more of
            this coming, `SPLICE_F_MOVE` for the hint the kernel has
            taken to ignoring, in any combination.

    Returns:
        How many bytes were moved, or -1 with `errno` set.

    Notes:
        Linux-specific, which the man page says on its first line:
        there is nothing on the other side to call.

        One end has to be the pipe. Two regular files are not
        spliced together by this call -- that is what
        `copy_file_range` is for, which needs no pipe and no pages
        in one on the way through.

        An empty pipe answers zero rather than waiting, and a zero
        from this call is not a failure: it is the pipe having
        nothing to hand over, the way a read at the end of a file
        is not one either.
    """
    return external_call[
        "splice", Int, Int32, c_ptr[Int64], Int32, c_ptr[Int64], UInt64, UInt32
    ](fd_in, off_in, fd_out, off_out, count, flags)


def vmsplice(
    fd: Int32, iov: c_ptr[iovec], nr_segs: UInt64, flags: UInt32
) -> Int:
    """Libc Linux `vmsplice` function.

    Reference:
        https://man7.org/linux/man-pages/man2/vmsplice.2.html

    Description:
        vmsplice() puts the caller's own memory into the pipe the
        descriptor fd opens: the pages the iovec names are handed to
        the kernel to be the pipe's contents, rather than copied into
        what the pipe already holds.

    Args:
        fd: A descriptor for the pipe the pages are put into.
        iov: The pieces of the caller's memory to put there, where
            each starts and how long it is.
        nr_segs: How many pieces the iovec holds.
        flags: `SPLICE_F_GIFT` to promise the pages are not touched
            again, which lets the kernel keep them rather than copy
            them; the rest of the flags say nothing here.

    Returns:
        How many bytes were put into the pipe, or -1 with `errno`
        set.

    Notes:
        Linux-specific, and the giving is the part worth having
        words for: what the kernel does with a gifted page is its
        own business from then on, and a caller who keeps writing
        through it is changing what the pipe holds behind the
        reader's back. The pages a caller means to keep are better
        handed over without the gift, and the copy that costs is
        the copy that keeps.

        A read end takes instead of gives: `vmsplice` on the read
        end of a pipe fills the caller's pages from what the pipe
        holds, which is the same moving in the other direction.
    """
    return external_call["vmsplice", Int, Int32, c_ptr[iovec], UInt64, UInt32](
        fd, iov, nr_segs, flags
    )


def tee(fd_in: Int32, fd_out: Int32, count: UInt64, flags: UInt32) -> Int:
    """Libc Linux `tee` function.

    Reference:
        https://man7.org/linux/man-pages/man2/tee.2.html

    Description:
        tee() copies count bytes from one pipe to another, and what
        it copies stays where it was: the pipe read from holds its
        bytes still, and the pipe written to holds a copy of them,
        with nothing coming up to the caller in between.

    Args:
        fd_in: The pipe to copy from, which keeps what it holds.
        fd_out: The pipe to copy into, which has to have room.
        count: Number of bytes to copy.
        flags: `SPLICE_F_NONBLOCK` for the pipes that would
            otherwise wait; the rest say nothing here.

    Returns:
        How many bytes were copied, or -1 with `errno` set.

    Notes:
        Linux-specific, and the keeping is the whole of it: `splice`
        moves what it takes and the pipe read from is emptier for
        it, where `tee` leaves the source exactly as it stood --
        which is how one pipe's contents get handed to two readers
        without the caller ever holding the bytes.

        Both ends have to be pipes. There is no file form of this
        one, and no `tee` for a regular file at either end.
    """
    return external_call["tee", Int, Int32, Int32, UInt64, UInt32](
        fd_in, fd_out, count, flags
    )
