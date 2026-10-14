"""Tests for the `libc.dlfcn` bindings, none of which had been called."""
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.dlfcn import RTLD_NOW, dlclose, dlerror, dlopen, dlsym
from libc.utils import string_to_char_ptr


def test_loading_the_c_library() raises:
    """`dlopen` takes the name and then the flags, `dlsym` the handle and
    then the symbol, and each hands back a pointer that is nothing at all
    when it fails. `dlerror` is the one that says which of those it was.

    What is found cannot be called from here — Mojo has no way to make a
    call through a pointer it was handed — so what is asked of `dlsym` is
    only whether it found the thing, and what is asked of `dlerror` is
    whether it has anything to say about the ones it did not.
    """
    # Darwin and glibc spell the C library differently, and there is no
    # name that is right on both.
    comptime LIBRARY = "libc.dylib" if CompilationTarget.is_macos() else "libc.so.6"

    var handle = dlopen(string_to_char_ptr(LIBRARY), RTLD_NOW)
    assert_true(Int(UInt(handle)) != 0, "dlopen opens the C library")
    # Whatever was left over from before is not what is being asked
    # about, so it is read once and put aside.
    _ = dlerror()

    var found = dlsym(handle, string_to_char_ptr("strlen"))
    assert_true(Int(UInt(found)) != 0, "dlsym finds a symbol that is there")
    assert_true(
        Int(UInt(dlerror())) == 0, "and there is nothing to be said about it"
    )

    var missing = dlsym(handle, string_to_char_ptr("no_such_symbol_anywhere"))
    assert_true(Int(UInt(missing)) == 0, "and nothing for one that is not")
    assert_true(Int(UInt(dlerror())) != 0, "which is what dlerror is for")

    assert_equal(dlclose(handle), 0, "and dlclose takes the handle back")


def main() raises:
    test_loading_the_c_library()
    print("test_dlfcn: ok")
