# What is here that C does not have

This is a binding, so what it can call is a subset of what C can call and
will stay that way. The count says how much of a subset: `libc`, `libm`,
`libdl` and `librt` publish 3574 functions between them, and this binds
999 C symbols, 991 of which are among those — **27.7%**. C offers more, and
calling more of it is not what this is for.

Both numbers move with the machine they are taken on, which is worth saying
before either is quoted. `nm -D --defined-only` over those four libraries
gives 3574 names here and gave 2778 on the machine this page was first
written on, a different glibc with fewer of them exported; the count of
symbols is the one `scripts/check-prototypes.py` walks, and it is the one
number here that cannot drift from the source, because it is read out of the
source and compared against this paragraph. Take the shape rather than the
digits: a quarter of what those four publish, every one of them checked
against the header it comes from, and no intention of the rest.

(That number took correcting twice. An earlier count here said 470, because the
symbol was read off the same line as `external_call[` and a fifth of the
calls in this package put the name on the next line instead. Then it said
567, which was right the day it was counted and was not recounted as the
package grew. The honest number is the one the check prints, and nobody
benefited from the lower one.)

The rest of this page is about the other question, which is not "how much"
but "how". There are things C cannot do for the caller, or does by
convention and hope, and a binding can do them properly because it gets to
choose what the call looks like on this side.

## Asking what a number means

`errno` is a number at run time and a macro at compile time, and nothing in
C joins the two. A program prints 2 and whoever reads it looks `ENOENT` up
in a table, because there is no `errno_name` in libc to ask.

There is one here:

```mojo
from libc.errno import errno_message, errno_name


def main():
    print(errno_name(2))     # ENOENT
    print(errno_message(2))  # ENOENT: No such file or directory
```

`check` covers the half of libc that says -1, so `check(open(path, O_RDONLY))`
hands back the descriptor or raises; `check_ptr` covers the other half, the one
that says NULL — `fopen`, `malloc`, `getcwd` — for which a test against a
negative number says nothing. C has no answer to either,
having no exceptions to raise: the nearest it comes is a macro of one's
own that calls `perror` and then `exit`, which is not the same as being
able to catch it.

`errno_name` answers for the platform it was built for. `EAGAIN` is 11 here
and 35 on Darwin, and it says `EAGAIN` either way.

## Macros that are functions

`WIFEXITED`, `WEXITSTATUS`, `WIFSIGNALED`, `WTERMSIG`, `WIFSTOPPED`,
`WSTOPSIG` and `WCOREDUMP` are macros in C, which is to say they are text
substitution: no types, no way to name one or pass it along, nothing for a
debugger to step into. Here they are functions, and they were checked the
only way worth checking — against glibc's macros, for all 65536 possible
statuses, and they agree on every one.

## Differences that are visible instead of hidden

C handles a difference between platforms with `#ifdef`, and the reader of
the header sees one of the two answers and not the fact that there was a
choice. This writes the choice out:

```mojo
from std.sys import CompilationTarget

comptime EAGAIN = 35 if CompilationTarget.is_macos() else 11
```

and then proves it on both, because CI runs on both. `EAGAIN` is the one
worth watching: a value that is not the platform's own fails a test here
rather than in somebody's error handling.

## A check that runs against C itself

This is the one with no counterpart. `scripts/check-prototypes.py`
compares the binding against C on this machine: 
every call is compared against the C prototype — 601 of them now, each
compiled from the header on this machine — and a mismatch is reported
rather than found later.

And now `scripts/check-constants.py` does the same for the numbers. It
includes every header either script knows, asks C to print each constant,
and compares: 553 of them at this writing, of which 52 are written as
expressions (`S_IRUSR | S_IWUSR`) rather than as numbers, so those are
handed to C whole and a misspelled name inside one fails to compile. It
runs on both platforms in CI, which is the point of it — the platform
decides which side of an `if is_macos()` is under trial, and neither job
can check the branch it is not standing on.

It earned its place on the first run. Fifty-five constants were Darwin's
values with no platform branch at all: `O_APPEND` was 8, which is what
Darwin says and not what Linux says, Linux saying 1024, and the same for
`O_CREAT`, `O_TRUNC`, every `LOG_*` and most of `F_*`. None of it failed
a test, because nothing here asserted what the number *meant* — `open`
received 512 where 64 was intended and created something other than was
asked for, quietly, in the way these things do. A number read off `gcc
-dM` by eye is right exactly once, and that was a long time ago.

