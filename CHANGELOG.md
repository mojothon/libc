# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.14.1] - 2026-11-12

### Fixed

- **`statfs` reads the second shape on Darwin.** The offsets come out of
  the machine's own headers instead of the Linux ones, the members Darwin
  keeps in four bytes are read as four, and the flags and file-id counts
  the page carries are named where C says them.
- **`stat` sits where the ARM ABI puts it.** Five members the thirty-two-bit
  ABI lays differently are read from where it lays them, and two are read
  at the width it gives them.
- **`epoll`'s record is one body for both ABI.** x86-64 packs the struct to
  twelve bytes and aarch64 lays it sixteen at eight, so the members are held
  as two words and read where each platform keeps them -- the stride the
  kernel writes is `EPOLL_EVENT_STRIDE`, and `data`'s place is
  `EPOLL_DATA_AT`.
- **`is_arm` asks the silicon, not the system.** Apple's silicon is ARM,
  and the branches that took the machine's word on which ISA it runs now
  take it on both platforms.
- **`write` goes by glibc's own alias**, and the syscall number it lowers
  to is the machine's table's, not this package's guess at it.

### Changed

- The open flags live where the open is, and the constants of `fcntl`,
  `netdb` and `epoll` are asked of C once each, not twice.

### Added

- **`putwchar` is asked, and a reason on the books was not one.** The call
  writes to standard output itself, and standard output's orientation is
  set by its first write and lasts as long as the process does, which is
  why the page said it could not be asked: a fork hands the child the
  stream the suite has already oriented, and a wide write to a
  narrow-oriented stream is not defined by C. What the reading missed is
  that the C library exports `stdout` as a variable, which `dlsym`
  reaches, and that `freopen` starts a stream over -- unoriented, and
  pointed at whatever descriptor 1 holds. The test's child reopens the
  stream at nowhere first, which drains the buffer the fork would
  otherwise hand over, then points descriptor 1 at a pipe, reopens,
  turns the stream wide, and calls `putwchar`: the pipe receives one
  byte, and the call answers the character it was given. The child ends
  through `fclose`, closing being the flush this package has -- an
  `fflush` binding is off the table, the Mojo standard library declaring
  that name already. 1059 bindings are now asked something and 2 are not.
- **`pthread_atfork` takes real handlers now.** It was bound with three
  byte pointers and a note that Mojo cannot make a C function pointer,
  which stopped being true when the thin-function bridge went in; the
  three parameters are `def() thin -> None` values, which are code
  addresses, the shape C asks for. What still stands between the call
  and a test is the name, not the call: glibc exports it only as
  pthread_atfork@GLIBC_2.2.5, with no default version, and the
  just-in-time run the suite uses looks the bare name up and finds
  nothing. That is the whole reason now, on the books in one place
  rather than two.
- **`libc.threads`, the last stub, written.** All twenty-five functions of
  `<threads.h>` are bound: `thrd_create` and the rest of the `thrd` family,
  `call_once`, the six `mtx` calls, the six `cnd` calls and the four `tss`
  calls. The module had waited longer than any other on one argument --
  `thrd_create` takes a function pointer -- and once that argument fell, the
  whole module came with it: `call_once`'s function and the `tss` destructor
  go over the same thin-function-value bridge. The handles are sized to
  glibc and kept opaque (`thrd_t` one word, `tss_t` one unsigned int,
  `once_flag` one int, `mtx_t` 40 bytes, `cnd_t` 48), `once_flag()` is C's
  `ONCE_FLAG_INIT` spelled in Mojo, and the header comment says the thing a
  Darwin user will find out anyway: importing this module there will not
  link, there being no `<threads.h>` on that side at all. The tests run
  real threads against each other, and the condition-variable handshake is
  written so that the signal cannot arrive before anybody waits -- the
  waiter signals from inside the mutex, and this side takes the mutex back
  before waking, which is something only a sleeping waiter could allow.
  Linux only; on Darwin the tests compile to nothing.
- **A function of one's own, handed to C.** `qsort`, `bsearch`,
  `pthread_create`, `pthread_join` and `pthread_exit` are bound. All of
  them were waiting on the same reading -- that Mojo cannot hand C a
  function pointer -- and the reading was wrong: a `def` that captures
  nothing converts to a `thin` function value, which is a code address and
  nothing else, and `external_call` passes it where C wants its
  `void (*)(void *)`. What cannot cross is state, so a callback reaches
  nothing that was in scope where it was written; everything it works on
  goes through the `void *` argument, which is what that argument is for.
  The thread tests now start a second thread, assert through `pthread_equal`
  that it is not the one asking, and read back what it left behind.
  `atexit` is still out, for a reason that has nothing to do with
  callbacks: glibc has no `atexit` symbol -- it exports `__cxa_atexit` and
  `on_exit` and leaves `atexit` to the static archive -- so there is
  nothing on Linux for a binding to link against.
- **`<sys/un.h>`: an address that is a path.** An `AF_UNIX` address was
  the one thing this package could not build at all -- `socketaddr` is
  sixteen bytes, which is a family, a port and four bytes of address, and
  a path is longer than that. `sockaddr_un` writes and reads the path
  where C keeps it, 108 bytes of it here and 104 on Darwin, where a
  one-byte `sun_len` comes first; both sizes and the offset of `sun_path`
  are put to C's `sizeof` and `offsetof`. The struct is a view of a
  caller's block rather than an owner of one, because the calls it is
  handed to read through a pointer and a copy would be an address they
  never see. A test binds one, connects to it, takes the connection, and
  then binds the same name again expecting `EADDRINUSE` -- which only
  arrives if the first call really did put that path into the kernel's
  table.
- **An `AF_INET` view of `socketaddr`.** The struct held sixteen bytes and
  said that nothing here packed or unpacked them, so every caller filling in
  an address wrote `set_byte(2, ...)`, `set_byte(4, 127)` and hoped: the port
  in network order, the address as four bytes, and the two platforms' family
  offsets all in the caller's head. `set_inet_port` and `set_inet_address`
  now write the two numbers where C's `sockaddr_in` keeps them -- the same
  offsets on both platforms, which C's `offsetof` confirms -- and
  `inet_port` and `inet_address` read them back. The port answers in the
  order a port is said in; the address answers as C's `in_addr` holds one,
  so `inet_addr` and `inet_ntoa` hand one in and take one out.
- **A recipe for two sockets on the loopback**, from `socket` to `accept`
  and a byte each way, built on those four.
- **The byte order is checked by two claims rather than one.** The test
  asserts the port's high byte lands first and that C's `ntohs` makes 8080
  of the same two bytes; a round trip through this package's own reader
  would agree with itself whichever order it wrote.

### Fixed

- **`test_pty` read once where a pseudo-terminal is free to answer
  twice.** A read at the master came back with twenty-five of twenty-six
  bytes on a machine that was busy compiling, which is a property of a pipe
  with a line discipline rather than of the binding: so the four reads there
  now gather until they have what they asked for, and a short answer is no
  longer a failure.

- **`test_pwd` compared a row with itself, and macOS's two lookups disagree
  about one field.** `getpwuid(0)` and `getpwnam("root")` hand back a row in a
  buffer that the next lookup writes over, so reading both rows after asking
  both questions compared whichever came second with itself: on glibc the
  test proved nothing, and passed. The first row is now read out into Strings
  before the second question is put. On Darwin the two answers turn out to be
  different records: `pw_shell` comes from Open Directory by number and from
  the local file by name, so the runner said `/bin/sh` one way and `/bin/bash`
  the other. That is the platform's, not a layout mistake — `offsetof` agrees
  with `PASSWD_SHELL_OFFSET` on Darwin — so what is asserted of it now is that
  both name an absolute path. Found by pointing CI's macOS job at `macos-14`
  after the `macos-latest` pool stopped handing out runners.
- **Fourteen constants that held Linux's number on a platform whose header
  says otherwise**, found by asking C about the constant's name for the first
  time. The `LDBL_*` limits and `DECIMAL_DIG` described an 80-bit `long
  double` that Darwin does not have — its `long double` is `double`, so the
  answers are 53, 15, -1021, -307, 1024 and 308, and 17 rather than 21;
  `POLLWRNORM` and `POLLWRBAND` were 256 and 512 where Darwin spells them 4
  and 256; `BUFSIZ` was 8192 where Darwin's is 1024, and the docstring beside
  `setbuffer` said the two platforms agreed on it. None of these had ever
  failed a test, because nothing here asserts what a number means.

### Added

- **A check on the room a string accessor gives itself inside a member.**
  `ut_user` is a `char[32]` on Linux and a `char[256]` on Darwin, and the
  accessor neither reads nor writes a fixed four or eight bytes of it: it
  passes a *room* to `_string`, and `_set_string` writes at most that many
  bytes. That number is a claim about the member's width like any reader's,
  and the one whose being wrong writes past the end of the member — on Linux
  `ut_user` ends exactly where `ut_host` begins. `check-layouts` now compares
  all four of them with `sizeof`, and a name longer than either room is
  written in a test that asserts it stops at the room and leaves the fields
  beside it empty.

