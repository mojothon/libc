# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <execinfo.h>, the stack the process is standing on.
#
# This is neither ISO C nor POSIX: it is a BSD extension that glibc copied,
# which is why the three calls exist twice over — XNU has had them since
# 10.5 and glibc since 2.1 — and why nothing outside those two promises they
# exist at all. What they do is read the return addresses off the stack:
# `backtrace` fills an array with them, `backtrace_symbols` turns that array
# into one line of text per frame, and `backtrace_symbols_fd` writes the
# same lines to a descriptor.
#
# The two forms are not the same call twice. The strings have to be
# allocated, so that call makes one block holding the array and the text
# together and hands back a pointer into it — which is why it is the array
# that goes back to `free` and not each string. The descriptor one allocates
# nothing and is safe to call where allocating is not, and that is the whole
# reason it exists: it is what a crash handler writes with while the heap it
# would have asked is already gone.
#
# The count is a count of what the unwinder could find, not of what is
# there. A frame the compiler inlined left no frame behind, a frame without
# unwind information may be stepped over, and a call to `backtrace` in a
# tail position has already replaced its caller's frame by the time it runs.
# So the answer is at most `size` and may be shorter, and the honest thing
# to test is the ceiling, the floor that the caller can prove, and that the
# two forms agree with each other about how many frames they are describing.
#
# XNU has two more that glibc does not — `backtrace_from_fp` and
# `backtrace_image_offsets` — so neither is here.
# ----------------------------------
from std.ffi import external_call

from libc.constant import c_int, c_ptr, c_void


def backtrace(buffer: c_ptr[c_ptr[c_void]], size: c_int) -> c_int:
    """C library <execinfo.h> function `backtrace`.

    Reference:
        https://man7.org/linux/man-pages/man3/backtrace.3.html

    Prototype:
        int backtrace(void **buffer, int size)

    Description:
        Records the return addresses of the frames above the caller. The
        first entry is the address this call returns to, and each one
        after it is a frame further out.

    Args:
        buffer: Where to write the addresses, room for `size` of them.
        size: How many frames to record at most.

    Returns:
        How many were recorded. Never more than `size`, and fewer when
        the stack runs out before it does.

    Notes:
        An address on its own says nothing a caller can use: it is an
        address of code, not of data, and what it means depends on where
        the image was loaded. The two calls below turn the array into
        text, and a symboliser outside libc turns that into a file and a
        line.

        Nothing is allocated and nothing outside the stack is read, so
        this is as cheap as a call that walks a few registers can be.
    """
    return external_call["backtrace", c_int, c_ptr[c_ptr[c_void]], c_int](
        buffer, size
    )


def backtrace_symbols(
    buffer: c_ptr[c_ptr[c_void]], size: c_int
) -> c_ptr[c_ptr[UInt8]]:
    """C library <execinfo.h> function `backtrace_symbols`.

    Reference:
        https://man7.org/linux/man-pages/man3/backtrace_symbols.3.html

    Prototype:
        char **backtrace_symbols(void *const *buffer, int size)

    Description:
        Turns what `backtrace` recorded into one line of text per frame.

    Args:
        buffer: The addresses `backtrace` wrote.
        size: How many of them to describe. Passing the count
            `backtrace` answered with describes all of them.

    Returns:
        An array of `size` strings, or null with `errno` set where the
        allocation failed. The array and every string in it are one
        block, so it is the array that is given back to `free` and the
        strings are not.

    Notes:
        A frame whose name cannot be found is written down anyway: glibc
        prints the object it is in and the offset into it, and XNU prints
        the address, so the text is not the same on the two platforms
        and a test can count the lines rather than read them.

        This allocates, which is what keeps it out of a signal handler.
        `backtrace_symbols_fd` is the one that is safe there.
    """
    return external_call[
        "backtrace_symbols", c_ptr[c_ptr[UInt8]], c_ptr[c_ptr[c_void]], c_int
    ](buffer, size)


def backtrace_symbols_fd(
    buffer: c_ptr[c_ptr[c_void]], size: c_int, fd: c_int
) raises:
    """C library <execinfo.h> function `backtrace_symbols_fd`.

    Reference:
        https://man7.org/linux/man-pages/man3/backtrace_symbols_fd.3.html

    Prototype:
        void backtrace_symbols_fd(void *const *buffer, int size, int fd)

    Description:
        Writes the same lines `backtrace_symbols` would have made, one
        per frame, straight to a descriptor.

    Args:
        buffer: The addresses `backtrace` wrote.
        size: How many of them to describe.
        fd: The descriptor to write them to.

    Notes:
        Each frame is one line, in the same order as the array the other
        call would have made, so the number of lines written is the
        number of frames described. That is what the test holds the two
        calls to, since neither the words nor their spelling is the same
        on both platforms.

        This allocates nothing, which is what makes it the one of the
        three that a signal handler may call.
    """
    external_call[
        "backtrace_symbols_fd", NoneType, c_ptr[c_ptr[c_void]], c_int, c_int
    ](buffer, size, fd)
