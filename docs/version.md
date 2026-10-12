# Version

| | |
| --- | --- |
| `libc.__version__` | `0.5.0` |
| Mojo | `>=1.1.0,<2` |
| Platforms | `linux-64`, `osx-arm64` |

```mojo
from libc import __version__


def main():
    print(__version__)
```

The version lives in `src/libc/version.mojo` and is mirrored in `pixi.toml`
and `recipe/recipe.yaml`. Bump all three together.

See [CHANGELOG](https://github.com/mojothon/libc/blob/main/CHANGELOG.md) for
the release history.