- **A check on the width a setter writes a member at.** The read side has been
  compared with `sizeof` since the widths were first asked about; the write
  side was not, and it is the one that hides: a four-byte member written two
  bytes wide reads back correctly for every value that fits in two, because the
  half nobody wrote is the zero the struct started as. `set_ut_pid` changed to
  `_set_u16` returns `4321` through `ut_pid` exactly as a correct one does.
  `check-layouts` now compares all eleven setters with `sizeof`, and a test
  writes a pid with something in its upper half so the behavioral half of the
  claim is asked for too. The same sweep now catches a setter at a literal
  offset, which was the one place a member could be placed without appearing
  in any count: `write_widths` only sees `_set_u32(NAME_OFFSET, ...)`, so
  `_set_u32(4, ...)` would have been invisible to both.

- **Nine of the fifty-five accessors no test called now have one, and the
  five in `stat` found their oracles in the file itself.** `dev` and `rdev`
  are the pair that answers without a second file: a regular file has a
  device and no device number of its own, so `dev` is non-zero and `rdev` is
  exactly zero, and an accessor reading the other's bytes fails one of the
  two whichever way round the mistake was made. `atime` and `ctime` are told
  apart from `mtime` by setting the two times to different values and asking
  each for its own — `ctime` is the one that has to be now. `blocks` is
  asserted as a range the file's own size fixes.
- **The shape of the ancillary data's header is now claimed and checked, and
  the claim is a real platform difference found by the descriptor test.** C's
  `struct cmsghdr` is not the same struct twice: glibc's is sixteen bytes with
  a `size_t` length, XNU's is twelve with a `socklen_t` length, and a control
  message built with glibc's shape answers EINVAL from XNU at every room
  `CMSG_SPACE` suggests. `CMSGHDR_LEN_BYTES`, `CMSGHDR_HEADER_BYTES`,
  `CMSGHDR_SPACE_ONE` and friends now name the shape, `check-layouts` compares
  them with `sizeof` and `CMSG_SPACE` on each platform, and the descriptor test
  builds the message in the shape its platform says.
- **The three mutants the symbol sweep left as crashes are caught by
  assertions now.** `fegetenv` pointed at `fesetenv` crashed because a
  zeroed environment was installed with nothing to catch it; the test
  saves the environment while the mode is upward and asserts the mode is
  still upward after the saving, which reading is and writing is not.
  `duplocale` pointed at `uselocale` crashed in the freeing, which is the
  only thing that tells a real copy from a handle another call answered
  with; the freeing is asked from a child, whose ending is a status the
  suite reads. `posix_spawn_file_actions_init` pointed at `destroy` took
  a mess of bytes for a list it had made; the pair is asked from a child
  the same way. Crashed was always noticed, but nothing written had
  caught it — now all three have an assertion that only the right call
  passes.
- **The check-of-checks now asks the three checks it had never broken.**
  `check-symbols` is asked with a binding pointed at `strcatx`, which no
  library exports; `check-comparisons` with the one sign assertion
  `strcasecmp` had flattened to a zero-or-not, which is the shape that
  survived seven swaps; and `check-magnitudes` with the `fabs` taken off
  a tolerance so the bound holds one side of the distance again. All
  three said so. Twenty-seven ways of being wrong are now each caught by
  the check that owns them, up from twenty-four, and every check in
  `scripts/` has had its claim asked except this one.
- **The speed table was run again, and the numbers it gave back are the
  first pair of runs this document has been able to compare.** Same
  machine, same day: every row within two percent of the run before —
  `nothing` moved by 3 and 7 ps, `strlen` by 11, the syscall rows by half
  a percent and a quarter of their three hundred thousand, which is the
  least movement where the number is the largest and the row that carries
  the claim. The cheap rows stay unreadable, as they always said they
  were; what repeats is the shape, and the shape repeated.
- **The mutation sweep of the symbol axis is closed, and the closing was
  one run that found nothing to fix.** The modules the story had not
  worked through — `unistd`, `wchar`, `ctype`, `signal`, `netdb`, `fenv`,
  `file`, `network` and the eight small files, `spawn` re-asked with
  them — are two hundred and forty-eight mutants in one run, and not one
  passed: two hundred and fourteen caught, three that took the process
  down, ten that are the same call under two names or arithmetic that
  does not remember its direction, nineteen that write state nothing
  reads back, and two that did not build. The axis ends there — every
  mutant caught, answered by a failure, or written down — and
  `--check-tables` reads the reasons back against the pairs that can
  still be made, so a written answer cannot outlive its pair. The
  paragraph is in the doc, at the end of the mutation story.
- **`<netinet/tcp.h>`: the four options a connection keeps.** `TCP_NODELAY`,
  `TCP_MAXSEG`, `TCP_KEEPINTVL` and `TCP_KEEPCNT`, as the numbers
  `setsockopt` takes with `IPPROTO_TCP` in the level. Two are the same on
  both libcs and two are not: Darwin's start again above the socket-layer
  range, so the keepalive pair is 0x101 and 0x102 where glibc has 5 and
  6. `TCP_KEEPIDLE` is left out because Darwin spells it `TCP_KEEPALIVE`,
  and one name that is not in both headers cannot be bound as one. The
  numbers are checked by behaviour rather than by agreement with
  themselves: nodelay is read off a fresh socket and turned on, the
  keepalive pair answers back two different numbers, and the segment size
  has to be one a segment could be -- a wrong option number is refused by
  the kernel, and one that exists under that number answers something
  else.
- **The order axis was swept again with the `pty` pair in it: 193 swaps,
  none unaccounted for.** 156 caught, 10 that took the process down -- the
  same ten as before, each a swap that hands a string where a pointer to
  one belongs -- and 26 that are the same call. Four that used to crash
  are caught now, where a test grew up around them.
- **`<pty.h>`: a pseudo-terminal pair, and the three calls that take
  one.** `openpty` hands back the two descriptors, `login_tty` puts one
  on 0, 1 and 2 as the controlling terminal of a new session, and
  `forkpty` is both of them around a `fork`. `struct winsize` comes with
  them, since a caller that wants a size to be there has to hand one in.
  Three constants came with the tests rather than the bindings: `ECHO`,
  `ICANON` and `ONLCR`, which are what a program reading a terminal's
  output turns off. Two things the tests measured rather than assumed:
  the master end answers `isatty` with yes as well (the line discipline
  is on both ends on Linux), and a default terminal sends a newline as a
  carriage return and a newline, so what arrives at the master is one
  byte longer than what the child wrote.
- **The whole of the mutation sweep was asked again, and the three
  crashes it found are assertions now.** The sweep had been made before
  the last few bindings arrived, so all five hundred and ninety-two
  mutants were asked on the tree as it stands, and nothing passed.
  `fegetenv` pointed at `fesetenv` has a test of its own: saving the
  environment leaves the mode alone, so a mode is set before saving and
  expected back twice. `putenv` pointed at `system` is caught by asking
  whether `getenv` found the name, which the shell never delivers to this
  process. `calloc` pointed at `aligned_alloc` is asked for a hundred
  bytes -- not a power of two, so no alignment can answer, and glibc
  returns nothing. One written answer went out of date: `cfsetispeed` and
  `cfsetospeed` had been written down as writing the same storage, and the
  tests have since told them apart, so the entry is gone.
- **The last of the untested accessors are tested, and one of the
  answers was printed rather than claimed.** `sysinfo`'s `sharedram`,
  `bufferram` and `freehigh` are asked beside what is already asked:
  shared memory and buffers are parts of the memory there is, so
  neither count can pass the whole of it, and a machine with no high
  memory — which is what a 64-bit one is — has none free either.
  `pwd`'s `pw_passwd` and `pw_gecos` are asked of root: the password
  field holds the placeholder each platform keeps, `x` on Linux and
  whatever Darwin keeps for an account whose password left the file,
  and the real name is not empty on either. The three Darwin-only
  members are asked too, and they are the place the platforms answer
  differently on purpose: Linux's struct has no such members and the
  accessors promise 0 and nothing there rather than bytes read out of
  a slot that holds another member, which is exactly what the Linux
  side asserts. On Darwin the account's own answers are claimed: the
  star the file keeps, a password changed at no time, an account that
  does not expire, and a class that is none.
- **Four more accessors no test called now have one, and one of them is
  asked two ways at once.** `netdb`'s `ai_canonname` and `ai_next` are
  asked of `localhost`, which every runner answers out of its own
  `/etc/hosts`: with `AI_CANONNAME` the first answer carries the name
  that was given and without it carries nothing, and `ai_next` threads
  whatever list there is into a null. `epoll_event`'s `data_u64` is
  asked with a tag that has something in each half — the kernel hands
  back all eight bytes untouched, which is C's own answer, and the low
  four answering `data_fd` says the two are the same eight bytes read
  different ways. `aio`'s `reqprio` has no C reader at all and is asked
  as a pair — but with the two members beside it written too, each with
  its own number, so a getter reading a neighbor's slot cannot pass.
  And `statvfs`'s `f_fsid` is asked of the path and of a descriptor
  opened on it, two bindings that have to agree about the identity of
  one file system; `f_favail` is asked beside `f_ffree`, which both
  platforms answer with the same number, there being no separate
  reserve of inodes for root.
