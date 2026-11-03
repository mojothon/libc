# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **Three of the bindings nothing asked, asked: `scanf`, `sigsuspend` and
  `pause`.** All three were on the list with one reason between them — they
  read standard input or wait for a signal, and a suite that waits is a
  suite that stops — and none of them turned out to need a handler or a
  thread to ask something.

  `scanf` takes a format and no conversion, so there is no address for
  libc to write through: a child's pipe with a word in it, **closed at the
  write end** (which is what gives the input an end at all — the first
  version left it open and the call sat there for the ten minutes the run
  had), answers 0 for the word and `EOF` for the call after it.

  `sigsuspend` waits under a mask of its own choosing, so the signal does
  not have to arrive: `SIGUSR1` is blocked and sent to itself, and the swap
  is what delivers it. What delivery then does differs — this build has a
  handler for `SIGUSR1`, so the call comes back with `EINTR` and takes the
  pending signal with it, and a build without one is ended by the signal —
  so the child says which happened by a byte down a pipe and the parent
  accepts both. A one-second alarm, blocked as well, is there so that a
  `sigsuspend` which failed to take the mask is woken by `SIGALRM` and
  named as such rather than sitting in the job until it times out.

  `pause` has no mask to swap, so its signal has to arrive: the child arms
  `ualarm` for a tenth of a second, calls `pause`, and is ended by the
  `SIGALRM` it never installed a handler for. Being ended by the signal it
  went to wait for is the assertion; a `pause` that came back would have
  left the child to exit on its own, which `WIFSIGNALED` tells apart.

  Eight remain, each with a reason, and the count on the modules page moved
  from 989 asked and 11 not to 992 and 8 — the guard added in the last
  commit failed until that sentence was corrected, which is what it is for.

- **Two more things the docs say, made able to fail.** `docs/modules.md`
  ends with what the suite does not ask, and that section had drifted a long
  way: it still named `sigwait` and `getchar` as unasked after both had been
  asked two rounds ago, still called `_Exit`, `system`, `getchar_unlocked`
  and `getwchar` unaskable, and still counted 977 asked and 17 not when the
  numbers were 989 and 11. Prose about calls is prose about state, so
  `scripts/check-tests.py` reads that section back now: every call it names
  has to be one the file is still holding as unasked, and the two numbers it
  states have to be the two just counted. The section was rewritten to say
  what is true — four bindings would stop the run rather than fail it
  (`scanf`, `sigsuspend`, `pause`, `pthread_cond_wait`), and the other seven
  are not about waiting — and split from the history that had grown into it,
  which is now under a heading of its own.

- **`pixi run check-release`, for the numbers a release moves.** The version
  is stated in five places — `pixi.toml`, `recipe/recipe.yaml`,
  `src/libc/version.mojo`, the table on the version page, and the specifier
  the install page tells a reader to ask conda for — and the Mojo range in
  four. Nothing about the package breaks when one is left behind, which is
  why nothing noticed: the docs build, the tests pass, and the install page
  goes on sending readers to a release that is two bumps old. The script
  compares them; the specifier is not compared as a string but asked whether
  the version this checkout actually is satisfies it, since `>=0.12.0,<0.13`
  is a claim about which releases can be installed rather than a restatement
  of the number.

  Both guards were checked by breaking what they guard: the old 977/17
  sentence, a table row naming `sigwait`, a renamed section heading, a
  `version.mojo` left one bump behind, an install specifier that excludes the
  version being shipped, and a Mojo range changed in one place only. Each
  fails the run and says which of them it was.

- **Six of the seventeen "a test cannot ask this" reasons were not
  reasons.** The suite has had, for a while now, a way to fork a child,
  point a pipe at one of its standard streams with `dup2`, and have it
  leave with the number it found. That is enough for all of these:

  - `getchar` and `getchar_unlocked` read the child's own standard
    input and leave with the `A` that was put there — 65;
  - `getwchar` does the same with a wide character, setting the C
    locale in the child first because the suite runs in one process
    and an earlier test may have left it another one;
  - `_Exit` ends the child with 42 and nothing after it runs, which
    is what it is for;
  - `system` is asked in the parent: `exit 7` comes back as a wait
    status that decodes to 7, and a null command says whether there
    is a shell at all;
  - `sigwait` is asked without waiting: `SIGUSR1` is blocked, sent,
    seen in `sigpending`, and only then taken, so it answers at once.

- **`_Exit` was bound but not exported.** `import *` passes names
  beginning with an underscore by, so the binding in
  `libc.stdlib.syscalls` could not be imported from `libc.stdlib` by
  anybody. `libc.stdlib.__init__` now re-exports it explicitly, and
  `test_import_all` and the new test both import it by name.

- **Two of the remaining reasons are sharper now.** `pthread_atfork`
  was tried and links and answers 0 in a built binary, but the suite
  is run just-in-time and the JIT run cannot resolve the symbol on
  this glibc; the binding stays unasked, with the reason it actually
  is. `putwchar` was tried too: it is not only that a wide write
  orients standard output for the rest of the process — a forked
  child inherits that orientation, and the suite has already
  oriented it narrow. A wide write to a narrow stream is undefined;
  a C probe showed glibc handing back the character while writing
  nothing at all. `getwchar` is still asked in a child, and the
  binding's notes say why its partner is not.

- **Five bindings that were missing between the ones already there:
  `getlogin` and `getlogin_r`, `sync`, `ttyslot` in `libc.unistd`, and
  `sockatmark` in `libc.sys.socket`.** All of them are declared and
  exported on both platforms; `strfmon` was looked at alongside them and
  left out, being variadic in a way that cannot be called — the amount to
  format comes after the format, and an external call cannot hand it
  one.

  `getlogin` and `getlogin_r` are the same question asked two ways, and
  the test asks them together: whichever way the machine answers — most
  CI machines are logged into by nothing — a name for one is the name
  for the other, and no name for one is no name for the other. When
  there is a name, a one-byte buffer is refused with `ERANGE`, which is
  the answer that says the call counted the room rather than the name.

  `sockatmark` is asked the whole of what it is for, over a loopback
  TCP connection: two ordinary bytes, one sent with the new
  `MSG_OOB` constant, one more ordinary byte after it. The answer is 0
  before the second byte is read, 1 from then on, and 0 again once the
  read has passed the mark. Reading the marked byte itself is where
  the platforms part ways — Linux keeps the mark until ordinary
  reading moves past that place, Darwin drops it as the marked byte is
  read — and the macOS run of the suite is what said so, the Linux one
  having answered 1 there.

  `sync` has nothing it can report, so the test asks only that the
  asking comes back; `ttyslot` counts a line in the machine's own login
  file, so the test asks for the floor — a line number, or the 0 that
  says there is not one.

  glibc declares `ttyslot` in `<utmp.h>` and Darwin in `<unistd.h>`, so
  `utmp.h` joins the headers `check-prototypes` parses; the binding
  lives with the other session questions in `libc.unistd`. The package
  now binds 996 C symbols, up from 991.

