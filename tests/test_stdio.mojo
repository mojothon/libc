from std.memory.alloc import unsafe_alloc
from std.testing import assert_equal, assert_true

from libc.file import FILE, close, fclose, fgets, fread, rewind
from libc.stdio import (
    IOFBF,
    fileno,
    fwrite,
    getc,
    pclose,
    popen,
    remove,
    rename,
    setvbuf,
    tmpfile,
    ungetc,
)
from libc.stdlib import mkstemp
from libc.utils import char_ptr_to_string, string_to_char_ptr


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


def main() raises:
    test_tmpfile_roundtrip()
    test_rename_and_remove()
    test_popen()
    test_fileno_and_buffering()
    test_ungetc()
    print("test_stdio: ok")