- **Six more accessors no test called now have one, and two of them are
  answered by a room the tests build.** `dirent`'s `type` and `reclen` are
  asked of a directory made in `/tmp` with an ordinary file in it: the
  dots every directory carries answer `DT_DIR`, the file answers `DT_REG`,
  and every record is big enough to hold its header and its name — and
  on glibc, whose records are packed, not much more, which is the bound
  that keeps `reclen` reading its own two bytes; Darwin's filesystems
  pad records to a grain of their own, so there the only bound asked is
  the buffer. Naming the type byte meant naming three constants — `DT_UNKNOWN`,
  `DT_DIR` and `DT_REG` — that had been raw numbers in no header of this
  package. `siginfo_t`'s `si_signo`, `si_uid` and `si_errno` are asked of
  the answer `sigtimedwait` already gives: which signal arrived, whose
  real user queued it, and that queuing was no error. And `glob_t` gets
  the setter it was missing — `set_gl_offs`, for the one member `glob`
  reads before it fills the block — which the `GLOB_DOOFFS` test then
  makes C act on: two nulls at the head of the vector and the pattern
  itself at the third place.
- **The three `ifaddrs` accessors no test called now have one, and the
  members agree with each other.** Every IPv4 entry's `ifa_netmask` is in
  the family of its address and only ever goes down — 255s and then 0s —
  and the loopback's is an eight. An interface that broadcasts names its
  broadcast in `ifa_dstaddr`, and that address is the interface's own
  address with the mask turned inside out, byte by byte — which is an
  answer one getter cannot give without the other two being right. glibc
  also hands entries that do not broadcast a far end, the loopback gets
  its own address there, and whatever it hands is in the family of the
  address. The packet and link entries are told apart by their signature:
  `ifa_data` filled, `ifa_netmask` empty, an address in neither Internet
  family.
- **The nine `msghdr` accessors no test called now have one, and C answers
  for six of them.** `sendmsg` reads the name `set_msg_name` wrote, and
  `recvmsg` answers with the sender's address written through `msg_name` —
  whose family and port are then read back through the getter itself, since
  reading the pointer the test kept would ask the getter nothing. A
  descriptor sent as `SCM_RIGHTS` ancillary data comes back with
  `msg_controllen` holding C's own count and a descriptor of its own at
  `msg_control`, which is used to send a byte that arrives on the end that
  stayed home. `msg_flags` is asked through `MSG_TRUNC` on a datagram
  received into half the room it needed. Two constants are named now to ask
  these questions — `MSG_TRUNC` and `SCM_RIGHTS` — having been written out
  in a comment before. `msg_iov` and `msg_iovlen` have no C reader on
  either platform and are asked as pairs, which the test says.
- **The twelve `termios` accessors are asked of a real pty.** `cfmakeraw` and
  `cfsetspeed` are C's writers of the words the accessors read, and what the
  accessors write is handed to `tcsetattr` and read back into a fresh block.
  Two are asked as pairs instead, and the reason is worth knowing: on glibc
  `cfgetispeed` answers from the baud bits of `c_cflag` and never looks at
  `c_ispeed`, so no glibc call can confirm where `set_ispeed` put its number —
  the fields are two storages, but C's reader of them is not. `cflag`'s bits
  mean different things on the two platforms and none of them is named here,
  so what is written into it is a number no line would take.

### Changed

- **`siginfo_t.si_ptr` reads the other half of the union `si_value` reads
  four bytes of.** `sigqueue` takes eight bytes and C names them twice:
  `sival_int` is the low four and `sival_ptr` all eight, and `si_value`
  returned `Int32`, so a number sent with anything above 2^32 in it came back
  truncated with no way to ask for the rest. `si_ptr` answers with the whole
  eight, and a test sends a value whose halves differ so that the two
  accessors cannot both be answering with the same four bytes.
- **The width check counts accessors, not members.** Adding `si_ptr` made that
  matter: `si_value` reads four of the eight bytes and `si_ptr` all eight, and
  keyed by member the four-byte read would have passed on the strength of the
  eight-byte one beside it. Keyed by accessor, each read is its own claim, and
  `si_value` stays the one exemption it always was.

- **`check-layouts` asks how wide a member is, and found the one accessor
  that reads less of one than C holds.** An accessor claims two things about
  a member: where it starts, from the offset it names, and how many bytes it
  takes, from the reader it calls. Only the first was ever asked. `_u32` where
  C has an eight-byte member truncates it, `_u64` where C has four carries the
  member beside it into the answer, and both look plausible — `offsetof` and
  `sizeof` are each right either way, so nothing here could see it. The width
  each accessor reads at is compared with `sizeof(((struct stat *)0)->st_size)`
  now, per platform and through the mask or shift it applies: fifty-eight
  members, fifty-seven agree. `si_value` is the one that does not, on purpose
  — it is the `sival_int` half of a union it shares with `sival_ptr` — and it
  is written down as such rather than left to look like the rest.
- **The same reading asks which half of a slot a member is in.** `pw_uid` and
  `pw_gid` share one eight-byte slot on both platforms, so one accessor masks
  the low four bytes and the other shifts the high four away; the half it keeps
  has to be the half `offsetof` puts the member in, and nothing compared them.
  Taking the other half gives a number of the right size and the wrong value,
  which is the shape of the `gl_flags` bug that went three releases before
  anyone looked.

- **`termios` reads and writes its flag words at the width it says, and the
  width is asked of C.** `TERMIOS_FLAG_BYTES` and `TERMIOS_SPEED_BYTES` state
  how wide a `tcflag_t` and a `speed_t` are here — four bytes on glibc, eight
  on Darwin — and nothing used either one: the width was decided again inside
  `_flag`, `_set_flag` and their speed callers, by asking which platform this
  is. Two exported claims, no reader, no question. The accessors are
  `_word[width]` and `_set_word[width]` now, called with those constants, and
  `check-layouts` puts `sizeof(tcflag_t)` and `sizeof(speed_t)` beside them,
  which is a third question it did not ask before.
- **`check-layouts` asks about the offsets it does not have, and found one.**
  The report over `OFFSETS` walked the list: a name in it that had been
  renamed or dropped came back unchecked, which is the list going stale. A
  constant that places a member and is not in the list said nothing at all,
  which is the list going incomplete, and a member read at a number written
  into the call (`self._u64(0)`) was invisible either way. Both are counted
  now and both fail. There was one of the second kind: `dirent.ino` read
  offset 0 directly, which is `d_ino` on glibc and Darwin alike and was true
  by luck. It is `DIRENT_INO_OFFSET`, registered, and `offsetof` agrees.
- **`check-constants` asks how wide a type alias is, and found two wrong.**
  `comptime off_t = Int64` is a claim about C rather than a number, so no
  value question could touch it: the aliases were the largest silent block
  left, thirty names reported as "not something these headers give a number
  for". `sizeof` and `(T)-1 < 0` from the compiler say what each one should
  be, and `ssize_t` was `UInt64` — so `read(...) < 0`, the test for failure,
  could never be true — while `c_ssize_t` beside it was signed, and `mode_t`
  was four bytes on Darwin, whose `mode_t` is two. Three more differ from C
  in signedness the way this package wants them to — `size_t` so lengths do
  not wrap, `c_char` because a byte is read as a byte, `c_wint` because
  `WEOF` is written as -1 — and each of those now prints its reason. The
  nine names that remain unchecked each print one too, including the five
  letters of an `fopen` mode string.
- **`check-constants` asks about enumerators, about the architecture, and
  compares a sum with the header's own answer.** `#ifdef` cannot see an
  enumeration constant, so `PTHREAD_MUTEX_NORMAL` and the fourteen other
  enumerators in the package were compared with the numbers they are written
  as; the preprocessed headers can see them, and asking about the names they
  spell is what puts them under trial. `PTHREAD_MUTEX_DEFAULT` is an alias of
  another constant, and the sum it is written as now has the header's answer
  for the same name to be compared with — on Linux, `PTHREAD_MUTEX_ERRORCHECK`
  would compile and be wrong. `CompilationTarget.is_x86()` is answerable the
  way `is_macos()` is, since the check runs on the machine that would compile
  the package, which brings the seven `FE_*` bits under trial on both
  architectures. Conditionals that sit inside one another are settled one at
  a time now, innermost last; that is what `FE_ALL_EXCEPT` is, and it turned
  out to be 0x3F on Intel Darwin and 0x9F on arm, where it had been the sum of
  the five standard bits — a set that does not include the sixth flag Darwin
  counts, so `feclearexcept(FE_ALL_EXCEPT)` there left it standing. And an
  expression too long for one line comes back from the
  formatter inside brackets with a Mojo type call in each branch: neither was
  read, so every `LC_*` category was reported as "computed in Mojo" and
  compared with nothing. That one found Darwin's categories holding their
  mask numbers.
- **`check-constants` reads past the brackets Mojo puts round a value, and
  asks about floats by name too.** A conditional too long for one line comes
  back from the formatter inside brackets of its own, and a branch of it is
  usually a Mojo type call — `Int32(0) if not is_macos() else Int32(2)` — so
  every `LC_*` category was reported as "computed in Mojo" and compared with
  nothing. Both wrappers come off now, thirty-nine more constants are checked
  than were, and the name question covers `FLT_MAX` and the rest: `%.17g`
  names a double uniquely, so a value that comes back different is a
  different double. That is how `LDBL_EPSILON` turned out to be the x87
  number on a platform whose `long double` is a `double`.
