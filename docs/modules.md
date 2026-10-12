# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the stub packages export nothing yet and
are listed at the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 126 |
| `libc.unistd` | `<unistd.h>` | 43 |
| `libc.file` | `<stdio.h>` file operations | 39 |
| `libc.ctype` | `<ctype.h>` | 29 |
| `libc.sys.socket` | `<sys/socket.h>` | 19 |
| `libc.sys.stat` | `<sys/stat.h>` | 17 |
| `libc.time` | `<time.h>` | 16 |
| `libc.fenv` | `<fenv.h>` | 16 |
| `libc.sys.mman` | `<sys/mman.h>` | 15 |
| `libc.pthread` | `<pthread.h>` | 14 |
| `libc.string` | `<string.h>` | 13 |
| `libc.sched` | `<sched.h>` | 13 |
| `libc.signal` | `<signal.h>` | 10 |
| `libc.locale` | `<locale.h>` | 10 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 8 |
| `libc.search` | `<search.h>` | 8 |
| `libc.dirent` | `<dirent.h>` | 6 |
| `libc.sys.wait` | `<sys/wait.h>` | 5 |
| `libc.inttypes` | `<inttypes.h>` | 5 |
| `libc.sys.resource` | `<sys/resource.h>` | 4 |
| `libc.network` | `<arpa/inet.h>` byte order helpers | 4 |
| `libc.logging` | `<syslog.h>` | 4 |
| `libc.fcntl` | `<fcntl.h>` | 4 |
| `libc.dlfcn` | `<dlfcn.h>` | 4 |
| `libc.wchar` | `<wchar.h>` | 2 |
| `libc.sys.statvfs` | `<sys/statvfs.h>` | 2 |
| `libc.sys.select` | `<sys/select.h>` | 2 |
| `libc.setjmp` | `<setjmp.h>` | 2 |
| `libc.sys.utsname` | `<sys/utsname.h>` | 1 |
| `libc.sys.sendfile` | `<sys/sendfile.h>` | 1 |
| `libc.sys.random` | `<sys/random.h>` | 1 |
| `libc.sys.prctl` | `<sys/prctl.h>` | 1 |
| `libc.sys.auxv` | `<sys/auxv.h>` | 1 |
| `libc.gpu` | GPU/CUDA driver entry points | 1 |
| `libc.errno` | `<errno.h>` | 1 |
| `libc.constant` | C type aliases and constants | — |
| `libc.utils` | String/pointer helpers | — |

## Not started yet

These sub-packages exist but export nothing:

| Module | C header |
| --- | --- |
| `libc.stdio` | `<stdio.h>` |
| `libc.stdlib` | `<stdlib.h>` |
| `libc.complex` | `<complex.h>` |
| `libc.float` | `<float.h>` |
| `libc.threads` | `<threads.h>` |

## API reference

Generate the docstring reference for any module with the Mojo toolchain:

```bash
mojo doc src/libc/unistd/syscalls.mojo
```
