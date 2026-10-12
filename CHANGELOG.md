# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-10-12

### Added

- `pixi.toml` with `default`, `build` and `docs` environments, replacing
  `mojoproject.toml` and `magic.lock` (the `magic` CLI is retired).
- GitHub Actions workflows: CI (format, test on Linux and macOS, conda build,
  docs) and release (prefix.dev upload, GitHub Pages docs, release artifact).
- `recipe/recipe.yaml` moved out of `src/` and rebuilt for `rattler-build`.
- Three sub-packages that were empty stubs: `libc.stdlib` (allocation,
  environment, number conversion, temporary files), `libc.float` (the
  `<float.h>` limits) and `libc.stdio` (the `<stdio.h>` entry points that
  `libc.file` does not already own).
- Rewritten test suite under `tests/`, driven by `tests/test_main.mojo` and
  `std.testing` assertions: `constant`, `ctype`, `dirent`, `float`, `math`,
  `network`, `stdio`, `stdlib`, `string`, `utils`, `version`.
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
