# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **The `_SC_*` knobs are bound in `libc.unistd`, eighty of them.**
  `sysconf` took a knob number and this package named exactly one,
  `SC_PAGESIZE`, so a caller asking about anything else had to write a
  number down. The audit that found the `_PC_*` numbering was shifted
  found a worse problem here: of the eighty knobs both platforms have,
  **every one is numbered differently on each**. glibc counts them from
  0 in POSIX order and XNU from 1 in an order of its own, so
  `_SC_ARG_MAX` is 0 here and 1 there, `_SC_PAGESIZE` 30 and 29, and
  `_SC_NPROCESSORS_ONLN` 84 and 58. All eighty are bound in the
  `X if is_macos() else Y` form the other platform constants use, so
  `check-constants` verifies the side that answers on each machine.
  `_SC_AVPHYS_PAGES` is left out because glibc has it and XNU does not.
  `libc.unistd` goes from 79 to 158.
- **`confstr` is bound, with the twenty-five `_CS_*` variables both
  platforms have.** The third of the three numbered-knob APIs and the
  same finding as the other two: all twenty-five are numbered
  differently, `_CS_PATH` being 0 here and 1 there. `confstr` itself was
  not bound at all, which is why nothing named them. The variables only
  one side answers are left out rather than faked — `_CS_GNU_LIBC_VERSION`,
  `_CS_GNU_LIBPTHREAD_VERSION` and the `_CS_LFS_*` are glibc's,
  `_CS_DARWIN_USER_*` are XNU's. `libc.unistd` goes to 184.
- **`libc.netdb` is new: `getaddrinfo`, `freeaddrinfo`, `gai_strerror`,
  the `addrinfo` they fill in, and the `AI_*` and `EAI_*` that go with
  them.** This is the call that turns a host and a service into the
  addresses a socket could be pointed at, and the one gap left in the
  audit that needed a name lookup rather than arithmetic. Two things
  about it are worth knowing. The ten `EAI_*` are negative on glibc and
  positive on XNU and **not one of them agrees across the platforms**,
  `EAI_SYSTEM` included, which is -11 here and 11 there; they are named
  rather than written down for that reason. And the two platforms
  disagree about where `ai_addr` and `ai_canonname` sit: POSIX puts the
  address first, glibc follows it, and Darwin does not, its canonical
  name being at 24 and its address at 32. Those two are therefore read by
  method at the offset of whoever is compiling, while the five ints in
  front of them stay fields at the offsets both agree on. `libc.netdb`
  starts at 21.

## [0.12.0] - 2026-10-19

### Added

- **The `_PC_*` knobs are bound in `libc.unistd`.** `pathconf` and
  `fpathconf` take a knob number, and the numbers are not the same on
  both sides: glibc numbers the list from 0 and XNU from 1, so the nine
  POSIX ones are shifted one along on Darwin and the optional ones are
  scattered further apart (`_PC_SYNC_IO` is 9 here and 25 there,
  `_PC_SYMLINK_MAX` 19 and 24). Without them a caller has to write the
  Linux number down and gets `EINVAL` and -1 on Darwin for every one of
  them. C spells them with a leading underscore, which makes a name
  private to a Mojo module, so they are `PC_LINK_MAX` and so on, the way
  `SC_PAGESIZE` already is. `libc.unistd` goes from 65 to 79.
- `libc.sys.wait` is exercised by `test_wait`: a forked child leaves
  with a status of its own choosing, and `waitpid` and `wait4` each
  take it back, the latter also saying what the child used. The
  pair was already wired in; the tests are why this row is here at
  all.
- `test_setjmp` is the only test for `libc.setjmp`. It asks for a
  `setjmp` to return 0 the first time and 42 the second, the only
  way to know `longjmp` is doing what it says. The first return is
  0, the second is 42; the hang that would happen if `longjmp` did
  not jump back is the other thing the test runs under a timeout.
- `test_inttypes` covers `imaxdiv` with all four sign combinations
  of numerator and denominator, the 7/1 edge, and the 0/5 edge. The
  quotient is truncated toward zero — `-10 / 3` is `-3` with `-1`
  left over, not `-4` with `2`, the way a floor division would have
  it.
