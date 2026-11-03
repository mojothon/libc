# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 133 |
| `libc.stdlib` | `<stdlib.h>` | 74 |
| `libc.float` | `<float.h>` | 30 |
| `libc.limits` | `<limits.h>` the widths of the integer types, and what a process may have | 24 |
| `libc.unistd` | `<unistd.h>` | 206 |
| `libc.file` | `<stdio.h>` file operations | 40 |
| `libc.ctype` | `<ctype.h>` | 30 |
| `libc.sys.socket` | `<sys/socket.h>` | 36 |
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
| `libc.sched` | `<sched.h>` | 15 |
| `libc.signal` | `<signal.h>` | 53 |
| `libc.spawn` | `<spawn.h>` start a process without fork | 25 |
| `libc.locale` | `<locale.h>` | 23 |
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

- `ioctl` is variadic with the request deciding what the arguments mean.
- `putwchar` writes to a stream the whole process shares, and orients it:
  forking a child does not get a fresh stream to try it on, only the one the
  suite has already written to as bytes.
- `pthread_atfork` registers a fork handler that the just-in-time run this
  suite uses cannot resolve; a built binary links and answers fine.

None of them is known to be broken; they are simply not asked.

999 bindings are asked something, and the 3 that are not have a reason
each. Both numbers are read back out of this page by
`scripts/check-tests.py`, and so is every call named above: the page fails
the run as soon as it says a call is not asked and a test starts asking it.

## What keeps it honest

Two calls are not bound at all, which is a different thing from not being
asked: `fflush` and `fdopen` cannot be declared from Mojo while the standard
library declares them. `std.io` has a `FILE *` of its own and a second
declaration of either name is refused at compile time — `existing function
with conflicting signature` — in whichever module makes the call and nowhere
else, so a binding for one compiles, sits in the package looking bound, and
fails when a caller touches it. Both were in that state until a test asked
them something; they are gone, and `scripts/check-symbols.py` fails if either
name comes back.

Two more names are gone for a quieter reason: nothing exports them.
`isascii_l` is a macro on glibc over `__isascii_l`, which is a macro over
`__isascii`, so there is no symbol to call, and Darwin's `xlocale/_ctype.h`
does not have the name at all. `sched_getcpucount` is FreeBSD's: glibc does
not declare it, and Darwin's `<sched.h>` holds only `sched_yield` and the
two priority bounds. Both were bound, compiled, and could not be called on
either platform — a test could not have caught it, since a test that calls
one fails to load rather than to assert. What catches it is one check
reading the other: `scripts/check-symbols.py` asks
`scripts/check-prototypes.py` which names no header here declares, and a
name excused by both lists is one that neither the headers nor the
libraries say is there.

`scripts/check-tests.py` keeps the full list, with a reason each, and fails
when a binding is added with neither a test nor a reason. It also keeps the
opposite list — bindings that could be asked something and have not been —
because that is where `gl_flags` was: called by nothing, wrong for three
releases, and every other check in this repository green. That list is
**empty** now, and empty is not the same as gone: it still fails if it
grows, which is the thing it was written for.

Six have left the list above. Three of them needed no handler: `scanf` takes a format and no conversion, so a child's pipe with a word
in it — closed at the write end, which is what gives the input an end — is
enough to ask it for 0 and then for `EOF`. `sigsuspend` waits under a mask
of its own, so a signal blocked and sent to itself is pending until the swap
delivers it: no waiting at all. `pause` has no such mask, and is asked
instead with an alarm it never armed a handler for: the child is ended by
the signal it went to wait for, which is what says it waited.

The other two needed the second thread the suite does not have, and found
it in a child. A condition variable and its lock can be put in a page both
sides address and made for sharing (`PTHREAD_PROCESS_SHARED`), which is
what `pthread_cond_wait` is asked with: the child takes the lock, and it
cannot take it until the parent is inside the wait and has let go of it, so
the signal cannot be sent before there is anyone to receive it — no sleep
stands in for the ordering. Cancelling a thread cannot be taken back, so
`pthread_cancel` is asked of a child as well — two of them, in fact: one
with cancellation left enabled, which does not come back from the next
cancellation point, and one that disabled it first, which does. The pair is
the assertion, because either half alone is passed by a cancel that does
nothing at all.

`prctl` left by being asked only what it answers without changing the
process: `PR_GET_DUMPABLE` and `PR_GET_TIMERSLACK` are reads, and the one
write, `PR_SET_NAME`, renames the calling thread and is undone before the
test returns. The name coming back as the name that was put is what shows
the pointer in the second argument arrived as a pointer. Its refusals are
asked as well: an option number that is not one comes back -1 with
`EINVAL`.

## API reference

Generate the docstring reference for any module with the Mojo toolchain:

```bash
mojo doc src/libc/unistd/syscalls.mojo
```
