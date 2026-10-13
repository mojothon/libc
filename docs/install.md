# Install

`libc` is distributed as a conda package that installs a precompiled Mojo
package (`libc.mojoc`) into your environment's `lib/mojo` directory, so
`import libc` resolves without extra flags.

## pixi

```bash
pixi add --from https://conda.modular.com/max --channel mojo-force libc
```

or, in `pixi.toml`:

```toml
[workspace]
channels = ["https://conda.modular.com/max", "conda-forge", "mojo-force"]

[dependencies]
libc = ">=0.10.0,<0.11"
mojo = ">=1.1.0,<2"
```

## conda / mamba

```bash
conda install -c https://conda.modular.com/max -c mojo-force libc
```

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
