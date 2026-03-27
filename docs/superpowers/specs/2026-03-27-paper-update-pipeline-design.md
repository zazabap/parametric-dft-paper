# Paper Update Pipeline — Design Spec

## Goal

Create an automated pipeline that pulls tensor network diagrams from ParametricDFT.jl and benchmark results from ParametricDFT-Benchmarks.jl to produce an up-to-date paper via `make all`.

**Key constraint:** All figure and plot generation lives in the submodules. The paper repo only copies and references outputs.

## Paper Structure

```
1. Introduction
2. Background: Tensor Network Representation of the FFT
   - Figure 1: FFT tensor network decomposition (from Typst)
3. Parametric Circuit Topologies
   - Figure 2: QFT circuit diagram (from Typst)
   - Figure 3: Entangled QFT circuit diagram (from Typst)
   - Figure 4: TEBD ring topology diagram (from Typst)
   - Figure 5: MERA hierarchical circuit diagram (from Typst)
   - Table 1: Comparison of Circuit Topologies (existing)
4. Training Objective and Optimization
5. Experiments
   5.1 Datasets and Setup
   5.2 MSE Loss Results (Primary)
       - Table 2: Quick Draw rate-distortion (MSE loss)
       - Table 3: DIV2K rate-distortion (MSE loss)
       - Table 4: CLIC rate-distortion (MSE loss)
       - Figure 6: Reconstruction grids (MSE, per dataset)
       - Figure 7: Cross-dataset PSNR/SSIM comparison (MSE)
   5.3 L1 Norm Results
       - Table 5: Rate-distortion summary (L1 loss)
       - Figure 8: Reconstruction grids (L1)
   5.4 Topology Comparison (8-qubit, 256x256)
       - Table 7: DIV2K 8q rate-distortion (QFT, Entangled QFT, TEBD, MERA)
       - Figure 11: Reconstruction grid (8q, all 4 topologies)
       - Figure 12: Training curves (8q)
   5.5 Training Dynamics
       - Table 6: Training time comparison
       - Figure 9: Training curves (epoch-level)
       - Figure 10: Step-level training losses
6. Discussion
7. Conclusion
Appendix A: Riemannian Optimization Details
Appendix B: Detailed Benchmark Configurations
```

## Directory Layout

```
parametric-dft-paper/
├── figures/
│   ├── diagrams/              # Exported from Typst -> PDF
│   │   ├── fft_tensor_network.pdf
│   │   ├── qft_circuit.pdf
│   │   ├── entangled_qft_circuit.pdf
│   │   ├── tebd_circuit.pdf
│   │   └── mera_circuit.pdf
│   └── benchmarks/            # Copied from Benchmarks submodule
│       ├── mse/
│       │   ├── quickdraw_reconstruction_grid.png
│       │   ├── div2k_reconstruction_grid.png
│       │   ├── clic_reconstruction_grid.png
│       │   ├── cross_dataset_psnr.png
│       │   ├── cross_dataset_ssim.png
│       │   ├── quickdraw_training_curves.png
│       │   ├── div2k_training_curves.png
│       │   ├── clic_training_curves.png
│       │   ├── quickdraw_step_losses.png
│       │   ├── div2k_step_losses.png
│       │   └── clic_step_losses.png
│       ├── l1norm/
│       │   ├── quickdraw_reconstruction_grid.png
│       │   ├── div2k_reconstruction_grid.png
│       │   ├── clic_reconstruction_grid.png
│       │   ├── cross_dataset_psnr.png
│       │   └── cross_dataset_ssim.png
│       └── topology/
│           ├── div2k_8q_reconstruction_grid.png
│           ├── div2k_8q_training_curves.png
│           └── div2k_8q_step_losses.png
├── tables/                    # Auto-generated LaTeX snippets
│   ├── quickdraw_mse.tex
│   ├── div2k_mse.tex
│   ├── clic_mse.tex
│   ├── l1norm_summary.tex
│   ├── div2k_8q.tex
│   └── timing.tex
├── scripts/
│   ├── export_diagrams.sh     # Typst compile wrappers -> PDF
│   ├── generate_tables.jl     # JSON/CSV -> LaTeX tables
│   └── copy_benchmarks.sh     # Copy PNGs from submodule
├── Makefile                   # Extended build pipeline
├── main.tex
├── references.bib
├── ParametricDFT.jl/         # submodule
└── ParametricDFT-Benchmarks.jl/  # submodule
```

## Component 1: Typst Diagram Extraction

Create standalone Typst wrapper files in `scripts/diagrams/`, one per diagram. Each extracts a single diagram from ParametricDFT.jl/note/main.typ's drawing code:

```typst
// scripts/diagrams/entangled_qft_circuit.typ
#import "@preview/cetz:0.3.4"
#set page(width: auto, height: auto, margin: 5pt)
// ... extracted diagram code
```