- **A Recipes page: five complete programs for the things a caller wants
  first.** Every `mojo` block in the docs is already compiled by
  `check-examples`, so the examples could not rot — but there were twelve
  of them across the whole package and none longer than four lines, which
  is enough to show a name is real and not enough to copy a working
  program out of.

  The five new ones each do one whole task end to end — say why a call
  failed (`opendir` + `get_errno` + `strerror`), read a file (`fopen` /
  `fread` with a `malloc` buffer), run a program and wait for it (`fork` /
  `execvp` / `waitpid`, with the `char **` argument list built by hand and
  the status read through `WIFEXITED`), write the time out
  (`clock_gettime` → `localtime_r` → `strftime`), and ask where a symbol
  is (`dlopen` / `dlsym` / `dladdr`, the pair bound last round, shown
  doing what they are for).

  Being compiled is a claim about the API, not about behaviour, so each
  one was also run before it was written down: the child echoes, the
  clock reads today, `dladdr` names `getpid` in libc. The page says so
  about itself, and the last recipe carries the two-spellings warning —
  `getpid` on one build, `__getpid` on another — where a reader who runs
  it will otherwise think it lied.

  `usage.md` points at the page from its end, and `mkdocs.yml` puts it
  after Usage in the nav. `check-examples` now compiles 17.

- **`libc.dlfcn` binds `dladdr`, which is `dlsym` the other way round.**
  `dlsym` takes a name and answers an address; `dladdr` takes an address and
  answers which object it is in, where that object was loaded, and the name
  of the nearest symbol at or below it — together with the `struct Dl_info`
  it fills, four pointers at 0, 8, 16 and 24 on both platforms. It is what
  makes the numbers `backtrace` hands back worth putting in a report, and
  it was the one call missing from a module that had the other four.

  The test asks the pair about each other, which needs no number written
  into it: a name goes into `dlsym`, the address comes out, the address
  goes into `dladdr`, and the name comes back, with `dli_saddr` the address
  that was handed over to the byte, since a symbol start is the nearest
  symbol to itself. What is looked up is `getpid` and
  not one of the string functions because those are ifuncs: `dlsym`
  answers with the implementation the machine chose, which is a different
  symbol from the one that was asked for and would be named differently, so
  the round trip would fail for a reason that has nothing to do with this
  binding.

  **What CI found that this machine did not.** The name comes back
  `getpid` here and `__getpid` there, on both platforms: libc exports the
  same address under both spellings, and the loader reports whichever its
  linker settled on. The address is what makes the two the same symbol, so
  the test takes either name and says why, which is the difference between
  a test that says "the name that went in comes back" and one that says
  "the string I happened to see locally comes back".

  The other half of the call is the address of a heap block, which is in
  no object: zero, and `dlerror` with nothing to say about it.

  The struct is spelled `dl_info` here, which is Darwin's tag: glibc leaves
  it unnamed behind the typedef, so neither spelling reaches both, and
  `check-layouts` is told the two names are the same thing so that it asks
  C for the size instead of reporting it as a struct with nothing to
  compare against.

  **What is left, and why it is not here.** `fts` — the recursive
  directory walk — was the last whole capability unbound, and it is not
  bindable: Darwin's `FTSENT` carries three members glibc's does not
  (`fts_ino`, `fts_dev`, `fts_nlink`), its `fts_level` is a `short` where
  glibc's is unsigned, and all five entry points there are behind
  `__DARWIN_INODE64`, which is the alias-macro case this package does not
  bind. `openpty`/`forkpty`/`login_tty` are in `libutil`, which nothing
  here links. Everything else still unbound is a macro, variadic, a
  callback, root's, or one platform's alone; `gap` is no longer a list of
  things to pick up.

  `beyond-c.md` says 991 symbols, 988 among the four libraries, 27.7%, and
  191 structs laid out in order; `modules.md` says `libc.dlfcn` has 9.

- **`libc.execinfo` is new: the three calls that read the stack the
  process is standing on.** Not ISO C and not POSIX — a BSD extension glibc
  copied, which is why it exists twice over — but it is the thing a crash
  handler and a diagnostic report are built on, and it was missing.
  `backtrace` fills an array with the return addresses of the frames above
  the caller, `backtrace_symbols` turns that array into one line of text
  per frame, and `backtrace_symbols_fd` writes the same lines to a
  descriptor. The two textual forms are not the same call twice: the first
  makes one block holding the array and the strings together, so it is the
  array that goes back to `free` and not each string, and the second
  allocates nothing at all, which is the whole reason it exists — it is
  what a handler writes with once the heap it would have asked is gone.

  **What this found is about the toolchain, not about C.** Run through
  `mojo run`, the same `backtrace` in the same three-deep nest answers
  **1** where a C program answers 4, and the one line it can print is a
  bare address with no object name on it: the program is built into memory
  just before it is run, those frames have no unwind information that libc's
  unwinder knows, and that memory belongs to no loaded image, so nothing can
  name it. Built ahead of time with `mojo build`, the same call answers 4.
  The binding is right in both cases; what a caller gets back is a property
  of how the program was built. So the test asserts the floor that holds
  either way — room for one frame records one, room for none records none,
  sixty-four is a ceiling — and not a depth, and the module says so where a
  reader will hit it.

  The assertion worth having is the two forms against each other: neither
  the words nor their spelling is the same on the two platforms, so what is
  compared is the number of lines, which both have to get right and which
  has to agree with what `backtrace` answered. Neither platform is asked
  what it wrote, only that it wrote as many of them as it said it would.

  `beyond-c.md` says 990 symbols, 987 among the four libraries, 27.7%;
  `modules.md` says `libc.execinfo` has 3, and its closing paragraph said
  936 asked and 18 unaskable, which was two recountings out of date and now
  says 977 and 17.

- **`libc.utmpx` is new: the seven calls of `<utmpx.h>`, and the record
  they hand back.** The login database: one record per session, who, on
  which terminal, since when, and whether it is still open. `getutxent`
  walks it a record at a time, `getutxline` and `getutxid` find one in
  it, `pututxline` writes one back, and `utmpxname` is what says which
  file all of that is about — which is the part that makes the package
  testable without being root: point it at a file of your own and the
  walk reads that one instead of `/var/run/utmpx`. The record is 384
  bytes on glibc and 640 on XNU, the login name first on one and the
  type first on the other, and not one member in the same place, so it
  is held as bytes and read at the offset of whoever is compiling — and
  the size is the platform's own rather than the larger of the two,
  because a record written out at the wrong length makes a file libc
  cannot walk. Two constants needed the same treatment as everything
  else that is numbered twice: `OLD_TIME` and `NEW_TIME` are the other
  way round on the two, and XNU's `ACCOUNTING`, `SIGNATURE` and
  `SHUTDOWN_TIME` are left out rather than bound on one platform and
  missing on the other. Three things the tests had to be told, none of
  them in a header: a search carries on from wherever the walk got to, so
  `getutxline` after a walk that has ended finds nothing at all until
  `setutxent` winds it back; XNU's `utmpxname` takes only a name ending
  in `x` and silently ignores anything else, and answers 1 for a name it
  takes where glibc answers 0; and an XNU database file is not an array
  of these records at all — it opens with a signature record in the
  narrower 32-bit shape and converts every record after it on the way in
  and out — so a file of one's own is libc's to make there, and only on
  glibc can the raw bytes at this struct's offsets be what libc reads.
  `libc.utmpx` starts at 29.
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
- **`getnameinfo` is bound, with the seven `NI_*` that go with it.** The
  way back from `getaddrinfo`: given the socket address it wrote, this
  says which host and which port that was. The four `NI_*` that decide
  what to answer are numbered the opposite way round on the two
  platforms — `NI_NUMERICHOST` is 1 on glibc and 2 on XNU, and the same
  for `NI_NOFQDN`, `NI_NAMEREQD` and `NI_NUMERICSERV` — while `NI_DGRAM`
  happens to be 16 on both and `NI_MAXHOST` and `NI_MAXSERV` agree. The
  address is taken as bytes rather than as a `socketaddr`, because it is
  the family in its first bytes that says which kind it is.
  `libc.netdb` goes from 21 to 29.
