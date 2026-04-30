# CLAUDE.md

Project guidance for Claude Code sessions in this repository.

## What this repo is

LaTeX source for the manuscript *Parametric Quantum Circuits as Sparse Image Bases*. The PDF builds with stock `pdflatex` + `bibtex` against `quantumarticle.cls` (vendored). Static assets (diagrams, referenced tables, benchmark figures) are tracked in git so a fresh clone compiles without Julia/Python.

## Build commands

```bash
# Build the paper (most common)
make paper                  # = pdflatex / bibtex / pdflatex / pdflatex

# Or directly
pdflatex main && bibtex main && pdflatex main && pdflatex main

# Verify
pdfinfo main.pdf | grep Pages   # expect 21

# Regenerate figures/tables from scripts (rare; needs Julia + Python + submodules)
make diagrams                # Typst → figures/diagrams/*.pdf
make tables                  # Julia + Python → tables/*.tex
make benchmarks              # Julia → figures/benchmarks/freqspace/*.pdf
make training_plots          # Julia → figures/benchmarks/mse/*.pdf
make all                     # everything

# Clean
make clean                   # wipes main.pdf, aux files, AND regenerable assets
```

`make clean` is destructive of tracked content (it removes `figures/diagrams/`, `figures/benchmarks/`, `tables/`). Prefer `rm -f main.aux main.bbl main.log main.out main.pdf` for a normal rebuild.

## Repo conventions

- **Static vs. generated.** `figures/diagrams/*.pdf` and `figures/benchmarks/**/*.pdf` are committed. The Typst/Julia sources live under `scripts/`. `tables/*.tex` is generated; only `published_8q_quickdraw.tex` and `qft_gate_summary.tex` are tracked because they're the ones `main.tex` `\input`s.
- **`.gitignore` is opinionated.** `tmp/`, agent logs in `docs/discussion/`, Julia env files, PNG previews under `figures/benchmarks/**`, the `topology/` preview grid, and unused `tables/*.tex` files are intentionally ignored. Don't blanket-add directories.
- **Submodules** (`pdft`, `pdft-benchmarks`, `ParametricDFT.jl`, `ParametricDFT-Benchmarks.jl`) hold reference implementations and trained-model outputs. They aren't required to compile the paper.

## Float-placement rule

`main.tex` uses `\usepackage{placeins}` with explicit `\FloatBarrier` calls. When adding new floats, prefer `[!tbp]` (and `figure*[!tbp]` / `table*[!tbp]` for page-wide ones) over `[!t]` so LaTeX has fallback slots. Tall column-wide figures with stacked subfigures will get stuck — convert to `figure*` with side-by-side subfigures at `0.48\textwidth` if you see "A float is stuck" warnings.

## Things not to do

- **Don't commit `docs/discussion/`** — it holds sci-brain agent logs with personal info (email, inferred identity). Already gitignored; keep it that way.
- **Don't commit `Project.toml`/`Manifest.toml`** — empty stubs, deliberately ignored.
- **Don't push without explicit user confirmation.** Ask before `git push`, especially to `master`.
- **Don't `git add -A` or `git add .`** — use file-by-file adds because the working tree often has unrelated WIP.
- **Don't run `make clean` casually** — it removes tracked files.

## Style

- Manuscript uses `\cref{...}` / `\Cref{...}` (cleveref) — don't use raw `\ref{...}`.
- Equation labels: `eq:foo`. Section: `sec:foo`. Figure: `fig:foo`. Table: `tab:foo`. Appendix sections: `app:foo`.
- Table fragments under `tables/` use `booktabs` rules (`\toprule`, `\midrule`, `\bottomrule`); don't introduce vertical rules.
