#!/bin/bash
# Copy benchmark plots from submodule to paper figures directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BENCH_DIR="$REPO_DIR/ParametricDFT-Benchmarks.jl/results/plots"
OUTPUT_DIR="$REPO_DIR/figures/benchmarks"

for subdir in mse l1norm topology; do
    src="$BENCH_DIR/$subdir"
    dst="$OUTPUT_DIR/$subdir"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -v "$src"/*.png "$dst"/ 2>/dev/null || echo "No PNGs in $src"
    else
        echo "Warning: $src not found, skipping"
    fi
done

echo "Benchmark plots copied to $OUTPUT_DIR"
