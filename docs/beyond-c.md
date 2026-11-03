# What is here that C does not have

This is a binding, so what it can call is a subset of what C can call and
will stay that way. The count says how much of a subset: `libc`, `libm`,
`libdl` and `librt` publish 3574 functions between them, and this binds
994 C symbols, 986 of which are among those — **27.6%**. C offers more, and
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
| places one by hand, at an offset listed in `OFFSETS` | 111 |
| declares them in order and leaves the layout to Mojo | 191 |
| reads none of them, and claims only a size | 17 |
| has a struct only Linux has | 13 |

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

## What C does and this does not

Being fair about the other direction:

- **Variadic functions.** `printf`, `scanf`, `fcntl`, `ioctl`. An external
  call has to name every type it passes, and C's own variadic convention
  on arm64 Darwin passes on the stack, where the call cannot reach.
- **Callbacks.** Nothing here can hand C a function pointer, so `qsort`,
  `bsearch` and signal handlers are out.
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