- `test_resource` reads a limit with `getrlimit` and asks
  `setrlimit` to set it to what it already is, which is the only
  way to call `setrlimit` that cannot fail. `prlimit` is then asked
  to read the same limit for this process (pid 0), and the two
  readings agree. The test exists because `Rlimit` is a struct
  passed by pointer and the wrong struct would have looked right
  at every step until the values were checked.
- `test_fenv` asks `feenableexcept` to trap a floating-point
  exception and `fedisableexcept` to put the flag back, and reads
  `fegetexcept` between the two. `FE_INVALID` is the one asked
  for; whatever was there before is restored at the end, so a
  trap left on would not end the test program the next time
  division by zero happened anywhere in it.
- `test_logging` asks `syslog` to write a message and the system
  log daemon to keep it, with the `LOG_PID` and `LOG_CONS` flags
  set. `setlogmask` is asked to filter everything above a level
  out, and the level is restored at the end.
- `test_mman` is a `mlock` and `munlock` round trip on a 4 KiB
  buffer, which is the smallest `mlock` is willing to count. The
  call is wrapped in a `comptime if not is_macos` because the
  call is Linux-specific; the same goes for `mlock2` and
  `remap_file_pages`, which have no test there.

### Changed

- **`struct timespec` has one definition again.** `libc.time`, `libc.sched`,
  `libc.sys.stat` and `libc.sys.epoll` each declared their own, with the
  same two 64-bit fields, so the bindings worked on both platforms — but
  Mojo treats each as a distinct type, and a `c_ptr[libc.time.timespec]`
  would not convert to a `c_ptr[libc.sched.timespec]` even though both
  describe the same memory. `libc.time.timespec` is the one that stays;
  the other three import it, the way `libc.poll` and `libc.sys.select`
  already did. The counts in `docs/modules.md` drop by three, since only
  the owner still declares the struct.
- **Five Linux-only bindings are now in `KNOWN_MISSING`.** `epoll_create`,
  `epoll_create1`, `getrandom`, `mlock2` and `prctl` each have a
  man page that says it is Linux-specific on its first line, and
  the other side has nothing to call. They were each given a `Notes:`
  segment in the docstring saying so (`prctl` already had one).
  Darwin's check-symbols would have reported all five as missing,
  which was the right answer for the wrong reason, and would have
  lost a CI run on a no-op.
- `check-symbols` looks for `external_call["X"` on a single line,
  which left multi-line calls — `ppoll`, `remap_file_pages`,
  `pselect`, `readv`, `writev` — uncounted. They are counted now,
  and `ppoll` and `remap_file_pages` were the two that were
  Linux-specific. They join the others in `KNOWN_MISSING`.

### Fixed

- **`Stat` reads its members from the wrong slots on Darwin.** Four
  members came back wrong on the macOS runner — `nlink` and `mode`
  answered zero, and `size`, `blocks` and `mtime` came from the
  wrong place. The offsets had been written from the field order of
  the pre-`_DARWIN_FEATURE_64_BIT_INODE` struct and only three
  `timespec`, when what `stat()` fills on a 64-bit process has
  `st_mode` and `st_nlink` ahead of a 64-bit `st_ino` and **four**
  `timespec` — access, modify, status change, and birth. That
  fourth one is what puts `st_size` at offset 96 rather than the 80
  it was read from. The layout is read from XNU's `bsd/sys/stat.h`
  with the widths from `bsd/sys/_types.h`, laid out in C to get the
  offsets, and cross-checked against the `stat(2)` man page; every
  member moves as a result.
- `RLIMIT_NOFILE` and `RLIMIT_AS` are set per platform. They are
  7 and 9 on Linux and 8 and 5 on Darwin, and the bindings had
  been written with the Linux numbers, which on macOS a caller
  reading a limit would have asked `getrlimit` for the wrong
  resource by name.
- `SYS_getpid` is 39 on Linux and 20 on Darwin. It was 39 on both
  sides, which on macOS would have been a number the kernel
  never uses.
- `test_resource` asked `setpriority` for 25 and asserted the value
  read back the same as what 19 left it — true on Linux, whose
  nice ceiling is 19, false on Darwin's 20. It asks for a value
  past either ceiling now and asserts only that the clamping kept
  it where the previous setting left it.
- `epoll_event.__init__(events, data)` had an `Args:` header one
  level too deep and a `Notes:` block written twice.
- `check-prototypes` had a wrong note about `sched_getcpucount`:
  glibc keeps it internal, neither declared nor exported, and
  the binding can be checked by the prototype alone, never by
  the symbol table.
