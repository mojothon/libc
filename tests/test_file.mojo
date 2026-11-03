"""Tests for the `libc.file` bindings that nothing had called."""
from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import AT_FDCWD, SEEK_CUR, SEEK_END, SEEK_SET, c_ptr
from libc.fcntl import O_CREAT, O_RDONLY, O_WRONLY, open as open_with_mode
from libc.stdio import fileno, remove, tmpfile
from libc.file import (
    clearerr,
    creat,
    dprintf,
    fclose,
    feof,
    ferror,
    fgetc,
    fmemopen,
    fopen,
    fprintf,
    fputc,
    fputs,
    freopen,
    fscanf,
    fseek,
    fseeko,
    ftell,
    ftello,
    getline,
    lseek,
    preadv,
    printf,
    pwritev,
    scanf,
    snprintf,
    sprintf,
    sscanf,
)
from libc.stdlib import exit, free
from libc.sys.socket import iovec
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.unistd import close, dup2, fork, pipe, unlink, write
from libc.utils import char_ptr_to_string, is_null, null_ptr, string_to_char_ptr


def test_a_stream_back_and_forth() raises:
    """`fputs` takes the string and then the stream, `fputc` the
    character and then the stream, and `fseek` the offset and then where
    to measure it from — three calls whose arguments can change places
    without a word from anyone.
    """
    var path = string_to_char_ptr("/tmp/libc_file_me")
    var out = fopen(path, string_to_char_ptr("w"))
    assert_true(Int(UInt(out)) != 0, "the file opens for writing")

    assert_true(
        fputs(string_to_char_ptr("hello"), out) >= 0, "fputs wrote the string"
    )
    assert_equal(
        fputc(Int32(ord("!")), out),
        Int32(ord("!")),
        "fputc wrote one character",
    )
    assert_equal(fclose(out), 0, "and the stream closes")

    var back = fopen(path, string_to_char_ptr("r"))
    assert_true(Int(UInt(back)) != 0, "it opens again for reading")
    assert_equal(fgetc(back), Int32(ord("h")), "fgetc takes one back")

    assert_equal(fseek(back, 0, SEEK_END), 0, "fseek went to the end")
    assert_equal(Int(ftell(back)), 6, "and ftell says where that is")
    assert_equal(fseek(back, 2, SEEK_SET), 0, "or to two from the start")
    assert_equal(Int(ftell(back)), 2, "which is where it is now")

    assert_equal(fseeko(back, 0, SEEK_END), 0, "fseeko goes there as well")
    assert_equal(Int(ftello(back)), 6, "and ftello says the same")

    # It is a read that found nothing that sets the flag, so `feof` has
    # nothing to say until after one.
    assert_equal(feof(back), 0, "the end has not been reached yet")
    while fgetc(back) != Int32(-1):
        pass
    assert_true(feof(back) != 0, "and now it has been")
    assert_equal(ferror(back), 0, "with no error on the way")

    _ = clearerr(back)
    assert_equal(feof(back), 0, "clearerr puts the flag back")
    assert_equal(fclose(back), 0, "and the stream closes")
    _ = unlink(path)
    path.unsafe_free()


def test_streams_from_other_things() raises:
    """`fmemopen` takes a piece of memory and how much of it, and
    `freopen` a path, a mode and the stream to reopen. `fdopen`, which
    would take a descriptor and a mode, is the one stream this package
    cannot make: see `libc.file.syscalls`, where it is not.
    """
    var path = string_to_char_ptr("/tmp/libc_fdopen_me")
    var made = creat(path, 0o644)
    assert_true(made >= 0, "creat made the file")
    assert_equal(close(made), 0, "and it closes")

    var memory = unsafe_alloc[UInt8](32)
    for i in range(32):
        memory.unsafe_store(i, 0)
    var on_memory = fmemopen(memory, 32, string_to_char_ptr("w"))
    assert_true(Int(UInt(on_memory)) != 0, "fmemopen opens a stream on memory")
    assert_true(
        fputs(string_to_char_ptr("held"), on_memory) >= 0, "it is written"
    )
    # Closing is what writes it through to the memory. `fflush` would be
    # the natural way to ask, and cannot be bound here at all: see the note
    # at the top of `libc.file.syscalls`.
    assert_equal(fclose(on_memory), 0, "the stream closes")

    var again = fopen(path, string_to_char_ptr("r"))
    assert_true(Int(UInt(again)) != 0, "the file opens")
    var reopened = freopen(path, string_to_char_ptr("r"), again)
    assert_true(
        Int(UInt(reopened)) != 0,
        "freopen takes a path, a mode and the stream to reopen",
    )
    assert_equal(fclose(reopened), 0, "and that one closes")

    memory.unsafe_free()
    _ = unlink(path)
    path.unsafe_free()


