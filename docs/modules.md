# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 124 |
| `libc.stdlib` | `<stdlib.h>` | 84 |
| `libc.float` | `<float.h>` | 30 |
| `libc.limits` | `<limits.h>` the widths of the integer types, and what a process may have | 24 |
| `libc.unistd` | `<unistd.h>` | 209 |
| `libc.file` | `<stdio.h>` file operations | 32 |
| `libc.ctype` | `<ctype.h>` | 30 |
| `libc.sys.socket` | `<sys/socket.h>` | 44 |
| `libc.sys.stat` | `<sys/stat.h>` | 36 |
| `libc.sys.times` | `<sys/times.h>` | 2 |
| `libc.time` | `<time.h>` | 39 |
| `libc.fenv` | `<fenv.h>` | 26 |
| `libc.sys.mman` | `<sys/mman.h>` | 15 |
| `libc.sys.sigqueue` | `<signal.h>` a signal sent with a number, and the two waits | 5 |
| `libc.sys.inotify` | `<sys/inotify.h>` watching files for what happens | 24 |
| `libc.sys.eventfd` | `<sys/eventfd.h>` a counter behind a descriptor | 6 |
| `libc.aio` | `<aio.h>` I/O handed over rather than waited for | 24 |
| `libc.sys.sysinfo` | `<sys/sysinfo.h>` | 18 |
| `libc.sys.timer` | `<time.h>` the timers Darwin does not have | 12 |
| `libc.pthread` | `<pthread.h>` | 103 |
| `libc.threads` | `<threads.h>` Linux only, the C11 threads | 40 |
| `libc.string` | `<string.h>` | 48 |
| `libc.stdio` | `<stdio.h>` output, buffering, pipes | 43 |
| `libc.complex` | `<complex.h>` | 46 |
| `libc.sched` | `<sched.h>` | 15 |
| `libc.signal` | `<signal.h>` an action, and a handler as its number | 67 |
| `libc.spawn` | `<spawn.h>` start a process without fork | 25 |
| `libc.locale` | `<locale.h>` | 23 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 9 |
| `libc.search` | `<search.h>` | 9 |
| `libc.dirent` | `<dirent.h>` | 22 |
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
| `libc.pty` | `<pty.h>` a terminal a program can hold | 4 |
| `libc.fcntl` | `<fcntl.h>` | 49 |
| `libc.getopt` | `<getopt.h>` taking a command line apart | 12 |
| `libc.dlfcn` | `<dlfcn.h>` | 9 |
| `libc.wchar` | `<wchar.h>` | 99 |
| `libc.wordexp` | `<wordexp.h>` shell-style word splitting | 6 |
| `libc.wctype` | `<wctype.h>` | 5 |
| `libc.uchar` | `<uchar.h>` the UTF-16 and UTF-32 conversions | 4 |
| `libc.sys.statfs` | `<sys/statfs.h>` the kernel's own account of a file system | 15 |
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
| `libc.termios` | `<termios.h>` how a terminal line is set | 57 |
| `libc.tcp` | `<netinet/tcp.h>` the options a connection keeps | 4 |
| `libc.sys.un` | `<sys/un.h>` an address that is a path | 4 |
| `libc.sys.ipc` | `<sys/ipc.h>` keys for System V objects | 9 |
| `libc.sys.msg` | `<sys/msg.h>` message queues | 6 |
| `libc.utmpx` | `<utmpx.h>` who is logged in, and where | 29 |
| `libc.constant` | C type aliases and constants | — |
| `libc.utils` | String/pointer helpers | — |

## Not started yet

`libc.threads` (`<threads.h>`) is Linux only: Apple never shipped C11
threads, and no Darwin SDK has the header. A header that one platform
does not have has never disqualified a module here — `libc.sys.epoll`,
`libc.uchar` and others are Linux-only on purpose, and say so — and this
one is the same kind of thing, so importing it on Darwin will not link.

It is also the module that waited longest, and the reason was one
argument: `thrd_create` takes a function pointer, and for most of this
package's life nothing here could hand C one. That reading was wrong —
a `def` that captures nothing converts to a `thin` function value, which
is a code address, and `thrd_create` takes it where C takes its
`thrd_start_t` — and once it was wrong, the whole module came with it:
all twenty-five functions, including `call_once` and the thread-local
`destructor`, are bound on the same discovery. `tests/test_threads.mojo`
starts threads, hands a mutex and a condition variable to two of them at
once, and proves a wake that cannot be lost.

