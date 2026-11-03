# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 133 |
| `libc.stdlib` | `<stdlib.h>` | 79 |
| `libc.float` | `<float.h>` | 30 |
| `libc.unistd` | `<unistd.h>` | 202 |
| `libc.file` | `<stdio.h>` file operations | 40 |
| `libc.ctype` | `<ctype.h>` | 31 |
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
| `libc.string` | `<string.h>` | 50 |
| `libc.stdio` | `<stdio.h>` output, buffering, pipes | 44 |
| `libc.complex` | `<complex.h>` | 46 |
| `libc.sched` | `<sched.h>` | 16 |
| `libc.signal` | `<signal.h>` | 53 |
| `libc.spawn` | `<spawn.h>` start a process without fork | 25 |
| `libc.locale` | `<locale.h>` | 16 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 7 |
| `libc.search` | `<search.h>` | 9 |
| `libc.dirent` | `<dirent.h>` | 18 |
| `libc.sys.wait` | `<sys/wait.h>` | 25 |
| `libc.inttypes` | `<inttypes.h>` | 7 |
| `libc.sys.resource` | `<sys/resource.h>` | 15 |
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
| `libc.dlfcn` | `<dlfcn.h>` | 7 |
| `libc.wchar` | `<wchar.h>` | 85 |
| `libc.wordexp` | `<wordexp.h>` shell-style word splitting | 6 |
| `libc.wctype` | `<wctype.h>` | 5 |
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

`libc.threads` (`<threads.h>`) exports nothing: Apple never shipped C11
threads, so a binding would only ever work on Linux.

`libc.math` has no `long double` variants — no `fabsl`, no `nexttoward` —
because Mojo has no type to pass: on x86-64 the C type is the 80-bit x87
format. `libc.locale` has no `FE_DFL_ENV`, see `fenv_t`.

`libc.sys.epoll`, `libc.sys.prctl`, `libc.sys.sendfile`, `libc.sys.eventfd`,
`libc.sys.inotify`, `libc.sys.sigqueue`, `libc.sys.timer` and `libc.sys.auxv`
wrap Linux-only
calls; importing them on Darwin will not link.
`libc.sys.random` holds one of each: `getentropy`, which both platforms
have, and `getrandom`, which answers -1 on Darwin rather than going
missing.

`libc.stdio` covers the `<stdio.h>` entry points that `libc.file` does not
already own; see the note at the top of `src/libc/stdio/syscalls.mojo`.
`libc.complex` models `double complex` and `float complex` as the two-field
structs the ABI actually passes; `long double complex` is left out because
Mojo has no 80-bit type.

## The six that would stop the suite

Six of the bindings would stop the run rather than fail it, which is a
worse trade than no test at all:

| Call | Why not |
|---|---|
| `libc.file.ioctl` | Variadic: which device it is and what it is asked to do both come after the arguments that can be given. |
| `libc.file.scanf` | Reads from standard input, which a test cannot promise will ever come to an end. |
| `libc.signal.sigsuspend` | Waits for a signal to arrive. A test that waits is a test that stops. |
| `libc.signal.sigwait` | The same. Given a set with nothing in it, glibc waits rather than refusing. |
| `libc.stdio.getchar` | Reads from standard input, as `scanf` does. |
| `libc.unistd.pause` | Waits for a signal. |

None of them is known to be broken; they are simply not asked. Twelve more
cannot be asked for a reason that is not about waiting: `getchar_unlocked`
and `getwchar` read standard input as well, `_Exit` ends the process the
suite is running in, `system` starts a shell, `setsid` takes the process out
of its terminal session, `pthread_atfork` asks for a fork, `pthread_cancel`
and `pthread_cond_wait` need a thread the suite is sharing, `prctl` is
Linux's and changes the process it is called on, `isascii_l` and
`sched_getcpucount` are symbols glibc does not export at all, and
`putwchar` orients standard output to wide characters for the rest of the
process. That last one is not about the terminal — the suite points fd 1 at
a file when it needs to — but about the stream: after one wide write, the
next byte write to it answers `EOF` and writes nothing, and there is no
`stdout` object here to reopen and clear it.

Two calls are not bound at all, which is a different thing from not being
asked: `fflush` and `fdopen` cannot be declared from Mojo while the standard
library declares them. `std.io` has a `FILE *` of its own and a second
declaration of either name is refused at compile time — `existing function
with conflicting signature` — in whichever module makes the call and nowhere
else, so a binding for one compiles, sits in the package looking bound, and
fails when a caller touches it. Both were in that state until a test asked
them something; they are gone, and `scripts/check-symbols.py` fails if either
name comes back.

`scripts/check-tests.py` keeps the full list, with a reason each, and fails
when a binding is added with neither a test nor a reason. It also keeps the
opposite list — bindings that could be asked something and have not been —
because that is where `gl_flags` was: called by nothing, wrong for three
releases, and every other check in this repository green. That list is
**empty** now: 977 bindings are asked something, and the 17 that are not
each have a reason written down. Empty is not the same as gone; it still
fails if it grows, which is the thing it was written for.

## API reference

Generate the docstring reference for any module with the Mojo toolchain:

```bash
mojo doc src/libc/unistd/syscalls.mojo
```