And `scripts/check-layouts.py` asks C how big each struct is and where it
has to start, which `tests/test_layout.mojo` had been doing for thirty-two
things about eight structs and nothing for the rest. Its first run found
six wrong. Five were opaque blocks held as `Array[UInt8, N]` — `fenv_t`,
`fexcept_t`, `pthread_attr_t`, `pthread_condattr_t`, `mbstate_t` — and a
row of single bytes asks to be aligned on no boundary at all, so every
call taking one was handed a pointer C asks for four or eight and never
agreed to be given one byte off. Those now sit in words.

The sixth was `qelem`, which is not opaque: it names the two links and
nothing else, which made it sixteen bytes to C's twenty-four, because C's
declares a third member, `char q_data[1]`, trailing after them. Nothing
here ever looked at those eight bytes, so `insque` and `remque` work
either way — until you put one next to anything else and it writes into
the gap. A struct used for its size and never read has to be the right
size for the reason that it is used for its size.

Being larger than C needs is not a mistake and half of them are: an opaque
block sized for whichever of the two platforms wanted most costs bytes and
breaks nothing, since every call takes it by pointer and libc writes less
than it was given. The script says which is which rather than treating any
difference as failure.

Field offsets were the half that stayed on trust: `size_of` and `align_of`
reach Mojo without constructing anything, the offset of a member does not,
because asking a pointer where a member lives asks for a member pointer and
Mojo has none. But a struct held as bytes does not have to be asked — the
numbers its accessors read at *are* the offsets, and C can be asked the
same question about the same member. Every member this package reads out of a
C struct is in that list now, and checked with `offsetof` on whichever
platform is running — from the record `getutxent` hands back to `si_pid` and
the one flag word in a `glob_t`. Thirteen of them are Linux's alone:
`sys/sysinfo.h` and the `timer_create` `sigevent` are not on the other side at
all, and Darwin's `sigevent` is a different struct with `sigev_notify` first,
so asking it would compare a member against the wrong struct. Those are
counted rather than asked, which is what the count is for.

| what a struct does with its members | how many |
| --- | --- |
| places one by hand, at an offset listed in `OFFSETS` | 116 |
| declares them in order and leaves the layout to Mojo | 187 |
| reads none of them, and claims only a size | 17 |
| has a struct only Linux has | 13 |

One struct is sized the other way round from the rest. Most of the blocks
here are as wide as the wider platform wants, because they are written *by*
libc and a generous buffer costs nothing; a `sigaction_t` is handed *to* libc,
so it is 152 bytes on glibc and 16 on Darwin, counting its slots per platform.
Being 152 bytes on Darwin would not fail — the kernel would read the first 16
and write the same — it would just mean this process wrote 136 bytes of its own
memory into a call it had no business writing to.

Those four numbers are the state of the whole exercise, and they are in a
table because a number in a paragraph is a number that goes stale quietly.
`scripts/check-layouts.py` counts the same four things and compares, so the
paragraphs below and the package cannot drift apart without one of them
failing.

The first twenty-two were already right, which is what a check written after
the fact tends to find. Of the ones that came after, one was not:
`gl_flags` was read from the high half of the word it begins in, which
answers 0 for a `glob` that was given flags, and no test had ever asked. That
is the argument for the rest of it — an offset written by hand is a claim,
and a claim nothing checks is only usually true — so they are named offsets
at the top of the module now, which is a layout a script can read, rather
than slot numbers and shift counts, which is a layout you have to
reconstruct in your head. `Statvfs` is why that matters: four of its members
share two words on Darwin and take four words on glibc, so the same struct
has `f_flag` at 48 and at 72, and one number written from the other
platform's header would leave nine members reading the right bytes of the
wrong member.

