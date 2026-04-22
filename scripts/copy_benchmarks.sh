#!/bin/bash
# Copy benchmark plots from the submodule to the paper's figures directory.
# The canonical layout is top-level {quickdraw, clic, div2k_8q}/plots/ plus
# results/plots/ for cross-dataset summary figures.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$REPO_DIR/ParametricDFT-Benchmarks.jl/results"
ANALYSIS_DIR="$REPO_DIR/ParametricDFT-Benchmarks.jl/analysis"
OUTPUT_DIR="$REPO_DIR/figures/benchmarks"

mkdir -p "$OUTPUT_DIR/mse" "$OUTPUT_DIR/topology" "$OUTPUT_DIR/freqspace"

copy_one() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        echo "  $(basename "$dst")"
    else
        echo "  [skip] missing: $src"
    fi
}

# Prefer a bare reconstruction_grid.png; fall back to the first numbered grid.
pick_recon() {
    local dir="$1"
    if [ -f "$dir/reconstruction_grid.png" ]; then
        echo "$dir/reconstruction_grid.png"
    else
        echo "$dir/reconstruction_grid_1.png"
    fi
}

echo "MSE figures -> $OUTPUT_DIR/mse"
# Per-dataset reconstruction grids + training curves (skip datasets with no plots).
qd_dir="$RESULTS_DIR/quickdraw/plots"
copy_one "$(pick_recon "$qd_dir")"       "$OUTPUT_DIR/mse/quickdraw_reconstruction_grid.png"
copy_one "$qd_dir/training_curves.png"    "$OUTPUT_DIR/mse/quickdraw_training_curves.png"

dv_dir="$RESULTS_DIR/div2k_8q/plots"
copy_one "$(pick_recon "$dv_dir")"                "$OUTPUT_DIR/mse/div2k_reconstruction_grid.png"
copy_one "$dv_dir/training_curves.png"            "$OUTPUT_DIR/mse/div2k_training_curves.png"
copy_one "$dv_dir/step_training_losses.png"       "$OUTPUT_DIR/mse/div2k_step_losses.png"

# Cross-dataset summary plots.
copy_one "$RESULTS_DIR/plots/cross_dataset_psnr.png" "$OUTPUT_DIR/mse/cross_dataset_psnr.png"
copy_one "$RESULTS_DIR/plots/cross_dataset_ssim.png" "$OUTPUT_DIR/mse/cross_dataset_ssim.png"

echo "Topology figures -> $OUTPUT_DIR/topology"
copy_one "$(pick_recon "$dv_dir")"         "$OUTPUT_DIR/topology/div2k_8q_reconstruction_grid.png"
copy_one "$dv_dir/training_curves.png"     "$OUTPUT_DIR/topology/div2k_8q_training_curves.png"

echo "Frequency-space analysis -> $OUTPUT_DIR/freqspace"
# Use the generalized (newer) run as the canonical source of figures.
# Override with FREQ_RUN=div2k_8q if you need the earlier run.
FREQ_RUN="${FREQ_RUN:-div2k_8q_generalized}"
# Centerpiece image for the frequency-space section.
FREQ_CENTER="${FREQ_CENTER:-0390}"
freq_src="$ANALYSIS_DIR/$FREQ_RUN/$FREQ_CENTER"
copy_one "$freq_src/frequency_spectra.pdf"      "$OUTPUT_DIR/freqspace/spectra_${FREQ_CENTER}.pdf"
copy_one "$freq_src/frequency_spectra_3d.pdf"   "$OUTPUT_DIR/freqspace/spectra_3d_${FREQ_CENTER}.pdf"
copy_one "$freq_src/kept_coefficient_masks.pdf" "$OUTPUT_DIR/freqspace/masks_${FREQ_CENTER}.pdf"
copy_one "$freq_src/reconstructions.pdf"        "$OUTPUT_DIR/freqspace/reconstructions_${FREQ_CENTER}.pdf"
copy_one "$freq_src/cumulative_energy.pdf"      "$OUTPUT_DIR/freqspace/cumulative_energy_${FREQ_CENTER}.pdf"

echo "Benchmark plots copied to $OUTPUT_DIR"
