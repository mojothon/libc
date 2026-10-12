#!/usr/bin/env bash
#
# Fail when `mojo format` would change anything.
#
# `mojo format` has no --check flag in Mojo 1.x, and comparing against git
# breaks whenever the working tree already holds unrelated edits, so format a
# copy of the tree and diff the two.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cp -a "${ROOT}/src" "${ROOT}/tests" "${WORK}/"
mojo format -q "${WORK}/src" "${WORK}/tests"

status=0
for dir in src tests; do
    if ! diff -ru "${ROOT}/${dir}" "${WORK}/${dir}"; then
        echo "error: ${dir}/ is not formatted; run 'pixi run format'" >&2
        status=1
    fi
done

if [ ${status} -eq 0 ]; then
    echo "all sources are formatted"
fi
exit ${status}