What is left is counted rather than trusted silently, and it splits in two.
The members of a struct Mojo lays out itself rest on the order they are
declared in, which is C's arrangement when the order is and says nothing
when it is not. The ones that hold their bytes in a buffer and read no member
at all are the other half — the eight pthread handles and attributes,
`fenv_t` and `fexcept_t`, the two spawn types, `fpos_t`, `mbstate_t`,
`fd_set`, `msqid_ds` and `shmid_ds`. Not one of them is a layout with numbers
in it: nothing here ever reads a field that C's header names, so there is no
offset to name and nothing for `offsetof` to disagree with. What they claim
is a size, and that is what gets checked, in one direction only. A block
larger than C's is safe, because libc is handed a pointer and writes what it
thinks is there; a block smaller than C's is whatever came next in memory
being overwritten, which is why the script calls that a failure and calls the
generous ones loose.

The last thing nothing here checked was whether a test would *notice*.
Every script above asks about the binding; `scripts/check-tests.py` asks that
each one be called, which is a lower bar than it sounds: `_ = f(...)` counts,
and a test that asks for an answer and then throws it away passes just as
quietly when the binding underneath is calling the wrong function. `gamma` was
in exactly that state for a while — it called `tgamma`, the gamma function
rather than its logarithm, and every check on this list was green — and what
tells that apart is a test failing when the symbol changes.

`scripts/mutation-probe.py` changes it on purpose. Two bindings in one file
with the same signature are interchangeable as far as the compiler is
concerned, so one is pointed at the other's symbol and the tests that call it
are run — a rebuild each, which is why it samples instead of sweeping. The
first two samples were twenty-four mutants and found four calls whose tests
could not tell: `strncmp`, whose two strings were the same case, so
`strncasecmp` answered identically; `endhostent`, called and never observed,
so `endprotoent` — next line, same shape — passed; `alarm`, asked twice for
nothing, which `close` also answers 0 to; and `getdomainname`, held only to
writing fewer than 256 bytes into a 256 byte buffer, which `gethostname`
does too. Each has an assertion now that only the right call passes: a
case-differing `strncmp`, a second `gethostent` after the database was shut —
the first row again, which is what shutting it means — ten seconds armed and
taken back unspent, and `uname`'s `domainname` agreeing on the one platform
whose `utsname` carries it. The same twenty-four come back as 21 caught by an
assertion, 2 that are the same function under two names (`scalbn` and
`ldexp`), and 1 that took the process down rather than fail an assertion.

A third sample of twenty-four, from a different seed, found three more.
`pow` was held to a bound from above, and `fmod(2, 10)` is 2, which is under
1024; `getpgid` was held to being positive, which `getsid` is too; `chown` was
asked only about a file that is not there, which `lchown` answers the same
way. Each has an assertion now that only the right call passes: two to the
tenth exactly, a new process group named after the process that made it, and a
link whose target is not there — `chown` follows it and finds nothing,
`lchown` changes the link itself, and no privilege is needed to tell them
apart. Two more were explained instead of fixed, because they are the same
call under two names: `cfgetospeed` and `cfgetispeed` read the same `CBAUD`
bits on glibc, where a terminal has one speed and not two, and `endgrent` and
`setgrent` leave the next `getgrent` at the same row, the descriptor they
differ over being one the API never hands out.

Explaining one puts it in a table, and a table of reasons is a thing that rots
in a way nothing notices: the reason is read only when the mutant survives, so
an entry that has outlived its pair sits there excusing a mistake nothing makes
any more. `--check-tables` reads both tables back against the mutants that can
still be built and takes seconds, because the ways an entry goes stale are all
in the shape of the call rather than in what the suite does: rename a
parameter, add a third binding to a file so a different sibling is the first
one found, change a signature so the call is no longer handed its own
parameters. The other direction only a run can see, and it says so too: an
entry whose mutant is caught now is an entry that has been answered and can go
— which is what happens to every reason the day somebody thinks of the input
that separates the pair.

The fifth verdict came out of that sample too. One mutant — a read lock
pointed at `pthread_rwlock_destroy` — left the test waiting rather than
failing, and the script stopped where it stood: the traceback was the last
thing the run printed, the mutants after it were never asked, and the tally
was a number nobody got. A test that waits is not a test that passed, and it
is worse than a survivor, because nothing after it in that file is asked
either. `hung` is a verdict now, counted with the rest, and the run goes on.

