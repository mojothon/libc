"""Tests for the `libc.dlfcn` bindings, none of which had been called."""
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr, c_void
from libc.dlfcn import (
    RTLD_NOW,
    dl_info,
    dladdr,
    dlclose,
    dlerror,
    dlopen,
    dlsym,
)
from libc.utils import char_ptr_to_string, string_to_char_ptr


def _the_c_library() -> c_ptr[UInt8]:
    """The name of the C library on this platform, opened.

    Darwin and glibc spell it differently and there is no name that is
    right on both.
    """
    comptime LIBRARY = "libc.dylib" if CompilationTarget.is_macos() else "libc.so.6"
    return dlopen(string_to_char_ptr(LIBRARY), RTLD_NOW)


def test_loading_the_c_library() raises:
    """`dlopen` takes the name and then the flags, `dlsym` the handle and
    then the symbol, and each hands back a pointer that is nothing at all
    when it fails. `dlerror` is the one that says which of those it was.

    What is found cannot be called from here — Mojo has no way to make a
    call through a pointer it was handed — so what is asked of `dlsym` is
    only whether it found the thing, and what is asked of `dlerror` is
    whether it has anything to say about the ones it did not.
    """
    var handle = _the_c_library()
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


def test_an_address_is_named_back() raises:
    """`dladdr` is `dlsym` the other way round, and the two of them
    together make a claim that can be checked without knowing anything
    about either: a name goes in one end and comes out the other.

    `getpid` is what is looked up rather than a string function, because
    the string ones are ifuncs: the address `dlsym` answers with is the
    implementation the machine chose, which is a different symbol from the
    one that was asked for and would be named differently.

    What is asserted about the answer is what the pair makes true: the
    name that comes back is the name that went in, the address of that
    symbol is the address that was handed over — exactly, since a symbol
    start is the nearest symbol to itself — and the object it is in has a
    load address that is not after it.

    The address of a heap block is in no object, which is the other half
    of the call: zero, and no error.
    """
    var handle = _the_c_library()
    assert_true(Int(UInt(handle)) != 0, "the C library is open")

    var address = dlsym(handle, string_to_char_ptr("getpid"))
    assert_true(Int(UInt(address)) != 0, "the symbol has an address")

    var info = unsafe_alloc[dl_info](1)
    assert_true(
        dladdr(address.unsafe_bitcast[c_void](), info) != 0,
        "and that address is in a loaded object",
    )
    var named = char_ptr_to_string(info[].dli_sname)
    assert_equal(named, String("getpid"), "which names the symbol that went in")
    assert_equal(
        Int(UInt(info[].dli_saddr)),
        Int(UInt(address)),
        "the symbol's address being the address that was asked about",
    )
    assert_true(
        char_ptr_to_string(info[].dli_fname).byte_length() > 0,
        "the object it is in has a name",
    )
    assert_true(
        Int(UInt(info[].dli_fbase)) <= Int(UInt(info[].dli_saddr)),
        "and is loaded at or before the symbol it holds",
    )
    info.unsafe_free()

    var outside = unsafe_alloc[UInt64](1)
    var blank = unsafe_alloc[dl_info](1)
    assert_equal(
        dladdr(outside.unsafe_bitcast[c_void](), blank),
        0,
        "an address in no object is in no object",
    )
    blank.unsafe_free()
    outside.unsafe_free()

    assert_equal(dlclose(handle), 0, "and the handle goes back")


def main() raises:
    test_loading_the_c_library()
    test_an_address_is_named_back()
    print("test_dlfcn: ok")
