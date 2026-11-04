#!/usr/bin/env bash
#
# Upload every conda package produced by `pixi run build-conda` to prefix.dev.
#
# Requires PREFIX_API_KEY in the environment, and rattler-build on PATH
# (the `build` pixi environment provides it).
set -euo pipefail

CHANNEL="${CHANNEL:-mojo-force}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"

shopt -s nullglob
packages=("${OUTPUT_DIR}"/**/*.conda)

if [ ${#packages[@]} -eq 0 ]; then
    echo "no .conda packages found under ${OUTPUT_DIR}/ - run 'pixi run build-conda' first" >&2
    exit 1
fi

if [ -z "${PREFIX_API_KEY:-}" ]; then
    echo "PREFIX_API_KEY is not set" >&2
    exit 1
fi

failed=0
for package in "${packages[@]}"; do
    echo "uploading ${package} to ${CHANNEL}"
    if output=$(rattler-build upload prefix -c "${CHANNEL}" "${package}" 2>&1); then
        echo "${output}"
        continue
    fi
    # A rebuild of a version the channel already has produces the same file
    # name and a different hash -- the package metadata carries the time it
    # was built -- and prefix.dev answers 409 rather than replace it. That
    # is one platform's file already being there, which is not a reason to
    # abandon the other platform's file in the same run. The body says
    # "already exists" when the upload names the file and only "409
    # Conflict" when it does not, so both are read.
    if grep -qiE "already exists|409 conflict" <<<"${output}"; then
        echo "already in ${CHANNEL}, left as it is: ${package}"
        continue
    fi
    echo "${output}" >&2
    failed=1
done
exit "${failed}"
