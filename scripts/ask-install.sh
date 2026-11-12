#!/bin/bash
# Walk the install page as a reader walks it, in a directory that has
# never seen this checkout.
#
# Everything upstream is a claim about parts: the package builds, the
# upload lands, the repodata holds the version, the download opens.
# What a reader does is none of those -- they make an empty directory,
# ask pixi for the package by the channels the install page names, and
# call the library. If any part is wrong, the journey is where it
# shows, and this is the journey.
#
# Usage: ask-install.sh VERSION

set -euo pipefail

VERSION="${1:?usage: ask-install.sh VERSION}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# The three channels, spelled out the way the install page says to --
# the short way is a channel that is not there, on a package that is.
pixi init -c https://conda.modular.com/max -c conda-forge \
    -c https://prefix.dev/mojo-force . >/dev/null
pixi add "libc==$VERSION" >/dev/null

cat > hello.mojo <<'PROG'
from libc import __version__
from libc.errno import EINVAL
from libc.unistd import getpid, getuid


def main():
    print("libc", __version__, "EINVAL", EINVAL, "uid", getuid(), "pid", getpid())
PROG

ANSWER="$(pixi run mojo run hello.mojo)"
echo "$ANSWER"
echo "$ANSWER" | grep -q "libc $VERSION EINVAL 22" || {
    echo "the journey's answer is not the one the page promises" >&2
    exit 1
}
echo "the install page's journey ends where it says it does"