def test_getline_reads_to_the_newline() raises:
    """What it hands back is the count of characters, and the newline is
    one of them.
    """
    var path = string_to_char_ptr("/tmp/libc_file_lines")
    var out = fopen(path, string_to_char_ptr("w"))
    assert_true(
        fputs(string_to_char_ptr("first\nsecond\n"), out) >= 0, "two lines"
    )
    assert_equal(fclose(out), 0, "and they are written")

    var back = fopen(path, string_to_char_ptr("r"))
    var line = unsafe_alloc[c_ptr[UInt8]](1)
    line.unsafe_offset(0)[] = null_ptr[UInt8]()
    var n = unsafe_alloc[UInt64](1)
    n.unsafe_offset(0)[] = 0

    assert_equal(Int(getline(line, n, back)), 6, "getline reads the first line")
    assert_equal(
        char_ptr_to_string(line.unsafe_offset(0)[]),
        "first\n",
        "newline and all",
    )
    # Not freed between the two: `getline` keeps the buffer it was
    # given and grows it, so freeing it is freeing the thing it is
    # about to write into.
    assert_equal(Int(getline(line, n, back)), 7, "and then the second")
    assert_equal(
        char_ptr_to_string(line.unsafe_offset(0)[]),
        "second\n",
        "which is longer",
    )
    _ = free(line.unsafe_offset(0)[])

    line.unsafe_free()
    n.unsafe_free()
    assert_equal(fclose(back), 0, "and the stream closes")
    _ = unlink(path)
    path.unsafe_free()


def test_the_printf_family() raises:
    """None of these can be given a format that asks for anything, which
    is what the note on each of them says, so each is given one that
    does not. `snprintf` is the one that shows the arguments landed in
    the right order: asked for four characters out of nine it writes
    four and reports nine.
    """
    var out = unsafe_alloc[UInt8](64)
    for i in range(64):
        out.unsafe_store(i, 0)
    assert_true(sprintf(out, string_to_char_ptr("mojo")) >= 0, "sprintf writes")
    assert_equal(
        char_ptr_to_string(out), "mojo", "into the buffer it was given"
    )

    for i in range(64):
        out.unsafe_store(i, 0)
    assert_equal(
        snprintf(out, 4, string_to_char_ptr("mojo libc")),
        9,
        "snprintf reports the length it wanted, not the one it wrote",
    )
    assert_equal(char_ptr_to_string(out), "moj", "and it stopped at four")
    out.unsafe_free()

    var nothing = string_to_char_ptr("/dev/null")
    var fd = open_with_mode(nothing, O_WRONLY)
    assert_true(fd >= 0, "/dev/null opens")
    assert_equal(
        dprintf(fd, string_to_char_ptr("five\n")),
        5,
        "dprintf counts what it wrote",
    )
    _ = close(fd)
    nothing.unsafe_free()

    assert_equal(printf(string_to_char_ptr("\n")), 1, "and printf does too")


