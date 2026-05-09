#!/bin/bash
# Copy benchmark plots from the submodule to the paper's figures directory.
# The canonical layout is top-level {quickdraw, clic, div2k_8q}/plots/ plus
# results/plots/ for cross-dataset summary figures.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$REPO_DIR/ParametricDFT-Benchmarks.jl/results"
ANALYSIS_DIR="$REPO_DIR/ParametricDFT-Benchmarks.jl/analysis"
PDFT_PY_RESULTS="$REPO_DIR/pdft-benchmarks/results"  # python pdft-benchmarks results tree
OUTPUT_DIR="$REPO_DIR/figures/benchmarks"

mkdir -p "$OUTPUT_DIR/mse" "$OUTPUT_DIR/topology" "$OUTPUT_DIR/freqspace" "$OUTPUT_DIR/sweep"

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
# DIV2K centerpiece image: prefer the 13-method gallery from pdft-benchmarks
# (Python results tree). Override with FREQ_CENTER if you want a different
# image index.
FREQ_CENTER="${FREQ_CENTER:-0390}"
div2k_freq_src="$PDFT_PY_RESULTS/div2k_8q_pca_vs_block_dct/figures"
copy_one "$div2k_freq_src/freq_recon_grid_img${FREQ_CENTER}_freq.pdf" "$OUTPUT_DIR/freqspace/spectra_${FREQ_CENTER}.pdf"
copy_one "$div2k_freq_src/freq_recon_grid_img${FREQ_CENTER}.pdf"      "$OUTPUT_DIR/freqspace/reconstructions_${FREQ_CENTER}.pdf"
# 5-method compact version (FFT, DCT, QFT, BlockDCT, BlockRealRich) for the
# main-text headline figure; full 13-method gallery above goes to appendix.
copy_one "$div2k_freq_src/freq_recon_grid_5method_img${FREQ_CENTER}_freq.pdf" "$OUTPUT_DIR/freqspace/spectra_5method_${FREQ_CENTER}.pdf"
copy_one "$div2k_freq_src/freq_recon_grid_5method_img${FREQ_CENTER}.pdf"      "$OUTPUT_DIR/freqspace/reconstructions_5method_${FREQ_CENTER}.pdf"

# Quick Draw centerpiece image: same convention.
QD_FREQ_CENTER="${QD_FREQ_CENTER:-0}"
qd_freq_src="$PDFT_PY_RESULTS/quickdraw_pca_vs_block_dct/figures"
copy_one "$qd_freq_src/freq_recon_grid_img${QD_FREQ_CENTER}_freq.pdf" "$OUTPUT_DIR/freqspace/quickdraw_freq_img${QD_FREQ_CENTER}.pdf"
copy_one "$qd_freq_src/freq_recon_grid_img${QD_FREQ_CENTER}.pdf"      "$OUTPUT_DIR/freqspace/quickdraw_recon_img${QD_FREQ_CENTER}.pdf"
# 5-method compact version (FFT, DCT, QFT, BlockDCT, RealRichBasis) for §5.3.
copy_one "$qd_freq_src/freq_recon_grid_5method_img${QD_FREQ_CENTER}_freq.pdf" "$OUTPUT_DIR/freqspace/quickdraw_freq_5method_img${QD_FREQ_CENTER}.pdf"
copy_one "$qd_freq_src/freq_recon_grid_5method_img${QD_FREQ_CENTER}.pdf"      "$OUTPUT_DIR/freqspace/quickdraw_recon_5method_img${QD_FREQ_CENTER}.pdf"

echo "Block-size sweep figures (Python pdft-benchmarks) -> $OUTPUT_DIR/sweep"
copy_one "$PDFT_PY_RESULTS/block_size_sweep/quickdraw/figures/sweep_quickdraw.pdf" \
         "$OUTPUT_DIR/sweep/sweep_quickdraw.pdf"
copy_one "$PDFT_PY_RESULTS/block_size_sweep/div2k_8q/figures/sweep_div2k_8q.pdf" \
         "$OUTPUT_DIR/sweep/sweep_div2k_8q.pdf"

echo "Benchmark plots copied to $OUTPUT_DIR"