Every one of those mutants changes *which* function is called. The other half
of a binding is the order its arguments go over in, and nothing above asks
about that: `chown(path, owner, group)` and `chown(path, group, owner)` are the
same string, the same return type and three arguments of two types, so the
compiler has nothing to say — and a test only has something to say if the two
numbers in those positions differ. `--kind order` makes that mistake instead,
and the first sample of twenty-four came back 13 caught, 2 that took the
process down rather than fail an assertion, and 9 that passed. Nine against
three on the symbol axis of the same size is the measure of how much more of
this suite proves which call ran than proves how it was asked.

Five of the nine had an assertion to write. `socketpair(AF_UNIX, SOCK_STREAM,
...)` is handed 1 and 1 — those are the two constants — so both orders are the
same call; a datagram pair is type 2, and `getsockopt` says which kind came
back. `strncasecmp` was asserted equal to a string that differs only in case,
and equal is the answer a swap gives too, so it is asserted to sort two
different strings now. `atan2(1, 1)` is on the diagonal, where the answer does
not depend on which argument is which; three quarters of pi is off it.
`iconv_open("UTF-8", "UTF-8")` is one name written twice, and the swap is
invisible until the two names differ — UTF-8 to UTF-16LE turns two bytes into
four, and the other way round turns the same two into three. And `execve` was
only ever watched failing: a program that is not there fails the same way
whichever list is in which slot, so the test now runs `/bin/echo` and reads
what it printed.

Four were explained rather than fixed, and each says why where a reader will
find it: `fmax` and `hypot` are commutative, `openlog`'s two integers are read
by a daemon that writes a file this process never reads, `catgets` has only a
catalog that did not open, and every `chown` a suite without a privilege can
ask about is one that fails before the two ids are looked at.

A second sample of twenty-four, from a different seed, found 10 more of the
same kind. Five had an assertion to write. `posix_memalign(slot, 32, 64)` was
handed a size that is a valid alignment, so the swap was answered: 48 is not,
and a binding handing it over as the alignment is refused with `EINVAL`.
`tcsendbreak` was given a duration of 0, which put the real descriptor in a
place the call ignores and a 0 where the descriptor goes — and whether 0 is a
terminal is a property of the runner. It is given 100000 now: not a descriptor
any process has, so the swap asks for that one and gets `EBADF` where the test
is holding out for `ENOTTY`. `strncasecmp_l` and `wcsncasecmp_l` were asserted
"not zero", which is the answer both ways round; the sign of the answer is
not. And `nextafter` is the one worth keeping: it was bounded above and below,
and a step in *either* direction passes both bounds, because both directions
land between the two numbers. What is asserted now is the size of the step —
one ulp past the argument it steps away from — which is 1 past the one and
under the four the other way round.

The other five are the same call with the arguments exchanged, and each says
why: `fminf` and the `x` and `y` of `fma` are a minimum and a product,
`calloc`'s block is the product of `nmemb` and `size` and its overflow check is
on the same product, `scandir`'s two callbacks are both NULL because this FFI
cannot hand C a function address, and `fchownat`'s call is refused before the
two ids are read.

Two more samples of the same size followed. The second one's survivors were
`fmaxf`, which is commutative, and `sigaction`, which was not a weak assertion
but a struct that was not there — that one is in `sigaction_t`. The third came
back 18 caught, 2 that took the process down, 1 that is the same call and 3
that passed, and all three had an assertion to write.

`fchown(-1, ...)` is refused before the two ids are read, so the swap answered
`-1` as well; a descriptor that exists is what tells them apart, and a file
given to the owner it already has answers 0 where the swap asks for descriptor
1000, which no process has. `wcscoll(one, two) != 0` and `wcscasecmp_l(hello,
shout) == 0` are the same failure twice: an answer that is the same either way
round. `abc` and `abd` do not stop differing when asked in the other order, and
`Hello` and `hELLO` do not stop agreeing, so what is asked now is which way
each leans — in both directions, and a binding that swaps the two gets the
first one backwards.

A fourth sample of twenty-four came back 19 caught, 2 that took the process
down, 1 that is the same call and 2 that passed. `wmemcmp(abc, abd, 3) != 0`
is the "same either way round" failure again — two different strings stay
different in either order — so it is asked which way it leans now. `tcflow`
is the descriptor one in a new place: on a descriptor that is not a terminal
neither argument is looked at past the descriptor, so both positions answered
`ENOTTY`. A descriptor that is not one at all is refused before the action is
read, so `-1` answers `EBADF` where the swap asks for descriptor `TCOOFF` — 0
on glibc, 1 on Darwin — and gets `ENOTTY` or `EINVAL` back instead.

