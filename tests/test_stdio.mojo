from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.constant import (
    AT_FDCWD,
    c_char,
    c_ptr,
    c_size_t,
    c_void,
)
from libc.file import (
    FILE,
    close,
    fclose,
    fgets,
    fopen,
    fread,
    getdelim,
    rewind,
)
from libc.stdio import (
    IOFBF,
    clearerr_unlocked,
    feof_unlocked,
    ferror_unlocked,
    fileno,
    fileno_unlocked,
    flockfile,
    ftrylockfile,
    funlockfile,
    fwrite,
    getc,
    getc_unlocked,
    getw,
    pclose,
    popen,
    putc,
    putc_unlocked,
    putchar,
    putw,
    remove,
    rename,
    renameat,
    setbuf,
    setvbuf,
    tmpfile,
    tmpnam,
    ungetc,
)
from libc.stdlib import free, mkstemp
from libc.utils import char_ptr_to_string, null_ptr, string_to_char_ptr


def test_tmpfile_roundtrip() raises:
    var f = tmpfile()
    var msg = string_to_char_ptr("mojo libc")
    assert_equal(Int(fwrite(msg, 1, 9, f)), 9)
    _ = rewind(f)

    var buf = unsafe_alloc[UInt8](32)
    assert_equal(Int(fread(buf, 1, 9, f)), 9)
    buf.unsafe_store(9, 0)
    assert_equal(char_ptr_to_string(buf), "mojo libc")

    _ = fclose(f)
    buf.unsafe_free()
    msg.unsafe_free()


def test_rename_and_remove() raises:
    var tpl = string_to_char_ptr("/tmp/libc_stdio_XXXXXX")
    var fd = mkstemp(tpl)
    assert_true(fd >= 0)
    assert_equal(close(fd), 0)

    var dst = string_to_char_ptr("/tmp/libc_stdio_renamed")
    assert_equal(rename(tpl, dst), 0)
    assert_equal(remove(dst), 0)

    tpl.unsafe_free()
    dst.unsafe_free()


def test_popen() raises:
    var p = popen(string_to_char_ptr("echo mojo"), string_to_char_ptr("r"))
    var buf = unsafe_alloc[UInt8](32)
    _ = fgets(buf, 32, p)
    assert_equal(char_ptr_to_string(buf), "mojo\n")
    _ = pclose(p)
    buf.unsafe_free()


def test_fileno_and_buffering() raises:
    var f = tmpfile()
    assert_true(fileno(f) >= 0)

    var buf = unsafe_alloc[UInt8](1024)
    assert_equal(setvbuf(f, buf, IOFBF, 1024), 0)
    _ = fclose(f)
    buf.unsafe_free()


def test_ungetc() raises:
    var f = tmpfile()
    var msg = string_to_char_ptr("ab")
    _ = fwrite(msg, 1, 2, f)
    _ = rewind(f)

    var first = getc(f)
    assert_equal(first, 97)
    assert_equal(ungetc(first, f), 97)
    assert_equal(getc(f), 97)
    assert_equal(getc(f), 98)

    _ = fclose(f)
    msg.unsafe_free()


def test_stream_locking() raises:
    """`flockfile`, `ftrylockfile` and `funlockfile`."""
    var stream = tmpfile()
    assert_true(Int(UInt(stream)) != 0)

    _ = flockfile(stream)
    # The lock is one you can take twice, so the same thread asking for it
    # again gets it rather than waiting for itself.
    assert_equal(ftrylockfile(stream), 0, "and again from the same thread")

    _ = funlockfile(stream)
    _ = funlockfile(stream)

    # Given up as often as it was taken, it is free again.
    assert_equal(ftrylockfile(stream), 0, "then it is free")
    _ = funlockfile(stream)
    assert_equal(fclose(stream), 0)


def test_putw_and_getw() raises:
    """`putw` writes the bytes of an `int` and `getw` reads them back."""
    var path = string_to_char_ptr("/tmp/libc-test-words.bin")
    var mode = string_to_char_ptr("w+")
    var stream = fopen(path, mode)
    assert_true(Int(UInt(stream)) != 0)

    assert_equal(putw(0x41424344, stream), 0, "one int goes in")
    _ = rewind(stream)
    assert_equal(getw(stream), 0x41424344, "and the same int comes back")

    assert_equal(fclose(stream), 0)
    assert_equal(remove(path), 0)
    path.unsafe_free()
    mode.unsafe_free()


def test_renameat() raises:
    """`renameat` renames by directory rather than by path."""
    var old = string_to_char_ptr("/tmp/libc-test-renameat-old")
    var new = string_to_char_ptr("/tmp/libc-test-renameat-new")
    var write = string_to_char_ptr("w")
    var read = string_to_char_ptr("r")

    assert_equal(fclose(fopen(old, write)), 0)
    assert_equal(
        renameat(AT_FDCWD, old, AT_FDCWD, new), 0, "renamed from here to here"
    )

    var there = fopen(new, read)
    assert_true(Int(UInt(there)) != 0, "and it is at the new path")
    assert_equal(fclose(there), 0)
    assert_equal(remove(new), 0)

    old.unsafe_free()
    new.unsafe_free()
    write.unsafe_free()
    read.unsafe_free()


