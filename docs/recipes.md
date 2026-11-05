# Recipes

Short programs for the things a caller is most likely to want first. Every
block on this page is compiled against this package by `check-examples` in
CI, so the names and signatures in them are the ones the package has — but
they are built, not run, so a program that compiles is a claim about the
API, not a promise about its output.

## Why a call failed

C's answer to failure is a special return value — often `NULL` — plus a
number in `errno` saying which failure it was. `strerror` turns the number
into a sentence:

```mojo
from libc.dirent import opendir
from libc.errno import get_errno
from libc.string import strerror
from libc.utils import char_ptr_to_string, is_null, string_to_char_ptr


def main() raises:
    var path = string_to_char_ptr("/does/not/exist")
    var dirp = opendir(path)
    if is_null(dirp):
        print("opendir:", char_ptr_to_string(strerror(get_errno())))
    path.unsafe_free()
```

`errno` only says what the last call did, so read it before anything else
has the chance to fail.

## Reading a file

A `FILE` stream from `fopen`, a buffer from `malloc`, and `fread` to fill
it. `fread` answers how much it read rather than failing, so there is no
`errno` to check here:

```mojo
from libc.file import FILE, fclose, fopen, fread
from libc.stdlib import free, malloc
from libc.utils import is_null, string_to_char_ptr


def main() raises:
    var path = string_to_char_ptr("docs/recipes.md")
    var mode = string_to_char_ptr("rb")
    var stream = fopen(path, mode)
    if is_null(stream):
        print("could not open the file")
        return

    var room = malloc(4096)
    var got = fread(room, 1, 4096, stream)
    print("read", got, "bytes")

    _ = fclose(stream)
    _ = free(room)
    path.unsafe_free()
    mode.unsafe_free()
```

## Running a program and waiting for it

`fork` makes a copy of the process, `execvp` replaces the copy with a
program found by name, and `waitpid` in the parent collects how it ended.
The argument list is a `char **`: the strings, then a null to say where
they end:

```mojo
from std.memory.alloc import unsafe_alloc

from libc.constant import c_ptr
from libc.stdlib import exit
from libc.sys.wait import WEXITSTATUS, WIFEXITED, waitpid
from libc.unistd import execvp, fork
from libc.utils import null_ptr, string_to_char_ptr


def main() raises:
    var pid = fork()
    if pid == 0:
        # The child: become `echo`, found by name along the PATH.
        # execvp only comes back when it failed.
        var program = string_to_char_ptr("echo")
        var argv = unsafe_alloc[c_ptr[UInt8]](3)
        argv.unsafe_offset(0)[] = string_to_char_ptr("echo")
        argv.unsafe_offset(1)[] = string_to_char_ptr("from a child process")
        argv.unsafe_offset(2)[] = null_ptr[UInt8]()
        _ = execvp(program, argv)
        _ = exit(1)

    # The parent: wait, then ask which kind of ending it was.
    var status = unsafe_alloc[Int32](1)
    _ = waitpid(pid, status, 0)
    if WIFEXITED(status.unsafe_offset(0)[]):
        print("the child exited with", WEXITSTATUS(status.unsafe_offset(0)[]))
    status.unsafe_free()
```

A child that exits without being waited for stays as a zombie until the
parent collects it, so the `waitpid` half is not optional.

## The time, written out

`clock_gettime` reads a clock into a `timespec` — whole seconds and then
nanoseconds — `localtime_r` breaks the seconds down against the machine's
timezone into a `tm`, and `strftime` writes that out in whatever shape is
asked for:

```mojo
from std.memory.alloc import unsafe_alloc

from libc.constant import c_long
from libc.time import CLOCK_REALTIME, clock_gettime, localtime_r, strftime, timespec, tm
from libc.utils import char_ptr_to_string, string_to_char_ptr


def main() raises:
    var now = unsafe_alloc[timespec](1)
    now[] = timespec()
    _ = clock_gettime(CLOCK_REALTIME, now)

    var seconds = unsafe_alloc[c_long](1)
    seconds[] = now[].tv_sec
    var broken = unsafe_alloc[tm](1)
    broken[] = tm()
    _ = localtime_r(seconds, broken)

    var text = unsafe_alloc[UInt8](64)
    var format = string_to_char_ptr("%Y-%m-%d %H:%M:%S")
    _ = strftime(text, 64, format, broken)
    print("now:", char_ptr_to_string(text))

    format.unsafe_free()
    text.unsafe_free()
    broken.unsafe_free()
    seconds.unsafe_free()
    now.unsafe_free()
```

`localtime_r` is the one to reach for: `localtime` hands every caller the
same single `tm`, so two calls overwrite each other's answer.

## Asking where a symbol is

`dlsym` takes a name and answers an address; `dladdr` takes the address
and answers which object it is in and the name of the nearest symbol at or
below it. Between them, a name can be shown to be real without anything
being called:

