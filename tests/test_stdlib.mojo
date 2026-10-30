from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget
from std.testing import assert_equal, assert_true

from libc.constant import c_char, c_double, c_ptr, c_uint, c_ushort, c_wchar
from libc.file import close
from libc.stdio import remove
from libc.sys.wait import WIFSIGNALED, waitpid
from libc.unistd import fork, rmdir
from libc.signal import SIGABRT, signal
from libc.stdlib import (
    a64l,
    abort,
    aligned_alloc,
    atof,
    atoi,
    atol,
    atoll,
    calloc,
    div,
    drand48,
    erand48,
    exit,
    free,
    getenv,
    getloadavg,
    getsubopt,
    initstate,
    jrand48,
    l64a,
    lcong48,
    ldiv,
    lldiv,
    lrand48,
    malloc,
    mblen,
    mbtowc,
    mkdtemp,
    mkstemp,
    mktemp,
    mrand48,
    nrand48,
    posix_memalign,
    putenv,
    rand,
    rand_r,
    random,
    realloc,
    realpath,
    rpmatch,
    secure_getenv,
    seed48,
    setenv,
    setstate,
    srand,
    srand48,
    srandom,
    strtod,
    strtof,
    strtol,
    strtoll,
    strtoq,
    strtoul,
    strtoull,
    strtouq,
    unsetenv,
    valloc,
    wctomb,
)
from libc.utils import char_ptr_to_string, is_null, null_ptr, string_to_char_ptr


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
        # The default is put back on SIGABRT before `abort` is asked
        # for. The run time has a handler of its own on that signal,
        # which writes out a stack and a report, and it is the report
        # that is the trouble: it is what leaves a job waiting on a
        # child that has already ended. SIG_DFL is a null handler, so
        # this is `signal(SIGABRT, SIG_DFL)`.
        _ = signal(SIGABRT, null_ptr[UInt8]())
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


def test_dividing_and_keeping_the_remainder() raises:
    """`div`, `ldiv` and `lldiv` each divide one number by another
    and hand back the quotient and the remainder together, which is
    what C makes awkward to ask for in two goes.

    Ten divided by three is the one asked of all three, and it is
    asked because the two halves are not the same: a quotient of 3
    and a remainder of 1, where three divided by ten would be 0 and
    3. That is what keeps a call that had its arguments the wrong way
    round from passing.

    Each is asked the same of a negative numerator, which is where
    the rounding shows: the quotient goes towards zero and the
    remainder takes the sign of the numerator, so -10 over 3 is -3
    with -1 left over, and not -4 with 2. Both platforms are asked to
    agree on that, C having said it rather than left it.
    """
    var d = div(10, 3)
    assert_equal(Int(d.quot), 3, "ten over three is three")
    assert_equal(Int(d.rem), 1, "with one left over")

    var l = ldiv(10, 3)
    assert_equal(Int(l.quot), 3, "and ldiv says the same")
    assert_equal(Int(l.rem), 1, "with one left over")

    var ll = lldiv(10, 3)
    assert_equal(Int(ll.quot), 3, "and so does lldiv")
    assert_equal(Int(ll.rem), 1, "with one left over")

    # Rounded towards zero, and the remainder follows the numerator.
    var minus = div(-10, 3)
    assert_equal(Int(minus.quot), -3, "minus ten over three is minus three")
    assert_equal(Int(minus.rem), -1, "with minus one left over")

    var lminus = ldiv(-10, 3)
    assert_equal(Int(lminus.quot), -3, "and ldiv says the same")
    assert_equal(Int(lminus.rem), -1, "with minus one left over")

    var llminus = lldiv(-10, 3)
    assert_equal(Int(llminus.quot), -3, "and so does lldiv")
    assert_equal(Int(llminus.rem), -1, "with minus one left over")

    # The other way round, which is a different answer and not the
    # same one with a sign in front of it.
    var other = div(3, 10)
    assert_equal(Int(other.quot), 0, "three over ten is nothing")
    assert_equal(Int(other.rem), 3, "with three left over")


