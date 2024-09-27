#!/bin/bash

for file in output/**/*.conda; do
    magic run rattler-build upload prefix -c "mojo-force" "$file" || true
done