- **Three structs were too short for what Darwin writes into them.**
  `check-layouts` had never run to completion on the macOS runner —
  the test suite failed first, every time, so the step after it was
  never reached. With the suite passing it ran for the first time and
  found three. `dirent` was 280 bytes, glibc's size, where Darwin's is
  1048; the comment already knew the record was the wider one and
  argued that being short was safe because `readdir` hands back a
  pointer into a record libc owns, which holds for reading through one
  and not for anything that copies one. `sched_param` was one `int`
  where Darwin's is two words, and `sched_getparam` writes both.
  `mbstate_t` was 32 bytes where Darwin's is 128, and `mbrtowc`,
  `wcrtomb` and `mbrlen` all write through the pointer they are handed.
  Each now holds its platform's own size. `sched_param` takes the shape
  `Stat` already has — one opaque block, the priority read off the
  front — because a struct with two named fields has to be exactly C's
  size, and one that is 8 on a platform and 4 on the other cannot be
  two named fields. The priority moves from a field to a method for
  that reason.
- **A file created with `O_CREAT` on Darwin carries no permissions.**
  `open`'s mode argument is variadic and does not arrive on arm64, so
  the file it leaves behind has mode 0, and any later call that needs a
  permission on the file by name answers `EACCES`. The Ubuntu runner is
  root and cannot see it; the macOS one is not. `test_the_times` held
  the descriptor it was created with instead of closing and reopening
  it for `futimens`, and `test_truncate_takes_a_path` sets the
  permissions with `fchmod` — which is not variadic, so the mode
  arrives — before the path is used.
- `test_fpathconf` asked `_PC_LINK_MAX` of a directory, which Linux
  answers 65000 for and Darwin -1 for. That -1 is not a failure: the
  Darwin man page allows an implementation to have no limit for a
  variable it is asked about, and says so with -1 and `errno` untouched.
  The test asks `PC_PIPE_BUF` of a pipe now, which is the one kind of
  descriptor where the answer is not left to the filesystem — XNU
  answers `PIPE_BUF` for a pipe without consulting anything else, and
  glibc's is a constant too. The two differ, 512 there and 4096 here,
  so what is asserted is that the call answers with a plausible block
  size.

## [0.11.0] - 2026-10-13

### Added

- `libc.fcntl` binds `F_SETFL` and `O_NONBLOCK`, and a three-argument
  `fcntl` to go with them. C's is variadic and `external_call` wants each
  type written out, so it is the int-argument form that is bound, which
  covers `F_SETFL`, `F_GETFL` and the commands that set a descriptor; a
  command that wants a pointer or a lock has nothing here to give it one,
  and the docstring says so. `F_SETFL` is 4 on both platforms and
  `O_NONBLOCK` is 2048 here and 4 on Darwin.

### Changed

- **Breaking.** `msghdr.msg_namelen` is `UInt32` now, which is what a
  `socklen_t` is on both platforms. It was `UInt16`, and the struct was
  56 bytes either way — the padding after the field swallows the
  difference — so nothing said a word while `recvmsg` wrote four bytes
  there and a 16-bit field read the low half of them.

### Fixed

- **The errno constants are set per platform now.** They were written as
  plain numbers, which are Linux's, and the numbering parts company with
  Darwin's for good from 35 up: `EAGAIN` is 11 here and 35 there,
  `EINPROGRESS` 115 and 36, `ENAMETOOLONG` 36 and 63, `ETIMEDOUT` 110
  and 60, and the socket errors numbered 88 to 113 here are 38 to 61
  there. Fifty-six of them differed, so on macOS forty-five answered
  with a number libc will never use, and a caller checking
  `errno == EAGAIN` against a failure that really is EAGAIN got a false
  negative. The Linux side was verified against errno.h with `gcc -dM`
  — all 134 of them, names and values both — and the Darwin side is
  taken from XNU's bsd/sys/errno.h. Forty-six are Linux's own, `ERFKILL`
  and `EHWPOISON` among them, and are left as they were.
- `EWOULDBLOCK` is set per platform along with `EAGAIN`, being its alias
  on both.

## [0.10.0] - 2026-10-13

### Added

