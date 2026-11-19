"""Check that the weekly patrols are actually walking.

Two workflows are meant to run themselves: the compatibility patrol
every Friday, the mutation sample every Monday. Their `cron` lines say
so, and saying so is not running -- GitHub's scheduler held this
repository's patrol past three hours past its minute on the first
Friday it was due, and its own docs say a scheduled event can be
delayed or skipped at busy times, which makes the schedule a promise
the scheduler is free to break in silence. A patrol that stops firing
fails exactly the way the patrol was built to catch: quietly, for
every week it does not walk, while the compiled package and the
compiler drift apart unwitnessed.

This asks, of each patrol, when its workflow last ran -- any run
counts, a dispatch as much as a schedule, because what the patrol owes
the shelf is the walk itself and not the reason the walk happened. A
patrol that has not walked in eight days is a patrol that has stopped,
and this check says so out loud instead of letting the calendar pass
unnoticed.

The asking goes to `gh`, whose own credentials outlast the bare
socket's patience with the API, the way the release-assets check asks.
"""

import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

WORKFLOWS = {
    "compat.yml": "the compatibility patrol",
    "mutation.yml": "the mutation sample",
}
MAX_AGE_DAYS = 8

# The asking of the api is the shared one -- one copy of the patience,
# where a copy of it here and one in the release-assets check would
# have been the same omission twice waiting to happen.
_gh_spec = importlib.util.spec_from_file_location(
    "gh", Path(__file__).resolve().parent / "gh.py"
)
gh = importlib.util.module_from_spec(_gh_spec)
_gh_spec.loader.exec_module(gh)
gh_ask = gh.gh_ask


def last_run(workflow: str) -> dict | None:
    """The most recent run of a workflow, any event that ran it."""
    done = gh_ask(
        [
            "repos/mojothon/libc/actions/workflows/" f"{workflow}/runs"
            "?per_page=1"
        ]
    )
    if not done:
        return None
    runs = json.loads(done)["workflow_runs"]
    return runs[0] if runs else None


def main() -> None:
    now = datetime.now(timezone.utc)
    ages = {}
    stale = []
    for workflow, name in WORKFLOWS.items():
        run = last_run(workflow)
        if run is None:
            ages[workflow] = None
            stale.append(f"{name} ({workflow}) has never run")
            continue
        created = datetime.fromisoformat(
            run["created_at"].replace("Z", "+00:00")
        )
        ages[workflow] = run["created_at"]
        if (now - created).days > MAX_AGE_DAYS:
            stale.append(
                f"{name} ({workflow}) last ran "
                f"{(now - created).days} days ago ({run['created_at']})"
            )
    if stale:
        for line in stale:
            print(f"  {line}", file=sys.stderr)
        raise SystemExit(
            "a patrol that has not walked in over eight days is a "
            "patrol that has stopped -- dispatch it, and ask the "
            "scheduler why it said nothing"
        )
    walked = ", ".join(
        f"{name} last ran {ages[w]}" for w, name in WORKFLOWS.items()
    )
    print(f"both patrols walked within the last eight days: {walked}")


if __name__ == "__main__":
    main()