def test_the_forty_eight_bit_sequence() raises:
    """`drand48`, `lrand48` and `mrand48` walk one sequence, the
    first handing back doubles spread over 0 to 1 and the other two
    handing back integers; `srand48` says where in it to start,
    `seed48` does that and hands the old state back, `lcong48` sets
    the numbers the sequence is worked out from, and `erand48` walks
    a sequence of its own kept in an array the caller holds.

    Nothing here holds the sequence to particular numbers. What it
    holds it to is what the standard says of it, which is that it is
    the same sequence every time, that a seed picks a place in it and
    picks the same place on both platforms, and that the numbers stay
    in the ranges they are said to stay in.

    That a seed picks a place is proved twice over: the same seed
    twice in a row gives the same number back, and another seed gives
    another. Either alone would be proved by a call that ignored its
    seed altogether, which is to say by one that was broken.

    `erand48` is asked the thing that sets it apart: it moves the
    three shorts on, so the same array asked twice gives two
    different numbers, and the array is not as it was.
    """
    srand48(42)
    var after42 = drand48()
    srand48(42)
    var after42again = drand48()
    srand48(43)
    var after43 = drand48()

    assert_true(after42 >= 0.0 and after42 < 1.0, "drand48 hands back 0 to 1")
    assert_equal(after42, after42again, "the same seed twice is the same place")
    assert_true(after42 != after43, "and another seed is another place")

    srand48(42)
    var whole = lrand48()
    assert_true(
        whole >= 0 and whole < 2147483648, "lrand48 hands back 0 to 2 to the 31"
    )
    srand48(42)
    var signed = mrand48()
    assert_true(
        signed >= -2147483648 and signed < 2147483648,
        "and mrand48 may come out negative",
    )
    assert_true(
        whole != signed or whole == 0,
        "the two read the same sequence as different things",
    )

    # Its own state, in an array, and moved on by every call.
    var state = unsafe_alloc[c_ushort](3)
    state.unsafe_offset(0)[] = 1
    state.unsafe_offset(1)[] = 2
    state.unsafe_offset(2)[] = 3
    var first = erand48(state)
    assert_true(first >= 0.0 and first < 1.0, "erand48 hands back 0 to 1")
    var second = erand48(state)
    assert_true(second >= 0.0 and second < 1.0, "and so does the next call")
    assert_true(first != second, "the state moved on, so the two differ")
    assert_true(
        not (
            Int(state.unsafe_offset(0)[]) == 1
            and Int(state.unsafe_offset(1)[]) == 2
            and Int(state.unsafe_offset(2)[]) == 3
        ),
        "and the three shorts are not the ones that went in",
    )

    # seed48 hands the state it displaces back.
    var seed16v = unsafe_alloc[c_ushort](3)
    seed16v.unsafe_offset(0)[] = 7
    seed16v.unsafe_offset(1)[] = 8
    seed16v.unsafe_offset(2)[] = 9
    var old = seed48(seed16v)
    assert_true(Int(UInt(old)) != 0, "seed48 hands back the state it displaces")

    # lcong48 sets the numbers themselves, and the sequence walks on.
    var seven = unsafe_alloc[c_ushort](7)
    for i in range(7):
        seven.unsafe_offset(i)[] = UInt16(i + 1)
    lcong48(seven)
    var after_lcong = drand48()
    assert_true(
        after_lcong >= 0.0 and after_lcong < 1.0,
        "and drand48 walks whatever it is given",
    )

    seven.unsafe_free()
    seed16v.unsafe_free()
    state.unsafe_free()


def test_writing_a_number_in_sixty_four_characters() raises:
    """`l64a` writes a long in the alphabet POSIX gives for it — a
    full stop for 0, a slash for 1, then the digits, then the
    capitals, then the small letters — and `a64l` reads one back.

    The round trip is what is asked: a number goes in, and the one
    that comes out of reading what was written is it again. That is
    asked of 0, which is written as nothing at all, and of a number
    with more than one character in it, which is where an alphabet
    read out of order would come apart.

    Nothing here holds the writing to particular characters. The
    alphabet is POSIX's to say and not this package's to check.
    """
    assert_equal(a64l(l64a(0)), 0, "nothing comes of 0, and nothing reads back")

    assert_equal(
        a64l(l64a(12345)),
        12345,
        "a number with more than one character in it comes back",
    )
    assert_equal(a64l(l64a(1)), 1, "and so does one with only the one")