- Seventy-three constants the docstrings were already using while the
  package had no way to name them:
  - `libc.signal`: the seventeen signal numbers, `SIG_DFL`, `SIG_IGN`,
    `SIG_ERR`, `SIG_BLOCK`, `SIG_UNBLOCK`, `SIG_SETMASK` and `SIGSTKSZ`.
    Linux and Darwin agree as far as SIGTRAP and part company after it,
    so the ones that differ are set per platform: `SIGBUS` is 7 here and
    10 there, `SIGUSR1` 10 and 30, `SIGCHLD` 17 and 20, and `SIGSTOP`
    and `SIGCONT` trade places.
  - `libc.sys.prctl`: the eighteen `PR_*` options, all Linux's own —
    there is no `<sys/prctl.h>` on Darwin, so nothing there needs them.
  - `libc.stdlib`: `RAND_MAX`, `LONG_MAX`, `LONG_MIN`, `ULONG_MAX`,
    `ULLONG_MAX`, `HUGE_VAL`, `HUGE_VALF` and `PATH_MAX`. The two
    `HUGE_*` are infinity, written as a literal past what a float can
    hold, which is the nearest Mojo has to a spelling for one.
  - `libc.fcntl`: `F_ULOCK`, `F_LOCK`, `F_TLOCK` and `F_TEST`, with
    `O_TMPFILE` — Linux's own, and glibc only says so under
    `_GNU_SOURCE`.
  - `libc.dlfcn`: `RTLD_LAZY`, `RTLD_NOW` and `RTLD_GLOBAL`, the last of
    which is 256 here and 8 there.
  - `libc.sys.wait`: `WNOHANG`, `WUNTRACED` and `WCONTINUED`, the last
    of which is 8 here and 16 there.
  - `libc.sys.resource`: `RUSAGE_SELF` and `RUSAGE_CHILDREN`.
  - `libc.sys.socket`: `SOCK_NONBLOCK` and `SOCK_CLOEXEC`, which differ
    on both platforms.
  - `libc.sched`: `SCHED_OTHER`, `SCHED_FIFO` and `SCHED_RR`, which are
    the same number on both.
  - `libc.time`: `CLOCKS_PER_SEC`.
  - `libc.unistd`: `SC_PAGESIZE`, which is C's `_SC_PAGESIZE` without the
    leading underscore, an underscore making a name private to a Mojo
    module. 30 here and 29 there.
  - `libc.sys.random`: `GRND_INSECURE`, Linux's own.

  The Linux values were read out of the headers with a C program rather
  than remembered, which is how two of them came to be right: `PR_GET_TSC`
  is 25 and `PR_GET_SECUREBITS` 27, and neither was where the old list
  had them.

### Fixed

- `libc.unistd`: `getpagesize`'s description said to ask `sysconf` for
  `_SC_PAGESIZE`, which is advice about a number that was not here.

## [0.9.0] - 2026-10-13

### Changed

- **Breaking.** `libc.sched.timespec.tv_sec` is 64 bits wide now, which is
  what C's is and what the three other `struct timespec` in this package
  already wrote. It was `Int32`, and the size came out 16 either way, the
  padding hiding it, which is why nothing said a word: what C writes
  there is eight bytes and a 32-bit field reads the low half of them, so
  a second past 2038 would have come back as whatever its low 32 bits
  are. It has a constructor now, as those do, and the layout test holds
  the width of the field and not only the size of the struct.

### Fixed

- Most of this one is what the docstrings said, which in four packages
  was not so:
  - `libc.sched`: `sched_getscheduler` described a `param` argument it
    has not got, and said the answer came back in it; it and
    `sched_rr_get_interval` said the answer is written into an argument,
    where both answer 0 or -1 themselves; two of them said `sched_param`
    has a `sched_slice` field, which it does not have on Linux or
    anywhere else; `sched_setaffinity` said a null `cpuset` clears the
    affinity, where Linux answers `EFAULT`. The four that take a policy
    say which number each one is, no `SCHED_*` being bound, and the two
    that take a CPU set say the bits are the caller's to set, there being
    no `CPU_*` macros here either.
  - `libc.signal`: nine said nothing about what they are given and eight
    nothing about what comes back. They say now that a handler is a C
    function pointer and Mojo cannot make one, so `signal`, `sigaction`
    and `sigaltstack` cannot be given a handler of one's own, and that
    there is no `struct sigaction` and no `stack_t` here either, so what
    goes in those arguments is bytes. A `sigset_t` is only a block with a
    bit per signal, so the four that take one can be had as they stand.
  - `libc.utils`: `string_to_char_ptr` said it takes ASCII, where it
    copies the UTF-8 bytes across as they are, and `char_ptr_to_string`
    said nothing about borrowing the buffer it measures rather than
    copying out of it, nor about what a buffer that is not UTF-8 gives.
  - `libc.sys.prctl`: the list of options had `PR_SET_TSC` in it four
    times and two of the numbers wrong; it names each one once now, gives
    the numbers the header has, and says `prctl` is Linux's own and does
    not link on Darwin.
