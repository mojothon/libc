from std.sys import CompilationTarget

# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
comptime LOG_PID = -1 if CompilationTarget.is_macos() else 1
comptime LOG_CONS = -1 if CompilationTarget.is_macos() else 2
comptime LOG_NDELAY = -1 if CompilationTarget.is_macos() else 8
comptime LOG_ODELAY = -1 if CompilationTarget.is_macos() else 4
comptime LOG_NOWAIT = -1 if CompilationTarget.is_macos() else 16
comptime LOG_KERN = -1 if CompilationTarget.is_macos() else 0
comptime LOG_USER = -1 if CompilationTarget.is_macos() else 8
comptime LOG_MAIL = -1 if CompilationTarget.is_macos() else 16
comptime LOG_NEWS = -1 if CompilationTarget.is_macos() else 56
comptime LOG_UUCP = -1 if CompilationTarget.is_macos() else 64
comptime LOG_DAEMON = -1 if CompilationTarget.is_macos() else 24
comptime LOG_AUTH = -1 if CompilationTarget.is_macos() else 32
comptime LOG_CRON = -1 if CompilationTarget.is_macos() else 72
comptime LOG_LPR = -1 if CompilationTarget.is_macos() else 48
comptime LOG_LOCAL0 = -1 if CompilationTarget.is_macos() else 128
comptime LOG_LOCAL1 = -1 if CompilationTarget.is_macos() else 136
comptime LOG_LOCAL2 = -1 if CompilationTarget.is_macos() else 144
comptime LOG_LOCAL3 = -1 if CompilationTarget.is_macos() else 152
comptime LOG_LOCAL4 = -1 if CompilationTarget.is_macos() else 160
comptime LOG_LOCAL5 = -1 if CompilationTarget.is_macos() else 168
comptime LOG_LOCAL6 = -1 if CompilationTarget.is_macos() else 176
comptime LOG_LOCAL7 = -1 if CompilationTarget.is_macos() else 184
comptime LOG_EMERG = -1 if CompilationTarget.is_macos() else 0
comptime LOG_ALERT = -1 if CompilationTarget.is_macos() else 1
comptime LOG_CRIT = -1 if CompilationTarget.is_macos() else 2
comptime LOG_ERR = -1 if CompilationTarget.is_macos() else 3
comptime LOG_WARNING = -1 if CompilationTarget.is_macos() else 4
comptime LOG_NOTICE = -1 if CompilationTarget.is_macos() else 5
comptime LOG_INFO = -1 if CompilationTarget.is_macos() else 6
comptime LOG_DEBUG = -1 if CompilationTarget.is_macos() else 7
