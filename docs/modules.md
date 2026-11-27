# Modules

`Symbols` counts the public declarations in each sub-package. Treat a low count
as "only the essentials are wired up"; the one remaining stub is described at
the bottom.

| Module | C header | Symbols |
| --- | --- | --- |
| `libc.math` | `<math.h>` | 124 |
| `libc.stdlib` | `<stdlib.h>` | 97 |
| `libc.float` | `<float.h>` | 30 |
| `libc.limits` | `<limits.h>` the widths of the integer types, and what a process may have | 24 |
| `libc.unistd` | `<unistd.h>` | 232 |
| `libc.file` | `<stdio.h>` file operations | 39 |
| `libc.ctype` | `<ctype.h>` | 30 |
| `libc.sys.socket` | `<sys/socket.h>` | 53 |
| `libc.sys.uio` | `<sys/uio.h>` | 2 |
| `libc.sys.stat` | `<sys/stat.h>` | 72 |
| `libc.sys.times` | `<sys/times.h>` | 2 |
| `libc.time` | `<time.h>` | 42 |
| `libc.fenv` | `<fenv.h>` | 26 |
| `libc.sys.mman` | `<sys/mman.h>` | 19 |
| `libc.sys.sigqueue` | `<signal.h>` a signal sent with a number, and the two waits | 5 |
| `libc.sys.inotify` | `<sys/inotify.h>` watching files for what happens | 24 |
| `libc.sys.eventfd` | `<sys/eventfd.h>` a counter behind a descriptor | 6 |
| `libc.sys.timerfd` | `<sys/timerfd.h>` a timer behind a descriptor | 6 |
| `libc.aio` | `<aio.h>` I/O handed over rather than waited for | 24 |
| `libc.sys.sysinfo` | `<sys/sysinfo.h>` | 18 |
| `libc.sys.timer` | `<time.h>` the timers Darwin does not have | 12 |
| `libc.pthread` | `<pthread.h>` | 123 |
| `libc.threads` | `<threads.h>` Linux only, the C11 threads | 40 |
| `libc.string` | `<string.h>` | 49 |
| `libc.stdio` | `<stdio.h>` output, buffering, pipes | 47 |
| `libc.complex` | `<complex.h>` | 46 |
| `libc.sched` | `<sched.h>` | 17 |
| `libc.signal` | `<signal.h>` an action, and a handler as its number | 69 |
| `libc.spawn` | `<spawn.h>` start a process without fork | 25 |
| `libc.locale` | `<locale.h>` | 23 |
| `libc.sys.epoll` | `<sys/epoll.h>` | 9 |
| `libc.search` | `<search.h>` | 21 |
| `libc.dirent` | `<dirent.h>` | 23 |
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
| `libc.fcntl` | `<fcntl.h>` | 63 |
| `libc.getopt` | `<getopt.h>` taking a command line apart | 12 |
| `libc.dlfcn` | `<dlfcn.h>` | 9 |
| `libc.wchar` | `<wchar.h>` | 99 |
| `libc.wordexp` | `<wordexp.h>` shell-style word splitting | 6 |
| `libc.wctype` | `<wctype.h>` | 5 |
| `libc.uchar` | `<uchar.h>` the UTF-16 and UTF-32 conversions | 4 |
| `libc.sys.statfs` | `<sys/statfs.h>` the kernel's own account of a file system | 15 |
| `libc.sys.mqueue` | `<mqueue.h>` | 10 |
| `libc.sys.memfd` | `<sys/memfd.h>` a file the kernel holds and nothing names | 4 |
| `libc.sys.xattr` | `<sys/xattr.h>` the words a caller keeps with a file | 12 |
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
| `libc.sys.io` | `<sys/io.h>` the ports of the machine | 2 |
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

`libc.sys.epoll`, `libc.sys.prctl`, `libc.sys.sendfile`, `libc.sys.eventfd`, `libc.sys.timerfd`, `libc.sys.memfd`,
`libc.sys.xattr`, `libc.sys.inotify`, `libc.sys.sigqueue`, `libc.sys.timer`, `libc.sys.auxv`,
`libc.sys.uio`,
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