- **`libc.regex` is new: `regcomp`, `regexec`, `regerror`, `regfree`, and
  the two structs and twenty `REG_*` that go with them.** Compiling a
  pattern once and matching it many times, which nothing else here could
  do. Two of the compile flags are numbered differently — glibc gave the
  bit after `REG_ICASE` to `REG_NEWLINE` and XNU gave it to `REG_NOSUB`,
  so they are named rather than written down — but the thirteen error
  numbers are **the same on both platforms**, which is the opposite of
  what `EAI_*` turned out to be. `regmatch_t` is not the same size on the
  two: its members are a `regoff_t`, which is a thirty-two-bit int on
  glibc and a sixty-four-bit `__darwin_off_t` on XNU, so it is eight
  bytes here and sixteen there and read out at whichever width is in
  play. `REG_NEWLINE` is tested by what it does to `^` rather than by
  what number it is, because the number is the thing that differs.
  `libc.regex` starts at 26.
- **`libc.netdb` is listed in `test_import_all`.** Every sub-package is
  imported there so the linker has to resolve each symbol, which is how
  a name one platform does not export fails in a test rather than in a
  caller; adding that package last round left it out of the list.
- **`libc.glob` is new: `glob`, `globfree`, the `glob_t` they use, and
  the twelve `GLOB_*` flags and three answers both platforms have.**
  This is what a shell means by `*.txt`, available without a shell. It
  is also the worst agreement between the platforms found so far: of the
  twelve flags **only `GLOB_NOCHECK` and `GLOB_MAGCHAR` carry the same
  number across**, `GLOB_NOESCAPE` being 64 on glibc and 8192 on XNU, and
  the three answers are positive here and negative there, so
  `GLOB_NOMATCH` is 3 on one and -3 on the other. `GLOB_PERIOD` and
  `GLOB_ONLYDIR` are glibc's alone and `GLOB_QUOTE` and `GLOB_LIMIT` are
  XNU's, and none of the four is bound rather than faked. In `glob_t` the
  vector of paths is at 8 on glibc and 32 on XNU, the other three members
  agree, so the four are read by method. `libc.glob` starts at 18.
- **`libc.fnmatch` is new: `fnmatch` and the five `FNM_*` flags both
  platforms have.** The question `glob` asks of every name, asked of one
  name at a time. `FNM_NOESCAPE` and `FNM_PATHNAME` trade numbers between
  glibc and XNU — 1 and 2 against 2 and 1 — while `FNM_PERIOD`,
  `FNM_LEADING_DIR`, `FNM_CASEFOLD` and the `FNM_NOMATCH` answer happen
  to agree; `FNM_EXTMATCH` is glibc's alone and is not here.
  `libc.fnmatch` starts at 7.
- **`libc.libgen` is new: `basename` and `dirname`, the two halves of
  cutting a path in two.** The first binding in the package that had to
  change which *symbol* it calls: glibc's `<libgen.h>` declares
  `__xpg_basename` and renames it `basename` with a macro, because the
  `basename` in its libc.so is the GNU one from `<string.h>`, and the two
  differ on `/usr/lib/` — POSIX trims the trailing slash, GNU does not.
  An `external_call` has no macros, so glibc is asked for
  `__xpg_basename` by name and XNU for `basename`, whose one symbol is
  POSIX's. `libc.libgen` starts at 2.
- **`scandir` and `alphasort` are bound, in `libc.dirent`.** A whole
  directory in one call, as a vector of entries that are all readable at
  once — the reason to want them sorted. Both take a comparator this
  package cannot supply, there being no way to make a Mojo closure into a
  C function pointer or to take the address of one libc already has, so
  the two arguments are `NULL`: keep everything, in filesystem order.
  `alphasort` is bound for asking about one pair at a time instead, and
  the test checks its answer against `strcmp` on the same two names.
  What `scandir` allocates is the caller's to release, each entry and
  then the vector, and that is documented where it matters.
  `libc.dirent` goes from 15 to 17.
- **`libc.grp` is new: `group`, and `getgrnam`, `getgrgid`, `getgrent`,
  `setgrent`, `endgrent`.** The group database, the other half of what
  `libc.pwd` covers, and the one place where the two platforms do not
  disagree about a struct: `gr_name`, `gr_passwd`, `gr_gid` and `gr_mem`
  sit at 0, 8, 16 and 24 either way, so unlike `passwd` — whose middle
  Darwin pads with three members of its own — this one is a block of
  thirty-two bytes with nothing to read at the offset of whoever is
  compiling. What the tests do not assume is which groups exist: id 0 is
  `root` on one and `wheel` on the other, so the round-trip asks for
  whatever name the database hands out first. `libc.grp` starts at 6.
- **`libc.iconv` is new: `iconv_open`, `iconv`, `iconv_close` and the
  `iconv_t` they pass around.** Converting bytes from one encoding to
  another, which until now needed a subprocess and `iconv -f`. The two
  platforms agree on the three calls — glibc's is in libc itself and
  XNU's is GNU libiconv under the same names — and differ only in which
  encodings they have, so the tests ask for UTF-8 to UTF-8, the one
  conversion every platform has and whose answer is known in advance.
  Both failures are tested too, and the second is the easy one to get
  wrong: an encoding libc does not know is `(iconv_t) -1` and *not*
  NULL, so `is_null` asks the wrong question of it, and `iconv` says it
  stopped short with `(size_t) -1`. `libc.iconv` starts at 4.
- **`libc.langinfo` is new: `nl_langinfo` and the fifty-five `nl_item`s
  both platforms name.** What the locale says about itself: day and
  month names, time and date formats, the decimal point, the character
  set. The two platforms **disagree about every single one of the
  numbers** — not by a bit, by *scheme*: glibc packs the locale
  category into the high bits and XNU numbers them flat from 0, and
  neither orders the items the same way either, with `ABDAY` and `DAY`
  swapped. `YESSTR` and `NOSTR` are XNU's but glibc keeps them behind
  `_GNU_SOURCE` and `D_MD_ORDER` is a FreeBSD extension; none of the
  three is here. Tests never write a number down and the empty string
  is the one answer an undefined item gives on both, which is the only
  safe test of `nl_langinfo` that does not depend on the locale.
  `libc.langinfo` starts at 56.