- `libc.dirent`: `opendir` and `readdir` had nothing written down at all,
  which is odd beside the four added around them. `readdir` now says that
  a null from it is one answer to two questions, the end of the stream and
  something gone wrong, and `errno` is not cleared on the way out, so the
  two cannot be told apart unless it is cleared first.
- `libc.ctype`: `toascii` was the last of the twenty-nine with no
  docstring. It masks off all but the low seven bits and asks nothing
  about what is left, so 255 comes back as 127.

## [0.8.0] - 2026-10-13

### Added

- `libc.unistd` binds the ids and the calls that wait: `getgid`, `getegid`,
  `setuid`, `setgid`, `seteuid`, `setegid`, `chown`, `fchown`, `lchown`,
  `fchownat`, `alarm`, `pause`, `sleep`, `nice` and `getpagesize`.
  `getuid` and `geteuid` were here already and `getgid` and `getegid` were
  not, which is the pair asked for the more often of the two.
- `libc.string` binds `strncat`, `stpcpy`, `stpncpy`, `strsep`, `memmem`,
  `ffs`, `ffsl` and `ffsll`.
- `libc.stdlib` binds `random`, `srandom`, `initstate`, `setstate` and
  `getsubopt`.
- `libc.stdio` binds the stream lock — `flockfile`, `ftrylockfile`,
  `funlockfile` — and with it `getw`, `putw` and `renameat`.
- `libc.dirent` binds `telldir`, `seekdir`, `rewinddir` and `fdopendir`.
  `telldir` answers a position within the directory and not a number of
  bytes, so it means nothing to `lseek`; `rewinddir` also forgets about
  entries added since the stream was opened, so a later `readdir` can show
  them; `fdopendir` takes over a descriptor, and `closedir` closes it from
  then on.
- `libc.fcntl` binds `lockf`, which is not Linux-only the way
  `posix_fadvise` and `posix_fallocate` are.
- `libc.file` binds `getdelim`, of which `getline` is a special case.
- `libc.utils` says how to hand C a NULL, which is `null_ptr[T]()`, and how
  to ask whether a pointer it handed back is one. A `Pointer` cannot be null
  in Mojo and a literal 0 is turned away, so it is the address that goes
  into one.

### Changed

- **Breaking.** Thirty-one bindings answered in a type that could not hold
  the answer, or took one too narrow to ask with. In three groups:
  - Answered in an unsigned or a short type where C answers with a count
    that can be -1: `getline`, which was `c_uint` and is `c_ssize_t`;
    `pread` and `pwrite` in both `libc.file` and `libc.unistd`; `getrandom`,
    which was `UInt64`; `readlink`, `readlinkat`, `writev` and `syscall`.
  - Took a size or an offset too narrow to be one. `fread`, `pread` and
    `pwrite` take `c_size_t` and a 64-bit offset, where they took `c_uint`
    and, in `libc.unistd`, an `Int8`: that asked for at most 127 bytes from
    an offset of at most 127. `fmemopen` and `snprintf` take `c_size_t`;
    `ioctl` takes its request as `c_ulong`; `mknod` and `mknodat` take the
    device as `UInt64`; `sched_getaffinity` and `sched_setaffinity`,
    `pthread_attr_getguardsize` and `pthread_attr_setguardsize`, `getcwd`
    and `swab` take a `UInt64` or an `Int64` where they took an `Int32`.
  - Had the wrong signature outright. `dlerror` took an argument C's does
    not and answered with an `Int32` where C answers with the message;
    `dlopen` and `dlsym` were missing their second argument; `remquo` and
    `remquof` take a pointer for the quotient, and a null pointer is allowed
    there; `nan` and `nanf` take a string, not a byte; `accept4` was missing
    its flags; `fdimf` took and answered `Float64`, which is `fdim`'s;
    `getcwd` answers with the buffer it was given; `swab` answers nothing.
