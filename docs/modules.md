# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 115 |
| `libc.stdlib` | `<stdlib.h>` | 45 |
| `libc.float` | `<float.h>` | 30 |
| `libc.unistd` | `<unistd.h>` | 64 |
| `libc.file` | `<stdio.h>` file operations | 40 |
| `libc.ctype` | `<ctype.h>` | 29 |
| `libc.sys.socket` | `<sys/socket.h>` | 23 |
| `libc.sys.stat` | `<sys/stat.h>` | 18 |
| `libc.time` | `<time.h>` | 30 |
| `libc.fenv` | `<fenv.h>` | 26 |
| `libc.sys.mman` | `<sys/mman.h>` | 15 |
| `libc.pthread` | `<pthread.h>` | 14 |
| `libc.string` | `<string.h>` | 39 |
| `libc.stdio` | `<stdio.h>` output, buffering, pipes | 27 |
| `libc.complex` | `<complex.h>` | 46 |
| `libc.sched` | `<sched.h>` | 16 |
| `libc.signal` | `<signal.h>` | 40 |
| `libc.locale` | `<locale.h>` | 16 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 8 |
| `libc.search` | `<search.h>` | 9 |
| `libc.dirent` | `<dirent.h>` | 12 |
| `libc.sys.wait` | `<sys/wait.h>` | 14 |
| `libc.inttypes` | `<inttypes.h>` | 7 |
| `libc.sys.resource` | `<sys/resource.h>` | 13 |
| `libc.network` | `<arpa/inet.h>` byte order helpers | 4 |
| `libc.logging` | `<syslog.h>` | 4 |
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
| `libc.sys.auxv` | `<sys/auxv.h>` | 1 |
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

## API reference

Generate the docstring reference for any module with the Mojo toolchain:

```bash
mojo doc src/libc/unistd/syscalls.mojo
```
