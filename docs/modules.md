# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 124 |
| `libc.stdlib` | `<stdlib.h>` | 76 |
| `libc.float` | `<float.h>` | 30 |
| `libc.limits` | `<limits.h>` the widths of the integer types, and what a process may have | 24 |
| `libc.unistd` | `<unistd.h>` | 206 |
| `libc.file` | `<stdio.h>` file operations | 32 |
| `libc.ctype` | `<ctype.h>` | 30 |
| `libc.sys.socket` | `<sys/socket.h>` | 35 |
| `libc.sys.stat` | `<sys/stat.h>` | 36 |
| `libc.sys.times` | `<sys/times.h>` | 2 |
| `libc.time` | `<time.h>` | 38 |
| `libc.fenv` | `<fenv.h>` | 26 |
| `libc.sys.mman` | `<sys/mman.h>` | 15 |
| `libc.sys.sigqueue` | `<signal.h>` a signal sent with a number, and the two waits | 5 |
| `libc.sys.inotify` | `<sys/inotify.h>` watching files for what happens | 24 |
| `libc.sys.eventfd` | `<sys/eventfd.h>` a counter behind a descriptor | 6 |
| `libc.aio` | `<aio.h>` I/O handed over rather than waited for | 24 |
| `libc.sys.sysinfo` | `<sys/sysinfo.h>` | 18 |
| `libc.sys.timer` | `<time.h>` the timers Darwin does not have | 12 |
| `libc.pthread` | `<pthread.h>` | 100 |
| `libc.string` | `<string.h>` | 48 |
| `libc.stdio` | `<stdio.h>` output, buffering, pipes | 43 |
| `libc.complex` | `<complex.h>` | 46 |
| `libc.sched` | `<sched.h>` | 15 |
| `libc.signal` | `<signal.h>` | 53 |
| `libc.spawn` | `<spawn.h>` start a process without fork | 25 |
| `libc.locale` | `<locale.h>` | 23 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 7 |
| `libc.search` | `<search.h>` | 9 |
| `libc.dirent` | `<dirent.h>` | 18 |
| `libc.sys.wait` | `<sys/wait.h>` | 25 |
| `libc.inttypes` | `<inttypes.h>` | 7 |
| `libc.sys.resource` | `<sys/resource.h>` | 14 |
| `libc.network` | `<arpa/inet.h>` byte order and address conversion | 16 |
| `libc.netdb` | `<netdb.h>` name and service lookup | 66 |
| `libc.netif` | `<net/if.h>` interface names and numbers | 9 |
| `libc.regex` | `<regex.h>` POSIX regular expressions | 29 |
| `libc.glob` | `<glob.h>` pathname matching | 23 |
| `libc.grp` | `<grp.h>` the group database | 12 |
| `libc.iconv` | `<iconv.h>` character encoding conversion | 4 |
| `libc.ifaddrs` | `<ifaddrs.h>` network interfaces | 16 |
| `libc.langinfo` | `<langinfo.h>` strings the locale decides | 64 |
| `libc.fnmatch` | `<fnmatch.h>` matching a single name | 7 |
| `libc.libgen` | `<libgen.h>` cutting a path in two | 2 |
| `libc.logging` | `<syslog.h>` | 6 |
| `libc.fcntl` | `<fcntl.h>` | 50 |
| `libc.getopt` | `<getopt.h>` taking a command line apart | 12 |
| `libc.dlfcn` | `<dlfcn.h>` | 9 |
| `libc.wchar` | `<wchar.h>` | 85 |
| `libc.wordexp` | `<wordexp.h>` shell-style word splitting | 6 |
| `libc.wctype` | `<wctype.h>` | 5 |
| `libc.uchar` | `<uchar.h>` the UTF-16 and UTF-32 conversions | 4 |
| `libc.sys.statvfs` | `<sys/statvfs.h>` | 15 |
| `libc.sys.select` | `<sys/select.h>` | 9 |
| `libc.sys.shm` | `<sys/shm.h>` shared memory | 7 |
| `libc.sys.sem` | `<sys/sem.h>` counters that wait | 6 |
| `libc.poll` | `<poll.h>` | 14 |
| `libc.setjmp` | `<setjmp.h>` | 2 |
| `libc.execinfo` | `<execinfo.h>` the stack the process is on | 3 |
| `libc.sys.utsname` | `<sys/utsname.h>` | 8 |
| `libc.sys.sendfile` | `<sys/sendfile.h>` | 1 |
| `libc.sys.random` | `<sys/random.h>` | 3 |
| `libc.sys.prctl` | `<sys/prctl.h>` | 19 |
| `libc.sys.auxv` | `<sys/auxv.h>` | 3 |
| `libc.errno` | `<errno.h>` | 6 |
| `libc.pwd` | `<pwd.h>` | 18 |
| `libc.termios` | `<termios.h>` how a terminal line is set | 54 |
| `libc.sys.ipc` | `<sys/ipc.h>` keys for System V objects | 9 |
| `libc.sys.msg` | `<sys/msg.h>` message queues | 6 |
| `libc.utmpx` | `<utmpx.h>` who is logged in, and where | 29 |
| `libc.constant` | C type aliases and constants | — |
| `libc.utils` | String/pointer helpers | — |

