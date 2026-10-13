# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from std.ffi import external_call
from std.sys import CompilationTarget
from libc.constant import c_ptr


# What `dlopen` is asked for. `RTLD_LAZY` and `RTLD_NOW` are the same
# number on both platforms; `RTLD_GLOBAL` is 256 here and 8 there.
comptime RTLD_LAZY: Int32 = 1
comptime RTLD_NOW: Int32 = 2
comptime RTLD_GLOBAL: Int32 = 8 if CompilationTarget.is_macos() else 256


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