- **`scripts/check-constants.py` compares a constant with the header of the
  same name, not with itself.** It asked C what the written value meant, so
  `EACCES = 13` was checked by asking what `13` is: that agreed 1078 times and
  could not see a number copied wrong. Asked by name it found `O_RSYNC` at -1
  on Linux, where it is `0x101000`, and `O_DSYNC` at -1 in
  `libc.constant.file` while `libc.fcntl` said `0x400000` for the same
  constant. Three kinds cannot be followed and are listed with the reason
  instead of passing: glibc 2.42 redefined the `B*` line speeds from indices
  to the rates themselves, glibc 2.34 turned `SIGSTKSZ` into a `sysconf`, and
  the `SI_*` and `SIGEV_*` numbers are glibc's in modules that are Linux-only.

## [0.13.0] - 2026-11-04

### Added

- **Six bindings: the old one-signal calls, and the two that move the
  break.** `sighold`, `sigrelse`, `sigignore` and `sigpause` are the
  single-signal spellings of `sigprocmask` and `sigaction` that the BSDs kept
  and POSIX made obsolescent; `brk` and `sbrk` are the allocator's own knob
  said as the end of the data segment and as a distance from it.

  The four are asked in children, because two of them end the process that
  uses them. A child holds a signal with `sighold` and only then raises it,
  so the holding is the only thing between the raise and the end of the
  child: the mask says it is held, the pending set says the raise is still
  there to be acted on, `sigwait` takes it out, and once `sigrelse` opens the
  door the same signal ends the process. A byte down a pipe says how far it
  came, which is what tells a child that died of the holding from one that
  died of the release — and the first draft of this test could not tell them
  apart, because it had blocked the signal by hand beforehand, which the
  mutation probe found by pointing `sighold` at `raise` and watching nothing
  happen. `sigignore` is asked against `sigpending`: an ignored signal is not
  a waiting one. And `sigpause` is asked with an alarm it never held, so being
  ended by `SIGALRM` is what says it waited.

  `sbrk` is asked to move the break and to read it back without moving it
  (`sbrk(0)`), so the place the move reports and the place the reading had
  are the same number, and the reading after it is that number plus 64.
  `brk` is asked only where it is implemented: glibc moves the break to what
  it is given and the reading confirms it, while Darwin's is a stub in
  `Libc/emulated/brk.c` that answers `ENOMEM` without looking at its
  argument, so what is asserted there is the refusal and the break that did
  not move. The call is bound without a return value for the same reason:
  `int` on one platform and `void *` on the other.

- **The six `strto*_l` readers and `strptime_l`.** The sieve's next clean
  family: `strtol_l`, `strtoul_l`, `strtoll_l`, `strtoull_l`, `strtod_l`
  and `strtof_l` read a number for a locale handed in, and `strptime_l`
  reads a date the same way. The number parsing is the part the C locale
  has no say in — ten digits, a sign, a base — so the test reads the same
  text through both spellings and lets each answer be the witness for
  the other, with `endptr` asked where the reading stopped and the one
  fraction `float` loses that `double` keeps. What a locale *does*
  decide — the decimal point, the month names `%B` asks for — is said in
  the docstrings, and waits for a runner that has such a locale to make.

- **The fourteen `_l` forms of the wide-character classes.** `iswalnum_l`
  through `iswxdigit_l`, plus `towlower_l` and `towupper_l` — each is the
  plain call with the locale named instead of the thread's borrowed, and
  the sieve that looks for what is left to bind found them as one family:
  declared in the headers, exported by Darwin's libraries, and of one
  signature (`wint_t` and a `locale_t`) that the package already speaks.
  The test makes a C locale, asks every class about every ASCII
  character both ways — the plain spelling and the `_l` one are the
  witness for each other — and then asks each class about the character
  between it and its nearest neighbour, the pairs that come closest
  being where a symbol pointed at a sibling shows up.

- **`libc.signal.sigaction_t` — the `struct sigaction` the binding said did not
  exist.** Third sample of `--kind order`: 19 caught, 2 crashed, 1 already
  explained, and 2 survivors — `fmaxf`, which is commutative, and `sigaction`,
  which had been called with two NULLs because this package had nothing to
  hand it. A `sigaction` is a handler union, a mask and flags, and the union is
  where the whole thing turns: two of the three things that can go in it are
  numbers, `SIG_DFL` (0) and `SIG_IGN` (1), so a handler of one's own being out
  of reach does not take the other two with it. The struct keeps that word as
  a number and offers the flags behind the mask as the second claim about C.

  It is sized per platform rather than generously, which is the one place in
  the package that is done: 152 bytes on glibc, 16 on Darwin. Handing Darwin a
  152-byte block would not fail — the kernel reads the first 16 and writes the
  same — but this process would have written 136 bytes of somebody else's
  memory into a call. Both offsets (`sa_handler`, `sa_flags`) and both sizes
  are asked of C by `check-layouts`.

  `sigaction` takes `c_ptr[sigaction_t]` now, and the test installs `SIG_IGN`
  with `SA_RESTART`, reads it back, and puts the default back. Reading it back
  is what the survivor was about: with the two arguments swapped the install
  becomes a read and the read an install, and the answer is the default the
  signal had before. `SA_RESTART` came back with a bit that was not asked for,
  `SA_RESTORER` (0x04000000), which glibc adds when it installs an action —
  so the test asks whether the bit it wanted is among them rather than whether
  it is alone. `SIGWINCH` is the signal borrowed for it: nothing sends one, its
  default is to be thrown away, and it is put back at the end.

- **`scripts/mutation-probe.py` asks a second question: two arguments handed
  over the other way round.** Pointing a binding at a sibling's symbol tests
  which function ran; it says nothing about the order the arguments went in,
  and `chown(path, owner, group)` against `chown(path, group, owner)` is the
  same string, the same return type and three arguments of two types — the
  compiler has nothing to say, and a test only has something to say if the two
  numbers in those positions differ. `--kind order` swaps two neighbours of
  the same declared type and runs the tests that call it.

  The first sample of twenty-four came back 13 caught, 2 that took the process
  down, and 9 that passed: three times the rate of the symbol axis on a sample
  of the same size. That is the measure of how much more of this suite proves
  which call ran than proves how it was asked. A second sample of twenty-four,
  from a different seed, found 10 more; after the assertions below it comes
  back 16 caught, 2 crashed, 6 that are the same call with the arguments
  exchanged, and none unaccounted for.

- **`scripts/check-duplicates.py` asks for one signature per symbol, not
  just one file.** The two questions are the same question one step apart. Two
  files binding one symbol disagree in a way a reader of either cannot see;
  one file binding one symbol twice disagrees in a way the compiler cannot see
  either until something calls both. C's `fcntl` was bound with the two
  arguments POSIX lets a caller give it and with the three its commands take,
  and each form was right about itself: a program that called either one built
  and answered. A program that called both stopped at lowering with `existing
  function with conflicting signature` — one symbol declared twice, a message
  that names the symbol and not the call written second, and a failure that
  arrives in a build rather than in a test. What found it was wanting to ask
  the two-argument form a question, which is now the question the test asks a
  three-argument form: the two-argument one is gone and the commands that read
  nothing are given 0.

  The guard is proven the way the others were: put a second form back, in the
  same file and in another one, and see it name both.

- **`fprintf`, which was missing while `printf`, `dprintf`, `sprintf` and
  `snprintf` were all here.** Like them it writes a format with nothing to
  fill in — a conversion lives in the variadic part and `external_call` cannot
  hand one over — and what it adds is the stream: a `tmpfile` takes the line
  and gives it back byte by byte, which is what the test reads.

- **What the variadic wall costs is written down now.** `ioctl`'s third
  argument is the address nearly every request writes its answer through, and
  it cannot be passed: `external_call` emits a call whose arguments are all in
  registers, and on arm64 a variadic callee reads its anonymous arguments from
  the stack instead. `FIONREAD` through the binding answers 0 on Apple silicon
  and leaves the integer it was asked about untouched — a probe on a runner
  showed it, and the same probe showed `fcntl`'s three-argument form losing
  its argument the same way. Both docstrings say so now, `modules.md`'s list
  of what the suite cannot ask carries the reason rather than "variadic", and
  `docs/beyond-c.md` has the paragraph. Nothing about the bindings changed;
  what changed is that two of them no longer read as if they worked.