- **Breaking.** `printf` takes only the format now. It took `*args` and
  passed the pack along, and `external_call` wants the type of each argument
  written out, which a pack has no way to give, so every call to it failed
  to compile. A conversion therefore needs arguments and there are none to
  give it, and a bare `%` is the start of one. The same is true of
  `dprintf`, `sprintf` and `snprintf`, which cannot write a conversion, and
  of `scanf`, `fscanf` and `sscanf`, which cannot read one, there being
  nowhere to put what it reads.
- The prototype check in CI knows about width now, and not only about kind:
  an `Int32` where C takes an `off_t` was passing it, and so was a signed
  type where C takes an unsigned one of the same size. It also compares how
  many types a binding writes in `external_call[...]` against how many
  arguments it hands over, which is how twenty-seven here were found to have
  been declaring none at all.

### Fixed

- `libc.ctype` had sixteen bindings and `libc.string` had ten that told
  `external_call` only their return type while handing it one or two
  arguments. Nothing notices while the argument is an integer or a pointer,
  which is why they have been working; it is not the call that was meant.
- `mempcopy` called `mempcopy`, and C's name is `mempcpy`.
- `AT_FDCWD` is -2 on Darwin, not -100.
- `nice` answers with the niceness the process came to on Linux, and with 0
  for success or -1 for failure on Darwin, so a 0 from Darwin is not a
  niceness of 0. The docstring says which is which.
- `rewinddir` does not promise the same number of entries back.

## [0.7.0] - 2026-10-12

### Added

- `libc.fenv` binds all eleven functions C99 puts in `<fenv.h>`, plus
  `feenableexcept`, `fedisableexcept` and `fegetexcept`, plus the `FE_*`
  macros. Twelve of them were declared as taking no arguments and had no
  body; two of those were not functions C has.
- `libc.locale` binds `struct lconv`, so `localeconv` now returns something
  you can read.

### Fixed

- A function's name and the symbol it calls were checked against every
  prototype in the headers. `fabs` called `fabsl`, `fmod` called `fmodl`,
  `erf` called `erff` — which made `erf(1.0)` return 1.0 instead of 0.8427 —
  `fdimf` called `fdim`, `fmaxl` called `fmal`, `fgetc` called `fgets`, five
  `is*_l` calls dropped the `_l`, and `Kill` was a second copy of `kill`.
- Every `is*_l` and `to*_l` needs the locale as a second argument and was
  passing only the character; `atan2` and `atan2f` need two arguments;
  `fchmodat` needs a flags; `listen` declared no argument types at all.
- `localeconv` was declared as taking a locale object, and C's takes nothing.
  `freelocale` is `void` and was declared as returning a byte.
- `locale_t` was a struct holding a pointer to six zero-byte objects that
  `Locale.__init__` allocated for an object libc owns and hands out itself.

### Removed

- `truncateat`, which C does not have (`truncate` was already there).
- `environ`, a global variable rather than a function: calling it runs data.
- The `long double` variants in `libc.math`, which Mojo cannot pass an
  argument to on x86-64.

### Changed

- **Breaking.** `locale_t` is `c_ptr[Locale]` now, which is what C means by
  it, and makes `null_ptr[Locale]()` usable for `newlocale` and `uselocale`.
- **Breaking.** `LC_*` and the `FE_*` rounding modes are set per platform,
  because glibc numbers the categories from `LC_CTYPE` and Darwin from
  `LC_ALL`, and arm64 keeps the rounding mode in FPCR bits where x86 keeps it
  in the x87 control word.

## [0.6.0] - 2026-10-12

### Added

- `libc.sys.utsname`: `uname` over a `Utsname`. It used to be declared as
  taking no argument and returning a pointer, which is not what
  `int uname(struct utsname *)` does.
- `libc.sys.select`: `fd_set` with `FD_ZERO`, `FD_SET`, `FD_CLR`, `FD_ISSET`,
  plus `pselect`. The sets used to be opaque pointers, so there was no way to
  put a descriptor in one.
- `libc.sys.statvfs`: a `Statvfs` struct for `statvfs` and `fstatvfs` to fill,
  which used to take a byte pointer. Its block and inode counts are 64-bit on
  Linux and 32-bit on Darwin, so they are read at the width that fits.
