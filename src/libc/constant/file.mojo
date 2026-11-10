# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from libc.constant.ctype import c_int
from std.sys import CompilationTarget

comptime off_t = Int64
# Darwin's `mode_t` is an `unsigned short`, and glibc's is an `unsigned
# int`: the same bits in the low half, and the four-byte one is what
# `open` and `chmod` read there. Written as the header has it, because a
# type alias that is twice the width it claims is the kind of thing that
# reads a neighbouring field.
comptime mode_t = UInt16 if CompilationTarget.is_macos() else UInt32

comptime FM_READ = "r"
comptime FM_WRITE = "w"
comptime FM_APPEND = "a"
comptime FM_BINARY = "b"
comptime FM_PLUS = "+"

comptime SEEK_SET = 0
comptime SEEK_CUR = 1
comptime SEEK_END = 2


# The flags and the commands `open` and `fcntl` read live beside the
# calls that use them, in `libc.fcntl`: one asking of each, so that a
# sweep's mistake in one copy has no second copy to be answered by. What
# is left here is the `<stdio.h>` half -- `FM_*`, the seeks, the three
# descriptors -- and the four `fcntl.h` numbers `libc.fcntl` does not
# carry: Darwin's `O_EXEC`, `O_SEARCH` and `O_RSYNC`, and the `O_TTY_INIT`
# both platforms spell -1.
comptime O_EXEC: Int32 = 1073741824 if CompilationTarget.is_macos() else -1
comptime O_SEARCH: Int32 = 1074790400 if CompilationTarget.is_macos() else -1  # O_EXEC|O_DIRECTORY there; Linux has neither O_SEARCH nor O_EXEC
comptime O_RSYNC: Int32 = 128 if CompilationTarget.is_macos() else 1052672  # both spell it the same as O_SYNC
comptime O_TTY_INIT = -1

comptime STDIN_FILENO = 0
comptime STDOUT_FILENO = 1
comptime STDERR_FILENO = 2

comptime F_RGETLK = 10
comptime F_RSETLK = 11
comptime F_CNVT = 12
comptime F_RSETLKW = 13
comptime F_DUPFD_CLOEXEC: Int32 = 67 if CompilationTarget.is_macos() else 1030

comptime AT_EACCESS: Int32 = 16 if CompilationTarget.is_macos() else 512
# Which number says "the current directory" is up to the platform:
# -100 on Linux, -2 on Darwin.
comptime AT_FDCWD: c_int = -2 if CompilationTarget.is_macos() else -100
comptime AT_SYMLINK_NOFOLLOW: Int32 = 32 if CompilationTarget.is_macos() else 256
comptime AT_REMOVEDIR: Int32 = 128 if CompilationTarget.is_macos() else 512
comptime AT_SYMLINK_FOLLOW: Int32 = 64 if CompilationTarget.is_macos() else 1024
comptime AT_NO_AUTOMOUNT = 2048
comptime AT_EMPTY_PATH = 4096
comptime AT_RECURSIVE = 32768