Three bindings are not asked anything, and the reason is about the call rather
than about the suite:

- `ioctl` is variadic, and its third argument is the address that nearly every
  request writes its answer through. `external_call` emits a call whose
  arguments are all in registers, and arm64 hands a variadic callee its
  anonymous arguments on the stack instead: what the callee reads is a slot
  nobody wrote. `FIONREAD` through this binding answers 0 on Apple silicon and
  leaves the integer it was asked about untouched. It is the same wall that
  makes the call that opens a file here be openat rather than open.

It is not known to be broken; it is simply not asked.
- `atexit` and `at_quick_exit` are the sayings of the going, and a just-in-time run
  looks their names up in vain: this machine's C library keeps them in what stands
  beside it and links them from there, which a built form asks and this run cannot.
  The going they say -- quick exit, whose name the library does hand over -- is
  asked, and the sayings are in the package on purpose.

The wide putwchar call used to be on this list, on the reading that a fork only hands a
child the stream the suite has already oriented. That was wrong twice over:
the C library exports its standard output as a variable that the dynamic
loader reaches, and reopening that stream starts it over -- unoriented, and
pointed at whatever descriptor 1 holds. A child that points descriptor 1 at
a pipe, reopens, turns the stream wide, and only then makes the wide write
gets a real wide standard output to write to, and the pipe receives what
the call wrote. The reasons on this page are claims, and claims get tested.

1170 bindings are asked something, and the 3 that are not have a reason.
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
- `timerfd_create` is a timer held as a descriptor -- Linux's own family,
- `sched_getcpu` reads which processor the thread runs on, which is the scheduler's own idea; Darwin has no such call to ask, and its pthread calls keep the answer where they keep the rest of the thread's state.
- `clock_getcpuclockid` and `pthread_getcpuclockid` name the clock that counts one
  process's or one thread's own processor time; Darwin's libSystem declares the calls
  and has no symbol for either.
- `pthread_spin_init`, `pthread_spin_destroy`, `pthread_spin_lock`, `pthread_spin_trylock`
  and `pthread_spin_unlock` are the lock whose wait is spun and not slept; Darwin's
  libSystem has no symbols for the spin family.
- `pthread_setname_np` is the naming again of one thread by the name it is given; Darwin's
  libSystem has a call of the same name that takes only the name -- the naming of the
  thread that asks and no other -- so the thread-taking one is asked where the kernel
  takes the thread as well, and `pthread_getname_np`, which Darwin has, is asked
  on both.
- `malloc_usable_size` is the length one allocation is good for, which is the allocator's own
  word and not a promise -- what one allocator keeps is not what another keeps, and a
  caller that writes the whole of the answer is a caller whose asking is not portable;
  Darwin's libSystem keeps the same word under another name (`malloc_size`), so the
  asking is had where the C library has it.
- `getresuid` and `getresgid` write the three numbers of the user and of the group -- the
  one the process was born with, the one its permissions are read by, and the one it was
  and could be again -- and the third is the kernel's own keeping; Darwin's libSystem has
  no such call to ask.
- `setresuid` and `setresgid` say the three numbers again -- each to what the caller says,
  the word for leave what is there being the biggest number there is, and a number the
  process is not being refused with `EPERM`; Darwin's libSystem has no such call
  to say.
- `personality` is the word of how the kernel presents itself to what the process does -- the
  asking of the biggest number there is says what it is and leaves it, and the saying of
  another word says back the one it replaced; Darwin's libSystem has no such call
  to ask.
- `ioperm` and `iopl` are the word for the ports of the machine, for some of them and for all of
  them at once -- the asking to have the ports is refused with `EPERM` to a process that is
  not allowed to ask, and the asking to give up what it never had is answered with nothing
  done; Darwin's libSystem has no such call to say.
- `atexit` and `at_quick_exit` say what the process is to do when it goes, the one when it
  exits the way an exit is and the other when it goes the quick way, the functions said
  later being called earlier, and `quick_exit` goes the quick way -- the two sayings kept
  apart, a function said to the one not being called by the other. The two sayings are
  asked by no line of this suite: their names are what this machine's C library does not
  hand a just-in-time run to look up.