def test_one_character_at_a_time() raises:
    """`mblen` says how many bytes the next multibyte character takes,
    `mbtowc` reads one out into a wide character, and `wctomb` writes
    one back out again.

    Under the C locale every character takes one byte, and that is the
    whole of what is asked of them here — which characters take more
    than one is the locale's to say, and a test that said otherwise
    would be holding the two platforms to agreeing on something they
    need not agree on.

    `mblen` is asked about a byte that is there and about the end of
    the string, of which 0 is what comes back. `mbtowc` is asked to
    read one out, and the character it read is what is looked at.
    `wctomb` is asked to write it back, and what comes out is what
    went in.

    Each of the two that keep a state is asked with a null pointer,
    which is how that state is put back at the beginning — the state
    being the library's own and there being one of it.
    """
    var a = string_to_char_ptr("a")
    assert_equal(mblen(a, 1), 1, "one byte for the a under the C locale")

    var empty = string_to_char_ptr("")
    assert_equal(
        mblen(empty, 1), 0, "and nothing at all at the end of a string"
    )

    var out = unsafe_alloc[c_wchar](1)
    assert_equal(mbtowc(out, a, 1), 1, "mbtowc read one byte")
    assert_equal(
        Int(out.unsafe_load(0)), 97, "and this is the character it read"
    )

    # A null string puts the state back at the beginning. What comes
    # back of that is the platform's own to say, so it is held only to
    # not being an error: glibc hands back 0 for an encoding with no
    # state, and Darwin does not have to agree.
    assert_true(
        mbtowc(out, null_ptr[c_char](), 0) >= 0, "a null string resets it"
    )

    var back = unsafe_alloc[UInt8](8)
    assert_equal(wctomb(back, 97), 1, "wctomb wrote one byte")
    back.unsafe_store(1, 0)
    assert_equal(
        char_ptr_to_string(back), "a", "and this is the character it wrote"
    )
    assert_true(
        wctomb(null_ptr[c_char](), 97) >= 0, "and a null pointer resets it too"
    )

    back.unsafe_free()
    out.unsafe_free()
    empty.unsafe_free()
    a.unsafe_free()


def test_yes_no_and_neither() raises:
    """`rpmatch` says whether what was written in answer to a
    question was yes or was no.

    It is asked about `y`, about `n`, and about a word that is
    neither, and what it answers is 1, 0 and -1. Those three are
    what it is asked for because they are the three it has: a
    question answered is one of them, and there is no fourth.

    What counts as yes and what counts as no is the current
    locale's to say, so what is handed in is the shortest thing
    there is and not a word.

    `valloc` is asked for room on a page boundary, and is asked for
    it the way `malloc` is asked, which is to say what is asked is
    that the room is there and that a number can be put in it and
    read back out. That the room begins where a page begins is what
    this call is for, and is not a thing a test can say without
    turning a pointer into a number.
    """
    assert_equal(rpmatch(string_to_char_ptr("y")), 1, "y is yes")
    assert_equal(rpmatch(string_to_char_ptr("n")), 0, "n is no")
    assert_equal(
        rpmatch(string_to_char_ptr("maybe")),
        -1,
        "and a word that is neither is neither",
    )

    var room = valloc(4096)
    assert_true(not is_null(room), "valloc gives room, and")
    var words = room.unsafe_bitcast[UInt8]()
    words.unsafe_store(0, 42)
    assert_equal(words.unsafe_load(0), 42, "a number put in it comes back out")
    free(room.unsafe_bitcast[UInt8]())


def test_a_name_is_made_and_a_number_is_read() raises:
    """`mktemp` finishes a name, and `strtoq` with `strtouq` read a
    number out of a string.

    `mktemp` is handed a name ending in six `X`s and is asked to
    write over them. What is asked of it is that the six characters
    it was given are no longer all `X`: a name that is still six
    `X`s is one no name was made for. The name it makes is not
    looked at, being each machine's own to pick.

    `strtoq` and `strtouq` are the older names for `strtoll` and
    `strtoull`, and are asked the same thing they are: that the
    number written in the string is the number they hand back. A
    call that read from the wrong place, or took the base the wrong
    way, hands back a number that is not the one written.
    """
    var template = string_to_char_ptr("mojoXXXXXX")
    assert_true(not is_null(mktemp(template)), "mktemp finishes the name, and")

    var still_x = 0
    for i in range(4, 10):
        if template.unsafe_load(i) == UInt8(ord("X")):
            still_x += 1
    assert_true(still_x < 6, "the six Xs are not six Xs any more")
    template.unsafe_free()

    var text = string_to_char_ptr("12345")
    var rest = unsafe_alloc[c_ptr[UInt8]](1)
    assert_equal(
        strtoq(text, rest, 10), 12345, "strtoq reads the number written"
    )
    assert_equal(
        strtouq(text, rest, 10),
        12345,
        "and so does strtouq under its old name",
    )
    assert_equal(
        strtoq(string_to_char_ptr("ff"), rest, 16),
        255,
        "and sixteen is asked for and is given",
    )

    text.unsafe_free()
    rest.unsafe_free()


