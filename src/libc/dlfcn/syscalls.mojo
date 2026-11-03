# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import c_ptr, c_void
from libc.utils import null_ptr


# What `dlopen` is asked for. `RTLD_LAZY` and `RTLD_NOW` are the same
# number on both platforms; `RTLD_GLOBAL` is 256 here and 8 there.
comptime RTLD_LAZY: Int32 = 1
comptime RTLD_NOW: Int32 = 2
comptime RTLD_GLOBAL: Int32 = 8 if CompilationTarget.is_macos() else 256


struct dl_info:
    """A C `struct Dl_info`: what `dladdr` found out about an address.

    Four members — the object's name, where it was loaded, the nearest
    symbol below the address, and that symbol's address — at 0, 8, 16 and
    24 on glibc and on Darwin both, thirty-two bytes and eight-aligned
    either way. Darwin calls the tag `dl_info` and glibc leaves the struct
    unnamed behind the typedef, so the name here is the tag one platform
    has and the typedef the other does.

    All four are borrowed. The two strings belong to the loader and stay
    valid for as long as the object is loaded, so nothing here copies
    them or frees them.
    """

    var dli_fname: c_ptr[UInt8]
    var dli_fbase: c_ptr[c_void]
    var dli_sname: c_ptr[UInt8]
    var dli_saddr: c_ptr[c_void]

    def __init__(out self):
        """Zeroes every member, which is the state of one nothing has filled."""
        self.dli_fname = null_ptr[UInt8]()
        self.dli_fbase = null_ptr[c_void]()
        self.dli_sname = null_ptr[UInt8]()
        self.dli_saddr = null_ptr[c_void]()


def dladdr(address: c_ptr[c_void], info: c_ptr[dl_info]) -> Int32:
    """C library <dlfcn.h> function `dladdr`.

    Reference:
        https://man7.org/linux/man-pages/man3/dladdr.3.html

    Prototype:
        int dladdr(const void *address, Dl_info *info)

    Description:
        Says what is at an address: which loaded object it falls in, where
        that object was loaded, and the nearest symbol at or below it. It
        is `dlsym` the other way round — one takes a name and answers an
        address, this takes an address and answers a name — and it is what
        turns the bare number `backtrace` hands back into something worth
        putting in a report.

    Arguments:
        address: The address to ask about.
        info: Where to write the answer. Every member is filled in when
            the call succeeds.

    Returns:
        Non-zero where the address is in a loaded object, and zero where
        it is in none — a stack address, a heap address, a number that was
        never an address at all. Zero is not an error and `dlerror` has
        nothing to say about it; there is simply nothing there to name.

    Notes:
        The symbol it answers with is the nearest one at or below the
        address, not the one the address is in: asking about the middle of
        a function names the function, and `dli_saddr` is then some way
        before the address that was asked about. The difference between
        the two is the offset into the symbol, which is what a symboliser
        outside libc adds to it.

        Where the object has no symbol table, or nothing below the address
        in it, `dli_sname` and `dli_saddr` come back null rather than the
        call failing: the object it is in is still an answer.

        Code that was built into memory by the interpreter has no object
        and no symbol table, so an address in it is in no loaded object and
        this answers zero — the same thing `backtrace_symbols` runs into
        when it can only write the address down. Code that was built ahead
        of time is in an object like any other.
    """
    return external_call["dladdr", Int32, c_ptr[c_void], c_ptr[dl_info]](
        address, info
    )


def dlclose(handle: c_ptr[UInt8]) -> Int32:
    """C library <dlfcn.h> function `dlclose`.

    Reference:
        https://man7.org/linux/man-pages/man3/dlclose.3.html

    Prototype:
        int dlclose(void *handle)

    Description:
        Closes a shared object that `dlopen` opened, once every handle to it
        has been closed.

    Arguments:
        handle: A handle `dlopen` returned.

    Return Value:
        0 on success, non-zero on error; `dlerror` says which.
    """
    return external_call["dlclose", Int32, c_ptr[UInt8]](handle)


def dlerror() -> c_ptr[UInt8]:
    """C library <dlfcn.h> function `dlerror`.

    Reference:
        https://man7.org/linux/man-pages/man3/dlerror.3.html

    Prototype:
        char *dlerror(void)

    Description:
        Returns a description of the most recent error from `dlopen`,
        `dlsym` or `dlclose`, and clears it: the second call after an error
        says there was none. This is not `errno` and does not use it.

    Returns:
        The message, or null if nothing has gone wrong since the last call.
    """
    return external_call["dlerror", c_ptr[UInt8]]()


def dlopen(filename: c_ptr[UInt8], flags: Int32) -> c_ptr[UInt8]:
    """C library <dlfcn.h> function `dlopen`.

    Reference:
        https://man7.org/linux/man-pages/man3/dlopen.3.html

    Prototype:
        void *dlopen(const char *filename, int flags)

    Description:
        Loads a shared object and returns a handle to it, or a handle to the
        one already loaded under the same name.

    Arguments:
        filename: The path of the object, or the name of one to look for in
            the usual places, or null for the main program.
        flags: `RTLD_LAZY` to resolve symbols as they are used or `RTLD_NOW`
            to resolve them now, either of them with `RTLD_GLOBAL` to make
            the object's symbols available to ones loaded later. The numbers
            stand for these differ between platforms, so name them from your
            own `<dlfcn.h>` rather than writing them down.

    Returns:
        A handle, or null on error; `dlerror` says which.
    """
    return external_call["dlopen", c_ptr[UInt8], c_ptr[UInt8], Int32](
        filename, flags
    )


def dlsym(handle: c_ptr[UInt8], symbol: c_ptr[UInt8]) -> c_ptr[UInt8]:
    """C library <dlfcn.h> function `dlsym`.

    Reference:
        https://man7.org/linux/man-pages/man3/dlsym.3.html

    Prototype:
        void *dlsym(void *handle, const char *symbol)

    Description:
        Finds a symbol in a loaded object, or in the ones loaded with it if
        the handle is for the main program.

    Arguments:
        handle: A handle `dlopen` returned.
        symbol: The name to look for.

    Returns:
        The address of the symbol, or null if there is no such one. A null
        result is not always an error, since a symbol can legitimately live
        at that address: `dlerror` is what tells the two apart.
    """
    return external_call["dlsym", c_ptr[UInt8], c_ptr[UInt8], c_ptr[UInt8]](
        handle, symbol
    )
