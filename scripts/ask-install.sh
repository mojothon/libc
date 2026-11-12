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
# The version `latest` asks for is the channel's newest -- which is
# what a reader gets today, against the toolchain pixi resolves today.
# The compiled package is frozen at the compiler that built it, and the
# compiler moves without this repository moving; a journey that only
# ran at release time would meet the compiler of release day and call
# that compatibility. Asked weekly, it is the patrol that finds the
# moving part and the frozen one disagreeing -- in a week, not at the
# next release's door.
#
# Usage: ask-install.sh VERSION|latest

set -euo pipefail

VERSION="${1:?usage: ask-install.sh VERSION|latest}"

if [ "$VERSION" = "latest" ]; then
    # The newest version the channel holds, by the same asking the
    # channel job makes of a release. Highest of what is there, so a
    # patrol never installs something that is no longer the shelf.
    VERSION="$(python3 - <<'PY'
import json, urllib.request

request = urllib.request.Request(
    "https://prefix.dev/mojo-force/linux-64/repodata.json",
    headers={"User-Agent": "libc-release-check/1.0"},
)
data = json.load(urllib.request.urlopen(request))
packages = list(data["packages"].values()) + list(
    data.get("packages.conda", {}).values()
)
versions = sorted(
    {p["version"] for p in packages if p["name"] == "libc"}
)
print(versions[-1])
PY
)"
    echo "the channel's newest is $VERSION; that is what a reader gets"
fi

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