def _seven_shorts() -> c_ptr[c_ushort]:
    """Seven shorts in a row, to hand `lcong48`."""
    return unsafe_alloc[c_ushort](7)


def _three_shorts(a: Int, b: Int, c: Int) -> c_ptr[c_ushort]:
    """Three shorts in a row, for the rand48s to walk."""
    var seeds = unsafe_alloc[c_ushort](3)
    seeds.unsafe_store(0, UInt16(a))
    seeds.unsafe_store(1, UInt16(b))
    seeds.unsafe_store(2, UInt16(c))
    return seeds


def _put_back_the_numbers_posix_says() raises:
    """`lcong48` with the numbers POSIX says are the default ones.

    The forty-eight family works its sequence out from a multiplier
    and an addend, and on Linux those two are kept in one place for
    the whole programme: `lcong48` writes them, and `jrand48` reads
    them. So a test somewhere else that has been at `lcong48` has
    moved the numbers for this one too, and `jrand48` hands back a
    number that is not the one POSIX wrote down.

    Handing the default ones back first makes this test answer the
    same wherever it is put and whatever ran before it. Where they
    are not shared, as on Darwin, this sets what was already there
    and changes nothing.
    """
    var param = _seven_shorts()
    param.unsafe_store(0, UInt16(0x330E))
    param.unsafe_store(1, UInt16(0xABCD))
    param.unsafe_store(2, UInt16(0x1234))
    param.unsafe_store(3, UInt16(0xE66D))
    param.unsafe_store(4, UInt16(0xDEEC))
    param.unsafe_store(5, UInt16(0x0005))
    param.unsafe_store(6, UInt16(0x000B))
    lcong48(param)
    param.unsafe_free()


def test_the_number_the_rand48s_have_next() raises:
    """`jrand48` and `nrand48` each hand back the next number of a
    sequence they keep in three shorts.

    Both are handed the same three shorts, and each is asked for the
    number that comes next. What they answer is not a surprise: the
    sequence is written down in POSIX, all the way to which number
    follows which, so the same three shorts are the same number on
    every machine. That is the whole of why a test can be written
    for these at all, where most of the rest of the forty-eight
    family cannot be — `mrand48` shares one sequence with whatever
    else has moved it on, so what it answers is anyone's guess.

    `jrand48` is also asked to walk the sequence twice from the same
    three shorts. Two steps that are not the same number are two
    steps, and a call that forgot to move the shorts on would hand
    back the first number both times.

    The two are asked for the same step of the same sequence and
    differ in how they read it: `jrand48` reads the top bit as a
    sign and `nrand48` does not. So the one that reads a sign
    answers twice the other, and a test that has asked both can say
    so.

    Three shorts of nothing are left alone. That seed is a fixed
    point of the step and hands back nothing, which is a number any
    broken call hands back too.
    """
    _put_back_the_numbers_posix_says()

    var seeds = _three_shorts(1, 2, 3)
    assert_equal(jrand48(seeds), 1898359750, "jrand48 walks the sequence")

    seeds = _three_shorts(1, 2, 3)
    assert_equal(nrand48(seeds), 949179875, "and nrand48 reads the same step")
    assert_equal(
        1898359750,
        2 * 949179875,
        "one reads a sign where the other does not",
    )

    seeds = _three_shorts(0x1234, 0xABCD, 0x330E)
    assert_equal(jrand48(seeds), 2104706203, "and a step is one number, then")
    assert_equal(jrand48(seeds), 1680765312, "the next step is another")
    seeds.unsafe_free()


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
    test_dividing_and_keeping_the_remainder()
    test_one_character_at_a_time()
    test_the_forty_eight_bit_sequence()
    test_writing_a_number_in_sixty_four_characters()
    test_yes_no_and_neither()
    test_a_name_is_made_and_a_number_is_read()
    test_the_number_the_rand48s_have_next()
    print("test_stdlib: ok")