- **`libc.ifaddrs` is new: `ifaddrs`, `getifaddrs`, `freeifaddrs`, and
  the five `IFF_*` flags both platforms agree on.** The list of
  network interfaces the kernel knows, walked by `ifa_next` until it
  reads null and released by `freeifaddrs` on the head. The seven
  members of `ifaddrs` line up the same on both: 0, 8, 16, 24, 32, 40
  and 48, fifty-six bytes either way, with glibc's union of
  `ifa_dstaddr` and `ifa_broadaddr` and Darwin's flat pointer sharing
  one slot. `IFF_UP`, `IFF_BROADCAST`, `IFF_LOOPBACK`, `IFF_POINTOPOINT`
  and `IFF_RUNNING` share numbers — 1, 2, 8, 16 and 64 — but
  `IFF_MULTICAST` does not, being 4096 here and 32768 there. Reading an
  address's family goes through `socketaddr` from `libc.sys.socket`,
  which is where Darwin's `sa_len` byte and glibc's bare family are
  already read the same way. `libc.ifaddrs` starts at 8.
- **`libc.netif` is new: `if_nametoindex`, `if_indextoname`,
  `if_nameindex`, `if_freenameindex`, `IfNameindex` and `IF_NAMESIZE`.**
  The same interfaces `getifaddrs` lists, asked for by name or by
  number instead. Both platforms agree on everything here: the two
  members of `struct if_nameindex` sit at 0 and 8, `IF_NAMESIZE` is
  sixteen either way, and the array `if_nameindex` hands back ends in
  the one entry whose number is 0 and whose name is null. The struct is
  called `IfNameindex` because `if_nameindex` the function wants the
  name C gives the struct, and the two cannot share one — the same
  reason `Stat` is not `stat`. `libc.netif` starts at 6.
- **`gethostname` is bound, in `libc.unistd`.** The name a machine has,
  which is the name `uname` reports under `nodename`; the test asks for
  it both ways and compares one against the other, and writes neither
  down, since the two runners are named different things. The platforms
  part company over a buffer too small for the name — glibc answers -1
  with `ENAMETOOLONG` and writes nothing, Darwin answers 0 and cuts the
  name to the room it was given — so the binding says both and the tests
  stay off that ground. `libc.unistd` is 185 → 186.
- **`getloadavg` is bound, in `libc.stdlib`.** How many things were
  waiting to run, averaged over the last minute, five minutes and
  fifteen minutes. Three is all there are, and asking for eight is
  answered with three. `libc.stdlib` is 45 → 46.
- **`libc.spawn` is new: `posix_spawn`, `posix_spawnp`, and the handles
  that go with them.** Starting a process without `fork` — everything
  `fork` and `execve` do between them, asked for in one call. Fifteen
  functions: the two that start a process, three file actions
  (`addopen`/`addclose`/`adddup2`) with their `init`/`destroy`, and six
  attributes — a process group, a mask, a set of defaults, and the flags
  that say which to honour — with `get*` for the two a caller can read
  back. The two handles are opaque and deliberately oversized: C names
  what is inside them under a name of its own and the platforms do not
  agree how much there is, eighty and three hundred thirty-six bytes on
  glibc against sixteen and a hundred twenty-eight on Darwin. A block
  larger than the truth is a block the truth fits in, since these are
  only ever passed by address. The six `POSIX_SPAWN_*` happen to agree
  across the platforms, which is worth noting only because the `_PC_*`,
  `_SC_*` and `_CS_*` knobs do not. The tests ask `sh -c 'exit 7'` for
  its code and hand a child a pipe to write into, which is what the
  file actions are for. `libc.spawn` starts at 23.
- **`libc.getopt` is new: `getopt_long`, `getopt_long_only`, `Option`,
  and the four globals the pair reports through.** Taking a command
  line apart, long options included. `getopt` itself is in
  `libc.unistd`, where POSIX puts it. `no_argument`,
  `required_argument` and `optional_argument` carry the same three
  numbers on both platforms, and so does the layout of `struct option`
  — 32 bytes with its members at 0, 8, 16 and 24.

  The four globals are the first data this package binds: `optarg`,
  `optind`, `optopt` and `opterr` are variables and not functions, so
  there is no calling them. Each is reached by asking `dlsym` where it
  sits and reading the value out of that address, with the handle
  handed back on each call so that `dlopen`'s count does not climb.
  `set_optind` is how a second command line is parsed: the `optreset`
  that Darwin has is BSD's and not POSIX's, and glibc does not carry
  it. The tests take five small command lines apart and check what
  came back against what was handed in. `libc.getopt` starts at 12.

### Changed

- **`scripts/check-layouts.py` checks field offsets now, for the members
  this package places by hand.** Size and alignment reach Mojo without
  constructing anything; an offset does not, because asking a pointer
  where a member lives asks for a member pointer and Mojo has none. But a
  struct held as bytes does not need asking: the number an accessor reads
  at *is* the offset, and C can be asked the same question with
  `offsetof`. Twenty-two are listed — the records of `utmpx`, `termios`,
  `dirent` and `aiocb`, which are the four places a member is placed by
  hand rather than by declaration — and each is compared on whichever
  platform is running, so the numbers taken from XNU's headers are
  checked against XNU's headers on the macOS job and by a compiler that
  has never seen them before. None of the twenty-two was wrong. What is
  not checked is counted in the output rather than assumed: the members
  Mojo lays out in declaration order, and the twenty-two structs that
  hold their bytes in a buffer while placing members at numbers written
  into their accessors, which is what `OFFSETS` is there to have more of.
- **`Stat` places its members by name now.** They were slot numbers and
  shift counts — `self._slots[0] >> 32 & 0xFFFF` for `st_mode` on Darwin,
  `self._slots[3] & 0xFFFFFFFF` for the same member on glibc — which is a
  layout that lives in the head of whoever wrote it and that nothing can
  check. The thirteen offsets are named at the top of the module now, one
  per member, with the width alongside each: `dev_t`, `blksize_t`,
  `mode_t` and `nlink_t` are half the size on Darwin that they are on
  glibc, and a member read at the wrong width is as wrong as one read at
  the wrong place. They go through three little-endian helpers, so a
  member is read where it says it is and how wide it says it is, and the
  byte order is the machine's, which is stated rather than implied.
  Nothing about the behaviour changed — the same bytes were already being
  read from the same places, and the `stat` tests, which fill a real file
  and read its mode, owner, size and times back, say so. What changed is
  that all thirteen are in `OFFSETS`, so both platforms now compare them
  with `offsetof`: a layout that was correct from memory is correct from
  the compiler, including on Darwin where `st_atimespec` is at 32 and
  `st_size` at 96 for no reason other than that a fourth `timespec` is in
  the way.
- **`Statvfs` and `Utsname` name their offsets too.** The same move, for
  the two structs where a member's place is least guessable. `Statvfs`
  keeps its members in the same order on both platforms and widths them
  differently — glibc's block and inode counts are `unsigned long`, XNU's
  `unsigned int` — so four of them share two words on Darwin and take
  four words on glibc, and `f_flag` lands at 48 on one and 72 on the
  other; a number copied from the wrong header would have nine members
  reading the right bytes of the wrong member. `Utsname` does not even
  have the same members: six arrays of 65 bytes against five of 256.
  Eleven offsets and six offsets respectively, all of them in `OFFSETS`,
  so `offsetof` confirms them on the platform that is running — 52
  members in total and none of them wrong. `UTSNAME_DOMAINNAME_OFFSET` is
  the one that cannot be confirmed everywhere, because Darwin's struct
  stops at `machine`; the script reports it as uncheckable there rather
  than skipping it, which is the difference between a hole that is
  counted and one that is not.
