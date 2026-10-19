from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_char, c_double, c_ptr, c_uint
from libc.file import close
from libc.stdio import remove
from libc.sys.wait import WIFSIGNALED, waitpid
from libc.unistd import fork, rmdir
from libc.stdlib import (
    abort,
    aligned_alloc,
    atof,
    atoi,
    atol,
    atoll,
    calloc,
    exit,
    free,
    getenv,
    getloadavg,
    getsubopt,
    initstate,
    malloc,
    mkdtemp,
    mkstemp,
    posix_memalign,
    putenv,
    rand,
    rand_r,
    random,
    realloc,
    realpath,
    secure_getenv,
    setenv,
    setstate,
    srand,
    srandom,
    strtod,
    strtof,
    strtol,
    strtoll,
    strtoul,
    strtoull,
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


def test_getloadavg() raises:
    """Three averages over three periods of time, the first of them the
    last minute. None is written down here — a machine is as busy as it
    happens to be — but the three are, in order, the short one, the
    middle one and the long one, and there is no fourth: asking for
    eight gets three, and asking for none gets none.
    """
    var room = unsafe_alloc[c_double](8)
    for i in range(8):
        room.unsafe_offset(i)[] = -1.0

    assert_equal(Int(getloadavg(room, 8)), 3, "three is all there are")
    var one = room.unsafe_offset(0)[]
    var five = room.unsafe_offset(1)[]
    var fifteen = room.unsafe_offset(2)[]
    assert_true(one >= 0.0, "counting things waiting to run")
    assert_true(five >= 0.0, "over five minutes as well")
    assert_true(fifteen >= 0.0, "and over fifteen")
    assert_equal(room.unsafe_offset(3)[], -1.0, "the fourth is left alone")

    assert_equal(Int(getloadavg(room, 1)), 1, "one is asked for, one is had")
    assert_equal(Int(getloadavg(room, 0)), 0, "and none is asked for, none")

    room.unsafe_free()


def test_the_untried_calls() raises:
    """Eleven of these had never been called. Two of them take an alignment
    and a size, in that order and of that one type; three of them write
    where they stopped into a pointer they are given rather than handing it
    back, which is the part a signature alone does not show.
    """
    var p = aligned_alloc(64, 128)
    assert_true(Int(UInt(p)) != 0, "aligned_alloc hands back memory")
    assert_equal(Int(UInt(p)) % 64, 0, "and it starts on the alignment")

    var slot = unsafe_alloc[c_ptr[c_char]](1)
    assert_equal(
        posix_memalign(slot, 32, 64), 0, "posix_memalign says it worked"
    )
    var q = slot.unsafe_offset(0)[]
    assert_true(Int(UInt(q)) != 0, "and it wrote a pointer into the slot")
    assert_equal(Int(UInt(q)) % 32, 0, "that starts where it was asked to")
    _ = free(q)
    slot.unsafe_free()
    _ = free(p)

    var big = string_to_char_ptr("123456789012")
    assert_equal(
        Int(atoll(big)), 123456789012, "atoll reads past what an int holds"
    )
    big.unsafe_free()

    var mixed = string_to_char_ptr("42abc")
    var end = unsafe_alloc[c_ptr[c_char]](1)
    assert_equal(
        Int(strtoll(mixed, end, 10)), 42, "strtoll stops at the letters"
    )
    assert_equal(
        char_ptr_to_string(end.unsafe_offset(0)[]),
        "abc",
        "and writes where it stopped rather than returning it",
    )
    assert_equal(
        Int(strtoul(mixed, end, 10)), 42, "strtoul reads the same string"
    )
    assert_equal(Int(strtoull(mixed, end, 10)), 42, "and so does strtoull")

    var half = string_to_char_ptr("2.5abc")
    assert_true(
        (Float64(strtof(half, end)) - 2.5) < 1e-6, "strtof reads two and a half"
    )
    assert_equal(
        char_ptr_to_string(end.unsafe_offset(0)[]),
        "abc",
        "and stops in the same place",
    )
    end.unsafe_free()
    mixed.unsafe_free()
    half.unsafe_free()

    # `putenv` keeps the string it is given rather than copying it, so this
    # one is handed over and not freed; `getenv` is what says it was taken.
    var assign = string_to_char_ptr("MOJO_LIBC_TRIED=1")
    assert_equal(putenv(assign), 0, "putenv takes the string")
    var name = string_to_char_ptr("MOJO_LIBC_TRIED")
    assert_equal(
        char_ptr_to_string(getenv(name)),
        "1",
        "and getenv finds what it was told",
    )
    name.unsafe_free()

    var seed = unsafe_alloc[c_uint](1)
    seed.unsafe_offset(0)[] = 42
    var first = rand_r(seed)
    seed.unsafe_offset(0)[] = 42
    assert_equal(rand_r(seed), first, "the same seed gives the same number")
    seed.unsafe_free()

    var tpl = string_to_char_ptr("/tmp/libcXXXXXX")
    var made = mkdtemp(tpl)
    assert_true(Int(UInt(made)) != 0, "mkdtemp made a directory")
    var path = char_ptr_to_string(made)
    assert_true(path.startswith("/tmp/libc"), "named after the template")
    assert_true(path != "/tmp/libcXXXXXX", "with the Xs replaced, not kept")
    assert_equal(rmdir(made), 0, "and it is there to be removed")
    tpl.unsafe_free()

    comptime if not CompilationTarget.is_macos():
        # There is no such call on Darwin, only on glibc.
        var home = string_to_char_ptr("HOME")
        assert_true(
            Int(UInt(secure_getenv(home))) != 0, "secure_getenv finds HOME too"
        )
        home.unsafe_free()


def test_abort_ends_the_child_and_not_us() raises:
    """`abort` ends the process that asks for it, so it is asked for
    in a child and nowhere else. What comes back from waiting is
    that the child was brought down by a signal.

    Which signal is not asked about. `abort` sends `SIGABRT`, but
    what is seen here is `SIGSEGV`: the run time having been asked
    to end the process, it ends it in its own way, and a test that
    said which one it must be would be a test that says more than
    there is to go on.
    """
    var child = fork()
    if child == 0:
        _ = abort()
        _ = exit(0)  # `abort` does not come back, but if it did the
        # child should still not carry on into the rest of the tests.

    assert_true(child > 0, "there is a child to wait for")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    assert_true(
        WIFSIGNALED(status.unsafe_load()), "and it was brought down by a signal"
    )
    status.unsafe_free()


def main() raises:
    test_malloc()
    test_the_untried_calls()
    test_calloc()
    test_realloc()
    test_conversions()
    test_environment()
    test_rand()
    test_random()
    test_getsubopt()
    test_getloadavg()
    test_paths()
    test_abort_ends_the_child_and_not_us()
    print("test_stdlib: ok")
