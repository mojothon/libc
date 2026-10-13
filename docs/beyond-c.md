# What is here that C does not have

This is a binding, so what it can call is a subset of what C can call and
will stay that way. The count says how much of a subset: `libc`, `libm`,
`libdl` and `librt` publish 2778 functions between them, and this binds
567 C symbols, 562 of which are among those — **20.2%**. C offers more, and
calling more of it is not what this is for.

(567 took correcting. An earlier count here said 470, because the symbol
was read off the same line as `external_call[` and a fifth of the calls
in this package put the name on the next line instead. The honest number
was higher, and nobody benefited from the lower one.)

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
from libc.errno import check, errno_message, errno_name

print(errno_name(2))            # ENOENT
print(errno_message(2))         # ENOENT: No such file or directory

var fd = check(open(path, O_RDONLY))          # raises instead of answering -1
var stream = check_ptr(fopen(path, mode))     # and for the calls that answer NULL
```

`check` covers the half of libc that says -1; `check_ptr` covers the other
half, the one that says NULL — `fopen`, `malloc`, `getcwd` — for which a
test against a negative number says nothing. C has no answer to either,
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

Field offsets are still on trust. `size_of` and `align_of` reach Mojo
without constructing anything; the offset of a member does not, because
asking a pointer where a member lives asks for a member pointer, and Mojo
has none. That leaves 116 fields whose positions are whatever they were
written down as.

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
- **Coverage.** 16.7%, as above. `open` here is bound as `openat` with
  `AT_FDCWD` filled in, which is what POSIX says the two amount to, and is
  the sort of thing that happens when the real name cannot be called.
- **Variadic arguments, and the argument after them.** `openat` is variadic
  too, so the mode is not a named argument on macOS either and does not
  arrive: a file asked for with 0o644 came out as 0o150, which is no umask
  of 0o644 but whatever was on the stack. `fchmod` afterwards is the way to
  be sure, and both docstrings say so.
- **Speed.** Measured, and there is nothing here to be modest about:
  **1.6 ns** per call through the binding against **2.2 ns** for the same
  call from C — `strlen`, 20 million times, run twice. The gap favours
  neither in any way that means anything: the C side pays for a jump
  through the procedure linkage table that an external call does not, and
  the spread between two runs of the same binary is wider than the
  distance between the two numbers. `scripts/bench-call.sh` prints both.