- **`group` and `passwd` name their offsets too.** Four members the two
  platforms agree on, and seven they do not: Darwin adds `pw_change`,
  `pw_class` and `pw_expire` after `pw_gid`, which pushes `pw_gecos`,
  `pw_dir` and `pw_shell` eight bytes further in and makes the struct 72
  bytes against glibc's 48. The getters used to spell that out at every
  use — `self._text_at(24 if not CompilationTarget.is_macos() else 40)` —
  and say `PASSWD_GECOS_OFFSET` now, with the platform decision made once
  where the constant is. Fourteen offsets go into `OFFSETS`, sixty-six in
  total: sixty-three are checkable on Linux and the three that are not are
  the Darwin-only members, counted as checkable elsewhere rather than
  dropped, and compared on the job where they exist.
- **`sockaddr` and `msghdr` name their offsets.** The two structs every
  socket call in here takes a pointer to, and the two where a member at
  the wrong offset reads as a plausible address rather than a crash.
  `sockaddr` is the sharpest case in the package: both platforms are
  sixteen bytes, and Darwin puts a one-byte `sa_len` in front of a
  one-byte family where glibc has a two-byte family and no length, so the
  family is at 0 on one and 1 on the other and no size check can see it.
  `msghdr` differs in width instead: `msg_iovlen` and `msg_controllen` are
  `size_t` on glibc and `int`/`socklen_t` on XNU, which puts `msg_flags`
  in the high half of the `msg_controllen` word on Darwin and in a word of
  its own on glibc — a shift that used to be written out in three places
  and is now `MSGHDR_FLAGS_OFFSET`. Nine offsets into `OFFSETS`,
  seventy-five in total, and `sa_len` counted as checkable on the one
  platform that has it.
- **`regmatch_t` and `sched_param` name theirs too**, which is three more
  offsets and one more thing the script learned. `regmatch_t` is the
  smallest struct in the package that the two platforms lay out
  differently at all: `regoff_t` is an `int` on glibc and
  `__darwin_off_t` on XNU, so `rm_eo` is at 4 on one and 8 on the other,
  and a subexpression that took no part in the match is -1 in both — which
  is why the read is sign-extending rather than masking, and why
  `regoff_t` being half a word showed up as `4294967295` before it was.
  `regmatch_t` is also a typedef with no struct tag, so
  `offsetof(struct regmatch_t, rm_so)` does not compile, and a member
  this cannot ask about is a member this cannot check: `check-layouts.py`
  now tries `struct X` and then plain `X` before giving up on a struct,
  which is what makes these two checkable at all.
- **`siginfo_t` names its seven, which is where the check earns the most.**
  glibc does not have a member called `si_pid`: it has a macro called
  `si_pid` that expands to `_sifields._kill.si_pid`, and the same for
  every other member after `si_code` — so the name in C and the number in
  this module were two separate statements of where the member is, and
  only `offsetof` (which macro-expands its argument before taking the
  address) could say whether they agreed. They do. The layout also stops
  agreeing exactly where the macros do: glibc pads `si_code` out to 16
  because everything after it lives in a union of `int _pad[SI_PAD_SIZE]`,
  and XNU packs `si_pid` in at 12 and reaches a 64-bit `si_addr` at 24
  without padding — 128 bytes against 104. `si_status` and `si_value` are
  both at 24 on Linux because they are different members of one union,
  a child's status and a value sent with `sigqueue` not being true of the
  same signal at once; on Darwin they are 20 and 32.
- **`glob_t` and `ifaddrs` name theirs, and `glob_t` had one wrong.**
  `gl_flags` is the one member of a `glob_t` that is not a count or a
  pointer, and it sits at 24 — a word of its own, whose low half is the
  flag word and whose high half is padding. It was being read from the
  high half, so `gl_flags` answered 0 whatever `glob` had been told, and
  no test had ever asked it. It is read at a named offset now, through a
  four-byte read that says which half it is, and a test says what the
  answer should be: `GLOB_MAGCHAR` is set for a pattern with a `*` in it
  and clear for a path without one, which both platforms promise. That
  the check found this the first time these offsets were written down is
  the whole argument for writing them down — `glob_t`'s other three
  members were right, and one wrong member out of four is not a rate
  anything else here would have caught. `ifaddrs` is the opposite case:
  seven members, the same seven offsets on both platforms, worth listing
  for the members that are *not* there — `ifa_flags` is four bytes with
  four bytes of padding behind it, and `ifa_dstaddr` is a union on glibc
  and a plain pointer on Darwin, spelled as a macro the first way and as
  a member the second, which `offsetof` settles either way.
- **The last three structs that read a member are in the table, and the
  rest are sizes rather than layouts.** `if_nameindex` names its two,
  `Sysinfo` its twelve — already named in the module, never compared — and
  `sigevent` the one word it sets. That is a hundred and eleven offsets,
  and every member this package reads out of a C struct is now read at an
  offset a script can compare with the compiler's. The seventeen that are
  left are the ones that read nothing: the eight pthread handles and
  attributes, `fenv_t`, `fexcept_t`, the two spawn types, `fpos_t`,
  `mbstate_t`, `fd_set`, `msqid_ds`, `shmid_ds`. Each of those is a block
  with a size and no members, so a name in `OFFSETS` would be a zero
  pretending to be a fact; what they claim is the size, which is checked,
  and only in one direction — libc writes into a block it was handed a
  pointer to, so a larger block is safe and a smaller one is somebody
  else's memory. `beyond-c.md` now says that out loud instead of counting
  them as work left undone.
- **`scripts/check-layouts.py` knows which members are Linux's alone.**
  `sysinfo`'s twelve and `sigevent`'s one were being asked of Darwin, which
  answered the second from a different struct — the only `sigevent` on
  macOS is the POSIX AIO one, which begins with `sigev_notify` where
  glibc's begins with eight bytes of `sigev_value` — and reported the
  answer as a disagreement. A number that differs from a different struct
  is not a finding, so those thirteen are listed as `LINUX_ONLY` and
  counted separately: not asked, not skipped quietly, and the total still
  adds up to a hundred and eleven.
- **`beyond-c.md` states the four counts in a table, and the script checks
  them.** The numbers in that essay — how many offsets are placed by hand,
  how many members are declared in order, how many structs claim only a
  size, how many are Linux's alone — were in the prose, where they go stale
  the first time a struct is added and nothing notices. They are a table
  now, recognised by the phrase in the first cell of each row, and
  `check-layouts.py` counts the same four things and fails if they differ.
  A row that disappears fails too: a document that stops making a claim is
  the drift this is watching for, and silence would pass for agreement.
- **`docs/modules.md` is read in both directions.** `check-prototypes.py`
  compared the count in each row against the package, which proves only
  that the listed packages are counted correctly: a package with no row had
  no count to disagree with, and passed. It now also fails when a package
  in `src/` has no row, and the dash the table already used for
  `libc.constant` and `libc.utils` is parsed rather than skipped — a row
  that says "listed, not counted" is a statement, and the two reasons for
  it are different: `libc.constant` is 416 `comptime` aliases rather than
  416 functions, and `libc.utils` is a file in `libc` itself rather than a
  sub-package. Adding a module and forgetting the table now fails in a
  second, on the spot, instead of waiting for a reader to notice.