- `libc.errno.set_errno` and `libc.sys.resource.getrusage`.

### Fixed

- Five structs were smaller than their C counterpart, and every one is an out
  parameter, so libc wrote past the end of them: `struct stat` (44 modelled,
  144 real), `struct rusage` and `epoll_event` (both empty), `struct rlimit`
  (8 modelled, 16 real), `pthread_attr_t` (32 modelled, 56 on glibc).
- `timespec` and `timeval` held a 32-bit `tv_sec`, so every second count read
  wrong. Same mistake in `st_blksize`: 32-bit on Darwin, read as 64.
- `wait4` ignored its `rusage` argument and called `waitpid` instead.
- `pthread_attr_init`, `pthread_attr_destroy` and `pthread_attr_getdetachstate`
  took the attribute object by value; C takes it by address.
- `longjmp` declared a return value that C's does not have.
- `read` and `write` in `libc.unistd` and `libc.file` declared `read` and
  `write` with different signatures than the ones std declares, and two
  external calls for one C symbol do not lower together: any program that
  printed while calling them failed to compile.
- 191 declarations spelled `char *` as `c_ptr[Int8]` while `libc.utils` spells
  it `c_ptr[UInt8]`, so the two halves of the package did not fit together.

### Changed

- **Breaking.** `Stat`'s fields are now methods (`size()`, `mode()`, `mtime()`,
  ...) because glibc and Darwin order `struct stat` differently. The opaque
  `pthread_attr_t`, `pthread_condattr_t` and `epoll_event` likewise hand their
  contents back through methods.

### Removed

- `libc.gpu`: one function whose body was `pass`.
- `wait4Impl`, which called `wait4` and nothing else.

## [0.5.0] - 2026-10-12

### Added

- `libc.search` stops being a set of empty stubs: `hcreate`, `hsearch` and
  `hdestroy` over an `ENTRY` row, with `FIND`/`ENTER`, plus `insque` and
  `remque` over a `qelem` node.
- `libc.inttypes` gains `wcstoimax` and `wcstoumax`.

### Fixed

- `strtoumax` called `strtoimax` and reinterpreted the result, so every
  unsigned conversion went through the signed path. It now calls
  `strtoumax`.
- `libc.inttypes` took `char *` as an `Int8` pointer; the rest of the package
  uses a byte pointer, so the two did not mix.
- `hdestroy` was documented as leaving the keys alone. BSD, Darwin included,
  calls `free` on every key; glibc does not. Handing it keys in Mojo-allocated
  memory aborted on macOS, so the test now uses `malloc` keys.
- `hcreate_r`, `hdestroy_r` and `hsearch_r` were empty stubs and are gone.
  They need `struct hsearch_data`, which is GNU-only and whose size is
  platform-internal (16 bytes on glibc, something else on Darwin), so there
  is no honest binding to give.

## [0.4.1] - 2026-10-12

### Fixed

- `tests/test_wchar.mojo` read past the bytes `wcrtomb` wrote, which writes
  no terminator. Linux handed back zeroed memory and hid it; the macOS runner
  did not, so the suite failed there.

## [0.4.0] - 2026-10-12

### Added

- `libc.wchar` grows from `btowc` and `wctob` into the wide string functions
  (`wcslen`, `wcscmp`, `wcsncmp`, `wcscpy`, `wcsncpy`, `wcscat`, `wcschr`,
  `wcsrchr`, `wcsstr`, `wcsspn`, `wcscspn`), the conversions between wide and
  multibyte (`mbstowcs`, `wcstombs`, `mbrtowc`, `wcrtomb`, `mbrlen`, over an
  opaque `mbstate_t`), the classification predicates (`iswalpha`, `iswalnum`,
  `iswdigit`, `iswspace`, `iswupper`, `iswlower`) and `towupper`/`towlower`.

## [0.3.0] - 2026-10-12

### Added

- `libc.string` grows the `<string.h>` functions it was missing: `strcmp`,
  `strncmp`, `strcasecmp`, `strncasecmp`, `strcoll`, `strxfrm`, `strchr`,
  `strrchr`, `strstr`, `strspn`, `strcspn`, `strpbrk`, `strtok`, `strtok_r`,
  `memcmp`, `memchr`, `strerror` and `strsignal`.
