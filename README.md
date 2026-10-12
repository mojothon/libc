# libc

A standard C library binding for the [Mojo](https://mojolang.org) programming
language.

Every C header is exposed as a Mojo sub-package — `libc.math`, `libc.string`,
`libc.unistd`, `libc.sys.socket`, ... — so `external_call` boilerplate lives in
one place and your code reads like the C it replaces.

- **Mojo:** `>=1.1.0,<2`
- **Platforms:** `linux-64`, `osx-arm64`
- **License:** MIT

## Install

```bash
pixi add --from https://conda.modular.com/max --channel mojo-force libc
```

```mojo
from libc.math import sqrt
from libc.unistd import getpid


def main():
    print(sqrt(2.0), getpid())
```

## Development

The project uses [pixi](https://pixi.sh); `magic`/`mojoproject.toml` are gone.

```bash
pixi install              # default environment (Mojo toolchain)
pixi run test             # run the test suite
pixi run package          # build dist/libc.mojoc
pixi run format           # apply mojo format
pixi run format-check     # fail if the tree is not formatted
pixi run doc              # serve the docs locally
```

Conda packaging and docs live in their own pixi environments:

```bash
pixi run -e build build-conda   # build output/linux-64/libc-*.conda
pixi run -e build publish       # upload to prefix.dev (needs PREFIX_API_KEY)
pixi run -e docs doc-build      # build the site with mkdocs --strict
```

## Layout

```text
src/libc/           the package: one sub-package per C header
src/main.mojo       small smoke program
tests/              test suite, entry point tests/test_main.mojo
recipe/             rattler-build recipe (installs libc.mojoc)
scripts/publish.sh  prefix.dev upload helper
docs/               mkdocs site sources
```

## Conventions

- Pointers are spelled `c_ptr[T]` (`Pointer[T, MutUntrackedOrigin]`), defined
  once in `libc.constant`.
- C structs mirror the C field layout; trivial ones conform to
  `TrivialRegisterPassable`.
- Functions keep their C names and raw return values (`-1`/`NULL` on failure);
  read `errno` with `libc.errno.get_errno()`.

## Version

`0.2.0` — see [CHANGELOG.md](CHANGELOG.md).