What `libc.pthread` owns and `libc.threads` does not is everything POSIX
added on top: attributes, cancellation, process-shared mutexes, barriers
once the other side has them. `threads.h` is the smaller vocabulary, and
a program that wants C11 spellings — or wants to read C11 code — gets it
here over the same libcs.

One call this page used to name alongside the missing module was never
behind that wall: `atexit` has no symbol in glibc, which exports
`__cxa_atexit` and `on_exit` in its place, so on this platform there is
nothing for a binding to link against whatever the callback situation is.

`libc.math` has no `long double` variants — no `fabsl`, no `nexttoward` —
because Mojo has no type to pass: on x86-64 the C type is the 80-bit x87
format. `libc.locale` has no `FE_DFL_ENV`, see `fenv_t`.

`libc.sys.epoll`, `libc.sys.prctl`, `libc.sys.sendfile`, `libc.sys.eventfd`,
`libc.sys.inotify`, `libc.sys.sigqueue`, `libc.sys.timer`, `libc.sys.auxv`,
`libc.threads` and `libc.uchar`
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

One binding is not asked anything, and the reason is about the call rather
than about the suite:

- `ioctl` is variadic, and its third argument is the address that nearly every
  request writes its answer through. `external_call` emits a call whose
  arguments are all in registers, and arm64 hands a variadic callee its
  anonymous arguments on the stack instead: what the callee reads is a slot
  nobody wrote. `FIONREAD` through this binding answers 0 on Apple silicon and
  leaves the integer it was asked about untouched. It is the same wall that
  makes the call that opens a file here be openat rather than open.

It is not known to be broken; it is simply not asked.

The wide putwchar call used to be on this list, on the reading that a fork only hands a
child the stream the suite has already oriented. That was wrong twice over:
the C library exports its standard output as a variable that the dynamic
loader reaches, and reopening that stream starts it over -- unoriented, and
pointed at whatever descriptor 1 holds. A child that points descriptor 1 at
a pipe, reopens, turns the stream wide, and only then makes the wide write
gets a real wide standard output to write to, and the pipe receives what
the call wrote. The reasons on this page are claims, and claims get tested.

1062 bindings are asked something, and the 1 that is not has a reason.
Both numbers are read back out of this page by
`scripts/check-tests.py`, and so is every call named above: the page fails
the run as soon as it says a call is not asked and a test starts asking it.

## What the built form asks

`pthread_atfork` registers the three fork handlers and answers 0, and no
test of this suite can ask it: the just-in-time run every test goes
through looks the bare name up and finds nothing, glibc exporting it with
no default version -- `Symbols not found: [ pthread_atfork ]`, the run
dead on the lookup. A binary built out of this source links it, which the
answer beside the suite had been claiming on trust. The claim is a test
now: `tests/test_atfork.mojo` registers three no-op handlers and takes
the 0, and the recipe builds it first and runs the binary -- the one form
the question can be asked in, and the one claim the asking retired.

## What only one platform asks

A test whose calls sit inside a `comptime if` naming one platform asks its
question there and nowhere else, and the count of asked bindings reads the
same text on both platforms -- which is how `putwchar` and `timespec_get`
were bound on both and asked on one without a tripwire to pull. The count
knows which guards the calls sit under now, and a binding whose every call
sits inside one platform's guard is listed with the reason the other
platform is not asked. All ten have the same shape of an answer: the
other platform's C library has no such call.

- `epoll_create`, `gettid`, `prlimit` and `sched_getaffinity` are Linux's
  own -- epoll has no half on Darwin, which answers the same need with
  kqueue, and the thread id, the pid form of the resource limits and the
  scheduler's CPU mask are the Linux kernel's ideas.
- `getauxval` reads the auxiliary vector, which is ELF's, and Darwin's
  loader keeps no such table.
- `get_nprocs` and `secure_getenv` are glibc names; Darwin answers the
  processor question through `sysconf` under different names, and the same
  `getenv` there with no setuid distinction to ask about.
- `thrd_detach`, `thrd_equal` and `tss_create` are C11 threads, which
  Darwin's libSystem does not provide.

Linux asks 10 bindings that Darwin passes over, and Darwin 0 that Linux
passes over. Both numbers are read back out of this page too, and so is
every call named here: the page fails the run when a binding goes
one-platform without a reason, and when one of these starts being asked
without a guard, which is the list being paid.
