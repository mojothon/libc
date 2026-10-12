from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import c_ptr
from libc.file import close
from libc.stdio import remove
from libc.stdlib import (
    atof,
    atoi,
    atol,
    calloc,
    free,
    getenv,
    getsubopt,
    initstate,
    malloc,
    mkstemp,
    rand,
    random,
    realpath,
    realloc,
    setenv,
    setstate,
    srand,
    srandom,
    strtol,
    strtod,
    unsetenv,
)
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def test_malloc() raises:
    var p = malloc(64)
    p.unsafe_store(0, 42)
    p.unsafe_store(63, 7)
    assert_equal(Int(p.unsafe_load(0)), 42)
    assert_equal(Int(p.unsafe_load(63)), 7)
    _ = free(p)


def test_calloc() raises:
    var p = calloc(16, 1)
    var i = 0
    while i < 16:
        assert_equal(Int(p.unsafe_load(i)), 0)
        i += 1
    _ = free(p)


def test_realloc() raises:
    var p = malloc(8)
    p.unsafe_store(0, 99)
    var q = realloc(p, 4096)
    assert_equal(Int(q.unsafe_load(0)), 99)
    q.unsafe_store(4095, 1)
    assert_equal(Int(q.unsafe_load(4095)), 1)
    _ = free(q)


def test_conversions() raises:
    var n = string_to_char_ptr("-1024")
    assert_equal(atoi(n), -1024)
    assert_equal(atol(n), -1024)
    n.unsafe_free()

    var f = string_to_char_ptr("3.5")
    assert_true((atof(f) - 3.5) < 1e-12)
    assert_true((strtod(f) - 3.5) < 1e-12)
    f.unsafe_free()

    var hex = string_to_char_ptr("ff")
    assert_equal(strtol(hex, 16), 255)
    hex.unsafe_free()


def test_environment() raises:
    var path = getenv(string_to_char_ptr("PATH"))
    assert_true(char_ptr_to_string(path).byte_length() > 0)

    var name = string_to_char_ptr("MOJO_LIBC_TEST")
    var value = string_to_char_ptr("1")
    assert_equal(setenv(name, value, 1), 0)
    assert_equal(char_ptr_to_string(getenv(name)), "1")
    assert_equal(unsetenv(name), 0)
    name.unsafe_free()
    value.unsafe_free()


def test_rand() raises:
    _ = srand(1)
    var first = rand()
    var second = rand()
    _ = srand(1)
    assert_equal(rand(), first)
    assert_equal(rand(), second)
    assert_true(first >= 0)


def test_paths() raises:
    var tmp = string_to_char_ptr("/tmp")
    # PATH_MAX, which is what realpath expects for the output buffer.
    var out = unsafe_alloc[UInt8](4096)
    var resolved = char_ptr_to_string(realpath(tmp, out))
    # Not compared against "/tmp": on macOS that is a symlink to
    # /private/tmp. What holds everywhere is that the result is absolute
    # and already canonical, so resolving it again is a no-op.
    assert_true(resolved.byte_length() > 0)
    assert_true(resolved.startswith("/"))
    # A second buffer: `realpath` reads its input while filling the output,
    # so passing one buffer as both is undefined.
    var out2 = unsafe_alloc[UInt8](4096)
    assert_equal(char_ptr_to_string(realpath(out, out2)), resolved)
    tmp.unsafe_free()
    out.unsafe_free()
    out2.unsafe_free()

    var tpl = string_to_char_ptr("/tmp/libc_stdlib_XXXXXX")
    var fd = mkstemp(tpl)
    assert_true(fd >= 0)
    assert_equal(close(fd), 0)
    assert_equal(remove(tpl), 0)
    tpl.unsafe_free()


def test_random() raises:
    """`random`, and the state it draws from."""
    srandom(42)
    var first = random()
    assert_true(first != random(), "the numbers move on")

    srandom(42)
    assert_equal(random(), first, "the same seed gives the same run again")

    var state = unsafe_alloc[UInt8](256)
    srandom(42)
    var with_default = random()

    var previous = initstate(42, state, 256)
    assert_true(Int(UInt(previous)) != 0, "it hands back the state before it")

    # Going back to that state brings back the run the default generator
    # was in the middle of, which is the whole point of the pair.
    _ = setstate(previous)
    srandom(42)
    assert_equal(random(), with_default, "and setting it back restores it")
    state.unsafe_free()


def test_getsubopt() raises:
    var ro = string_to_char_ptr("ro")
    var rw = string_to_char_ptr("rw")
    var tokens = unsafe_alloc[c_ptr[UInt8]](3)
    tokens.unsafe_offset(0)[] = ro
    tokens.unsafe_offset(1)[] = rw
    tokens.unsafe_offset(2)[] = null_ptr[UInt8]()

    var optionp = unsafe_alloc[c_ptr[UInt8]](1)
    optionp.unsafe_offset(0)[] = string_to_char_ptr("rw,ro")
    var valuep = unsafe_alloc[c_ptr[UInt8]](1)

    assert_equal(getsubopt(optionp, tokens, valuep), 1, "rw is the second")
    assert_equal(getsubopt(optionp, tokens, valuep), 0, "and ro the first")
    assert_equal(getsubopt(optionp, tokens, valuep), -1, "then it is done")

    ro.unsafe_free()
    rw.unsafe_free()
    tokens.unsafe_free()
    optionp.unsafe_free()
    valuep.unsafe_free()


def main() raises:
    test_malloc()
    test_calloc()
    test_realloc()
    test_conversions()
    test_environment()
    test_rand()
    test_random()
    test_getsubopt()
    test_paths()
    print("test_stdlib: ok")