## Not started yet

`libc.threads` (`<threads.h>`) exports nothing, and the reason is not the
one the header suggests. Apple never shipped C11 threads — no Darwin SDK
has `<threads.h>` — but a header that one platform does not have has never
disqualified a module here: `libc.sys.epoll`, `libc.uchar` and others are
Linux-only on purpose, and say so.

The blocker is `thrd_create`, which takes a function pointer, and nothing
in this package can hand C one. The same wall stands behind `qsort`,
`atexit` and `pthread_create`. Here it takes the whole module with it: of
the twenty-five functions `<threads.h>` declares, twenty-two could be
bound, and every one of them is about meeting another thread. A mutex with
one thread never blocks, a condition variable with one thread can only
time out, and `thrd_join` wants a `thrd_t` that nothing here can bring
into being. `libc.pthread` has the same hole and a hundred other entry
points that are worth having on their own; `threads.h` is a wrapper over
those same calls with nothing else in it.

`libc.math` has no `long double` variants — no `fabsl`, no `nexttoward` —
because Mojo has no type to pass: on x86-64 the C type is the 80-bit x87
format. `libc.locale` has no `FE_DFL_ENV`, see `fenv_t`.

`libc.sys.epoll`, `libc.sys.prctl`, `libc.sys.sendfile`, `libc.sys.eventfd`,
`libc.sys.inotify`, `libc.sys.sigqueue`, `libc.sys.timer`, `libc.sys.auxv`
and `libc.uchar`
wrap Linux-only
calls; importing them on Darwin will not link. `libc.uchar` is there because
Darwin has no `<uchar.h>` — not in the 10.15 SDK, not in 14.4, and not in
Apple's Libc sources — rather than because one call is missing from it.
`libc.sys.random` holds one of each: `getentropy`, which both platforms
have, and `getrandom`, which answers -1 on Darwin rather than going
missing.

`libc.stdio` covers the `<stdio.h>` entry points that `libc.file` does not
already own; see the note at the top of `src/libc/stdio/syscalls.mojo`.
`libc.complex` models `double complex` and `float complex` as the two-field
structs the ABI actually passes; `long double complex` is left out because
Mojo has no 80-bit type.

## What the suite does not ask

Three bindings are not asked anything, and every one of them has a reason that
is about the call rather than about the suite:

- `ioctl` is variadic, and its third argument is the address that nearly every
  request writes its answer through. `external_call` emits a call whose
  arguments are all in registers, and arm64 hands a variadic callee its
  anonymous arguments on the stack instead: what the callee reads is a slot
  nobody wrote. `FIONREAD` through this binding answers 0 on Apple silicon and
  leaves the integer it was asked about untouched. It is the same wall that
  makes the call that opens a file here be openat rather than open.
- `putwchar` writes to a stream the whole process shares, and orients it:
  forking a child does not get a fresh stream to try it on, only the one the
  suite has already written to as bytes.
- `pthread_atfork` registers a fork handler that the just-in-time run this
  suite uses cannot resolve; a built binary links and answers fine.

None of them is known to be broken; they are simply not asked.

998 bindings are asked something, and the 3 that are not have a reason
each. Both numbers are read back out of this page by
`scripts/check-tests.py`, and so is every call named above: the page fails
the run as soon as it says a call is not asked and a test starts asking it.
