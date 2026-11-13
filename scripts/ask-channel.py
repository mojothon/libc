"""Ask the channel's own repodata whether the version just published is there.

An upload that said done is not a package a user can ask the channel
for. The repodata is the channel's word about what it holds, and this
is the release read back from it: one platform, one package name, one
version -- and, since a version on a channel is a promise about what
a download opens, the package is taken down and its metadata tape is
unrolled. What it holds must be what the recipe says goes in: the
compiled package, the tests the build ran, and the licence. The whole
file is asked for its sum again, against the one the channel's index
wrote down, so what is read is what the channel says it serves. The
index can take a minute to catch up with the upload, so the asking
waits and asks again before it believes an absence.
"""

import hashlib
import io
import json
import subprocess
import sys
import tarfile
import time
import urllib.request
import zipfile

UA = "libc-release-check/1.0"


def fetch(url: str) -> bytes:
    # The channel sits behind a content network that answers a default
    # Python client with forbidden, and answers a browser with the
    # data; say whose asking this is.
    #
    # Three asks, spaced: a connection that times out, or a request the
    # server drops, is the network's weather and not the version being
    # missing, and the wait's red is only meaningful if a dropped
    # packet cannot cause it.
    for attempt in range(3):
        request = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            return urllib.request.urlopen(request, timeout=120).read()
        except OSError:
            if attempt == 2:
                raise
            time.sleep(10)


def untape(blob: bytes) -> dict[str, bytes]:
    """The members of a zstd-compressed tar, by the runner's own zstd."""
    tape = subprocess.run(
        ["zstd", "-d"], input=blob, capture_output=True, check=True
    ).stdout
    out: dict[str, bytes] = {}
    with tarfile.open(fileobj=io.BytesIO(tape), mode="r:") as box:
        for member in box.getmembers():
            if member.isfile():
                out[member.name] = box.extractfile(member).read()
    return out


def repodata_entry(platform: str, version: str, channel: str) -> dict:
    """The channel's record of the version, waiting out the index.

    The wait is fifty minutes, not five: 0.14.1 appeared in the index
    within five minutes of its upload, 0.14.2 took forty -- the server
    took the packages the moment they were offered and its index let
    them be seen when it was ready, which is the server's own pace and
    not a promise the release makes. The asking keeps the pace it needs.
    """
    url = f"https://prefix.dev/{channel}/{platform}/repodata.json"
    for attempt in range(50):
        data = json.loads(fetch(url))
        packages = list(data["packages"].values()) + list(
            data.get("packages.conda", {}).values()
        )
        mine = [
            p
            for p in packages
            if p["name"] == "libc" and p["version"] == version
        ]
        if mine:
            if len(mine) > 1:
                raise SystemExit(
                    f"{platform}: the channel lists {version} {len(mine)} times"
                )
            return mine[0]
        if attempt == 5:
            versions = sorted(
                {p["version"] for p in packages if p["name"] == "libc"}
            )
            raise SystemExit(
                f"{platform}: the channel has {versions}, not {version}"
            )
        time.sleep(60)
    raise SystemExit(f"{platform}: the index never answered")


def ask_contents(platform: str, version: str, entry: dict) -> None:
    """Take the package down and ask what the recipe promised of it."""
    build = entry["build"]
    blob = fetch(
        f"https://prefix.dev/mojo-force/{platform}/"
        f"libc-{version}-{build}.conda"
    )
    # The file tape is not unrolled -- its contents are what `paths.json`
    # already names, and the whole file's sum is what says the tape is
    # the one the index describes.
    if hashlib.sha256(blob).hexdigest() != entry["sha256"]:
        raise SystemExit(
            f"{platform}: the bytes sum to something the index never wrote"
        )
    with zipfile.ZipFile(io.BytesIO(blob)) as box:
        infos = [n for n in box.namelist() if n.startswith("info-")]
        pkgs = [n for n in box.namelist() if n.startswith("pkg-")]
        if len(infos) != 1 or len(pkgs) != 1:
            raise SystemExit(
                f"{platform}: the package holds {len(infos)} metadata and "
                f"{len(pkgs)} file tapes; a conda package holds one of each"
            )
        members = untape(box.read(infos[0]))
        paths = json.loads(members["info/paths.json"])

    files = {p["_path"] for p in paths["paths"]}
    tests = [f for f in files if f.startswith("etc/conda/test-files/")]
    missing = []
    if "lib/mojo/libc.mojoc" not in files:
        missing.append("the compiled package")
    if "info/licenses/LICENSE" not in members:
        missing.append("the licence")
    if not tests:
        missing.append("the tests the build ran")
    if missing:
        raise SystemExit(f"{platform}: the package opens without " +
                         ", ".join(missing))
    print(
        f"{platform}: {version} opens -- the compiled package, the licence, "
        f"and {len(tests)} tests, and the bytes sum to what the index says"
    )


def main() -> int:
    platform, version, channel = sys.argv[1], sys.argv[2], sys.argv[3]
    entry = repodata_entry(platform, version, channel)
    ask_contents(platform, version, entry)
    return 0


if __name__ == "__main__":
    sys.exit(main())
