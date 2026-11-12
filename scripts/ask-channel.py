"""Ask the channel's own repodata whether the version just published is there.

An upload that said done is not a package a user can ask the channel
for. The repodata is the channel's word about what it holds, and this
is the release read back from it: one platform, one package name, one
version, and the index can take a minute to catch up with the upload,
so the asking waits and asks again before it believes an absence.
"""

import json
import sys
import time
import urllib.request


def main() -> int:
    platform, version, channel = sys.argv[1], sys.argv[2], sys.argv[3]
    url = f"https://prefix.dev/{channel}/{platform}/repodata.json"
    for attempt in range(6):
        # The channel sits behind a content network that answers a
        # default Python client with forbidden, and answers a browser
        # with the data; say whose asking this is.
        request = urllib.request.Request(
            url, headers={"User-Agent": "libc-release-check/1.0"}
        )
        with urllib.request.urlopen(request) as answer:
            data = json.load(answer)
        packages = list(data["packages"].values()) + list(
            data.get("packages.conda", {}).values()
        )
        versions = {p["version"] for p in packages if p["name"] == "libc"}
        if version in versions:
            print(f"{platform}: {version} is on the channel")
            return 0
        if attempt == 5:
            raise SystemExit(
                f"{platform}: the channel has {sorted(versions)}, not {version}"
            )
        time.sleep(60)
    return 1


if __name__ == "__main__":
    sys.exit(main())
