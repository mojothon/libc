"""The api's answer, by the way `gh` asks: three asks, spaced.

One asking, two checks -- the release-assets check asks the release's
metadata with it, the patrol check asks when the patrols last walked
with it -- and one copy, because the week's own history is what a copy
is worth: the patience lesson was written into the new check and left
out of the askings that came before it, and each copy of this would
have been the same omission waiting to happen again.

A connection `gh` cannot make is the network's weather, and
api.github.com has been caught dropping them for minutes at a stretch
-- three asks, spaced, with a ceiling on how long any one may hold, so
the red a check raises is the shelves having come apart and not a
dropped packet. A 404 is not weather: it is the api saying there is
nothing there, and it is returned as nothing the first time it is
said -- the caller knows whether nothing is its red.
"""

import subprocess
import time


def gh_ask(args: list[str]) -> str:
    """The stdout of `gh api` with the given arguments, or "" on a 404."""
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
