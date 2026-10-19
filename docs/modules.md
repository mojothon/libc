# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 115 |
| `libc.stdlib` | `<stdlib.h>` | 45 |
| `libc.float` | `<float.h>` | 30 |
| `libc.unistd` | `<unistd.h>` | 185 |
| `libc.file` | `<stdio.h>` file operations | 40 |
| `libc.ctype` | `<ctype.h>` | 29 |
| `libc.sys.socket` | `<sys/socket.h>` | 23 |
| `libc.sys.stat` | `<sys/stat.h>` | 18 |
| `libc.time` | `<time.h>` | 30 |
| `libc.fenv` | `<fenv.h>` | 26 |
| `libc.sys.mman` | `<sys/mman.h>` | 15 |
| `libc.pthread` | `<pthread.h>` | 16 |
| `libc.string` | `<string.h>` | 39 |
| `libc.stdio` | `<stdio.h>` output, buffering, pipes | 28 |
| `libc.complex` | `<complex.h>` | 46 |
| `libc.sched` | `<sched.h>` | 15 |
| `libc.signal` | `<signal.h>` | 40 |
| `libc.locale` | `<locale.h>` | 16 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 7 |
| `libc.search` | `<search.h>` | 9 |
| `libc.dirent` | `<dirent.h>` | 15 |
| `libc.sys.wait` | `<sys/wait.h>` | 14 |
| `libc.inttypes` | `<inttypes.h>` | 7 |
| `libc.sys.resource` | `<sys/resource.h>` | 15 |
| `libc.network` | `<arpa/inet.h>` byte order and address conversion | 6 |
| `libc.netdb` | `<netdb.h>` name and service lookup | 29 |
| `libc.regex` | `<regex.h>` POSIX regular expressions | 26 |
| `libc.logging` | `<syslog.h>` | 6 |
| `libc.fcntl` | `<fcntl.h>` | 49 |
| `libc.dlfcn` | `<dlfcn.h>` | 7 |
| `libc.wchar` | `<wchar.h>` | 27 |
| `libc.sys.statvfs` | `<sys/statvfs.h>` | 3 |
| `libc.sys.select` | `<sys/select.h>` | 9 |
| `libc.poll` | `<poll.h>` | 14 |
| `libc.setjmp` | `<setjmp.h>` | 2 |
| `libc.sys.utsname` | `<sys/utsname.h>` | 2 |
| `libc.sys.sendfile` | `<sys/sendfile.h>` | 1 |
| `libc.sys.random` | `<sys/random.h>` | 2 |
| `libc.sys.prctl` | `<sys/prctl.h>` | 19 |
| `libc.sys.auxv` | `<sys/auxv.h>` | 3 |
| `libc.errno` | `<errno.h>` | 6 |
| `libc.pwd` | `<pwd.h>` | 6 |
| `libc.constant` | C type aliases and constants | — |
| `libc.utils` | String/pointer helpers | — |

## Not started yet

`libc.threads` (`<threads.h>`) exports nothing: Apple never shipped C11
threads, so a binding would only ever work on Linux.

`libc.math` has no `long double` variants — no `fabsl`, no `nexttoward` —
because Mojo has no type to pass: on x86-64 the C type is the 80-bit x87
format. `libc.locale` has no `FE_DFL_ENV`, see `fenv_t`.

`libc.sys.epoll`, `libc.sys.prctl`, `libc.sys.sendfile`, `libc.sys.auxv` and
`libc.sys.random` wrap Linux-only calls; importing them on Darwin will not
link.

`libc.stdio` covers the `<stdio.h>` entry points that `libc.file` does not
already own; see the note at the top of `src/libc/stdio/syscalls.mojo`.
`libc.complex` models `double complex` and `float complex` as the two-field
structs the ABI actually passes; `long double complex` is left out because
Mojo has no 80-bit type.

## The six no test asks for

Six of the bindings are never called by a test, and cannot be:

| Call | Why not |
|---|---|
| `libc.file.ioctl` | Variadic: which device it is and what it is asked to do both come after the arguments that can be given. |
| `libc.file.scanf` | Reads from standard input, which a test cannot promise will ever come to an end. |
| `libc.signal.sigsuspend` | Waits for a signal to arrive. A test that waits is a test that stops. |
| `libc.signal.sigwait` | The same. Given a set with nothing in it, glibc waits rather than refusing. |
| `libc.stdio.getchar` | Reads from standard input, as `scanf` does. |
| `libc.unistd.pause` | Waits for a signal. |

None of them is known to be broken; they are simply not asked. A
test that hung, or that ended the process running it, would be
worse than no test at all.

## API reference

Generate the docstring reference for any module with the Mojo toolchain:

```bash
mojo doc src/libc/unistd/syscalls.mojo
```
