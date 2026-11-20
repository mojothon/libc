# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# -----------------------------------
# C library <sys/uio.h>.
#
# The two here read and write another process's memory, where the
# pieces are named the way `readv` names the caller's own -- an
# iovec on each side, one in this address space and one in the
# other's, and the kernel carries the bytes between them. The
# permission it needs is the permission to trace the process, which
# is the caller's own children by default and nobody else's
# otherwise.


from std.ffi import external_call
from libc.constant import c_ptr
from libc.sys.socket import iovec


def process_vm_readv(
    pid: Int32,
    local_iov: c_ptr[iovec],
    liovcnt: UInt64,
    remote_iov: c_ptr[iovec],
    riovcnt: UInt64,
    flags: UInt64,
) -> Int64:
    """C library <sys/uio.h> function `process_vm_readv`.

    Reference:
        https://man7.org/linux/man-pages/man2/process_vm_readv.2.html

    Description:
        process_vm_readv() reads out of the memory the process pid
        holds, the pieces named by remote_iov being where the bytes
        are in that address space and the pieces named by local_iov
        being where they go in this one -- the kernel carrying what
        is read, and nothing of the other process's memory ever
        coming up in one piece unless the pieces ask for it so.

    Args:
        pid: The process to read from.
        local_iov: The pieces to fill, in the caller's own memory.
        liovcnt: How many pieces the local array holds.
        remote_iov: The pieces to read, in the other process's.
        riovcnt: How many pieces the remote array holds.
        flags: None are named yet; pass zero.

    Returns:
        How many bytes were read, or -1 with `errno` set.

    Notes:
        The permission behind it is worth having words for: the
        kernel answers only when the caller may trace the process
        it is reading, which is its own children by default, and
        a caller without that is refused rather than shown the
        memory. What a debugger does by attaching, this does in
        one call, without the stopping that attaching costs.

        A short read is a short answer and not a failure: the
        count that comes back is what moved, and the pieces the
        remote side named but the call did not reach are left
        as they were.
    """
    return external_call[
        "process_vm_readv",
        Int64,
        Int32,
        c_ptr[iovec],
        UInt64,
        c_ptr[iovec],
        UInt64,
        UInt64,
    ](pid, local_iov, liovcnt, remote_iov, riovcnt, flags)


def process_vm_writev(
    pid: Int32,
    local_iov: c_ptr[iovec],
    liovcnt: UInt64,
    remote_iov: c_ptr[iovec],
    riovcnt: UInt64,
    flags: UInt64,
) -> Int64:
    """C library <sys/uio.h> function `process_vm_writev`.

    Reference:
        https://man7.org/linux/man-pages/man2/process_vm_writev.2.html

    Description:
        process_vm_writev() writes into the memory the process pid
        holds, the pieces named by local_iov being where the bytes
        are in this address space and the pieces named by
        remote_iov being where they go in the other's -- the same
        carrying the read does, in the other direction.

    Args:
        pid: The process to write to.
        local_iov: The pieces to send, in the caller's own memory.
        liovcnt: How many pieces the local array holds.
        remote_iov: The pieces to fill, in the other process's.
        riovcnt: How many pieces the remote array holds.
        flags: None are named yet; pass zero.

    Returns:
        How many bytes were written, or -1 with `errno` set.

    Notes:
        The writing is the part a caller should hold lightly:
        what the other process does with bytes put into its
        memory is its own business, and a page the process is
        executing from is changed at the cost of whatever it
        was about to do. The reading shows a process's memory;
        the writing changes it, and the permission is the same
        for both because the kernel cannot tell the difference
        between looking and changing once the looking is done.
    """
    return external_call[
        "process_vm_writev",
        Int64,
        Int32,
        c_ptr[iovec],
        UInt64,
        c_ptr[iovec],
        UInt64,
        UInt64,
    ](pid, local_iov, liovcnt, remote_iov, riovcnt, flags)