- `setdomainname` is the saying again of the name of the network domain the machine stands in --
  the NIS domain and not the hostname; a process that is not allowed to say it is refused
  with `EPERM` whatever the name it says, and Darwin's libSystem has no such call
  to say.
- `ptsname_r` says the name of the far end of a pseudo-terminal in the room the caller
  gives rather than where the library keeps it -- the room-given form a thread's own
  asking cannot have another thread's asking overwrite, a room too narrow refused
  with `ERANGE` and the writing all or nothing; Darwin's libSystem has no such
  call to say.
- `twalk_r` is the walk that brings the asker's own word along -- the same
  depth-first passing as `twalk`, every node with children handed over three
  times and a leaf once, with a room the asking itself says handed with every
  node, so a thread's own walk cannot have another thread's walk handing over
  into the same place; Darwin's libSystem has no such call to say.
- `tdestroy` takes the tree apart, every node handed over to the saying the
  asker brings -- the member, which is the key the node points at, coming
  back for the asker to put away -- and the tree that holds nothing coming
  apart without a single handing-over; Darwin's libSystem has no such call
  to say.
- `qsort_r` is the sorting that brings the asker's own word along -- the same
  in-place ordering `qsort` does, with the room the asking itself said handed
  to the comparator as a third argument, so a thread's own sorting cannot have
  another thread's sorting reading the same place; glibc's own word, and
  Darwin's libSystem says another word with the sayings in the other order.
- `malloc_trim` gives the free bytes at the top of what the allocator keeps back
  to the machine, keeping a slack the asking names, and says whether anything
  was given back; `malloc_stats` says how many bytes of the machine's own the
  allocator keeps and how many are in use, into the errors channel, which is
  the channel a caller can point at another room for; and `malloc_info` says
  the whole of what the allocator keeps in the XML saying the machine's own
  tools read, into the stream the caller opens. All three are glibc's own
  words; Darwin's libSystem has no such call to say.
- `canonicalize_file_name` is the canonical saying of a path, the way
  `realpath` says it with a room the caller gives, kept in a room of its own
  that the caller puts away with `free` -- a symlink and a `.` on the way
  said as what they really are, and a place that is not there refused with
  nothing coming back and `errno` saying why; glibc's own word, and Darwin's
  libSystem has no such call to say.
- `sync_file_range` is the seeing-to of the middle of a file's bytes -- wait
  for the writing already asked for, ask for the writing, and wait for the
  writing this asking made, all three together being what `fdatasync` does
  of the middle of a file without the metadata a caller may not be waiting
  for; Linux's own word, and Darwin has no call that takes it.
- `execveat` is what `execve` does of a path, said by way of a directory
  descriptor -- the saying looked for in the directory `fd` opens, or, with
  `AT_EMPTY_PATH` and an empty saying, in the very file `fd` itself opens;
  Linux's own word, and Darwin has no call that takes it.
- `fsetxattr`, `fgetxattr`, `flistxattr` and `fremovexattr` are the words a
  caller keeps with a file, under names of the caller's own -- a word kept,
  taken back the same, counted, read by its size alone, and let go, after
  which asking for it is refused the way it would be if it had never been
  kept. All four are Linux's own words; Darwin answers different words with
  the sayings in the other order.
- The path sayings of the same -- `setxattr`, `getxattr`, `listxattr` and
  `removexattr`, each by way of a path whose symlinks are followed, and
  `lsetxattr`, `lgetxattr`, `llistxattr` and `lremovexattr`, each by way of
  a path whose symlinks are not. The kernel keeps none of the caller's kind
  on a link itself, so the sayings that ask the link answer with nothing
  and `errno` saying why.
- `fexecve` is what `execve` does of a path, said by way of the very file
  itself, with no path at all -- the program is the file `fd` opens, which
  is the way a program that cannot trust the directories on the way says
  itself. What the asking of one that works says is the same as `execveat`
  with `AT_EMPTY_PATH` and an empty saying, spelled without the word that
  carries it; Linux links it from what a just-in-time run looks words up
  in, and Darwin's libSystem keeps no such symbol to look up.