- `libc.utils.null_ptr[T]()`, the one way to hand C a NULL: Mojo pointers are
  non-nullable, and `strtok`'s continuation call is one of many entry points
  that need one.

## [0.2.0] - 2026-10-12

### Added

- `pixi.toml` with `default`, `build` and `docs` environments, replacing
  `mojoproject.toml` and `magic.lock` (the `magic` CLI is retired).
- GitHub Actions workflows: CI (format, test on Linux and macOS, conda build,
  docs) and release (prefix.dev upload, GitHub Pages docs, release artifact).
- `recipe/recipe.yaml` moved out of `src/` and rebuilt for `rattler-build`.
- Four sub-packages that were empty stubs: `libc.stdlib` (allocation,
  environment, number conversion, temporary files), `libc.float` (the
  `<float.h>` limits), `libc.stdio` (the `<stdio.h>` entry points that
  `libc.file` does not already own) and `libc.complex` (the `<complex.h>`
  functions over `cdouble` and `cfloat`, the two-field structs the ABI passes
  in place of a complex number).
- Rewritten test suite under `tests/`, driven by `tests/test_main.mojo` and
  `std.testing` assertions: `complex`, `constant`, `ctype`, `dirent`, `float`,
  `math`, `network`, `stdio`, `stdlib`, `string`, `time`, `utils`, `version`.
- `CHANGELOG.md`, expanded mkdocs site (`install`, `usage`, `modules`,
  `version`) rebuilt on `mkdocs-material`.

### Fixed

- `libc.math`, `libc.errno`, `libc.file`, `libc.dlfcn` and `libc.logging` had an
  empty `__init__.mojo`, so `from libc.math import sqrt` did not resolve. All
  five now re-export their `syscalls` module.
- `struct dirent` used the glibc layout on every platform. Darwin puts an
  extra `d_namlen` before `d_type` and sizes `d_name` at `MAXPATHLEN`, so
  entry names came back empty on macOS. The struct now has the right size and
  reads the name at the right offset on both; use `dirent.type()` for the file
  type, since the `d_type` field only lines up on glibc.
- `pixi run package` failed in a clean checkout because `mojo precompile` does
  not create `dist/`.
- `<time.h>` was declared wrong: `asctime`, `asctime_r`, `ctime` and `ctime_r`
  took a `char *` where C takes a `struct tm *`, `gmtime` and `mktime` passed
  broken-down times around as bare integers, and `strftime`'s `size_t` was an
  `Int32`. All of them now take the new `struct tm`, and `strptime`,
  `localtime`, `localtime_r`, `clock_getres`, `clock_settime`, `timespec_get`
  and the `struct timespec` they share are covered too.
- `libc.file.fclose()` could not be called at all: `std.io` emits its own
  `fclose` declaration, and a second `external_call` for the same symbol that
  takes a `Pointer` fails to lower with "existing function with conflicting
  signature". The binding now passes the stream address as an `Int`, which is
  ABI-identical on every supported target.

### Changed

- Ported all 89 sources to Mojo 1.1.0:
  - `fn` → `def`, `alias` → `comptime`, `read` → `imm`, `inout` → `out`/`mut`.
  - `@register_passable("trivial")` → `TrivialRegisterPassable`; `@value`
    removed, `struct` definitions now state their traits explicitly.
  - `@always_inline("nodebug")` → `@inline(.nodebug)`; `@parameter if` →
    `comptime if`.
  - Standard library imports moved under `std.` (`std.ffi`, `std.memory`,
    `std.sys`), `external_call` now comes from `std.ffi`.
  - `UnsafePointer[T]` replaced by `c_ptr[T]`, an alias for
    `Pointer[T, MutUntrackedOrigin]`; `alloc`/`bitcast`/`store`/`free` use the
    `unsafe_`-prefixed spellings.
  - `StringRef` replaced by `String(unsafe_from_utf8=Span[...])`;
    `CString` now conforms to `Writable`.
  - `os_is_windows()` dropped in favour of `CompilationTarget.is_macos()`.
- Precompiled package format is now `.mojoc`; `.mojopkg` support was removed in
  Mojo 1.1.
- `struct dirent.d_name` is modelled as `Array[UInt8, 256]` instead of a
  pointer, which fixes both the field offset and reading entry names.
- `main.mojo` no longer imports the non-existent `libc.memory`.

### Removed

- `mojoproject.toml`, `magic.lock`, `src/recipe.yaml`.