- **The Mojo in the docs is compiled now.** `README.md` and `docs/*.md` are
  the one place a call to this package is written and nothing checks it: a
  renamed function leaves an example naming something that no longer
  exists, and the first person to find out is a reader following it.
  `scripts/check-examples.py` builds every fenced `mojo` block against
  `src/` — builds rather than runs, since two of them print whichever
  directory entry comes first and none asserts an answer — and reports the
  block and the line when one fails. Two blocks were not programs at all:
  the `errno_name` example was file-scope print statements, which Mojo does
  not allow, and the `EAGAIN` line was a `comptime` quoting part of the
  module without its `CompilationTarget` import. Both compile now. A block
  that has to stay a fragment says so with a `mojo fragment` fence, and the
  run prints how many it skipped, so the escape hatch is counted rather
  than assumed.
- **The symbol count on the first line of `beyond-c.md` is checked.** That
  paragraph calls it "the one number here that cannot drift from the source,
  because it is read out of the source" — and nothing read it out of
  anything, so it was a number three lines into the page with the same
  standing as the 3574 beside it. `check-prototypes.py` now compares what
  the page says against the symbols it walks, and fails if the sentence is
  reworded out of recognition, because the claim is the sentence. The
  percentage beside it was computed from 950 rather than from the 947 the
  sentence names — 26.6% where 947 of 3574 is 26.5% — and is 26.5% now. The
  3574 and the 947 stay as stated: they come from `nm` on one glibc, the
  page says so, and checking them would fail on the machine next door.
- **Every binding is now either asked something by a test or says why it
  cannot be.** `gl_flags` was read from the wrong half of a word for three
  releases and every check here was green, because nothing was wrong except
  that no test gave `glob` a flag. `scripts/check-tests.py` walks the same
  bindings `check-prototypes.py` does and asks `tests/` which ones it calls,
  ignoring imports, since `test_import_all.mojo` imports all 978. 923 are
  called. Of the 31 that are not, 17 cannot be — reading standard input,
  waiting for a signal, ending or forking the process, or naming a symbol
  glibc does not export — and each says which. The remaining 14 are testable
  and untested: a debt with a number on it that fails the run only if it
  grows. Eight of them were paid off in the same change (`round`,
  `remainder`, `erff`, `csinf`, `access`, `dup`, `link`, `umask`), which is
  the shape the rest is meant to go.
- **`getprotoent` and `getservent` are bound**, which the coverage check is
  what found: `setprotoent` and `endprotoent` were both here with nothing
  between them, so the package documented a walk over the protocol database
  whose middle it did not have, and the same for services. A setter with no
  reader is not a call anybody can make. Both docstrings had been describing
  `getprotoent` as the middle of the walk, which is how the gap read as
  complete.
- **The counts that follow move with it**: `beyond-c.md` now says 952 C
  symbols, 949 of them in the four libraries, 26.6%; `modules.md` says
  `libc.netdb` has 50. Both are checked, and both failed before the numbers
  were changed.
- **`posix_spawn_file_actions_addopen` is asked something.** The file actions
  could already say "put this descriptor there" (`adddup2`), and `addopen` is
  the other half: "open this path there", so the file is opened by the child
  after it exists and the parent never holds it. The test points the child's
  standard output at a file in `/tmp`, waits for it, and reads the file back —
  a call that opened it in the parent, or on the wrong descriptor, leaves it
  empty. That leaves eleven bindings with no test and a reason for each.
- **`check-tests.py` now asks whether the tests are called.** The same
  argument it makes about bindings holds one level up, and it had the same
  hole: a `def test_` that no line in its own `main` calls has never run, and
  reads exactly like one that has — it is in the file, it has a docstring
  saying what it asks, and `all tests passed` says nothing about it either
  way. Two were in that state: a `killpg` test in `test_signal.mojo` and a
  `clock_nanosleep` one in `test_time.mojo`. Both were called and both
  passed first time, which is the harmless version of the story; the other
  version is a test that would have failed and was never asked to. The
  runner is checked the same way — a `tests/test_x.mojo` whose `main` that
  `test_main.mojo` never starts is a whole suite that does not run — with
  two entries exempt and the reasons written down: `test_main` is the suite,
  and `test_smoke` is what `recipe/recipe.yaml` runs against a built package,
  where nothing can be printed.
- **`fflush` and `fdopen` are gone, because this package cannot bind them.**
  Both were written, both were exported, and neither could be called: the
  Mojo standard library declares both names itself, `std.io` keeping a
  `FILE *` of its own, and `external_call` refuses a second declaration of a
  name that is already declared. The error is `existing function with
  conflicting signature`, it comes out of `std/ffi` at compile time, and it
  appears only in the module that makes the call — so a binding for one
  compiles, ships, and fails when a caller touches it, which is the worst
  place for it to fail. Every other `FILE *` call in the package is fine,
  `fopen` and `fclose` and `freopen` among them, so this is about the two
  names rather than about streams. Three lines that import nothing from this
  package show it; they are in `scripts/check-symbols.py`, which now fails
  if either name is bound again. What found them was a test: `fdopen` had
  been named in a docstring as though it were called, and `fflush` had a
  comment explaining why it was not available, which is a thing worth
  noticing in a package that binds `fclose`.
- **`puts`, `putchar_unlocked` and `perror` are asked something.** They were
  the three that write where they point — standard output twice, standard
  error once — and a test that let them do it would have written into the
  middle of the suite's own output. So `dup` keeps the descriptors the
  process started with, `dup2` moves files over descriptors 1 and 2, and the
  same pair puts them back; it is the pair `adddup2` uses to point a child's
  output somewhere, used on this process instead. `perror`'s message is
  compared against `strerror` rather than against words, which are each
  platform's own. Standard output is buffered and nothing in this package can
  flush it now, so a long line of spaces is written again and again until the
  buffer writes itself out, and characters of that line in the file are what
  says the call went to descriptor 1; the line is spaces because whatever is
  left in the buffer is written to the terminal when the process exits.
- **`beyond-c.md` says 950 symbols again**, 947 of them in the four
  libraries, 26.5% — the two that left took the count back to where it was
  before `getprotoent` and `getservent` were added, which is a coincidence
  worth only this line. `modules.md` says `libc.file` has 40.
- **`<math.h>` has its two `exp2` calls and its six Bessel calls.** The
  coverage walk said 103 functions in that header were unbound, which is
  misleading in the way a count like that usually is: most of them are
  `long double` variants this package has no type for, macros such as
  `isinf`, or the `nexttoward` family whose second argument is one.
  What was actually left was eight calls both libcs export and nobody had
  asked for. `exp2` and `exp2f` are C99; the Bessel six are SVID and BSD
  additions ISO C never took, but both platforms put them in `<math.h>`.
  The test writes down no Bessel value: `jn(0, x)` and `jn(1, x)` are
  `j0(x)` and `j1(x)`, and `jn(2, x)` is what those two say by the
  recurrence, so the six are pinned against each other and a swapped
  `(n, x)` answers `jn(1, 2.0)` and fails. The second kind is a separate
  family obeying the same recurrence, checked from the other side.
  `exp2` is the one place a number can be written down, a whole power of
  two being exact — 1024 and 0.125, not approximations. `beyond-c.md`
  says 958 symbols, 955 among the four libraries, 26.7%; `modules.md`
  says `libc.math` has 131.