After five samples the axis was swept instead of sampled: all 191 swaps, in
one run. That came back 146 caught, 11 that took the process down, 13 that are
the same call and 20 that passed — and the twenty are worth reading as one
number, because five samples of twenty-four had found eleven between them. The
remaining nine were in candidates no sample had happened to draw.

After the twenty were dealt with the same sweep comes back 152 caught, 11 that
took the process down, 27 that are the same call and none unaccounted for — the
axis, not a sample of it, with every swap either caught or written down.

Five of the twenty had an assertion to write, and two of those are the same
mistake as the ulp — `powf` was asserted as `powf(2, 10) - 1024 < 1e-6`, which
is true of every answer below 1024 and so is true of `powf(10, 2)`, and
`nextafterf` was bounded on each side, which a step from either end satisfies.
`tcflush` is the descriptor lesson again. `pthread_sigmask` was asked twice
with the same empty mask in both positions, so it never mattered which came
first; it blocks `SIGWINCH` and watches the mask change now, and puts it back.
`setpgid` was asked with two zeroes, which are the two arguments that mean
"this process" and "its own group"; it names the group it is in now, which is a
move to where it already is.

Nine were explained: `fmin`, `hypotf` and `fmaf` are the float twins of calls
already in the table, `pthread_equal` is a question with no order to it, and
the rest are the two shapes this suite keeps meeting — an id this process does
not have the privilege to change (`setreuid`, `setregid`, `lchown`,
`adjtime`), and a call that fails at its first argument before reading the
second (`getnetgrent`, `innetgr`, `aligned_alloc`, `mbsnrtowcs`,
`wcsnrtombs`, `sched_setscheduler`).

The twentieth was the `sigaction` story again, and it closed the same way:
`sigaltstack` was asked with two NULLs because there was no `stack_t` to give
it, and there is one now.

It is also the sharpest lesson of the three, because there was nothing to see.
glibc's `stack_t` is a pointer, four bytes of flags and a size; Darwin's is a
pointer, a size and four bytes of flags. Both are 24 bytes, 8-aligned, and the
same three types — a header read on one platform is a header that looks right.
The struct was written with glibc's order and the offsets were checked against
glibc, so the layout check agreed with it, the tests passed, and the first
sample to say otherwise was the macOS job: a stack installed with the size
where the flags go is a stack with flags of 131072, which is not a flag, and
the call answers `EINVAL`. The offsets are two numbers now, and the header
checks in the test job run before the suite, so that the next one fails in the
check that names the member rather than in the test that used it.

Writing the test turned up something else worth knowing: the runtime puts a
handler on `SIGUSR1` and an alternate stack under it, so the process the suite
runs in is not one that has never set a stack. The test therefore measures the
restore against the first read rather than against zero.

A fifth sample came back 17 caught, 2 that took the process down, 3 that are
the same call and 2 that passed. `lockf(-1, 3, 0)` is the descriptor lesson
again — `-1` is refused before the command is read — and is asked about a real
file now, where `F_TEST` on a range nobody holds is 0. `sscanf` is the first
one that no input can separate: the format it is given has no conversion in it,
because the places a conversion writes to are in the variadic part this cannot
pass, and a format with nothing to convert answers 0 for any input at all. That
one is written down as the same call, with the reason.

Seven of the survivors across those samples were one shape: an assertion that
is true whichever way round the two arguments went. `!= 0` on two strings that
differ, `== 0` on two that agree, a bound above and a bound below — each is the
half of a comparison's answer that survives the swap. A sample that finds the
same shape seven times in a hundred and twenty is not sampling any more; it is
finding a rule, and a rule can be asked of the whole family at once.

`scripts/check-comparisons.py` does that. Every binding whose symbol ends in
`cmp` or `coll` — nineteen of them, `strcoll_l` and `wcsncasecmp` included —
must have one assertion that compares the answer with zero rather than with
`!= 0`, because a sign is the part that changes when the arguments do. It found
`strcasecmp_l` on its first run, which no sample had landed on yet, and it will
find the next one when a comparison is bound. `bcmp` is in the family by name
and answers only zero or not, which is written down in the script next to the
reason.