```mojo
from std.memory.alloc import unsafe_alloc
from std.sys import CompilationTarget

from libc.constant import c_void
from libc.dlfcn import RTLD_NOW, dl_info, dladdr, dlclose, dlopen, dlsym
from libc.utils import char_ptr_to_string, string_to_char_ptr


def main() raises:
    # The two platforms spell the C library differently.
    comptime LIBRARY = "libc.dylib" if CompilationTarget.is_macos() else "libc.so.6"

    var handle = dlopen(string_to_char_ptr(LIBRARY), RTLD_NOW)
    var address = dlsym(handle, string_to_char_ptr("getpid"))

    var info = unsafe_alloc[dl_info](1)
    if dladdr(address.unsafe_bitcast[c_void](), info) != 0:
        print(
            char_ptr_to_string(info[].dli_sname),
            "is in",
            char_ptr_to_string(info[].dli_fname),
        )
    info.unsafe_free()
    _ = dlclose(handle)
```

What the name comes back as can be spelled two ways: libc exports the
same address under the public name and under an underscored one, and the
loader reports whichever its linker settled on — `getpid` on one build
and `__getpid` on another. The address is what identifies the symbol; the
name is one of the things it is called.

## The addresses of this machine's interfaces

`getifaddrs` answers a linked list of one record per address the machine
has, walked through `ifa_next` until it runs out. The flags on each record
say what the interface is, and the loopback is the one to skip when what
is wanted is the addresses that reach other machines:

```mojo
from std.memory.alloc import unsafe_alloc

from libc.constant import c_ptr
from libc.ifaddrs import IFF_LOOPBACK, freeifaddrs, getifaddrs, ifaddrs
from libc.utils import is_null, null_ptr


def main() raises:
    var list = unsafe_alloc[c_ptr[ifaddrs]](1)
    list.unsafe_offset(0)[] = null_ptr[ifaddrs]()

    if getifaddrs(list) != 0:
        print("getifaddrs failed")
        return

    var node = list[]
    while not is_null(node):
        if (Int(node[].ifa_flags()) & IFF_LOOPBACK) == 0:
            print(node[].ifa_name())
        node = node[].ifa_next()

    freeifaddrs(list[])
    list.unsafe_free()
```

The list is one allocation from the kernel, and `freeifaddrs` gives the
whole of it back — there is nothing to free per record. One platform
difference worth knowing before reading `ifa_dstaddr`: on a point-to-point
link that member is the address at the far end, and glibc fills the
loopback's with the loopback's own address, so a destination that equals
the address does not mean the record is wrong.

## Looking up an account

`getpwnam` takes a name and answers a row of the account database; the
row lives in a buffer the next call to the same functions will reuse, so
read it before asking again:

```mojo
from libc.pwd import getpwnam
from libc.utils import is_null, string_to_char_ptr


def main() raises:
    var name = string_to_char_ptr("root")
    var row = getpwnam(name)
    if is_null(row):
        print("no such account")
        return

    print(row[].pw_name(), "is uid", Int(row[].pw_uid()), "with home", row[].pw_dir())
    name.unsafe_free()
```

The password member is a placeholder, not a password: the password left
this row long ago — to `shadow` on Linux, which keeps `x` there, and out
of the file on Darwin, which keeps `*`. Three more members — the time the
password was last changed, the time the account expires, and the login
class — exist on Darwin's struct and not on Linux's; the accessors answer
0 and nothing on Linux rather than reading a slot that holds another
member.

## Giving a program a terminal to talk to

`forkpty` is `openpty`, `login_tty` and `fork` in one call: the child
starts life with a pseudo-terminal's slave on descriptors 0, 1 and 2, and
the parent holds the master. The master is the terminal's other end, so
what the child prints arrives there and what is written there is the
child's input.

```mojo
from std.memory.alloc import unsafe_alloc

from libc.constant import c_char, c_int, c_ptr
from libc.pty import Winsize, forkpty
from libc.stdlib import exit
from libc.sys.wait import waitpid
from libc.termios import Termios
from libc.unistd import close, read, write
from libc.utils import null_ptr, string_to_char_ptr


comptime SAID = "the child has a terminal\n"


def main() raises:
    var master = unsafe_alloc[c_int](1)
    master.unsafe_offset(0)[] = -1

    var child = forkpty(
        master, null_ptr[c_char](), null_ptr[Termios](), null_ptr[Winsize]()
    )
    if child == 0:
        # The slave is already on 0, 1 and 2 here: a program that insists
        # on a terminal has one, and does not have to be told.
        var said = string_to_char_ptr(SAID)
        _ = write(1, said, UInt32(SAID.byte_length()))
        _ = exit(0)

    var m = master.unsafe_load()
    var block = unsafe_alloc[c_char](128)
    var got = read(m, block, 128)
    while got > 0:
        print(
            String(unsafe_from_utf8=Span[UInt8](unsafe_ptr=block, length=Int(got))),
            end="",
        )
        got = read(m, block, 128)

    var status = unsafe_alloc[Int32](1)
    status.unsafe_offset(0)[] = 0
    _ = waitpid(child, status, 0)

    _ = close(m)
    block.unsafe_free()
    status.unsafe_free()
    master.unsafe_free()
```

