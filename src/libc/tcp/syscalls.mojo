# -----------------------------------
# author: llango
# email: rontomai@gmail.com
# github: github.com/llango
# ----------------------------------
# C library <netinet/tcp.h> option numbers.
#
# The options a TCP connection keeps for itself, as the numbers
# `setsockopt` and `getsockopt` take with `IPPROTO_TCP` in the level:
# whether small writes wait for company, how large a segment may be, and
# how a kept-alive connection asks the far end whether it is still there.
#
# The two libcs number these in different worlds. glibc gives them 1, 2,
# 3, 4, in the order the header grew; Darwin's start again above the
# socket-layer numbers -- 0x01 and 0x02 for the first two, and then
# 0x101 and 0x102 for the keepalive pair, the jump being where the socket
# options ran out of room. A number written from one platform and used on
# the other asks for an option that does not exist, which is `ENOPROTOOPT`
# at best, and that is why each of the four that differ is written twice.
#
# The keepalive timing has a third wrinkle worth knowing before asking
# for it: Linux spells the idle interval `TCP_KEEPIDLE` and Darwin spells
# it `TCP_KEEPALIVE`, so the one name is not in both headers and is not
# bound here. `TCP_KEEPINTVL` and `TCP_KEEPCNT` are in both, and answer
# the same question on both.
from std.sys import CompilationTarget


# Off makes small writes wait until a full segment has gathered, or until
# the waiting is over. On sends each write as soon as it arrives, which is
# what a request-and-reply protocol wants and what a bulk transfer does
# not. The number is 1 on both platforms, but what a read of it answers is
# not: glibc answers the 1 back, and Darwin answers the flag the kernel
# set, its `TF_NODELAY`, which is 4. Both mean on.
comptime TCP_NODELAY: Int32 = 1

# The largest segment this connection may send, which a connected socket
# answers with what the path negotiated. Also 2 on both.
comptime TCP_MAXSEG: Int32 = 2

# How long a kept-alive connection waits between the probes it sends to a
# far end that has gone quiet, and how many go unanswered before the
# connection is given up on. Both are seconds and a count, and both are
# settable before the connection is made.
comptime TCP_KEEPINTVL: Int32 = 0x101 if CompilationTarget.is_macos() else 5
comptime TCP_KEEPCNT: Int32 = 0x102 if CompilationTarget.is_macos() else 6
