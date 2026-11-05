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