def test_getdelim() raises:
    """`getdelim` reads up to a byte of your choosing."""
    var stream = tmpfile()
    var text = string_to_char_ptr("one,two")
    assert_equal(fwrite(text, 1, 7, stream), 7)
    _ = rewind(stream)

    var lineptr = unsafe_alloc[c_ptr[c_char]](1)
    var n = unsafe_alloc[c_size_t](1)
    lineptr.unsafe_offset(0)[] = null_ptr[c_char]()
    n.unsafe_offset(0)[] = 0

    # The 44 is a comma. It is kept in what comes back, so "one," is four
    # bytes and not three.
    assert_equal(getdelim(lineptr, n, 44, stream), 4, "one, is four bytes")
    assert_equal(char_ptr_to_string(lineptr.unsafe_offset(0)[]), "one,")

    # With no comma left to find, it reads to the end of the file.
    assert_equal(getdelim(lineptr, n, 44, stream), 3, "and two is three")

    _ = free(lineptr.unsafe_offset(0)[].unsafe_bitcast[c_void]())
    lineptr.unsafe_free()
    n.unsafe_free()
    assert_equal(fclose(stream), 0)
    text.unsafe_free()


def test_the_two_that_write_one_character() raises:
    """`putc` is given the character and then the stream, and `putchar`
    is `putc` with the stream already decided for it. Both hand back the
    character they wrote.

    What `putchar` is asked to write is a newline, it being a character
    that can be put in the middle of this output without showing up in
    it, and one that does not wait to be flushed.
    """
    var path = string_to_char_ptr("/tmp/mojo_libc_stdio_putc")
    var out = fopen(path, string_to_char_ptr("w"))
    assert_true(Int(UInt(out)) != 0, "the file is open")
    assert_equal(Int(putc(0x41, out)), 0x41, "putc hands back what it wrote")
    assert_equal(fclose(out), 0, "and it is closed again")

    var back = fopen(path, string_to_char_ptr("r"))
    var got = unsafe_alloc[c_char](2)
    assert_equal(Int(fread(got, 1, 1, back)), 1, "one byte comes back out")
    assert_equal(Int(got.unsafe_load()), 0x41, "and it is the one that went in")
    _ = fclose(back)
    got.unsafe_free()

    assert_equal(Int(putchar(10)), 10, "putchar hands back what it wrote too")


def test_setbuf_and_tmpnam() raises:
    """`setbuf` tells a stream to keep its characters in a buffer the
    caller holds rather than one of libc's own, which is why the buffer
    has to outlive the stream. `tmpnam` writes a name that is not in use
    into a buffer it is handed, and hands back that same pointer.
    """
    var path = string_to_char_ptr("/tmp/mojo_libc_stdio_setbuf")
    var out = fopen(path, string_to_char_ptr("w"))
    assert_true(Int(UInt(out)) != 0, "the file is open")

    var held = unsafe_alloc[c_char](4096)
    _ = setbuf(out, held)
    assert_equal(Int(putc(0x42, out)), 0x42, "and a character goes into it")
    assert_equal(fclose(out), 0, "the stream is closed")
    held.unsafe_free()

    var back = fopen(path, string_to_char_ptr("r"))
    var got = unsafe_alloc[c_char](2)
    assert_equal(Int(fread(got, 1, 1, back)), 1, "and it comes back out")
    assert_equal(
        Int(got.unsafe_load()), 0x42, "through the buffer it was given"
    )
    _ = fclose(back)
    got.unsafe_free()

    var name = unsafe_alloc[c_char](256)
    var made = tmpnam(name)
    assert_true(Int(UInt(made)) != 0, "tmpnam hands back a name")
    assert_true(
        Int(name.unsafe_load()) != 0, "and it wrote it where it was told to"
    )
    name.unsafe_free()


def test_the_unlocked_spellings() raises:
    """`getc_unlocked` and `putc_unlocked` move one byte to and from
    a stream without taking its lock, and `feof_unlocked`,
    `ferror_unlocked`, `fileno_unlocked` and `clearerr_unlocked` ask
    about one without taking it either.

    The stream is one `tmpfile` makes. Two bytes are written, and the
    stream is put back to its start before they are read, which is
    what a round trip through a file needs: writing leaves the stream
    at the end, and reading from there would find nothing.

    The end mark is asked about before and after. It is 0 first and
    something else once a read has hit the end, which is the one
    thing here that could not be true of a call that asked some other
    question — the error mark stays 0 the whole way through, and is
    asked for to say that the end mark is not it.

    `getchar_unlocked` and `putchar_unlocked` are bound and not
    called, being the two that go to the terminal.
    """
    var stream = tmpfile()
    assert_true(Int(UInt(stream)) != 0, "tmpfile hands back a stream")

    assert_true(Int(fileno_unlocked(stream)) >= 0, "and it has a descriptor")

    assert_equal(ferror_unlocked(stream), 0, "no error is marked on it yet")
    assert_equal(feof_unlocked(stream), 0, "and neither is the end")

    assert_equal(putc_unlocked(65, stream), 65, "A goes into the stream")
    assert_equal(putc_unlocked(66, stream), 66, "and B after it")

    _ = rewind(stream)
    assert_equal(getc_unlocked(stream), 65, "A comes back out of it")
    assert_equal(getc_unlocked(stream), 66, "and B after it")

    assert_equal(feof_unlocked(stream), 0, "the end is not marked yet, and")
    assert_equal(
        getc_unlocked(stream), -1, "there is nothing after B, which is EOF"
    )
    assert_true(
        Int(feof_unlocked(stream)) != 0, "and now the end is marked on it"
    )
    assert_equal(
        ferror_unlocked(stream), 0, "the error mark is not the end mark"
    )

    clearerr_unlocked(stream)
    assert_equal(feof_unlocked(stream), 0, "clearerr takes the end mark off")

    assert_equal(fclose(stream), 0, "the stream is closed")


def main() raises:
    test_tmpfile_roundtrip()
    test_rename_and_remove()
    test_popen()
    test_fileno_and_buffering()
    test_ungetc()
    test_stream_locking()
    test_putw_and_getw()
    test_renameat()
    test_getdelim()
    test_the_two_that_write_one_character()
    test_setbuf_and_tmpnam()
    test_the_unlocked_spellings()
    print("test_stdio: ok")
