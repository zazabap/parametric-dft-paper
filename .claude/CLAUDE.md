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
pdfinfo main.pdf | grep Pages   # expect 17

# Regenerate figures/tables from scripts (rare; needs Julia + Python + submodules)
make diagrams                # Typst → figures/diagrams/*.pdf
make tables                  # Julia + Python → tables/*.tex
make benchmarks              # Julia → figures/benchmarks/freqspace/*.pdf
make training_plots          # Julia → figures/benchmarks/mse/*.pdf
make all                     # everything

# Clean
make clean                   # safe: wipes main.pdf, aux files only
make distclean               # destructive: also removes regenerable assets
```

`make clean` only deletes build artifacts (aux/bbl/log/pdf), so it's safe to run before any rebuild. Use `make distclean` only when you actually want to drop the tracked `figures/diagrams/`, `figures/benchmarks/`, and `tables/` outputs and regenerate them from source.

## Repo conventions

- **Static vs. generated.** `figures/diagrams/*.pdf` and `figures/benchmarks/**/*.pdf` are committed. The Typst/Julia sources live under `scripts/`. `tables/*.tex` is generated; only `published_div2k.tex`, `published_quickdraw.tex`, and `qft_gate_summary.tex` are tracked because those are the ones `main.tex` `\input`s.
- **`.gitignore` is opinionated.** `tmp/`, agent logs in `docs/discussion/`, Julia env files, PNG previews under `figures/benchmarks/**`, the `topology/` preview grid, and unused `tables/*.tex` files are intentionally ignored. Don't blanket-add directories.
- **Submodules** (`pdft`, `pdft-benchmarks`, `ParametricDFT.jl`, `ParametricDFT-Benchmarks.jl`) hold reference implementations and trained-model outputs. They aren't required to compile the paper.

## Float-placement rule

`main.tex` uses `\usepackage{placeins}` with explicit `\FloatBarrier` calls. When adding new floats, prefer `[!tbp]` (and `figure*[!tbp]` / `table*[!tbp]` for page-wide ones) over `[!t]` so LaTeX has fallback slots. Tall column-wide figures with stacked subfigures will get stuck — convert to `figure*` with side-by-side subfigures at `0.48\textwidth` if you see "A float is stuck" warnings.

## Things not to do

- **Don't commit `docs/discussion/`** — it holds sci-brain agent logs with personal info (email, inferred identity). Already gitignored; keep it that way.
- **Don't commit `Project.toml`/`Manifest.toml`** — empty stubs, deliberately ignored.
- **Don't push without explicit user confirmation.** Ask before `git push`, especially to `master`.
- **Don't `git add -A` or `git add .`** — use file-by-file adds because the working tree often has unrelated WIP.
- **Don't run `make distclean` casually** — it removes tracked figures/tables. Plain `make clean` is safe.

## Style

- Manuscript uses `\cref{...}` / `\Cref{...}` (cleveref) — don't use raw `\ref{...}`.
- Equation labels: `eq:foo`. Section: `sec:foo`. Figure: `fig:foo`. Table: `tab:foo`. Appendix sections: `app:foo`.
- Table fragments under `tables/` use `booktabs` rules (`\toprule`, `\midrule`, `\bottomrule`); don't introduce vertical rules.
- This is an academic paper — **don't bake repo paths or filenames into prose or captions** (no `pdft-benchmarks/results/...`, no `run_div2k_10q.py`, etc.). Software citations like `\texttt{ParametricDFT.jl}` (the open-source release) with a `\url{...}` are fine; arbitrary script/path references are not.
- Row-color / cell-color tables use `colortbl` (loaded after `xcolor` in the preamble — `quantumarticle.cls` already loads `xcolor`, so loading it with `[table]` causes an option clash).