Two things happen to those bytes on the way. The terminal translates as
well as carries: at its default settings `ONLCR` turns each newline the
child writes into a carriage return and a newline, so a child that wrote
twenty-five bytes has a parent reading twenty-six. And there is no end of
file to read while anything still holds the slave open -- the loop above
ends because the child exited, and a pair taken with `openpty` whose
slave the parent forgot to close has the parent waiting for that zero
forever. `forkpty` closes the slave in the parent for exactly that
reason, and `login_tty` makes the child a session leader so that closing
the master hangs the terminal up and sends it `SIGHUP` -- which is how a
program that will not read what is sent to it is stopped.

One thing not to use to tell the two ends apart: `isatty` says yes for
both. The line discipline is on both ends, and the master answers
`tcgetattr` as readily as the slave does.

## Two sockets on the loopback

A connection is made of an address and two sockets: one bound to the
address and listening, one asking for it. `socketaddr` is the sixteen
bytes C passes as a `struct sockaddr` whatever the family is, and it owns
them, so it is filled in place rather than handed back. `set_family`
writes Darwin's `sa_len` and the family where the two platforms keep
them, `set_inet_port` writes the port in the order the wire counts in,
and `set_inet_address` writes the four bytes as `in_addr` holds them.

```mojo
from std.memory.alloc import unsafe_alloc

from libc.constant import AF_INET, SOCK_STREAM, c_char
from libc.network import in_addr, inet_addr, inet_ntoa
from libc.sys.socket import (
    accept,
    bind,
    connect,
    getsockname,
    listen,
    socket,
    socketaddr,
)
from libc.unistd import close, read, write
from libc.utils import char_ptr_to_string, string_to_char_ptr


comptime ADDRESS_SIZE: UInt32 = 16


def at_the_loopback(mut address: socketaddr, port: UInt16) -> None:
    """Fills `address` in as the loopback on `port`.

    The struct owns its sixteen bytes, so it is filled in place rather
    than handed back, and the four bytes of the address come from C's
    own parser rather than from arithmetic here -- which is the short
    way of saying 127.0.0.1 without also saying what order its bytes are
    in.

    Args:
        address: The sixteen bytes to fill in.
        port: The port, or 0 to let the kernel choose one.
    """
    address = socketaddr()
    address.set_family(UInt16(AF_INET))
    address.set_inet_port(port)
    var loopback = in_addr()
    loopback.s_addr = inet_addr(string_to_char_ptr("127.0.0.1"))
    address.set_inet_address(loopback)


def main() raises:
    var listener = socket(AF_INET, SOCK_STREAM, 0)
    var here = unsafe_alloc[socketaddr](1)
    at_the_loopback(here.unsafe_offset(0)[], 0)
    _ = bind(listener, here, ADDRESS_SIZE)
    _ = listen(listener, 1)

    # Which port 0 turned out to be is only knowable by asking.
    var chosen = unsafe_alloc[socketaddr](1)
    var size = unsafe_alloc[UInt32](1)
    size.unsafe_offset(0)[] = ADDRESS_SIZE
    _ = getsockname(listener, chosen, size)
    var port = chosen.unsafe_offset(0)[].inet_port()
    print("listening on", port)

    var caller = socket(AF_INET, SOCK_STREAM, 0)
    var there = unsafe_alloc[socketaddr](1)
    at_the_loopback(there.unsafe_offset(0)[], port)
    _ = connect(caller, there, ADDRESS_SIZE)

    # `accept` writes whoever asked into a buffer of its own.
    var who = unsafe_alloc[socketaddr](1)
    var length = unsafe_alloc[UInt32](1)
    length.unsafe_offset(0)[] = ADDRESS_SIZE
    var taken = accept(listener, who, length)
    var caller_text = char_ptr_to_string(
        inet_ntoa(who.unsafe_offset(0)[].inet_address())
    )
    print("connected from", caller_text)

    var said = string_to_char_ptr("hello\n")
    _ = write(caller, said, 6)
    var heard = unsafe_alloc[c_char](64)
    var got = read(taken, heard, 64)
    print("the other end read", got, "bytes")

    _ = close(caller)
    _ = close(taken)
    _ = close(listener)
    heard.unsafe_free()
    length.unsafe_free()
    who.unsafe_free()
    there.unsafe_free()
    chosen.unsafe_free()
    size.unsafe_free()
    here.unsafe_free()
```

Two things are worth knowing before the code. A port of 0 is not a port:
it asks the kernel to choose one, and `getsockname` is the only way to
learn which one it picked -- which is why nothing here can collide with
anything else on the machine, and why the second address is built from a
port that was already answered for rather than from a number guessed at.
And `accept` hands back a socket of its own, because the listener's job
is to keep listening; the address it fills in alongside is the caller's,
not the listener's, which is the one place a connection's two ends are
told apart by something other than which descriptor is which.
