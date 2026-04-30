# Parametric Quantum Circuits as Sparse Image Bases

LaTeX source for the manuscript *Parametric Quantum Circuits as Sparse Image Bases* (Shiwen An, Zhongyi Ni, Huanhai Zhou, Jin-Guo Liu).

## Quick start: build the PDF

The repo ships with everything `pdflatex` needs — pre-rendered diagrams, the two referenced `\input` tables, and the eleven benchmark figures. No Julia, Python, or submodule data is required to compile.

```bash
git clone git@github.com:zazabap/parametric-dft-paper.git
cd parametric-dft-paper
pdflatex main && bibtex main && pdflatex main && pdflatex main
```

Or via the Makefile:

```bash
make paper
```

The output is `main.pdf` (21 pages, A4, two-column).

## TeX prerequisites

A standard TeX Live ≥ 2021 install is enough. The document is built with `pdflatex` against the `quantumarticle` class (vendored in `quantumarticle.cls`) and uses these packages:

`amsmath`, `amssymb`, `amsthm`, `graphicx`, `booktabs`, `hyperref`, `cleveref`, `algorithm`, `algpseudocode`, `tikz`, `braket`, `multirow`, `xcolor`, `placeins`, `subcaption`

On Debian/Ubuntu:

```bash
sudo apt install texlive-latex-recommended texlive-latex-extra \
                 texlive-science texlive-fonts-extra texlive-bibtex-extra
```

On macOS (MacTeX) or Windows (MiKTeX), the corresponding full distributions cover all of the above.

## Regenerating figures and tables (optional)

The committed PDFs/tables under `figures/benchmarks/` and `tables/` were produced by the scripts in `scripts/`. You only need this section if you want to rebuild them from raw benchmark results.

| Target | Command | Requires |
|---|---|---|
| Hand-drawn circuit diagrams (`figures/diagrams/`) | `make diagrams` | [Typst](https://typst.app) ≥ 0.10 |
| Benchmark tables (`tables/`) | `make tables` | Julia ≥ 1.9, Python ≥ 3.10, populated `pdft-benchmarks/` submodule |
| Frequency-space and reconstruction figures (`figures/benchmarks/freqspace/`) | `make benchmarks` | Julia, populated `pdft-benchmarks/` |
| Training-curve plots (`figures/benchmarks/mse/`) | `make training_plots` | Julia + `parametric-dft-python/benchmarks/results/` (see `scripts/plot_training_curves.jl`) |
| Everything from scratch | `make all` | All of the above |

Julia dependencies used by the scripts (`JSON3`, `CairoMakie`, `OMEinsum`, `Yao`, …) are picked up from the global Julia environment; `Project.toml`/`Manifest.toml` are intentionally not pinned in the repo.

To populate the submodules with the trained results:

```bash
git submodule update --init --recursive
```

## Repository layout

```
main.tex                    Manuscript source
references.bib              Bibliography
quantumarticle.cls          Journal class (vendored)
Makefile                    Build orchestration

figures/
  diagrams/                 Hand-drawn circuit diagrams (Typst sources in scripts/diagrams/)
  benchmarks/               Generated plots (freqspace/, mse/, variations/)

tables/                     LaTeX table fragments \input by main.tex
scripts/                    Generators for diagrams, tables, and plots

pdft/, pdft-benchmarks/                     Submodules: Python implementation + benchmark results
ParametricDFT.jl, ParametricDFT-Benchmarks.jl   Submodules: Julia implementation + benchmarks
```

## Cleaning up

```bash
make clean   # removes main.pdf, LaTeX aux files, and regenerable figures/ + tables/
```

Note: `make clean` also wipes `figures/diagrams/`, `figures/benchmarks/`, and `tables/`. To restore everything tracked in git afterwards, `git checkout -- figures/ tables/`.