def test_the_scanf_family_asked_for_nothing() raises:
    """`sscanf` and `fscanf` are variadic, and the places they would
    write what they read are in the variadic part, which cannot be
    given from here — so there is no asking them for anything.

    Asked for nothing, a format with no `%` in it, they answer with
    how many things they took, which is none, and that is the whole
    of what they can be asked here.
    """
    var text = string_to_char_ptr("hello")
    assert_equal(
        Int(sscanf(text, text)), 0, "sscanf took nothing from what it was given"
    )

    var path = string_to_char_ptr("/tmp/mojo_libc_scanf")
    var writing = fopen(path, string_to_char_ptr("w"))
    assert_true(Int(writing) != 0, "there is a file to read back")
    _ = fputs(text, writing)
    _ = fclose(writing)

    var reading = fopen(path, string_to_char_ptr("r"))
    assert_equal(
        Int(fscanf(reading, text)), 0, "and fscanf took nothing from it"
    )
    _ = fclose(reading)

    _ = remove(path)
    path.unsafe_free()
    text.unsafe_free()


def test_scanf_reads_the_standard_input_it_is_given() raises:
    """`scanf` reads standard input, which a suite cannot promise has an
    end -- so a child makes its own, the way `getchar` is asked: a pipe
    with a word in it, put where standard input is read from.

    The format is that word and nothing else, which is the whole of
    what this binding can be asked: the pointers a conversion writes
    through are in the variadic part, and `external_call` has no way to
    hand them over, so a `%` would be answered by writing through
    whatever address came next. A format with no `%` in it reads and
    assigns nothing, which leaves the two things it does say: 0 when
    the input was there to be matched, and `EOF` when it was not.

    Both are asked in the one child, the second call finding the stream
    where the first one left it -- at its end. The child asserts them
    itself and leaves with its status, so an answer that was neither is
    a red run rather than a number reported as the right one.
    """
    var child = fork()
    if child == 0:
        var fds = unsafe_alloc[Int32](2)
        assert_equal(pipe(fds), 0, "a pipe to be standard input")
        var word = unsafe_alloc[UInt8](5)
        var letters = "hello"
        for i in range(5):
            word.unsafe_store(i, UInt8(ord(letters[byte=i])))
        assert_equal(
            write(fds.unsafe_offset(1)[], word, 5), 5, "with the word in it"
        )
        word.unsafe_free()
        assert_equal(
            dup2(fds.unsafe_offset(0)[], 0), 0, "and it is standard input"
        )
        # The write end is closed here and not left to the exit: an end
        # of the input is a closed pipe, and this child holding one open
        # is a `scanf` with nothing to read and no reason to stop.
        _ = close(fds.unsafe_offset(1)[])
        _ = close(fds.unsafe_offset(0)[])

        var format = string_to_char_ptr("hello")
        assert_equal(
            Int(scanf(format)),
            0,
            "the word is matched, and nothing is assigned",
        )
        assert_equal(
            Int(scanf(format)),
            -1,
            "and at the end of the input it says so rather than answering 0",
        )
        format.unsafe_free()
        _ = exit(0)

    assert_true(child > 0, "there is a child to read it")
    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    assert_equal(waitpid(child, status, 0), child, "the child is waited for")
    assert_true(
        WIFEXITED(status.unsafe_load()), "and it left of its own accord"
    )
    assert_equal(
        Int(WEXITSTATUS(status.unsafe_load())),
        0,
        "having found both answers where they were expected",
    )
    status.unsafe_free()


