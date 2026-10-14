"""What `epoll` is asked for: which events to watch, and what to do.

These are Linux's and nobody else's. Darwin has `kqueue` instead, so
there is no second set of numbers to choose between here; every one of
these is glibc's, and a program that wants them is a program that has
already decided where it is running.

`EPOLLET` is `0x80000000`, which is a number an `Int32` cannot hold as a
positive one, so it is written here as the negative it comes back as.
"""
comptime EPOLLIN: Int32 = 1
comptime EPOLLPRI: Int32 = 2
comptime EPOLLOUT: Int32 = 4
comptime EPOLLRDNORM: Int32 = 64
comptime EPOLLRDBAND: Int32 = 128
comptime EPOLLWRNORM: Int32 = 256
comptime EPOLLWRBAND: Int32 = 512
comptime EPOLLMSG: Int32 = 1024
comptime EPOLLERR: Int32 = 8
comptime EPOLLHUP: Int32 = 16
comptime EPOLLRDHUP: Int32 = 8192
comptime EPOLLEXCLUSIVE: Int32 = 268435456
comptime EPOLLWAKEUP: Int32 = 536870912
comptime EPOLLONESHOT: Int32 = 1073741824
comptime EPOLLET: Int32 = -2147483648

# What `epoll_ctl` is told to do with the descriptor it is given.
comptime EPOLL_CTL_ADD: Int32 = 1
comptime EPOLL_CTL_DEL: Int32 = 2
comptime EPOLL_CTL_MOD: Int32 = 3

# Handed to `epoll_create1`.
comptime EPOLL_CLOEXEC: Int32 = 524288
