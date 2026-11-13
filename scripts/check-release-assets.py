"""Check that the GitHub release's assets are the channel's bytes.

The release page and the conda channel are two shelves holding the
same packages, and nothing walked the distance between them until
0.14.1 was out: the release was assembled by one job from the build
artifacts and the channel was fed by another from the same artifacts,
so the two agree as long as both take what the build produced -- but
each is its own copy, and a copy that a hand replaces, or an upload
that lands twice, or an asset edited after the fact is a difference
neither side can see. The reader who installs from the channel and
the reader who downloads from the release page would hold different
bytes and both would be told they hold the same release.

The comparison is by the sum the channel's index already records: the
index says what sha256 each package file it holds sums to (and
`ask-channel.py` opens the file and asks the index's sum of it, so
the index's word about the channel is itself witnessed), and this
check asks the same sum of every asset on the release page. Where the
two sums agree, the release page's copy and the channel's copy are
the same bytes; where one side holds a file the other does not name,
the shelves have come apart.

The version asked of is the newest one the changelog announces, which
is the one the release was cut for.
"""

import hashlib
import json
import re
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = "libc-release-check/1.0"
PLATFORMS = ["linux-64", "linux-aarch64", "osx-arm64"]


def changelog_version() -> str:
    """The newest version the changelog announces."""
    text = (ROOT / "CHANGELOG.md").read_text()
    m = re.search(r"^## \[([0-9]+\.[0-9]+\.[0-9]+)\]", text, re.M)
    if m is None:
        raise SystemExit("the changelog announces no version at all")
    return m.group(1)


def fetch(url: str) -> bytes:
    """The bytes a URL serves, asked with a name the server answers.

    Three asks, spaced: a connection that times out, or a request the
    server drops, is the network's weather and not the shelves having
    come apart, and a check whose red a dropped packet can cause is a
    check that cries wolf.
    """
    for attempt in range(3):
        request = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            return urllib.request.urlopen(request, timeout=120).read()
        except OSError:
            if attempt == 2:
                raise
            time.sleep(10)


def gh_ask(args: list[str]) -> str:
    """The api's answer, by the way `gh` asks: three asks, spaced.

    The same patience the fetches are given, given to the process that
    asks the api for them: a connection `gh` cannot make is the
    network's weather, and the red the check raises must be the
    shelves having come apart, not a dropped packet. A 404 is not
    weather -- it is the api saying the release is not there, which is
    the check's red, said the first time it is said.
    """
    for attempt in range(3):
        try:
            done = subprocess.run(
                ["gh", "api", *args],
                capture_output=True,
                text=True,
                timeout=120,
            )
        except subprocess.TimeoutExpired:
            if attempt == 2:
                raise
            time.sleep(10)
            continue
        if done.returncode == 0:
            return done.stdout
        if "HTTP 404" in done.stderr:
            break
        if attempt == 2:
            raise SystemExit(f"asking GitHub failed: {done.stderr.strip()}")
        time.sleep(10)
    return ""


def release_assets(version: str) -> dict[str, str]:
    """{asset name: the sum its bytes make}, from the release page.

    The release's metadata is asked of `gh`, not of the API with a
    bare socket: api.github.com has been caught dropping connections
    for minutes at a stretch while the CDN that holds the assets
    answered every time, and `gh` carries its own credentials and its
    own patience. The assets themselves come from the download URLs
    the metadata names -- the same CDN, asked the way a browser asks.
    """
    done = gh_ask([f"repos/mojothon/libc/releases/tags/v{version}"])
    if not done:
        raise SystemExit(f"GitHub holds no release tagged v{version}")
    release = json.loads(done)
    assets = {}
    for asset in release["assets"]:
        blob = fetch(asset["browser_download_url"])
        assets[asset["name"]] = hashlib.sha256(blob).hexdigest()
    return assets


def channel_assets(version: str) -> dict[str, str]:
    """{package filename: the sum the index records}, every platform.

    The repodata a bare request gets is the channel's newest
    publication, a snapshot that rolls with the index's own pace -- it
    has been caught mid-roll holding none of the shelf at all -- so an
    asking that finds the version missing is asked again before it is
    believed, the way the channel job asks: the version's absence is
    only stated after the asking has outlasted the roll.
    """
    assets = {}
    for platform in PLATFORMS:
        url = f"https://prefix.dev/mojo-force/{platform}/repodata.json"
        mine = []
        for attempt in range(10):
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
                break
            if attempt == 9:
                versions = sorted(
                    {p["version"] for p in packages if p["name"] == "libc"}
                )
                raise SystemExit(
                    f"{platform}: the channel holds {versions}, not {version}, "
                    "after ten askings"
                )
            time.sleep(20)
        if len(mine) != 1:
            versions = sorted(
                {p["version"] for p in packages if p["name"] == "libc"}
            )
            raise SystemExit(
                f"{platform}: the channel lists {version} {len(mine)} times "
                f"(it holds {versions})"
            )
        entry = mine[0]
        # The index does not carry the filename; it carries the build,
        # and the file is named the way the shelf names every package:
        # name, version, build.
        assets[f"libc-{version}-{entry['build']}.conda"] = entry["sha256"]
    return assets


def main() -> None:
    version = changelog_version()
    github = release_assets(version)
    channel = channel_assets(version)

    missing_on_github = sorted(set(channel) - set(github))
    missing_on_channel = sorted(set(github) - set(channel))
    if missing_on_github:
        raise SystemExit(
            f"v{version}: the channel holds {missing_on_github} "
            "the release page does not"
        )
    if missing_on_channel:
        raise SystemExit(
            f"v{version}: the release page holds {missing_on_channel} "
            "the channel does not"
        )
    differing = sorted(
        name for name in channel if github[name] != channel[name]
    )
    if differing:
        raise SystemExit(
            f"v{version}: {differing} sums differently on the release "
            "page than the channel's index records"
        )
    print(
        f"v{version}: the release page's {len(github)} assets are the "
        "channel's bytes, each by the sum the index records"
    )


if __name__ == "__main__":
    main()
