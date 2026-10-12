# Usage

## Calling a C function

Each module mirrors one C header. Functions keep their C names and are thin
`external_call` wrappers, so the arguments and return values match the C
prototype:

```mojo
from libc.unistd import getpid, getuid


def main():
    print(getpid(), getuid())
```

## Strings

C APIs take `char *`. `libc.utils` converts between Mojo `String` and a NUL
terminated buffer:

```mojo
from libc.utils import CString, char_ptr_to_string, string_to_char_ptr, strlen


def main() raises:
    var ptr = string_to_char_ptr("hello, libc")
    print(strlen(ptr))              # 11
    print(char_ptr_to_string(ptr))  # hello, libc

    var view = CString(ptr)         # borrowed view, printable
    print(view)

    ptr.unsafe_free()               # you own the buffer
```

`string_to_char_ptr()` allocates; release the result with `unsafe_free()`.
Pointers returned by C (for example `opendir()`) must be released with the
matching C function instead.

## Pointers

Raw pointers are spelled `c_ptr[T]`, an alias for
`Pointer[T, MutUntrackedOrigin]`:

```mojo
from libc.constant import c_ptr


def read_first(p: c_ptr[UInt8]) -> UInt8:
    return p.unsafe_load(0)
```

Point at a Mojo value with `Pointer(to=value)` when a C API needs an out
parameter.

## Structs

Structures are declared with the field layout of the corresponding C struct.
Trivial ones conform to `TrivialRegisterPassable`, so they can be passed and
returned by value:

```mojo
from libc.dirent import closedir, opendir, readdir
from libc.utils import string_to_char_ptr


def main() raises:
    var path = string_to_char_ptr("/tmp")
    var dirp = opendir(path)
    var entry = readdir(dirp)
    print(entry[].name())
    _ = closedir(dirp)
    path.unsafe_free()
```

!!! warning
    `struct dirent.d_name` is modelled as `Array[UInt8, 256]`, not a pointer.
    Reading it as a pointer both yields a garbage address and shifts the field
    to the wrong offset.

## Constants

`libc.constant` carries the C type aliases (`c_int`, `c_size_t`, ...) plus the
`O_*`, `SEEK_*`, `AT_*` and `errno` values:

```mojo
from libc.constant import O_CREAT, O_RDWR, SEEK_END
```

## Errors

Most wrappers return the raw C value: `-1` (or `NULL`) on failure with `errno`
set. Read it with `libc.errno.get_errno()`.