- **`libc.limits`, the numbers in `<limits.h>`.** Twenty-four constants of
  two kinds. The widths of the integer types — `CHAR_BIT`, `INT_MAX`,
  `LONG_MIN`, `ULLONG_MAX` and the rest — which are the same on both
  platforms here and are what a caller reads to decide what to cast into.
  And the limits the system puts on a process, which are not the same:
  `PATH_MAX` is 4096 on Linux and 1024 on Darwin, `PIPE_BUF` is 4096 and
  512, `NGROUPS_MAX` is 65536 and 16, `MAX_CANON` and `MAX_INPUT` are 255
  and 1024. A buffer sized from the Linux answer is a buffer that overflows
  on the other machine, which is the reason these are worth asking for
  rather than writing down.

  `MB_LEN_MAX` is deliberately absent. It bounds the bytes a multibyte
  character can take — 16 on glibc and 6 on Darwin — and it is not a number
  a caller sizes anything from; `MB_CUR_MAX`, which is a call and not a
  constant, answers that for the encoding actually in use.

  Five of these were already somewhere else. `PATH_MAX`, `LONG_MAX`,
  `LONG_MIN`, `ULONG_MAX` and `ULLONG_MAX` sat in `libc.stdlib`, a module
  for `<stdlib.h>`, which is not the header that defines them; they moved
  here and `libc.stdlib` imports them back, so `from libc.stdlib import
  PATH_MAX` keeps working and answers the same number. `INT_MIN` and
  `INT_MAX` left `libc.constant` for the same reason. And `wcstoll`'s
  docstring told the reader to take `LONG_LONG_MAX` and `LONG_LONG_MIN`
  from `libc.constant` — a name C does not have, in a module that did not
  export it; it now points at `LLONG_MAX` and `LLONG_MIN` here.

  The tests do not repeat the numbers, because `scripts/check-constants.py`
  already asks C for every one of them on every platform the suite runs on.
  They assert what the numbers mean instead: every unsigned max is
  `2 * signed_max + 1` and every signed min is `-signed_max - 1`, in
  arithmetic one type wider so the check cannot overflow; `char` is signed
  and `long` is as wide as `long long`; and the two calls the file limits
  are for work — a `PATH_MAX` buffer holds what `getcwd` writes, and
  `PIPE_BUF` bytes go into a pipe in one `write` that is neither short nor
  split.

- **`libc.uchar`, the C11 conversions between the locale's encoding and
  UTF-16 or UTF-32.** Four calls — `mbrtoc16`, `mbrtoc32`, `c16rtomb`,
  `c32rtomb` — and Linux only, because glibc has `<uchar.h>` and Darwin has
  no such header at all: not in the 10.15 SDK, not in 14.4, and not in
  Apple's Libc sources.

  Two of the four are why this is worth having. A character above U+FFFF is
  one UTF-32 character, four UTF-8 bytes and two UTF-16 code units, and C11
  splits that work over two calls: `mbrtoc16` consumes the four bytes and
  writes the high surrogate, and the next call writes the low one and
  answers `(size_t) -3` with nothing read. `c16rtomb` is the same pair the
  other way round — the high half answers 0 and writes nothing, and the four
  bytes arrive with the low half. A loop that takes every answer for a byte
  count drops half of every character outside the BMP, and `-3` is the only
  thing that says so.

  The tests ask both directions on U+1D11E, and the answers that are not a
  character: `-2` for bytes split across two reads, and `-1` with `EILSEQ`
  for a byte that starts nothing. Two places glibc differs from C11 are
  written down, and both are asserted: a null output pointer answers 1 for
  every character rather than the length it would take, and clears the
  state on the way; and a code point above U+10FFFF is encoded rather than
  refused, as the old four byte form — U+110000 comes back `F4 90 80 80`,
  which no UTF-8 decoder reads back.

  The conversions read the calling thread's locale, and the suite runs in
  `C`, where nothing above ASCII converts, so the tests move this thread
  into `C.UTF-8` with `newlocale` and `uselocale` and put it back
  afterwards. That cost a run: `newlocale` takes `LC_CTYPE_MASK`, which is
  `1 << LC_CTYPE`, and the category `LC_CTYPE` itself builds an object that
  changes nothing without returning an error. `newlocale`'s docstring now
  says so, since the masks are not bound and a caller has to spell one.

- **`libc.locale` has the seven `LC_*_MASK` constants, which are what
  `newlocale` takes.** They are a second numbering rather than a shift of
  the categories: glibc's `LC_CTYPE_MASK` is `1 << LC_CTYPE`, and Darwin
  numbered its six alphabetically, so there `LC_CTYPE_MASK` is `1 << 1`
  while `LC_CTYPE` is 2. The two `LC_ALL_MASK`s come to 8127 and 63,
  because glibc has six more categories to cover. Both platforms' numbers
  are checked against C by `scripts/check-constants.py`, which needed
  Darwin's `xlocale.h` in its header list to see them there.

  Six tests were calling `newlocale(LC_ALL, …)`: a category where a mask
  belongs, which is neither an error nor a locale — the object comes back
  with a good pointer and changes nothing. They pass `LC_ALL_MASK` now.
  Nothing observable changed, since the global locale was already `C`, and
  that is the point: it was wrong in a way no test could see, and it cost
  the first run of `test_uchar` a C-locale `EILSEQ` before the mask was
  found.

- **`prctl` asked the questions it answers without changing anything.** It
  was on the cannot-ask list as Linux's own and as a call that changes the
  process it is made on. The second half is only true of some of its options:
  `PR_GET_DUMPABLE` and `PR_GET_TIMERSLACK` read, and the one write that is
  asked — setting the kernel's name for the calling thread — is put back the
  way it was found before the test returns, so the rest of the suite sees
  what it started with.

  `PR_SET_NAME` followed by `PR_GET_NAME` gives back the name that was put,
  and that round trip is what shows the `char *` in the second argument
  arrived as a pointer rather than as the address written down as a number.
  `PR_GET_DUMPABLE` answers 0 or 1 and is not pinned to either, since a
  process started set-user-ID may not dump core; `PR_GET_TIMERSLACK` answers
  a positive count of nanoseconds, and which count is the kernel's to choose.
  The last question is the refusal: an option number that is not one of
  `prctl`'s own comes back -1 with `EINVAL`, and without it "returned 0"
  would only mean "returned".

  The docstring had said that no `PR_*` constant was bound beside this call,
  and eighteen of them were; it now says what the arguments mean instead.
  Five reasons are left on the list, and the count on the modules page moved
  from 994 asked and 6 not to 995 and 5.

- **The last two bindings that needed a second thread: `pthread_cond_wait`
  and `pthread_cancel`.** Both were on the cannot-ask list because the suite
  runs one thread, and neither needed one started — a forked child is enough
  if the two of them are looking at the same bytes.

  `pthread_cond_wait` waits on a condition the child signals. A fork copies
  the page, and a copy of a condition variable is a different condition
  variable, so the condition and its lock are made in a `MAP_SHARED` page
  with `PTHREAD_PROCESS_SHARED` set on both. The ordering is what makes the
  wake-up impossible to miss rather than merely unlikely: the parent takes
  the lock **before** the fork, so the child's own `pthread_mutex_lock`
  cannot succeed until the parent is inside the wait, where the lock is let
  go. Nothing sleeps to stand in for that. The wait answers 0 with the lock
  held again, which is checked by unlocking it, and a ten-second `alarm`
  turns "no wake-up" into a failed run rather than a job that hangs until
  it times out.

  `pthread_cancel` cannot be taken back, so it is asked of a child and the
  child is what ends. Two children ask, and the difference between them is
  one call: with cancellation left enabled the child never comes back from
  `usleep` to write the byte after it, and with
  `pthread_setcancelstate(DISABLE)` in front of the request it does come
  back and leaves with 0. Either half alone would be passed by a cancel
  that did nothing, which is why both are there.

  How the enabled child ends is not asserted, because the platforms do not
  agree: glibc ends the process with status 0 at the cancellation point and
  Darwin ends it on a signal. A probe run on both said so before the
  assertion was written, which is cheaper than guessing and finding out
  from a red macOS job.

  Six remain, all with reasons that are about the call. The count on the
  modules page moved from 992 asked and 8 not to 994 and 6.

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

- **`scripts/check-duplicates.py`, one file per C symbol.** Two modules can
  bind the same call to two signatures that look alike and are not, and
  both compile, so nothing here ever compared them. Twenty bindings were
  like that: `strlen` answered `UInt64` in `libc.string` and `Int` in
  `libc.utils`; `read` took `c_ptr[c_void]` in `libc.file` and
  `c_ptr[UInt8]` in `libc.unistd`; `ldiv` read `long` in `libc.stdlib` and
  `Int64` in `libc.math`, and each module had its own `ldiv_t` to go with
  it. The check asks the one question a copy cannot answer — which file
  binds this symbol — and the fix is a re-export, so a module that wants to
  offer a call another module owns imports it and the two names are one
  function rather than two that agree today. An alias inside one file is
  still allowed, because `gamma` and `lgamma` are the same symbol under two
  names deliberately and whoever reads that file can see both; the same
  pair in two files is what this refuses.

- **`scripts/mutation-probe.py`, which points a binding at the wrong
  function and asks whether any test notices.** `check-tests.py` asks that
  every binding be called, and `_ = f(...)` counts, so a test that asks a call
  for its answer and then throws the answer away is green against the wrong
  symbol — the shape of the `gamma`/`tgamma` bug. Two bindings in one file
  with the same signature are what the compiler cannot tell apart, so one is
  pointed at the other's symbol and the tests that call it are run. Not a
  gate: every mutant is a rebuild of the package and a suite run, so it
  samples, with `--only` for named bindings and `--strict` to fail on a
  survivor that is not a pair known to answer the same thing.

### Fixed

- **`pthread_atfork` was said to be unreachable from Mojo, and it is only
  unreachable from the JIT.** The docstring said a lookup by name finds
  nothing, "so the call cannot be made from Mojo at all". Built and run, the
  same source answers 0: the linker resolves `pthread_atfork@GLIBC_2.2.5`
  once, where the just-in-time run asks for the bare name and is told
  `Symbols not found: [ pthread_atfork ]`. Both were measured before the
  sentence was rewritten, and the test file says the same thing now.

