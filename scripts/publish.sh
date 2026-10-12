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

for package in "${packages[@]}"; do
    echo "uploading ${package} to ${CHANNEL}"
    rattler-build upload prefix -c "${CHANNEL}" "${package}"
done
