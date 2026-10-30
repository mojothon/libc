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
    fgetc,
    fgets,
    fopen,
    fputs,
    fread,
    getdelim,
    rewind,
)
from libc.stdio import (
    BUFSIZ,
    IOFBF,
    clearerr_unlocked,
    ctermid,
    feof_unlocked,
    ferror_unlocked,
    fgetpos,
    fileno,
    fileno_unlocked,
    flockfile,
    fpos_t,
    fsetpos,
    ftrylockfile,
    funlockfile,
    fwrite,
    getc,
    getc_unlocked,
    getw,
    open_memstream,
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
    setbuffer,
    setlinebuf,
    setvbuf,
    tempnam,
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


def test_where_a_stream_is() raises:
    """`fgetpos` writes down where a stream is and `fsetpos` puts it
    back there, which is `ftell` and `fseek` done with an opaque value
    instead of a long.

    A stream is read partway, the place is written down, and the rest
    is read; then the stream is put back and read again. The second
    read has to come out the same as the first, which is what a call
    that wrote nothing down, or one that put the stream anywhere else,
    could not manage.

    The place itself is not looked into. What is in it is the
    library's own to say, and it is not the same on the two platforms.
    """
    var f = tmpfile()
    assert_true(Int(UInt(f)) != 0, "a temporary file to work on")
    _ = fputs(string_to_char_ptr("abcdefghij"), f)
    _ = rewind(f)

    var pos = unsafe_alloc[fpos_t](1)
    pos.unsafe_offset(0)[] = fpos_t()

    assert_equal(fgetpos(f, pos), 0, "fgetpos writes the place down")
    assert_equal(fgetc(f), 97, "the a at the start")
    assert_equal(fgetc(f), 98, "and the b after it")

    assert_equal(fsetpos(f, pos), 0, "and fsetpos puts the stream back")
    assert_equal(fgetc(f), 97, "so the a is read again")
    assert_equal(fgetc(f), 98, "and so is the b")

    pos.unsafe_free()
    _ = fclose(f)


def test_naming_a_terminal_and_a_temporary() raises:
    """`ctermid` says the name of the terminal this process is on, and
    `tempnam` makes up the name of a file that no file has yet.

    Neither is held to particular characters. What a terminal is
    called, and where files of no account are made, is for the
    platform to say; what is asked here is that each says something.

    `ctermid` is asked with nowhere to write, which is what a null
    pointer asks for, and what comes back is not to be freed. What it
    says is not a promise that there is a terminal, which is `isatty`'s
    to answer and not this one's.

    `tempnam` is asked for a name beginning with a prefix, and the
    prefix is in what comes back — which is the one thing here a call
    that made up any name at all would not answer. Its memory is its
    own asking for, so `free` is what gives it back.
    """
    var name = ctermid(null_ptr[c_char]())
    assert_true(Int(UInt(name)) != 0, "ctermid says something")
    assert_true(
        char_ptr_to_string(name).byte_length() > 0,
        "and what it says is not empty",
    )

    var pfx = string_to_char_ptr("mytmp")
    var made = tempnam(null_ptr[c_char](), pfx)
    assert_true(Int(UInt(made)) != 0, "tempnam makes up a name")
    var whole = char_ptr_to_string(made)
    assert_true(whole.find("mytmp") >= 0, "and the prefix asked for is in it")
    assert_true(
        whole.byte_length() > 5, "and there is more to it than the prefix"
    )

    _ = free(made.unsafe_bitcast[c_void]())
    pfx.unsafe_free()


def test_writing_a_stream_into_memory() raises:
    """`open_memstream` opens a stream that writes into memory, growing
    the room as it goes.

    Writing comes out when the stream is shut, so that is when the two
    things it was handed are asked: the address of what was written,
    and how many bytes of it there are. Both are asked here, and what
    is at the address is asked too.

    The size is held to six and not to seven, the terminator not being
    counted in it, which is the one thing about the size a call that
    counted the terminator would get wrong. What was written is held to
    be exactly what was put in and no more, which is what says the
    room was grown to fit and not left to overrun.

    The room is the library's own asking for, so `free` gives it back
    once the stream is shut.
    """
    var bufloc = unsafe_alloc[c_ptr[c_char]](1)
    var sizeloc = unsafe_alloc[c_size_t](1)
    bufloc.unsafe_offset(0)[] = null_ptr[c_char]()
    sizeloc.unsafe_offset(0)[] = 0

    var f = open_memstream(bufloc, sizeloc)
    assert_true(Int(UInt(f)) != 0, "open_memstream hands back a stream")

    _ = fputs(string_to_char_ptr("hello!"), f)
    assert_equal(fclose(f), 0, "and shutting it lets the writing come out")

    assert_equal(
        Int(sizeloc.unsafe_offset(0)[]),
        6,
        "six bytes written, terminator and all",
    )
    assert_equal(
        char_ptr_to_string(bufloc.unsafe_offset(0)[]),
        "hello!",
        "and this is what was written",
    )

    _ = free(bufloc.unsafe_offset(0)[].unsafe_bitcast[c_void]())
    sizeloc.unsafe_free()
    bufloc.unsafe_free()


def test_saying_how_a_stream_buffers() raises:
    """`setbuffer` says what room a stream is to buffer in and
    `setlinebuf` says that it is to write out a line at a time.

    Neither hands anything back, so what is asked of them is that the
    stream still works after they have been said: something is written
    on it and read back, and it is what went in.

    `setbuffer` is asked with room of its own, and again with no room
    at all, which is what a null pointer asks for and is the only way
    this one can say that nothing is to be buffered.

    Each is said before anything is written on the stream, as both
    require, and the room is given back only after the stream is shut.
    """
    var room = unsafe_alloc[UInt8](BUFSIZ)
    var f = tmpfile()
    setbuffer(f, room, BUFSIZ)
    _ = fputs(string_to_char_ptr("hello"), f)
    _ = rewind(f)
    var got = unsafe_alloc[UInt8](8)
    _ = fgets(got, 8, f)
    assert_equal(
        char_ptr_to_string(got), "hello", "the stream still writes and reads"
    )
    _ = fclose(f)
    room.unsafe_free()
    got.unsafe_free()

    # No room at all, which is what a null pointer asks for.
    var g = tmpfile()
    setbuffer(g, null_ptr[c_char](), 0)
    _ = fputs(string_to_char_ptr("hi"), g)
    _ = rewind(g)
    var got2 = unsafe_alloc[UInt8](8)
    _ = fgets(got2, 8, g)
    assert_equal(
        char_ptr_to_string(got2), "hi", "and so does one with nothing buffered"
    )
    _ = fclose(g)
    got2.unsafe_free()

    var h = tmpfile()
    setlinebuf(h)
    _ = fputs(string_to_char_ptr("line"), h)
    _ = rewind(h)
    var got3 = unsafe_alloc[UInt8](8)
    _ = fgets(got3, 8, h)
    assert_equal(char_ptr_to_string(got3), "line", "and one set to lines")
    _ = fclose(h)
    got3.unsafe_free()


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
    test_where_a_stream_is()
    test_naming_a_terminal_and_a_temporary()
    test_writing_a_stream_into_memory()
    test_saying_how_a_stream_buffers()
    print("test_stdio: ok")
