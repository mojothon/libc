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
    snprintf,
    sprintf,
    sscanf,
)
from libc.stdlib import free
from libc.sys.socket import iovec
from libc.unistd import close, unlink
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


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
    """`fdopen` takes a descriptor and a mode, `fmemopen` a piece of
    memory and how much of it, and `freopen` a path, a mode and the
    stream to reopen.
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
    # Closing is what writes it through to the memory, there being no
    # `fflush` that can be named here.
    assert_equal(fclose(on_memory), 0, "the stream closes")
    assert_equal(
        char_ptr_to_string(memory), "held", "and that is where it ended up"
    )

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


def main() raises:
    test_the_scanf_family_asked_for_nothing()
    test_a_stream_back_and_forth()
    test_streams_from_other_things()
    test_getline_reads_to_the_newline()
    test_the_printf_family()
    test_pieces_at_an_offset()
    print("test_file: ok")
