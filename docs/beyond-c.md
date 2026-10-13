# What is here that C does not have

This is a binding, so what it can call is a subset of what C can call and
will stay that way. The count says how much of a subset: `libc`, `libm`,
`libdl` and `librt` publish 2778 functions between them, and this binds
470 C symbols, 465 of which are among those — **16.7%**. C offers more, and
calling more of it is not what this is for.

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

This is the one with no counterpart. Three scripts compare the binding
against C on this machine:

- every call is compared against the C prototype — 592 of them, and a
  mismatch is reported rather than found later;
- structure layouts are compared against `offsetof`, because `struct stat`
  is 144 bytes here and 128 on Darwin with the members in a different
  order, and every member is read at the offset that fits;
- constants are compared against what `gcc -dM` prints.

glibc does not come with anything that checks glibc.

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
