# Install

`libc` is distributed as a conda package that installs a precompiled Mojo
package (`libc.mojoc`) into your environment's `lib/mojo` directory, so
`import libc` resolves without extra flags.

## pixi

```bash
pixi init -c https://conda.modular.com/max -c conda-forge -c https://prefix.dev/mojo-force .
pixi add libc
```

or, in `pixi.toml`:

```toml
[workspace]
channels = ["https://conda.modular.com/max", "conda-forge", "https://prefix.dev/mojo-force"]

[dependencies]
libc = ">=0.14.1,<0.15"
mojo = ">=1.2.0,<2"
```

## conda / mamba

```bash
conda install -c https://conda.modular.com/max -c https://prefix.dev/mojo-force libc
```

!!! note "The channel is a URL, and `mojo-force` on its own is not it"
    A bare channel name is read as an anaconda.org channel, so `-c mojo-force`
    asks `conda.anaconda.org/mojo-force`, which does not exist — and pixi reads
    `"mojo-force"` in `channels` the same way. The channel lives on prefix.dev,
    which is why both of the commands above spell it out. Written the short way
    the failure is a `404` for a channel that is not there, on a package that is.

!!! note "This page is walked, not only written"
    Every release, an empty directory that has never seen the checkout runs
    the commands above, installs the release the way a reader does, and calls
    the library — `EINVAL` by number, a process id, a user id. The walk also
    happens every week against the newest version on the channel and whatever
    toolchain pixi resolves that day: the compiled package is frozen at the
    compiler that built it, and the compiler moves without this repository
    moving. If the page ever stops working — at a release, or under a new
    compiler — the patrol that caught it does not go out green.

## From source

```bash
git clone https://github.com/mojothon/libc.git
cd libc
pixi run test            # run the test suite
pixi run package         # build dist/libc.mojoc
```

To consume a source checkout directly, point the compiler at `src`:

```bash
mojo run -I src your_program.mojo
```

!!! note
    A precompiled `.mojoc` package is tied to the compiler version that produced
    it. Rebuild the package (or use the source checkout) after upgrading Mojo.