- **The README still said the version was `0.2.0`, ten releases after it
  stopped being.** Nothing reads the front page, so nothing noticed: the
  places `check-release` compared all agreed with each other, and the one a
  stranger reads first was the only one that did not. It states `0.12.0` now,
  and `scripts/check-release.py` reads that line back out of `README.md`.

  The Mojo range on the same page is read the same way, and it was a place
  nothing had ever compared. Three ways of getting it wrong — the number, the
  range, and the line going missing — were each tried before the sentence
  above was written, and each of the three fails the check with the file
  named and the two answers shown.

- **`docs/beyond-c.md` was dividing one count by another, and neither could
  be right everywhere.** The page opened with three figures — 3574 functions
  published, 1012 of the bound symbols among them, 28.3% — taken from two
  different `nm` filters, so the percentage divided one set by another.

  Counting them was put into `check-prototypes` and taken back out again the
  same day: the denominator is whatever glibc the run happens to have, and
  the same commit counted 3701 of them on one machine and 3985 on the next,
  which makes a check that compares the page against this machine and passes
  only on this machine. What the page says now is the number that is the same
  everywhere — 1026 symbols, read out of the source — and a quarter, with the
  digits left out because they would be wrong somewhere.

- **The new signal test freed the same block twice.** Its second scenario
  reused the `status` buffer the first had already freed, so the second
  `waitpid` wrote through a dangling pointer and the second `unsafe_free`
  freed the block again. Run on its own the file passed; run before the rest
  of the suite it left the allocator holding a cycle, and a later
  `unsafe_free` crashed inside `_free`. What found it was the suite and not
  the file, which is the one thing that would not have happened if the test
  had been checked only where it was written.

- **`tests/test_import_all.mojo` is a test again.** It lists every public name
  in every sub-package and imports it, which is how a name that a platform
  does not export is found here rather than in whatever a caller was doing. It
  had two names that no longer exist — `fflush`, which `libc.file` stopped
  binding because `std.io` declares the same symbol, and `close`, which moved
  to `libc.unistd` — and the suite was green the whole time.

  It was green because imported from `test_main.mojo` none of it is checked:
  Mojo resolves the names a function body *uses*, and these functions use none
  of the ones they import, so every import in the file is dropped before
  anything looks at it. The function still ran, still printed `ok`, and proved
  nothing. Run as the module the compiler starts from, the same file fails to
  parse — which is what `pixi run test-imports` does now, and what the lint job
  in CI does. The call from the runner stays, because it is harmless and
  because what it does not do is worth knowing.

### Removed

- **`fcntl`'s two-argument form, which could not be used with the
  three-argument one.** Both were bound and each worked on its own — a program
  that only asked `fcntl(fd, F_GETFD)` built and answered, and so did one that
  only set a flag. A program that did both did not build at all: one symbol
  with two signatures, and the compiler stops when it lowers the module with
  `existing function with conflicting signature`, which is nowhere near the
  call that was written second. The three-argument form is the one every
  caller here already used, so it is the one that stayed, and a command that
  reads nothing is given 0. The docstring says which commands lose their
  argument on Apple silicon — the ones that set something — and why the ones
  that only ask are unaffected.

