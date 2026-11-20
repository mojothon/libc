# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <sys/memfd.h>.
#
# Linux only: a file the kernel keeps in memory and nothing names.
# There is no path on any filesystem behind the descriptor this
# makes, which is the whole point of it -- a scratch file whose
# contents never touch the disk and whose name never appears in any
# directory, only in /proc/self/fd where the kernel shows every
# descriptor it has.
# -----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_uint


# What the flags are worth. The sealing one does nothing by itself:
# it only says this file is willing to have its seals set later, by
# whoever calls `fcntl` on it with the seal operations.
comptime MFD_CLOEXEC: c_uint = 1
comptime MFD_ALLOW_SEALING: c_uint = 2
comptime MFD_HUGETLB: c_uint = 4


def memfd_create(name: c_ptr[UInt8], flags: c_uint) -> c_int:
    """C library <sys/memfd.h> function `memfd_create`.

    Reference:
        https://man7.org/linux/man-pages/man2/memfd_create.2.html

    Prototype:
        int memfd_create(const char *name, unsigned int flags)

    Description:
        Makes an anonymous file: a descriptor that reads and writes
        like a regular file's, backed by memory rather than by any
        filesystem, and reachable through no path at all. The name is
        a label for `/proc/self/fd` and for debugging -- two files
        may carry the same one, and neither name appears in any
        directory.

        The file starts empty and grows as it is written, exactly as
        a regular file does; `ftruncate` sizes it, `mmap` maps it,
        and every descriptor to it sees the same bytes, which is
        what makes it the modern shape of the anonymous scratch
        space `shm_open` used to be reached for.

    Args:
        name: The label the file carries in `/proc/self/fd`. Not a
            path and not looked up anywhere; only shown.
        flags: `MFD_CLOEXEC` to have the descriptor closed on `exec`,
            `MFD_ALLOW_SEALING` to let the file's seals be set
            later, `MFD_HUGETLB` for the huge-page backing, in any
            combination of the three.

    Returns:
        The descriptor, or -1 with `errno` set.

    Notes:
        Linux-specific, which the man page says on its first line.
        There is no equivalent on the other side: Darwin has no
        such call, no such header, and no `/proc` to show the
        descriptor in.

        The seals are the part `shm_open` never had: a file made
        with `MFD_ALLOW_SEALING` can be marked, through `fcntl`,
        against shrinking, against writing, against either growing
        back -- and once a seal is set with the permanent bit, no
        holder of any descriptor, not even the maker, can take it
        off. What that buys is trust between processes: the bytes
        can be handed to a party who did not make the file, and
        the party can check the seals rather than trust the hand.

        An empty name is accepted: the label shows nothing and the
        file is made all the same, the kernel having no rule for it
        to break. A name longer than the kernel's limit for it is
        truncated rather than refused, the way a regular file's name
        would not be -- the name here is shown, not kept in a
        directory, so the directory's rules do not reach it.
    """
    return external_call["memfd_create", c_int, c_ptr[UInt8], c_uint](
        name, flags
    )