- **Both halves of the error function, and both directions of an NSAP
  address.** The coverage walk now says 415 functions are unbound, and
  the same three filters cut that down as before: `long double`
  variants, macros, callbacks, and GNU extensions that only one
  platform has. What remained were two pairs whose other half was
  simply missing: `erf`/`erff` were bound without `erfc`/`erfcf`, and
  `inet_pton`/`inet_ntop` without `inet_nsap_addr`/`inet_nsap_ntoa`.
  Both pairs exist on both sides — Apple's `Libm` ships `erfc.c` and
  `erfcf.c`, its `Libc` ships `net/FreeBSD/nsap_addr.c` — and neither
  test writes down a value from the library: `erf(x) + erfc(x)` is 1,
  and since `erf` is odd `erfc(-x) + erfc(x)` is 2, while the NSAP
  pair round-trips six bytes through whatever spelling the platform
  chooses — one writes a `0x` prefix and dots, the other bare hex. `wait`, `finite`, `scalb`, `drem`, `significand`
  and `gamma` are declared on Darwin but carry `__DARWIN_ALIAS_C`,
  so the symbols have a suffix and an `external_call` under the plain
  name cannot reach them; they stay unbound on purpose. `ecvt`,
  `fcvt` and `gcvt` looked unbound to a grep that did not look across
  lines, but all three were already here. `beyond-c.md` says 962
  symbols, 959 among the four libraries, 26.8%; `modules.md` says
  `libc.math` has 133 and `libc.network` 16.
- **`<wctype.h>` has both halves now.** It already carried `wctrans` and
  `towctrans`, but its docstring said Darwin had no `iswctype`, so the
  `wctype`/`iswctype` pair was left out. That note was wrong: Apple's
  `locale/iswctype.c` compiles the inline classifiers into extern
  functions with `_EXTERNALIZE_WCTYPE_INLINES_TOP_` — the same route by
  which `iswalpha`, already bound and passing on macOS, reaches
  libSystem — and `locale/FreeBSD/wctype.c` is an ordinary function
  whose twelve standard class names return the very masks the inline
  `isw*` functions test. Both are now bound and the note is corrected.
  A `wctype` handle is an unsigned integer on both platforms
  (address-sized on Linux, a bit mask on Darwin), unlike the `wctrans`
  handle which is a pointer on one and a number on the other, so one
  `UInt64` carries either and no second comptime alias is needed.
  The test writes nothing down about the handle's value: for all 128
  ASCII characters and all twelve class names, `iswctype(c,
  wctype(name))` has to agree with the corresponding `iswX(c)` bound in
  `libc.wchar` — 1536 comparisons against twelve independent bindings,
  so a symbol wired to the wrong function or an argument order reversed
  cannot survive. An unknown name and a name meaning a change of case
  both answer zero, and a zero handle classifies nothing. `beyond-c.md`
  says 964 symbols, 961 among the four libraries, 26.9%; `modules.md`
  says `libc.wctype` has 5.
- **The networks database, the third row family in `<netdb.h>`.**
  `protoent` and `servent` each had both ends of their walk bound and
  the row defined; the networks walk had neither. `getnetent`,
  `setnetent` and `endnetent` are now bound together with `getnetbyname`
  and `getnetbyaddr`, and `struct netent` with them — a name, a list of
  aliases, the family and the number at 0, 8, 16 and 20, twenty-four
  bytes and eight-aligned on both platforms, the one layout in the
  header that needed no platform branch at all.

  The symbols are not in Apple's `Libc` — there is no `getnetent.c`
  anywhere in it — but in `libsystem_info.tbd`, alongside the
  `getprotoent` and `getservent` already bound from there. That file is
  what settled the question without spending a CI round trip on it.

  The test writes nothing down about `/etc/networks`, which is not on
  every machine: a null first row is taken as an answer and the walk
  stops there. Where there is a row it asks that `setnetent` winds the
  walk back to that row, and that the row's name and number find the
  same row through the two lookups — three ways into one buffer, with
  nothing said about the contents except that every row is `AF_INET`
  and every row has a name. `beyond-c.md` says 969 symbols, 966 among
  the four libraries, 27.0%, and 183 members laid out in order;
  `modules.md` says `libc.netdb` has 56.
- **The RPC program database, the fourth row family in `<netdb.h>`.**
  `getrpcent`, `setrpcent` and `endrpcent` are bound with
  `getrpcbyname` and `getrpcbynumber`, and `struct rpcent` with them --
  a name, a list of aliases and the program number at 0, 8 and 16,
  twenty-four bytes and eight-aligned on both platforms. Again no
  branch: `r_number` is an `int` on both, even though the argument
  `getrpcbynumber` takes is written down as a `long` on a 32-bit Darwin
  build, and every machine this is built for is a 64-bit one.

  glibc declares these in `<rpc/netdb.h>` rather than `<netdb.h>`; the
  latter includes the former under `__USE_MISC`, so a translation unit
  that includes `<netdb.h>` sees them, which is what the prototype
  check reads and why nothing had to be added to its header list.

  The row is a program number and not a port, which the name invites
  getting wrong: 100000 is the portmapper, and the portmapper is what
  turns a number into a port.

  The test has the same shape as the networks one and writes nothing
  down about `/etc/rpc`, which is empty on many machines that have it:
  a null first row is an answer. Where there is a row, `setrpcent` has
  to wind the walk back to it, and the row's own name and number have
  to find that same row through the two lookups.
  `beyond-c.md` says 974 symbols, 971 among the four libraries, 27.2%,
  and 187 members laid out in order; `modules.md` says `libc.netdb` has
  62.
- **Netgroups: the last group of four in `<netdb.h>`.** `setnetgrent`,
  `getnetgrent`, `endnetgrent` and `innetgr` are bound. The first points
  a walk at one group, the second reads its `(host, user, domain)`
  triples through three `char **` the caller owns, the third ends it,
  and the fourth asks membership without walking at all.

  `setnetgrent` is the one signature in this package the two platforms
  spell differently in a way that cannot be papered over: glibc says it
  answers with an `int` (0 where the group could not be opened) and
  Darwin says it answers with nothing. It is bound as answering
  nothing, which is right on Darwin and safe on glibc -- the `int` is
  dropped rather than read on one platform and invented on the other --
  and loses nothing, because a group that could not be opened is a
  group whose walk answers nothing, which `getnetgrent` says anyway.

  The test needs no `/etc/netgroup`, which is on very few machines. It
  asks only things settled without the file: a group that is not there
  holds no triple, so `innetgr` says 0 whether the file is absent,
  empty, or full of other groups, and a walk over that group ends
  before it starts. That is what pins down 0 as "no" rather than "could
  not look".

  `beyond-c.md` says 978 symbols, 975 among the four libraries, 27.3%;
  `modules.md` says `libc.netdb` has 66.