def test_pieces_at_an_offset() raises:
    """`pwritev` and `preadv` on a stream that was opened for something
    else: two pieces are handed to the file at offset 8 and read back the
    same way, and the stream's own position is still zero on either side
    of both calls.

    That last part is the whole of what these two are. `writev` writes
    where the stream is and moves it; `pwritev` writes where it is told
    and leaves it alone, which is why the same offset read twice gives
    the same bytes — a test that only compared the bytes would pass
    against `writev` and `lseek` put together.

    The eight bytes before the pieces are read too, because writing past
    the end of a file makes a hole rather than a gap: nothing fills it,
    nothing reports it, and a caller that reads it back gets zeroes.
    """
    var f = tmpfile()
    var fd = fileno(f)

    var head = unsafe_alloc[UInt8](3)
    head.unsafe_store(0, 97)
    head.unsafe_store(1, 98)
    head.unsafe_store(2, 99)
    var tail = unsafe_alloc[UInt8](2)
    tail.unsafe_store(0, 100)
    tail.unsafe_store(1, 101)

    var pieces = unsafe_alloc[iovec](2)
    pieces.unsafe_offset(0)[] = iovec(head, UInt64(3))
    pieces.unsafe_offset(1)[] = iovec(tail, UInt64(2))

    assert_equal(
        Int(pwritev(fd, pieces, 2, 8)),
        5,
        "five bytes went out over two pieces, and the count is the sum",
    )
    assert_equal(
        Int(lseek(fd, 0, SEEK_CUR)),
        0,
        "and the stream did not move to meet them",
    )

    var first = unsafe_alloc[UInt8](3)
    var second = unsafe_alloc[UInt8](2)
    var gathered = unsafe_alloc[iovec](2)
    gathered.unsafe_offset(0)[] = iovec(first, UInt64(3))
    gathered.unsafe_offset(1)[] = iovec(second, UInt64(2))

    assert_equal(
        Int(preadv(fd, gathered, 2, 8)), 5, "and five came back the same way"
    )
    assert_equal(
        first.unsafe_load(0), UInt8(97), "the first piece where it was put"
    )
    assert_equal(
        first.unsafe_load(2), UInt8(99), "filled to its own length exactly"
    )
    assert_equal(second.unsafe_load(0), UInt8(100), "and the second follows it")
    assert_equal(second.unsafe_load(1), UInt8(101), "to the far end")
    assert_equal(
        Int(lseek(fd, 0, SEEK_CUR)), 0, "with the stream still where it was"
    )

    assert_equal(
        Int(preadv(fd, gathered, 2, 8)), 5, "the second read is the same read"
    )
    assert_equal(
        first.unsafe_load(0), UInt8(97), "because the offset did not advance"
    )

    var hole = unsafe_alloc[UInt8](8)
    var one = unsafe_alloc[iovec](1)
    one.unsafe_offset(0)[] = iovec(hole, UInt64(8))
    assert_equal(Int(preadv(fd, one, 1, 0)), 8, "the eight bytes before them")
    assert_equal(hole.unsafe_load(0), UInt8(0), "are a hole")
    assert_equal(
        hole.unsafe_load(7), UInt8(0), "that reads as zeroes right up to them"
    )

    _ = fclose(f)
    head.unsafe_free()
    tail.unsafe_free()
    first.unsafe_free()
    second.unsafe_free()
    hole.unsafe_free()
    pieces.unsafe_free()
    gathered.unsafe_free()
    one.unsafe_free()


def test_fprintf_writes_the_format_as_it_stands() raises:
    """`fprintf` writes to the stream it is handed, which is what it has
    that `printf` has not: a `tmpfile` takes the line and gives it back,
    and what comes back is the format and nothing besides.

    Nothing besides is all this binding can write. C's takes `...` after
    the format and `external_call` cannot hand a variadic argument over,
    so a `%` in the format would be answered by reading whatever sits
    next to it. A line with no `%` in it is what is left, and it is asked
    for byte by byte rather than by length, so that a stream which wrote
    something of the right size and the wrong letters is a red run.
    """
    var stream = tmpfile()
    assert_true(not is_null(stream), "a stream of its own to write to, and")
    var text = "no room for a percent here"
    var line = string_to_char_ptr(text)
    assert_equal(
        Int(fprintf(stream, line)),
        text.byte_length(),
        "the format goes in as it stands, all of it, and",
    )
    line.unsafe_free()

    assert_equal(fseek(stream, 0, SEEK_SET), 0, "the stream is read back, and")
    for i in range(text.byte_length()):
        assert_equal(
            Int(fgetc(stream)), Int(ord(text[byte=i])), "the same bytes again"
        )
    assert_equal(Int(fgetc(stream)), -1, "and nothing after them")
    _ = fclose(stream)


def main() raises:
    test_the_scanf_family_asked_for_nothing()
    test_a_stream_back_and_forth()
    test_streams_from_other_things()
    test_getline_reads_to_the_newline()
    test_the_printf_family()
    test_pieces_at_an_offset()
    test_scanf_reads_the_standard_input_it_is_given()
    test_fprintf_writes_the_format_as_it_stands()
    print("test_file: ok")
