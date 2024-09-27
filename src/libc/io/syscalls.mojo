# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from sys import external_call
from memory import UnsafePointer
from libc.constant import * 

@value
@register_passable("trivial")
struct DIR:
    pass


@value
@register_passable("trivial")
struct dirent:
    var d_ino: c_ulong
    var d_off: c_ulong
    var d_reclen: c_ushort
    var d_type: c_char
    var d_name: UnsafePointer[c_char]



fn closedir(arg: UnsafePointer[DIR]) -> c_int:
    """Libc POSIX `closedir` function.

    Args:
        arg: An accessible object of the type DIR.  If a file descriptor is used to implement type DIR, that file descriptor shall be closed.

    Returns:
        Upon successful completion, closedir() shall return 0; otherwise,
       -1 shall be returned and errno set to indicate the error.

    Notes:
        [Reference](https://man7.org/linux/man-pages/man3/closelog.3p.html).
        Fn signature: `  int closedir(DIR *dirp)`.
    """
    return external_call["closedir", Int32, UnsafePointer[DIR]](arg)


fn opendir(arg: UnsafePointer[c_char]) -> UnsafePointer[DIR]:
    return external_call["opendir", UnsafePointer[DIR], UnsafePointer[c_char]](arg)


fn readdir(arg: UnsafePointer[DIR]) -> UnsafePointer[dirent]:
    return external_call["readdir", UnsafePointer[dirent], UnsafePointer[DIR]](arg)


fn fdopendir(arg: Int32) -> DIR:
    return external_call["fdopendir", DIR](arg)


fn strnlen(pointer: UnsafePointer[UInt8]) -> Int:
    return external_call["strnlen", Int, UnsafePointer[UInt8]](pointer)