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
    fileno,
    flockfile,
    ftrylockfile,
    funlockfile,
    fwrite,
    getc,
    getw,
    pclose,
    popen,
    putw,
    remove,
    rename,
    renameat,
    setvbuf,
    tmpfile,
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
    print("test_stdio: ok")
