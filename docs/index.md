# libc

`libc` is a binding layer that exposes the C standard library, POSIX and Linux
system calls to [Mojo](https://mojolang.org) through `external_call`.

Every header gets its own sub-package, so you import only what you need:

```text
libc.math      libc.string     libc.stdio      libc.stdlib
libc.unistd    libc.dirent     libc.time       libc.signal
libc.pthread   libc.network    libc.sys.*      ...
```

## Status

The package is developed against **Mojo 1.1.0** and is published to the
`mojo-force` channel on [prefix.dev](https://prefix.dev). It is exercised on
Linux (x86-64) and macOS (Apple silicon).

## Quick start

```mojo
from libc.math import sqrt
from libc.string import strlen
from libc.utils import string_to_char_ptr


def main() raises:
    print(sqrt(2.0))

    var ptr = string_to_char_ptr("hello")
    print(strlen(ptr))
    ptr.unsafe_free()
```

See [Install](install.md) and [Usage](usage.md) for the details.

## License

MIT. See [LICENSE](https://github.com/mojothon/libc/blob/main/LICENSE).
