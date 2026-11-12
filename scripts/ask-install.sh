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
    #
    # The asking goes to the GraphQL view, not to the repodata file:
    # the repodata a bare request gets is the channel's newest
    # publication, a snapshot that rolls with the index's own pace and
    # has been caught mid-roll holding none of the shelf at all, while
    # the GraphQL view is the server's word about what the channel
    # keeps. A patrol that asks the snapshot can be red on a version
    # that is there; a patrol that asks the server's word is red only
    # when the shelf itself has changed.
    VERSION="$(python3 - <<'PY'
import json, urllib.request

request = urllib.request.Request(
    "https://prefix.dev/api/graphql",
    data=json.dumps(
        {
            "query": '{ p: package(channelName: "mojo-force", '
            'name: "libc") { versions { page { version } } } }'
        }
    ).encode(),
    headers={
        "User-Agent": "libc-release-check/1.0",
        "Content-Type": "application/json",
    },
)
result = json.load(urllib.request.urlopen(request))
entry = result["data"]["p"]
if entry is None:
    raise SystemExit("the channel's view holds no libc at all")
versions = sorted(v["version"] for v in entry["versions"]["page"])
if not versions:
    raise SystemExit("the channel's view holds no libc at all")
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