- **Two bindings that could be called on neither platform: `isascii_l` and
  `sched_getcpucount`.** Both sat on the cannot-ask list with the reason
  that glibc does not export them, which was true and was half the story:
  the other half was that Darwin does not have them either, and nobody had
  asked. `isascii_l` is a macro in glibc's `<ctype.h>` — `#define
  isascii_l(c,l) __isascii_l((c),(l))`, itself a macro over `__isascii` —
  so there is no symbol behind the name, and Darwin's `xlocale/_ctype.h`
  spells only `isascii`. `sched_getcpucount` is FreeBSD's: glibc neither
  declares nor exports it, and Darwin's `<sched.h>`, which is a link to
  `pthread/sched.h`, holds `sched_yield` and the two priority bounds and
  nothing else.

  A binding for either compiled, sat in the package looking bound, and
  would have failed its first caller at load time — which is also why no
  test caught it: a test that calls one fails to load rather than to
  assert. What catches it now is `scripts/check-symbols.py` reading
  `NOT_DECLARED_HERE` out of `scripts/check-prototypes.py`. A name that no
  header here declares and no library here exports has nothing on this
  machine vouching for it, and two whitelists excusing the same name is
  what the two reasons above amounted to. The pair fails the run, so the
  next binding in that state has to be removed rather than excused.

  The modules page loses two names from the cannot-ask list — three are
  left, all of them about the call — and the counts move from 995 asked and
  5 not to 995 and 3.

### Changed

- **Five tests now fail when a binding hands its two arguments over in the
  other order**, which is what `--kind order` found by making that happen.
  `socketpair(AF_UNIX, SOCK_STREAM, ...)` was handed 1 and 1, which are the
  two constants, so both orders were the same call; a datagram pair is type 2
  and `getsockopt` says which kind came back. `strncasecmp` was asserted equal
  to a string differing only in case, and equal is the answer a swap gives
  too; it is asserted to sort two different strings now. `atan2(1, 1)` is on
  the diagonal, where the answer does not depend on which argument is which,
  and three quarters of pi is off it. `iconv_open("UTF-8", "UTF-8")` is one
  name written twice: UTF-8 to UTF-16LE turns two bytes into four and the
  other way round turns the same two into three. `execve` was only ever
  watched failing, and a program that is not there fails the same way
  whichever list is in which slot, so the test runs `/bin/echo` and reads what
  it printed.

  Four more were explained rather than fixed, and the reason is in the
  script's `SAME_ORDER`: `fmax` and `hypot` are commutative, `openlog`'s two
  integers are read by a daemon whose file this process never reads,
  `catgets` has only a catalog that did not open, and every `chown` a suite
  without a privilege can ask about fails before the two ids are looked at.

- **Five more from the second sample of `--kind order`.** `posix_memalign` was
  handed a size that is a valid alignment (64), so the swap was answered; 48 is
  not a power of two, and a binding handing it over as the alignment is refused
  with `EINVAL`. `tcsendbreak` was given a duration of 0, which put the real
  descriptor where the call ignores it and a 0 where the descriptor goes, and
  whether 0 is a terminal is a property of the runner; it is given 100000 now,
  which is nobody's descriptor, so the swap gets `EBADF` where the test holds
  out for `ENOTTY`. `strncasecmp_l` and `wcsncasecmp_l` were held to "not
  zero", which is the answer both ways round; the sign of the answer is not.
  `nextafter` was bounded above and below, and a step in *either* direction
  passes both bounds — what is asserted now is the size of the step, one ulp
  past the argument it steps away from.

  Five more were explained instead: `fminf` and the `x` and `y` of `fma` are a
  minimum and a product, `calloc`'s block and its overflow check are both the
  product of `nmemb` and `size`, `scandir`'s two callbacks are both NULL
  because this FFI cannot hand C a function address, and `fchownat`'s call is
  refused before the two ids are read.

- **Two more from the fifth sample of `--kind order`.** That sample came back
  17 caught, 2 crashed, 3 that are the same call and 2 that passed. `lockf` was
  asked with `-1`, which is refused before the command is read, so the swap
  answered `-1` too; it is asked about a real file now, where `F_TEST` on a
  range nobody holds is 0 and the swap asks for descriptor `F_TEST` with the
  file's own number as a command. `sscanf` is the first survivor that no input
  can separate: the places a conversion writes to are in the variadic part this
  FFI cannot pass, so the format has no conversion in it, and a format with
  nothing to convert answers 0 for any input — which is written into
  `SAME_ORDER` rather than asserted differently.

- **The order axis swept rather than sampled.** All 191 swaps in one run: 146
  caught, 11 crashed, 13 that are the same call and 20 that passed. Five
  samples of twenty-four had found eleven of those twenty; the other nine were
  in candidates no sample happened to draw, which is the measure of what
  sampling was leaving on the table. With those dealt with the same sweep comes
  back 152 caught, 11 crashed, 27 the same call and none unaccounted for.

  Five had an assertion to write. `powf(2, 10) - 1024 < 1e-6` is true of every
  answer below 1024 and therefore of `powf(10, 2)`, and `nextafterf` was
  bounded on each side, which a step from either end satisfies; both are asked
  for an absolute distance now. `tcflush` is the descriptor lesson again.
  `pthread_sigmask` was asked twice with the same empty mask in both positions,
  so it never mattered which came first; it blocks `SIGWINCH` and watches the
  mask change now, and puts it back. `setpgid(0, 0)` names "this process" and
  "its own group", both zero; it names the group it is in — a move to where it
  already is — so the swap names that group as the process and is refused.

  Nine more went into `SAME_ORDER` with their reasons: `fmin`, `hypotf` and
  `fmaf` are float twins of calls already there, `pthread_equal` is a question
  with no order in it, and the rest are an id this process cannot change
  (`setreuid`, `setregid`, `lchown`, `adjtime`) or a call that fails on its
  first argument before reading the second (`getnetgrent`, `innetgr`,
  `aligned_alloc`, `mbsnrtowcs`, `wcsnrtombs`, `sched_setscheduler`).

  The twentieth was `sigaltstack`, asked with two NULLs because there was no
  `stack_t` to give it, which is the `sigaction` story over again.

  It is bound now, and it is the sharpest of the three, because there was
  nothing to see: glibc's `stack_t` is a pointer, four bytes of flags and a
  size, Darwin's is a pointer, a size and four bytes of flags, and both are 24
  bytes and 8-aligned. Written with glibc's order it agreed with the layout
  check, which asks one header, and with the tests, which run where that header
  is — and the macOS job was the first thing to disagree: a stack installed
  with the size where the flags go has flags of 131072, which is not a flag,
  and is refused with `EINVAL`. The offsets are two numbers now, and the header
  checks in the test job run before the suite, so the next one fails in the
  check that names the member instead of in the test that used it.

  The test installs a stack of `SIGSTKSZ` bytes, reads it back and puts the old
  one back; a swap installs what the read buffer held, which is no stack at
  all, and is refused with `EINVAL`. Writing it turned up something else worth
  knowing: the runtime puts a handler on `SIGUSR1` and an alternate stack under
  it, so the suite's own process has one already, and the restore is measured
  against the first read rather than against zero.

- **The symbol axis swept: 574 mutants, 175 survivors, and `math` is now 0.**
  376 caught, 4 crashes, 7 hangs, 9 that are the same call, 175 that passed —
  the sample of twenty-four had been finding a fraction of what was there. The
  probe also takes `--jobs`, which is what makes a sweep of the axis half an
  hour rather than four.

  `math` had 31 of them and two causes. The trigonometry was asked at nothing,
  where six of those functions answer nothing and two answer one, so most of
  the twelve could have been pointed at `fabs` and nothing would have said so;
  they are asked at a half now, where the twelve answer twelve different
  numbers. The rest was `answer - expected < epsilon`, which is true of every
  answer below the expected one: `hypot(3, 4)` answered by `fmod` is 3, and
  3 - 5 is under 1e-9. Every difference in `test_math` and `test_stdlib` is a
  distance now, and `fmin`/`fmax` moved off one and two because `fmod` answers
  its first argument when it is the smaller. Two of the thirty-one are the same
  call (`llround`/`lround`, `ldexpf`/`scalbnf`) and are written down as such.

- **The symbol axis, second pass: `complex` and `pthread` are down to four
  unexplainable survivors between them.** `complex` was sixteen functions all
  answered by `conj` if asked at the origin, and they are asked at a half plus
  a half of i now, where every answer has an imaginary part that is not
  nothing. `pthread` was the `_init`/`_destroy` pairs -- both answer 0, and
  `_destroy` leaves the object as it found it -- and the `get`/`set` pairs
  asked for what a new object has. The resets are what is asserted now, and the
  pairs are asked with values no default has: a `FIFO` policy, a priority of
  seven, a detach state that is not the scope's number. The condition variable
  gets a second round in the cross-process test with `_broadcast` in the child,
  because with one waiter `_signal` and `_broadcast` are the same wake-up.

- **The sweep is done: the last twenty-nine, and none of them survived.**
  `rmdir` was called for its 0 and not asked whether what it took was gone,
  which `chdir` -- same path, same 0 -- would not have taken with it;
  `sigemptyset` and `sigpending` are asked while a blocked signal stands in
  the queue, which is the one moment an emptied set and a pending set differ;
  `aio_fsync` was allowed the answer -1 that `aio_cancel` also gives, and is
  held to 0 now; `posix_spawn` and `posix_spawnp` are told apart by a bare
  name, the one shape the two disagree on, and the `init` calls are given a
  block full of bytes no allocator made, which `init` cleans and `destroy`
  dies on. `termios` wanted a real line: a pty is opened, echo turned off,
  and `tcflush` is held to having emptied a queue that had bytes in it,
  `tcflow` to the stop character arriving on the other end, `tcdrain` and
  `tcgetsid` to the difference between 0 and a session -- `tcgetsid` asked by
  a child that has taken the line for its own terminal. `herror` says what it
  says with the error stream taken away and read back, and `setnetgrent`, the
  call next to it in the table, is held to having said nothing;
  `getutxid` and `getutxline` are each given a probe that names one thing and
  asks for the other. Three speed setters are one storage on this platform,
  measured -- two different speeds were set and one came back through both
  getters -- and ten are in the third table with the measurement written
  down: the walks that start again whichever of their calls is made, the
  break that leaves nothing a read finds, the branch of `get_errno` this
  machine does not run.

- **`file`, `fenv`, `netdb` and `unistd`: ten more caught.** `clearerr` was
  asked whether it cleared the flag and not whether it left the stream where it
  was -- which is what `rewind` does not; `feholdexcept` was asked to answer 0
  with no flag standing, and the flags being quiet is the whole difference
  between it and `fegetenv`; `hstrerror` and `gai_strerror` are asked to say
  different things about the same number; `sleep` is timed either side of a
  second, since its answer of 0 is `close`'s answer too; `fchdir` is asked
  where the process is afterwards -- from `/` rather than from `/tmp`, which it
  was already standing in; `gettid` is asked to equal `getpid`, and `fork` is
  what it would otherwise have been; `execv` and `execvp` are asked in a child
  about a bare name, which is the one shape they disagree on; and
  `getusershell` is asked for a path, which `getlogin` does not hand back.
  `setusershell` against `endusershell` is unobservable and measured: the walk
  starts again either way.

- **`string`, `sched`, `network` and `time`: nineteen survivors, and only one
  of them left.** `memcpy` was called for its side effect and not asked what it
  answered, which is the one thing `mempcpy` answers differently; `strcmp` was
  asked about a pair that differs in more than case; `bcmp` about blocks with
  no nothing in them, where the string comparison that could stand in for it
  stops; `strcoll_l` about a pair the folding neighbour folds away;
  `strsignal` was asked whether it said something rather than whether it said
  something about a signal. `sched_getparam` was given zeroed room, which is
  what a `sched_setparam` would have left; the priority pair was asked about
  the one policy where the two answer the same number; `sched_setaffinity` was
  given back the set it had just read, which is not a change — an empty set,
  which it refuses, is. `clock_getres` was asked to answer 0 and not to answer
  a resolution; `gmtime` and `localtime` were read on a machine that keeps UTC,
  where they are the same call, and are read under a `TZ` five hours away now.
  Six are one routine under two names, measured with `dlsym`: `memcpy` and
  `memmove`, `mktime` and `timelocal`, and the two byte-order pairs, which are
  the same arithmetic on every input. `strcoll` against `strcmp` is in the
  third table, C-locale collation being code-point order.

- **`stdio` and `stdlib` had twenty-three between them, and eight are now
  caught.** The stream calls were being asked for what a call with the same
  signature answers anyway: `pclose` was not asked for its status, so `getc`
  would have done; `tmpnam` was asked for a name and not for the name of
  something that does not exist, which is what tells it from `ctermid` looking
  the other way; `fgetpos` was asked to write the place down and never asked
  whether it also moved the stream, which is `fsetpos`; `setlinebuf` was
  checked by reading the line back through the same stream, which flushes it,
  so a stream that was not line-buffered answered the same. `valloc` was never
  asked where its room begins -- the one thing it is for, and a number a
  pointer can be turned into. `exit` and `_Exit` were separated by a child that
  leaves with 42 either way, and are separated now by a buffer that one empties
  on the way out and the other does not. `strtoll`/`strtoq` and
  `strtoull`/`strtouq` are one address each in glibc, measured with `nm`.
  Eleven are unobservable and are in the third table with the reason: the
  locked and unlocked spellings of one byte in and out need a second thread to
  contend for the lock, `flockfile` and `funlockfile` are the same wall,
  `secure_getenv` needs a process that is not privileged, and `valloc` answers
  with everything `malloc` promises plus alignment.

- **`sys` had fourteen survivors and thirteen of them are now caught.**
  `munmap` was leaving nothing to observe, so the test asks `mprotect` on the
  address it gave back -- not a mapping any more, which is `ENOMEM`. `mlock`
  and `munlock` are separated by the one condition that tells them apart: with
  `RLIMIT_MEMLOCK` brought down to nothing the first is refused and the second
  still answers 0. `mprotect` is asked from a child that writes to the page it
  made read-only, which is the only way to see a refusal that would end the
  process asking; `msync` by flags only it validates, `posix_madvise` by the
  error number it returns rather than puts in errno, `epoll_create1` by being
  called with no flags at all (a size of 0 is what `epoll_create` refuses),
  `lutimes` and `utimes` on a link rather than a plain file, `setrlimit` by
  lowering the limit by one and reading it back, and `get_avphys_pages` by
  taking a quarter of a gigabyte and watching which of the two numbers moves.
  `get_nprocs` against `get_nprocs_conf` is the one left, and it needs a
  machine with a processor taken offline.

- **`RLIMIT_MEMLOCK` is bound**, on both platforms, so that a lock can be asked
  for where it cannot be granted.

- **The wide-character calls, asked where a count and a string differ.**
  `wchar` had fourteen survivors and seven of them were the `wmem` family:
  a count and a string are the same thing until something in the middle is a
  terminator or the count runs past it, so `wmemcmp` is asked about a run with
  a nothing inside it and `wmemcpy` and `wmemmove` about counts that run past
  the end, where the `wcs` copy would start filling with nothings. `wcscmp` and
  `wcsncmp` are asked about a pair that differs only in case, which is the one
  thing the case-folding neighbours fold away. `wcscpy` is asked to copy onto
  something, since from empty a copy and an append are the same five
  characters. Four are the same call under two spellings (`putwc` and
  `fputwc`, `getwc` and `fgetwc`), and three cannot be separated under the C
  locale at all -- `btowc` against `wctob` and `wcscoll` against `wcscmp`,
  both measured rather than assumed.

- **A third table in the probe, for pairs that no defined observation
  separates.** `pthread_attr_destroy` and `_init` answer the same 0 and differ
  in what may be done with the object afterwards, which after a destroy is
  undefined; calling that "the same answer" would have made the table read as
  an answer when it was a hole. `NO_OBSERVATION` asks for the same kind of
  written reason and is checked for staleness the same way, so the four entries
  in it are four things somebody measured rather than four things nobody
  looked at.

- **`scripts/check-magnitudes.py` asks every tolerance which side it holds.**
  A tolerance written as `answer - expected < epsilon` is a one-sided bound
  with a `fabs` missing, and it passes for every answer below the expected one.
  The script reads every `assert_true` in the suite and requires the thing
  compared with the tolerance to be the absolute value of the whole difference
  — `fabs(answer) - expected` fails it too, because the absolute value went on
  the answer rather than on the distance. It found a ninth line the day it was
  written, in `test_stdlib`, where no mutation sample had ever landed.

- **The probe's two tables of reasons are checked, in the one direction that
  does not need a suite run.** A reason is read only when its mutant survives,
  so an entry that has outlived its pair excuses a mistake nothing makes any
  more. `--check-tables` (`pixi run mutation-tables`, wired into the Lint job)
  rebuilds the mutant list and reports every entry that no longer names one:
  a renamed parameter, a third binding added to a file so a different sibling
  is the first one found, a signature change that stops the call being handed
  its own parameters. The other direction is reported by a run: a reason whose
  mutant is caught now is a reason that can be deleted, and `--strict` fails on
  it. Both directions were made to fail on purpose before either was believed.

- **`scripts/check-comparisons.py` asks every comparison which way it leans.**
  Seven of the survivors across four samples were one shape: an assertion that
  is true whichever way round the two arguments went — `!= 0` on two strings
  that differ, `== 0` on two that agree, a bound above and a bound below. That
  is not a sample any more, it is a rule, and a rule can be asked of the whole
  family at once: every binding whose symbol ends in `cmp` or `coll` must have
  one assertion comparing the answer with zero rather than with `!= 0`.

  Nineteen of them do. `bcmp` is in the family by name and answers only zero or
  not, which is written down in the script beside the reason, and an entry that
  stops being true fails the run. The script found `strcasecmp_l` on its first
  run — no sample had landed on it — and closed four more before a sample could:
  `wcsncmp`, `wcscasecmp`, `wcsncasecmp` and `strcasecmp_l`.

- **Two more from the fourth sample of `--kind order`.** That sample came back
  19 caught, 2 crashed, 1 that is the same call and 2 that passed.
  `wmemcmp(abc, abd, 3) != 0` is the same-either-way-round failure again, and
  is asked which way it leans now. `tcflow` is the descriptor lesson in a new
  place: on a descriptor that is not a terminal neither argument is looked at
  past the descriptor, so both positions answered `ENOTTY`; a descriptor that
  is not one at all is refused before the action is read, so `-1` answers
  `EBADF` where the swap asks for descriptor `TCOOFF` — 0 on glibc, 1 on
  Darwin — and answers whatever a pipe or a terminal says about an action that
  is not one.

- **Three more from the third sample of `--kind order`.** That sample came back
  18 caught, 2 crashed, 1 that is the same call and 3 that passed. `fchown`
  was asked with `-1`, which is refused before the two ids are read, so the
  swap was answered `-1` as well; a descriptor that exists is what tells them
  apart — a file given to the owner it already has answers 0, and the swap asks
  for descriptor 1000, which no process has. `wcscoll(one, two) != 0` and
  `wcscasecmp_l(hello, shout) == 0` are one failure wearing two names: an
  answer that is the same either way round. Two strings that differ do not stop
  differing when asked in the other order, so the sign of the answer is what is
  asserted now, in both directions.

- **Three tests now fail when the binding underneath them calls the wrong
  function, and the mutation probe has a verdict for a test that waits instead
  of failing.** A third sample of twenty-four mutants found `pow` held to a
  bound from above — `fmod(2, 10)` is 2, which is under 1024 — `getpgid` held
  only to being positive, which `getsid` is too, and `chown` asked only about
  a file that is not there, which `lchown` answers the same way. What
  replaced them: two to the tenth exactly, a new process group named after the
  process that made it, and a link whose target is not there — `chown`
  follows it and gets `ENOENT`, `lchown` changes the link itself — which is
  the one file that separates the pair without a privilege the test does not
  have. Two more turned out to be the same call under two names rather than
  calls nothing looked at, and each says why: `cfgetospeed` and `cfgetispeed`
  read the same `CBAUD` bits of `c_cflag` on glibc, and `endgrent` and
  `setgrent` both leave the next `getgrent` at the first row.

  One mutant — `pthread_rwlock_rdlock` pointed at `pthread_rwlock_destroy` —
  left the test waiting rather than failing, and the run ended in a traceback
  at the timeout with the mutants after it never asked. That is a verdict of
  its own now: `hung`, counted in the tally, and the run goes on to the rest.

- **The errno test runs on macOS again, and the reason it did not was the
  variadic argument.** `test_errno` was skipped on that side with a note about
  the runner hanging somewhere around a read of a non-blocking pipe, and the
  note was right and the diagnosis behind it was not: the read end was made
  non-blocking with `fcntl(fd, F_SETFL, O_NONBLOCK)`, the flag never arrived
  on arm64, and the read waited for a byte that was not coming. A fifo opened
  with `O_NONBLOCK` in the `openat` call says the same thing with an argument
  that has a name, and a read of it with nothing in it answers `EAGAIN` on
  both platforms — 11 here and 35 on Darwin, which is the number the test
  exists to pin down. What it cost was a job that timed out rather than an
  assertion that failed.
  - And `fcntl`'s two questions have a test of their own now: `F_GETFD` and
    `F_GETFL` on a descriptor opened with `O_CLOEXEC` and `O_NONBLOCK`, then
    the same two on a descriptor opened with neither, then `-1` with `EBADF`
    on one that is not there. They are the commands that never look at the
    third argument, which is what makes them worth asking on both platforms.

- **Four tests now fail when the binding underneath them calls the wrong
  function**, which is what `scripts/mutation-probe.py` found by making that
  happen. `strncmp`'s two strings were the same case, so `strncasecmp`
  answered identically; `endhostent` was called and never observed, so
  `endprotoent` — next line, same shape — passed; `alarm` was asked twice for
  nothing, which `close` also answers 0 to; `getdomainname` was held only to
  writing fewer than 256 bytes into a 256 byte buffer, which `gethostname`
  does too. What replaced them: a case-differing `strncmp` comparison, a
  `gethostent` after the database was shut starting over at the first row,
  ten seconds armed and taken back unspent, and `uname`'s `domainname`
  agreeing on the one platform whose `utsname` carries it. The same
  twenty-four mutants now come back 21 caught by an assertion, 2 the same
  function under two names, and 1 that took the process down rather than fail
  an assertion.

- **Every C symbol is bound in one file now**, and the name is imported
  where a second door was wanted:

  - `libc.file` still answers for `read`, `write`, `close`, `lseek`,
    `pread`, `pwrite`, `fcntl`, `openat` and `creat` without binding any of
    them. They are `libc.unistd`'s and `libc.fcntl`'s, and the module that
    promises "the descriptor-level calls" now imports them, so a caller
    gets the same signature whichever module they came through.
  - `libc.stdio` keeps `fputc` the same way: it belongs to `libc.file`
    with the rest of the stream lifecycle, and is imported there.
  - `libc.math` no longer binds the integer arithmetic. `abs` and `labs`
    are declared in `<stdlib.h>` and have moved to `libc.stdlib`;
    `ldiv` and `lldiv` were already there, and `imaxabs` and `imaxdiv`
    were already in `libc.inttypes`, with a `ldiv_t`, a `lldiv_t` and an
    `imaxdiv_t` of their own on this side of the wall. All six names are
    still exported from `libc.math`, because a whole number is not a
    reason to send someone to another module for its absolute value.
  - `libc.sys.resource`'s `nice` said `<unistd.h>` in its own docstring
    while `libc.unistd` bound the same call. The copy is gone.
  - `libc.sys.socket`'s copy of `close` is gone, which leaves the
    descriptor calls where their header is.
  - `libc.string` offered `strcopy` and `strncopy` as second names for
    `strcpy` and `strncpy` in the same file, with the source and
    destination named more helpfully and no way to tell from the outside
    which one a caller should reach for. The C names are what is left; the
    test that used to assert the alias now asserts that `strncpy` pads to
    the count with NULs.

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
