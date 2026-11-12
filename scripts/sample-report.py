"""Read the sample's answers back, and put the machines' words side by side.

The weekly sample runs on three machines, and each answers in its own
job's log -- three files a reader has to open, each a page of runs, to
learn what the asking came back with. This asks the run for its jobs
and their logs, takes every tally the probe printed, and lays them out
one line per machine and axis, so the three machines' answers are one
table. A job that did not finish green is red here; a job that
answered nothing is red here too, a machine asked a question it did
not answer being the same failure as one whose answer was a survivor.
"""

import json
import re
import subprocess
import sys
import time

TALLY = re.compile(
    r"caught (\d+), crashed (\d+), hung (\d+), same answer (\d+),"
    r" unobservable (\d+), survived (\d+), flaky (\d+),"
    r" did not build (\d+)"
)

FIELDS = (
    "caught",
    "crashed",
    "hung",
    "same",
    "unobservable",
    "survived",
    "flaky",
    "nobuild",
)


def gh(*argv: str) -> str:
    proc = subprocess.run(["gh", *argv], capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit(f"gh {' '.join(argv)} said no: {proc.stderr.strip()}")
    return proc.stdout


def tallies(run: str) -> list[tuple[str, str, dict[str, int]]]:
    """Every tally the run's logs printed, with the job and step that said it."""
    log = None
    for attempt in range(3):
        proc = subprocess.run(
            ["gh", "run", "view", run, "--log"], capture_output=True, text=True
        )
        if proc.returncode == 0 and proc.stdout.strip():
            log = proc.stdout
            break
        # The log download answers with a gateway error now and then;
        # it has answered to the asking again every time so far.
        time.sleep(30)
    if log is None:
        raise SystemExit("the run's logs would not come down; ask again later")
    found = []
    for line in log.splitlines():
        match = TALLY.search(line)
        if not match:
            continue
        where = line.split("\t")
        job = where[0].strip() if where else "?"
        step = "?"
        if len(where) > 1 and where[1].strip() != "UNKNOWN STEP":
            step = where[1].strip()
        found.append(
            (job, step, dict(zip(FIELDS, map(int, match.groups()))))
        )
    return found


def main() -> int:
    if len(sys.argv) > 1:
        run = sys.argv[1]
    else:
        run = gh(
            "run", "list", "--workflow=mutation.yml", "--limit", "1",
            "--json", "databaseId", "--jq", ".[0].databaseId",
        ).strip()
    report = json.loads(gh("run", "view", run, "--json", "jobs,conclusion"))
    if report.get("conclusion") not in (None, "success"):
        print(f"the run ended {report['conclusion']}\n")
    answers = tallies(run)
    per_job: dict[str, list[tuple[str, dict[str, int]]]] = {}
    for job, step, numbers in answers:
        per_job.setdefault(job, []).append((step, numbers))
    print(
        f"{'machine':44} {'step':26} "
        + " ".join(f"{f:>11}" for f in FIELDS)
    )
    wrong: list[str] = []
    for job in report["jobs"]:
        name = job["name"]
        if job["conclusion"] not in (None, "success"):
            wrong.append(f"{name}: the job ended {job['conclusion']}")
        mine = per_job.get(name, [])
        if not mine:
            wrong.append(f"{name}: the job printed no tally at all")
        for step, numbers in mine:
            row = " ".join(f"{numbers[f]:>11}" for f in FIELDS)
            print(f"{name[:44]:44} {step[:26]:26} {row}")
            if numbers["survived"]:
                wrong.append(f"{name} ({step}): survived {numbers['survived']}")
    if wrong:
        print()
        for line in wrong:
            print(f"  *** {line}")
        return 1
    print("\n  every machine answered, and no machine answered with a survivor")
    return 0


if __name__ == "__main__":
    sys.exit(main())