Compile via: `typst compile scripts/diagrams/X.typ figures/diagrams/X.pdf`

**5 diagrams to extract** (from note/main.typ):
1. FFT tensor network decomposition (lines ~119-254)
2. QFT circuit (from QFT basis section)
3. Entangled QFT circuit (lines ~289-383)
4. TEBD ring topology (lines ~416-459)
5. MERA hierarchical circuit (lines ~492-580)

`scripts/export_diagrams.sh` loops over all .typ files in scripts/diagrams/ and compiles each.

## Component 2: Benchmark Submodule Changes

**Modify `generate_report.jl` in ParametricDFT-Benchmarks.jl** to output plots organized by loss type:

```
results/plots/
├── mse/                       # From *_mse_old/ directories
│   ├── cross_dataset_psnr.png
│   ├── cross_dataset_ssim.png
│   ├── {dataset}_reconstruction_grid.png
│   ├── {dataset}_training_curves.png
│   └── {dataset}_step_losses.png
├── l1norm/                    # From moderate/ preset directories
│   ├── cross_dataset_psnr.png
│   ├── cross_dataset_ssim.png
│   ├── {dataset}_reconstruction_grid.png
│   ├── {dataset}_training_curves.png
│   └── {dataset}_step_losses.png
└── topology/                  # From div2k_8q/ directory
    ├── div2k_8q_reconstruction_grid.png
    ├── div2k_8q_training_curves.png
    └── div2k_8q_step_losses.png
```

Also generate per-loss-type summary CSVs:
- `results/mse/cross_dataset_summary.csv`
- `results/mse/timing_summary.csv`
- `results/l1norm/cross_dataset_summary.csv`
- `results/l1norm/timing_summary.csv`

Changes needed in `generate_report.jl`:
1. Add function to detect and collect results by loss type (_mse_old vs moderate)
2. Generate cross-dataset comparison plots per loss type
3. Output to organized `results/plots/{mse,l1norm,topology}/` structure
4. Generate per-loss-type summary CSVs

## Component 3: Table Generation Script

`scripts/generate_tables.jl` reads benchmark JSON/CSV and outputs LaTeX table snippets.

**Data sources:**
- MSE tables: `*_mse_old/metrics.json` (quickdraw, div2k, clic)
- L1 Norm table: `moderate/{quickdraw,div2k,clic}/metrics.json`
- Topology table: `div2k_8q/metrics.json`
- Timing: `timing_summary.csv` + MSE timing data

**Table format** (per dataset, per loss):
```
Compression | FFT | DCT | QFT | Entangled QFT | TEBD
5%          | PSNR / SSIM | ...
10%         | ...
15%         | ...
20%         | ...
```

Features:
- Bold best result per row
- Standard deviation in parentheses
- DCT baseline where available
- MERA column in 8q table

Output: `\begin{tabular}...\end{tabular}` blocks in `tables/*.tex`.

## Component 4: Copy Script

`scripts/copy_benchmarks.sh` copies PNGs from submodule to paper:

```bash
cp ParametricDFT-Benchmarks.jl/results/plots/mse/* figures/benchmarks/mse/
cp ParametricDFT-Benchmarks.jl/results/plots/l1norm/* figures/benchmarks/l1norm/
cp ParametricDFT-Benchmarks.jl/results/plots/topology/* figures/benchmarks/topology/
```

## Component 5: Makefile

Extend existing Makefile with new targets:

```makefile
diagrams:     # typst compile each wrapper -> figures/diagrams/
tables:       # julia scripts/generate_tables.jl
benchmarks:   # bash scripts/copy_benchmarks.sh
paper:        # pdflatex + bibtex (existing)
all:          # diagrams + tables + benchmarks + paper
update:       # git submodule update --remote + make all
```

## Component 6: main.tex Rewrite

- Add `\graphicspath{{figures/diagrams/}{figures/benchmarks/}}`
- Replace hand-written tables with `\input{tables/X.tex}`
- Add `\includegraphics` for all figures with appropriate captions
- Restructure sections per the outline above
- Enable quantikz2 if needed, add graphicx package

## Data Source Mapping

| Paper Element | Source |
|---|---|
| Fig 1-5 (diagrams) | ParametricDFT.jl/note/main.typ via Typst wrappers |
| Tables 2-4 (MSE) | Benchmarks: *_mse_old/metrics.json |
| Table 5 (L1) | Benchmarks: moderate/*/metrics.json |
| Table 6 (timing) | Benchmarks: timing CSVs |
| Table 7 (8q topology) | Benchmarks: div2k_8q/metrics.json |
| Figs 6-7 (MSE plots) | Benchmarks: results/plots/mse/ |
| Fig 8 (L1 plots) | Benchmarks: results/plots/l1norm/ |
| Figs 9-10 (training) | Benchmarks: results/plots/mse/ |
| Figs 11-12 (topology) | Benchmarks: results/plots/topology/ |