- **Pseudo-terminals: `posix_openpt`, `grantpt`, `unlockpt`, `ptsname`.**
  A pty is one pair of descriptors that carry bytes the way a terminal
  does, and these four are the whole of opening one: the first gives a
  master, the next two make the far end openable, and the last says
  where it is. They were missing because they are declared under
  `_XOPEN_SOURCE` and the gap scan does not define it, not because
  anything is against them.

  The test asks for the pair to be a pair: a line written at the
  master has to come out whole at the far end, byte for byte. That is
  the one assertion here that two unrelated terminals could not pass,
  and it is why the test does not stop at "the descriptor is not -1".
  The line goes out with a newline after it because the far end is a
  terminal in canonical mode, where nothing is handed to a reader until
  a line is finished -- the terminal's rule, not this binding's.

  Nothing is written down about the name: glibc answers `/dev/pts/13`
  and Darwin `/dev/ttys013`, so the test asks only that the name opens
  and that what opens is a terminal.

  `beyond-c.md` says 982 symbols, 979 among the four libraries, 27.4%;
  `modules.md` says `libc.stdlib` has 79.
- **`wcwidth` and `wcswidth`: columns, not characters.** A width is
  what a terminal needs to know and a length is not: two one-column
  characters and one two-column character are the same width and not
  the same length. The pair answers that, and the nil is the one
  character whose width really is nothing, which is 0 and not -1.

  Both are locale-dependent, and more than the name suggests: the C
  locale has no tables saying how wide anything outside ASCII is, so
  `wcwidth` of a printable letter with an accent is -1 there -- not
  one, and not two. That decided the test rather than the binding:
  every assertion is about ASCII, because anything else would be an
  assertion about whichever locale the machine happened to be in.
  What ASCII does settle is the shape -- printable is one column, nil
  is none, control is none and answers -1 rather than 0, `n` is a cap
  that the string's own nil can end first, and one character with no
  column makes the whole string -1.

- **`strcasestr`: `strstr` with both sides folded together.** It
  answers a pointer into the haystack and not into a copy, so what
  comes back is the text as it was written rather than as it was
  compared -- which is what the test asserts, by finding `world` and
  `WORLD` and `wOrLd` in `Hello World` and checking that all three
  answer `World`.

  It is a BSD extension that glibc only declares under `_GNU_SOURCE`,
  which is the same reason `posix_openpt` was missing a while back:
  `check-prototypes` defines those macros itself, but the ad-hoc scan
  used to look for gaps does not, so functions behind a feature macro
  never appear in its list of things to bind. `strcasestr` was found by
  rescanning every header with the macros defined, which turned up
  about twelve hundred names the scan had never seen -- most of them
  glibc-only `*64` and `*_l` variants, but not all.

  `beyond-c.md` says 985 symbols, 982 among the four libraries, 27.5%;
  `modules.md` says `libc.wchar` has 85 and `libc.string` has 50.
- **`tcgetpgrp` and `tcsetpgrp`: which process group a terminal is
  serving.** A terminal has one group in the foreground of it and that
  is the group its input and its job-control signals go to, so this is
  the pair a shell uses to hand a terminal over to a job and take it
  back. The terminal is what is being asked about rather than the
  caller, so a process may read the foreground group of a terminal it
  is not in the foreground of, and the descriptor only has to be one
  for that terminal.

  The test is a child of its own, because there is no terminal worth
  asking about here: from CI standard input is a pipe, and from a shell
  it would be answering about the terminal the shell is on. The child
  takes a session of its own and opens the far end of a
  pseudo-terminal, which is enough on both platforms — a session leader
  with no terminal takes the first one it opens, and the terminal's
  foreground group becomes the leader's own. Three of the numbers it
  finds are then the same group seen twice: its own, which a session
  leader's is its pid, and what the terminal says. The fourth is a
  different group on purpose, a grandchild put into a group of its own,
  because setting a terminal to the group it already names would pass
  whether or not anything was written down. The refused group is one
  that cannot exist, and what is checked of it is that the answer is
  -1 and that the terminal still names what it named before.

  **The child was ended by `SIGHUP` before it could report, and the
  reason is worth writing down**: closing the master hangs up the
  terminal the child has just made its controlling one, and a hangup is
  a `SIGHUP` to the session that owns it — which by then is the child.
  So closing up shop tidily destroys the report. Left to the exit, the
  descriptors are closed after the exit status is settled, and the same
  hangup is then asked of a process already on its way out.

  `setsid` comes off the list of things a test cannot ask for. It was
  there because taking a process out of its session is for every test
  after it, and that is true of a test that does it in its own process
  — it is not true of one that does it in a child, which is what this
  one does and what the docs for the pair describe.

  `beyond-c.md` says 987 symbols, 984 among the four libraries, 27.5%;
  `modules.md` says `libc.unistd` has 202.
- **The list of bindings a test could ask and has not is empty.** Five of
  the last six debts were not blocked by anything, which is the point: four
  of the reasons said a privilege, a thread or a policy was needed, and
  the suite already had each of them. What was left was one call that really
  cannot be asked, and its reason is written down now.
  - `pthread_mutex_getprioceiling` and `pthread_mutex_setprioceiling`: a
    lock made with `PTHREAD_PRIO_PROTECT` and a ceiling of 7 in its
    attributes needs no privilege at all. `get` reads 7, `set(42)` hands
    back the 7 it replaced, and the next `get` reads 42 — the pair is the
    whole claim, on both libcs. Darwin reads the ceiling off the lock
    without asking about the protocol; glibc refuses both calls without it.
  - `pthread_detach`: `pthread_create` takes a function pointer Mojo
    cannot make, but the initial thread is a thread nobody joins. The
    first detach answers 0 (or `EINVAL` where it was never joinable), and
    the second must answer `EINVAL` — that second answer is the one that
    would catch a binding that never changed anything.
  - `sched_rr_get_interval` and `sched_setscheduler`: asked on Linux only,
    where `sched_*` answers for pid 0. The first has to write a real length
    of time into a `timespec` that was zeroes; the second is set to the
    policy the process is already on with the priority it already has,
    which is no change and asks for no privilege, and `sched_getscheduler`
    says afterwards that it has not moved.
  - `putwchar` is the one that goes to `CANNOT_ASK`, and not because of
    the terminal: one wide write orients standard output to wide characters
    for the rest of the process, `fwide` will not change an oriented stream,
    and clearing it takes a `freopen` on the `stdout` variable, which a
    package of function bindings cannot reach. On glibc the next `puts`
    answers `EOF` and writes nothing, so one call here would silence every
    later byte-oriented test sharing the stream.
- **Two docstrings said things that were no longer true.** `putwchar`'s
  said a test could not hold the terminal's answer, which stopped being
  the reason once the suite could point fd 1 at a file; `sched_setscheduler`'s
  said the package binds no `SCHED_*` constants, while `SCHED_OTHER` has
  been one since the module was written and the test uses it. The suite's
  own module docstrings said the mutexes were not tested yet and that
  `sched_setscheduler` was left out; all four now say what is there.

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

- **`glob_t.gl_flags` answered 0 for every `glob` that was given flags.**
  The flag word is the low half of the word at 24 on both platforms, and
  it was read as the high half — four bytes of padding — so `GLOB_MAGCHAR`
  and every flag the caller had passed in came back as zero. Nothing
  caught it because nothing had ever read it: the offset was written by
  hand, along with three that were right. It is a named offset now with
  a test on the other side of it.
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