glibc, for its part, does not come with anything that checks glibc.

## Next to Rust's `libc`

The nearest thing to this that is not this: [rust-lang/libc](
https://github.com/rust-lang/libc). It binds the same C and implements
none of it, which is what this does too. Four of its Linux files declare
681 C functions; this binds 567; 293 are in both.

The difference is not the count. Rust answers "what is `EAGAIN`" with a
file per platform and a `cfg` that picks one, so the answer for the
platform you are not on is somewhere else in the tree. This writes both
numbers on one line and runs CI on both. Rust supports more platforms than
two, and this supports two and proves both — which is the trade, stated
as the trade rather than as a win.

## One thing that is awkward, and said out loud

Mojo's pointers are non-null by design: `Bool(ptr)` is refused, and the
type says a pointer always points at something. C's half of the binding
does not share that opinion, and a call that fails answers with NULL
whatever the type says, so NULL is what arrives — a pointer whose address
is 0. `check_ptr` turns it into an exception, and `Int` is how it sees it,
being the one way left to ask.

The other awkward one is C's `...`. `external_call` wants every type written
out, so a call whose C declaration ends in a variadic parameter is bound with
the arguments in front of it and none of it: a conversion, or the address a
request answers through, is not something the binding can be given. Writing
the extra type out anyway is not a way round it — on arm64 a variadic callee
reads its anonymous arguments from the stack, while a call that describes
itself that way passes them in registers, so what the callee reads is a slot
nobody wrote. `open` is bound as `openat` here because of it; `FIONREAD`
through `ioctl` answers 0 on Apple silicon and leaves the integer it was asked
about untouched, which is what a probe on a runner showed; and `fcntl`'s
three-argument form is dependable only where that slot happens to hold what
was meant, which is not a thing to promise.

There is a second way the wall shows up, in the binding rather than in the
call. `fcntl` was bound twice, once with the two arguments C lets you give it
and once with the three that the commands take, and each form compiled and
worked — but a program that made both calls did not build: one symbol
declared with two signatures, and the compiler stops at lowering with
`existing function with conflicting signature`. So there is one form, the
three-argument one, and the commands that read nothing are given 0. It is the
same lesson as `isascii_l` a few paragraphs down, from the other side: what a
name can be called with is one thing, and what can be built is the evidence.

What found it was wanting to ask the two-argument form something — `F_GETFD`
is a question and not a command, so it was the form to ask it with — and
finding that the suite would not build once the test did. Every other check
was green while there were two forms, and would be again: each of them is
right about itself, and the compiler only complains at lowering, where it
names the symbol and not the call that was written second.

`scripts/check-duplicates.py` asks for the rule now, rather than leaving it to
whoever writes the second form: one signature per symbol, in one file or
across two.

Everything the suite cannot ask, and why, is in [Modules](modules.md).

## What C does and this does not

Being fair about the other direction:

- **Variadic functions.** `printf`, `scanf`, `fcntl`, `ioctl`. An external
  call has to name every type it passes, and C's own variadic convention
  on arm64 Darwin passes on the stack, where the call cannot reach.
- **Callbacks.** Nothing here can hand C a function pointer, so `qsort`,
  `bsearch` and a signal handler of one's own are out. A struct that carries
  one is not always out with it, though: `struct sigaction` is here as
  `sigaction_t`, with the handler kept as the number C stores there, because
  two of the three things that can go in that union are not addresses at all —
  `SIG_DFL` is 0 and `SIG_IGN` is 1. So a signal can be told to be ignored,
  asked what it is doing, and put back; it cannot be given a function to run.
- **Bodies that live in another library.** `<arpa/inet.h>` declares
  `inet_net_pton`, `inet_net_ntop`, `inet_neta` and the two `inet_nsap_*`
  on both platforms, and on Linux they are not in libc: they are in
  `libresolv`, which a C program is linked against without ever saying
  so. Nothing here links it, and the call does not resolve —
  `undefined reference to inet_net_pton` — while the header goes on
  saying the function is there. The declaration is not the evidence; the
  link is, and the quickest place to look is
  `nm -D /lib/x86_64-linux-gnu/libresolv.so.2`.
- **Declarations written inside `#if 0`.** Four of `<spawn.h>`'s functions
  are spelled out in full in Darwin's header and cannot be called:
  `posix_spawnattr_setschedparam`, `posix_spawnattr_setschedpolicy` and
  the two getters are inside `#if 0 /* _POSIX_PRIORITY_SCHEDULING : not
  supported */`. A prototype listing, and a `gcc -aux-info` run on the
  other platform, both say they are there. So `spawn.h` is bound to 27 of
  its 31, and the four left over are less a gap in this than a gap in the
  platform.
- **Names that are only a macro.** `isascii_l` is spelled in glibc's
  `<ctype.h>` as `#define isascii_l(c,l) __isascii_l((c),(l))`, which is
  itself a macro over `__isascii`, so there is no symbol for a loader to
  find, and Darwin's `xlocale/_ctype.h` does not carry the name at all.
  `sched_getcpucount` went with it: that one is FreeBSD's, and neither
  platform declares it. Both were bound here, compiled, and could be called
  nowhere — a name in a string can outlive both the header and the compiler
  while naming nothing. `scripts/check-symbols.py` now reads
  `NOT_DECLARED_HERE` out of `scripts/check-prototypes.py`, and a name
  excused by both lists fails the run.
- **Names that are zero and mean something.** `timer_create` writes a
  `timer_t` that can be 0 and be valid: the kernel numbers its timers
  from zero, so the first one a process makes is named 0. A binding that
  checks the name for NULL throws away a working timer, and a test that
  does it fails on the first timer and passes on the second.
- **Coverage.** The share above, and no more than that intended. `open` here
  is bound as `openat` with `AT_FDCWD` filled in, which is what POSIX says
  the two amount to, and is the sort of thing that happens when the real
  name cannot be called.
- **Variadic arguments, and the argument after them.** `openat` is variadic
  too, so the mode is not a named argument on macOS either and does not
  arrive: a file asked for with 0o644 came out as 0o150, which is no umask
  of 0o644 but whatever was on the stack. `fchmod` afterwards is the way to
  be sure, and both docstrings say so.
- **Semaphores.** `<semaphore.h>` is read and not bound, for two reasons
  that meet in the same header. Darwin has no unnamed semaphores:
  `sem_init` is declared, marked deprecated, and answers -1 with `ENOSYS`,
  because Apple never implemented them — what its `sem_t` is, is an `int`
  naming a semaphore the kernel holds. The named ones work, `sem_open`
  being a syscall there, but the count a new one starts at is an argument
  after a variadic one, which is the `openat` problem again: on arm64
  Darwin whatever arrives as the count is what was on the stack, and a
  semaphore that starts at the wrong number is worse than one that is not
  there at all. A round was written and taken back for this. The failure
  signature is worth knowing if anyone tries again: the call answers 0 and
  the semaphore exists, and only a `sem_trywait` says the count was not
  the one asked for.
- **Speed.** `scripts/bench-call.sh` runs it: a hundred million calls of
  `strlen`, `strcmp` and `getpid`, five times over, keeping the fastest of
  the five, with a first row that is the same loop with no call in it. A
  call's cost is the distance from that row, and nothing else says what the
  loop itself cost. On the machine this was last run on:

  ```
  call        through C    through the binding
  nothing         282 ps              454 ps
  strlen         2504 ps             1499 ps
  strcmp         2087 ps             1904 ps
  getpid       327878 ps           329006 ps
  ```

  The row that settles anything is `getpid`. A syscall costs what a syscall
  costs through either side — 0.4% apart — which is the whole claim: an
  external call adds nothing measurable to a call. The two cheap rows are
  another matter, and the honest reading is that they cannot be read at
  all: run the script again and `strlen` through C moves by 500 ps, which
  is the size of the gap that was supposed to be measured between the two
  languages. An earlier version of this paragraph quoted **1.6 ns** against
  **2.2 ns** for `strlen`, taken the same way and without the `nothing` row
  to hold them down; a repeat will not give either number back. What
  repeats is the shape — the binding is not slower — and the syscall row,
  which does not move at all.
