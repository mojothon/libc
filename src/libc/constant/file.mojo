# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
from libc.constant.ctype import c_int
from std.sys import CompilationTarget

comptime off_t = Int64
comptime mode_t = UInt32

comptime FM_READ = "r"
comptime FM_WRITE = "w"
comptime FM_APPEND = "a"
comptime FM_BINARY = "b"
comptime FM_PLUS = "+"

comptime SEEK_SET = 0
comptime SEEK_CUR = 1
comptime SEEK_END = 2

comptime O_RDONLY = 0
comptime O_WRONLY = 1
comptime O_RDWR = 2
comptime O_APPEND: Int32 = 8 if CompilationTarget.is_macos() else 1024
comptime O_CREAT: Int32 = 512 if CompilationTarget.is_macos() else 64
comptime O_TRUNC: Int32 = 1024 if CompilationTarget.is_macos() else 512
comptime O_EXCL: Int32 = 2048 if CompilationTarget.is_macos() else 128
comptime O_SYNC: Int32 = 128 if CompilationTarget.is_macos() else 1052672
comptime O_NONBLOCK: Int32 = 4 if CompilationTarget.is_macos() else 2048
comptime O_ACCMODE = 3
comptime O_CLOEXEC: Int32 = 16777216 if CompilationTarget.is_macos() else 524288

# from fcntl.h
comptime O_EXEC: Int32 = 1073741824 if CompilationTarget.is_macos() else -1
comptime O_SEARCH: Int32 = 1074790400 if CompilationTarget.is_macos() else -1  # O_EXEC|O_DIRECTORY there; Linux has neither O_SEARCH nor O_EXEC
comptime O_DIRECTORY: Int32 = 1048576 if CompilationTarget.is_macos() else 65536
comptime O_DSYNC = -1 if CompilationTarget.is_macos() else 4096  # Darwin has no such flag; it has O_SYNC
comptime O_NOCTTY: Int32 = 131072 if CompilationTarget.is_macos() else 256
comptime O_NOFOLLOW: Int32 = 256 if CompilationTarget.is_macos() else 131072
comptime O_RSYNC = -1
comptime O_TTY_INIT = -1

comptime STDIN_FILENO = 0
comptime STDOUT_FILENO = 1
comptime STDERR_FILENO = 2

comptime F_DUPFD = 0
comptime F_GETFD = 1
comptime F_SETFD = 2
comptime F_GETFL = 3
comptime F_SETFL = 4
comptime F_GETOWN: Int32 = 5 if CompilationTarget.is_macos() else 9
comptime F_SETOWN: Int32 = 6 if CompilationTarget.is_macos() else 8
comptime F_GETLK: Int32 = 7 if CompilationTarget.is_macos() else 5
comptime F_SETLK: Int32 = 8 if CompilationTarget.is_macos() else 6
comptime F_SETLKW: Int32 = 9 if CompilationTarget.is_macos() else 7
comptime F_RGETLK = 10
comptime F_RSETLK = 11
comptime F_CNVT = 12
comptime F_RSETLKW = 13
comptime F_DUPFD_CLOEXEC: Int32 = 67 if CompilationTarget.is_macos() else 1030

# TODO(cristian)
comptime FD_CLOEXEC = 1
comptime F_RDLCK: Int32 = 1 if CompilationTarget.is_macos() else 0
comptime F_UNLCK = 2
comptime F_WRLCK: Int32 = 3 if CompilationTarget.is_macos() else 1

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
