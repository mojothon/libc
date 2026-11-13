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

import json
import subprocess
import sys
from datetime import datetime, timezone

WORKFLOWS = {
    "compat.yml": "the compatibility patrol",
    "mutation.yml": "the mutation sample",
}
MAX_AGE_DAYS = 8


def last_run(workflow: str) -> dict | None:
    """The most recent run of a workflow, any event that ran it."""
    done = subprocess.run(
        [
            "gh",
            "api",
            f"repos/mojothon/libc/actions/workflows/{workflow}/runs"
            "?per_page=1",
        ],
        capture_output=True,
        text=True,
    )
    if done.returncode != 0:
        raise SystemExit(
            f"asking GitHub for the {workflow} runs failed: "
            f"{done.stderr.strip()}"
        )
    runs = json.loads(done.stdout)["workflow_runs"]
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
