# Version

| | |
| --- | --- |
| `libc.__version__` | `0.12.0` |
| Mojo | `>=1.1.0,<2` |
| Platforms | `linux-64`, `osx-arm64` |

```mojo
from libc import __version__


def main():
    print(__version__)
```

The version lives in `src/libc/version.mojo` and is mirrored in `pixi.toml`,
`recipe/recipe.yaml`, and the two pages that state it — this one and the
specifier on the install page. Bump all five together: `pixi run check-release`
compares them, and asks that the version this checkout is satisfies the
`libc = "..."` line a reader on the install page is told to use.

See [CHANGELOG](https://github.com/mojothon/libc/blob/main/CHANGELOG.md) for
the release history.