- `getpt` is a pseudo-terminal master, given out with no saying at all --
  what `posix_openpt` does of the flag word, said without one, the kernel
  taking the flags it likes and leaving the caller with what it gives: a
  descriptor that does not close itself when a program is said. The word
  is GNU's own, and Darwin has no call that says it.
- `execvpe` is what `execvp` does of a file said with no path, looked for
  in the directories the PATH keeps, said with the caller's own room of
  names -- the program the file becomes is told what the caller says, not
  what the shell around it keeps. The word is GNU's own, and Darwin has
  no call that says it.
- `name_to_handle_at` and `open_by_handle_at` are a handle said of a file,
  kept by the filesystem itself -- not a saying the caller makes, but the
  filesystem's own name of the file, as long as the filesystem says; a
  room too small is refused with the size said where the answer will fit,
  and the file said back by the handle alone is the cap the kernel keeps
  for the privileged. Both are Linux's own words, and Darwin has no call
  that takes either.
- `syncfs` is what `sync` does of every file at once, said of one -- the
  writing the file `fd` opens waits for is waited for, all of it, the
  whole mount the file lives on. The word is GNU's own, and Darwin has
  no call that says it.
- `strverscmp` is what `strcmp` does of letters, said of the numbers
  inside: a run of digits is said as the number it is, not as the
  letters it is made of, so that versions sort the way versions do. What
  a difference is made of is not said -- only which side of zero it
  falls on. The word is GNU's own, and Darwin has no call that says it.
- `setfsuid` and `setfsgid` say who the file-keeping is said as -- the
  user and the group the kernel checks a file's keeping against when a
  file is opened, kept beside the asking's own. Said with nothing -- a
  -1 -- they only say who it is; said with who it already is, the
  answer is who it was. Nothing they refuse is said as a refusal.
  Both words are GNU's own, and Darwin has no call that says either.
- `chroot` is where / begins, said again -- the directory the saying
  says becomes the asking's own root, and everything said after is
  looked for under it, whatever stands above being no longer part of
  the view. What the asking has open stays open, which is what a jail
  is careful about. Both platforms say it.
- `sethostname` is who the machine says it is, said again -- the name
  the asking of a host comes back with is what the saying makes it.
  Who may say it is the kernel's own keeping; a caller without it is
  refused with `errno` saying so, and the name is what it was. Both
  platforms say it.
- `get_current_dir_name` is what the asking's own room of names is said
  as now -- the way `getcwd` says it, with the room made for the saying
  and handed back, which is the asking's to take back with `free`. The
  word is GNU's own, and Darwin has no call that says it.
- `sigset` is what standing before the saying was, coming back as the
  answer: the action said for a signal is what the saying makes it, and
  the answer is the action that was there. Said again, the answer is
  what the last saying left. The word is System V's own, and Darwin has
  no call that says it.
- `getdents64` is what a directory keeps, read raw: the room the asking
  gives is filled with the saying the directory keeps itself, entry after
  entry, each with the length that takes the asking to the next -- which
  the asking walks and proves comes out even. The word is Linux's own,
  and Darwin has no call that says it.
- `siggetmask` is what stands between the asking and the saying, as a
  word: the blocked set said in the one machine word the old sayings
  trade in, with one bit for each signal. `sigprocmask` is what to say
  now; this is the word the old sayings keep saying.
- `sethostid` is what the asking says it is, as a number, said again:
  the saying is written where the asking of it later reads, and who may
  say it is the tree's own keeping. Said back where it was, the number
  is what it was either way. The word is Linux's own, and Darwin has no
  call that says it.
- `pipe2` is a pipe made with its flag word applied as it is
  made -- close-on-exec and non-blocking set before the
  descriptors exist to be raced for, which is the kernel's own
  speedup of what a caller sets with `fcntl` afterwards, and
  Darwin has no call that takes the word.
  of which eventfd's counter is the other half, and Darwin answers the same
  need with kqueue, which is a different call with different answers.

Linux asks 66 bindings that Darwin passes over, and Darwin 0 that Linux
passes over. Both numbers are read back out of this page too, and so is
every call named here: the page fails the run when a binding goes
one-platform without a reason, and when one of these starts being asked
without a guard, which is the list being paid.
