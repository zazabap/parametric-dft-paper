# Paper Update Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated pipeline that pulls tensor network diagrams from ParametricDFT.jl and benchmark results from ParametricDFT-Benchmarks.jl to produce an up-to-date paper via `make all`.

**Architecture:** The paper repo contains scripts that (1) compile standalone Typst wrappers into PDF diagrams, (2) run a Julia script to generate LaTeX tables from benchmark JSON/CSV data, (3) copy benchmark plots from the submodule. All plot generation lives in the benchmark submodule. The paper's `main.tex` uses `\input{}` for tables and `\includegraphics` for figures.

**Tech Stack:** LaTeX (pdflatex/bibtex), Typst (cetz library), Julia (JSON3 for table generation), Make, Bash

---

## File Structure

### New files in paper repo
- `scripts/diagrams/fft_tensor_network.typ` — standalone Typst wrapper for FFT tensor network diagram
- `scripts/diagrams/qft_circuit.typ` — standalone Typst wrapper for QFT circuit (Entangled QFT, which shows both QFT and entanglement)
- `scripts/diagrams/entangled_qft_circuit.typ` — standalone Typst wrapper for Entangled QFT circuit
- `scripts/diagrams/tebd_circuit.typ` — standalone Typst wrapper for TEBD ring topology
- `scripts/diagrams/mera_circuit.typ` — standalone Typst wrapper for MERA hierarchical circuit
- `scripts/export_diagrams.sh` — compiles all Typst wrappers to PDF
- `scripts/generate_tables.jl` — reads benchmark JSON, outputs LaTeX table snippets
- `scripts/copy_benchmarks.sh` — copies PNGs from submodule to figures/
- `figures/` — output directory for diagrams and benchmark plots (gitignored except diagrams/)
- `tables/` — output directory for generated LaTeX tables (gitignored)

### Modified files in paper repo
- `Makefile` — add targets: diagrams, tables, benchmarks, all, update
- `main.tex` — restructure with \input{} tables, \includegraphics figures, new sections
- `.gitignore` — add figures/benchmarks/, tables/

### Modified files in benchmark submodule
- `ParametricDFT-Benchmarks.jl/generate_report.jl` — add loss-type-organized plot output

---

## Task 1: Update generate_report.jl in Benchmark Submodule

**Files:**
- Modify: `ParametricDFT-Benchmarks.jl/generate_report.jl`

This task adds functions to generate plots organized by loss type (mse, l1norm, topology) into `results/plots/`.

- [ ] **Step 1: Add result collection by loss type**

Add these functions after the existing `load_all_results()` function in `generate_report.jl`:

```julia
# ============================================================================
# Load Results by Loss Type
# ============================================================================

const MSE_RESULT_DIRS = Dict(
    :quickdraw => "quickdraw_moderate_mse_old",
    :div2k => "div2k_mse_old",
    :clic => "clic_mse_old",
)

const L1NORM_RESULT_DIRS = Dict(
    :quickdraw => joinpath("moderate", "quickdraw"),
    :div2k => joinpath("moderate", "div2k"),
    :clic => joinpath("moderate", "clic"),
)

const TOPOLOGY_RESULT_DIRS = Dict(
    :div2k_8q => "div2k_8q",
)

function load_results_by_type(result_dirs::Dict{Symbol,String})
    all_results = Dict{Symbol,Any}()
    for (dataset_name, subdir) in result_dirs
        metrics_path = joinpath(RESULTS_DIR, subdir, "metrics.json")
        if isfile(metrics_path)
            all_results[dataset_name] = load_benchmark_results(metrics_path)
            display_name = get(DISPLAY_NAMES, dataset_name, string(dataset_name))
            @info "Loaded results for $display_name from $subdir"
        else
            @warn "No results found at $metrics_path"
        end
    end
    return all_results
end
```

- [ ] **Step 2: Add the paper plot generation function**

Add this function that generates all plots for a given loss type into a subdirectory:

```julia
# ============================================================================
# Generate Paper Plots (organized by loss type)
# ============================================================================

function generate_paper_plots(all_results::Dict{Symbol,Any}, output_subdir::String;
                              dataset_names=DATASET_NAMES)
    plots_dir = joinpath(RESULTS_DIR, "plots", output_subdir)
    mkpath(plots_dir)

    available_datasets = [d for d in dataset_names if haskey(all_results, d)]

    # Per-dataset plots
    for dataset_name in available_datasets
        results = all_results[dataset_name]
        display_name = get(DISPLAY_NAMES, dataset_name, string(dataset_name))

        # Training curves (epoch-level)
        fig = Figure(size = (800, 500))
        ax = Axis(fig[1, 1];
            xlabel = "Epoch",
            ylabel = "Validation Loss",
            title = "Training Convergence — $display_name",
            yscale = log10,
        )
        for basis_name in ["qft", "entangled_qft", "tebd", "mera"]
            if haskey(results, basis_name) && haskey(results[basis_name], "history")
                history = results[basis_name]["history"]
                val_losses = Float64.(history["val_losses"])
                if !isempty(val_losses)
                    lines!(ax, 1:length(val_losses), val_losses;
                        label = BASIS_DISPLAY_NAMES[basis_name],
                        color = BASIS_COLORS[basis_name],
                    )
                end
            end
        end
        axislegend(ax; position = :rt)
        save(joinpath(plots_dir, "$(dataset_name)_training_curves.png"), fig; px_per_unit = 2)
        @info "Saved $(dataset_name) training curves to $output_subdir"

        # Step-level losses
        fig_steps = Figure(size = (1000, 500))
        ax_steps = Axis(fig_steps[1, 1];
            xlabel = "Optimization Step",
            ylabel = "Training Loss",
            title = "Per-Step Training Loss — $display_name",
        )
        for basis_name in ["qft", "entangled_qft", "tebd", "mera"]
            if haskey(results, basis_name) && haskey(results[basis_name], "history")
                history = results[basis_name]["history"]
                step_losses = Float64.(history["step_train_losses"])
                if !isempty(step_losses)
                    valid = step_losses .> 0
                    if any(valid)
                        lines!(ax_steps, (1:length(step_losses))[valid], step_losses[valid];
                            label = BASIS_DISPLAY_NAMES[basis_name],
                            color = BASIS_COLORS[basis_name],
                        )
                    end
                end
            end
        end
        axislegend(ax_steps; position = :rt)
        save(joinpath(plots_dir, "$(dataset_name)_step_losses.png"), fig_steps; px_per_unit = 2)
        @info "Saved $(dataset_name) step losses to $output_subdir"

        # Reconstruction grids (reuse existing logic but save to new path)
        # Skip if no trained bases available (reconstruction needs model files)
        output_dir = if haskey(MSE_RESULT_DIRS, dataset_name)
            joinpath(RESULTS_DIR, MSE_RESULT_DIRS[dataset_name])
        elseif haskey(L1NORM_RESULT_DIRS, dataset_name)
            joinpath(RESULTS_DIR, L1NORM_RESULT_DIRS[dataset_name])
        elseif haskey(TOPOLOGY_RESULT_DIRS, dataset_name)
            joinpath(RESULTS_DIR, TOPOLOGY_RESULT_DIRS[dataset_name])
        else
            joinpath(RESULTS_DIR, string(dataset_name))
        end

        # Check for existing reconstruction grid and copy it
        existing_grid = joinpath(output_dir, "plots", "reconstruction_grid.png")
        if isfile(existing_grid)
            cp(existing_grid, joinpath(plots_dir, "$(dataset_name)_reconstruction_grid.png"); force=true)
            @info "Copied reconstruction grid for $display_name to $output_subdir"
        else
            @warn "No reconstruction grid found for $display_name at $existing_grid"
        end
    end

    # Cross-dataset comparison plots
    if length(available_datasets) > 1
        basis_order = ["qft", "entangled_qft", "tebd", "mera", "fft", "dct"]

        for (metric_name, ylabel, _) in [
            ("psnr", "PSNR (dB)", true),
            ("ssim", "SSIM", true),
        ]
            fig = Figure(size = (800, 500))
            ax = Axis(fig[1, 1];
                xlabel = "Dataset",
                ylabel = ylabel,
                title = "Cross-Dataset Comparison — $(uppercase(metric_name)) @ 10% kept",
                xticks = (1:length(available_datasets),
                          [get(DISPLAY_NAMES, d, string(d)) for d in available_datasets]),
            )

            n_bases = length(basis_order)
            bar_width = 0.15

            for (bi, basis_name) in enumerate(basis_order)
                values = Float64[]
                positions = Float64[]
                for (di, dataset_name) in enumerate(available_datasets)
                    if haskey(all_results[dataset_name], basis_name)
                        metrics = all_results[dataset_name][basis_name]["metrics"]
                        if haskey(metrics, "0.1")
                            push!(values, Float64(metrics["0.1"]["mean_$(metric_name)"]))
                            push!(positions, di + (bi - (n_bases + 1) / 2) * bar_width)
                        end
                    end
                end
                if !isempty(values)
                    barplot!(ax, positions, values;
                        width = bar_width,
                        color = BASIS_COLORS[basis_name],
                        label = BASIS_DISPLAY_NAMES[basis_name],
                    )
                end
            end

            axislegend(ax; position = :rt)
            save(joinpath(plots_dir, "cross_dataset_$(metric_name).png"), fig; px_per_unit = 2)
            @info "Saved cross-dataset $(metric_name) plot to $output_subdir"
        end
    end

    # Summary CSV
    csv_path = joinpath(RESULTS_DIR, "plots", output_subdir, "cross_dataset_summary.csv")
    open(csv_path, "w") do io
        print(io, "Basis")
        for dataset_name in available_datasets
            display_name = get(DISPLAY_NAMES, dataset_name, string(dataset_name))
            print(io, ",$display_name PSNR@10%")
        end
        println(io)
        for basis_name in ["qft", "entangled_qft", "tebd", "mera", "fft", "dct"]
            print(io, BASIS_DISPLAY_NAMES[basis_name])
            for dataset_name in available_datasets
                if haskey(all_results[dataset_name], basis_name)
                    metrics = all_results[dataset_name][basis_name]["metrics"]
                    if haskey(metrics, "0.1")
                        @printf(io, ",%.2f", Float64(metrics["0.1"]["mean_psnr"]))
                    else
                        print(io, ",N/A")
                    end
                else
                    print(io, ",N/A")
                end
            end
            println(io)
        end
    end
    @info "Saved summary CSV to $csv_path"
end
```

- [ ] **Step 3: Update the main() function**

Replace the existing `main()` function with:

```julia
function main()
    println("=" ^ 80)
    println("Generating Benchmark Report")
    println("=" ^ 80)

    # Original report generation (backwards compatible)
    all_results = load_all_results()

    if !isempty(all_results)
        generate_rate_distortion_csv(all_results)
        generate_training_curves(all_results)
        generate_reconstruction_grids(all_results)
        generate_cross_dataset_summary(all_results)
        generate_cross_dataset_plots(all_results)
        generate_timing_table(all_results)
    end

    # Paper-organized plots by loss type
    println("\n" * "=" ^ 80)
    println("Generating Paper Plots (by loss type)")
    println("=" ^ 80)

    # MSE results
    mse_results = load_results_by_type(MSE_RESULT_DIRS)
    if !isempty(mse_results)
        generate_paper_plots(mse_results, "mse")
    end

    # L1 Norm results
    l1_results = load_results_by_type(L1NORM_RESULT_DIRS)
    if !isempty(l1_results)
        generate_paper_plots(l1_results, "l1norm")
    end

    # Topology results (8q)
    topo_results = load_results_by_type(TOPOLOGY_RESULT_DIRS)
    if !isempty(topo_results)
        generate_paper_plots(topo_results, "topology"; dataset_names=[:div2k_8q])
    end

    println("\n" * "=" ^ 80)
    println("Report generation complete!")
    println("Results in: $RESULTS_DIR")
    println("=" ^ 80)
end
```

- [ ] **Step 4: Add display name for div2k_8q**

Add to the `DISPLAY_NAMES` constant at the top of the file:

```julia
const DISPLAY_NAMES = Dict(
    :quickdraw => "Quick Draw",
    :div2k => "DIV2K",
    :clic => "CLIC",
    :div2k_8q => "DIV2K (8q, 256×256)",
)
```

- [ ] **Step 5: Verify the file runs without errors**

Run: `cd /home/claude-user/parametric-dft-paper/ParametricDFT-Benchmarks.jl && julia --project=. -e 'include("generate_report.jl")'`

Expected: The script runs. It may warn about missing dataset files (images not downloaded) but should not error on the plot generation code. The `results/plots/{mse,l1norm,topology}/` directories should be created with PNG files.

- [ ] **Step 6: Commit in the submodule**

```bash
cd /home/claude-user/parametric-dft-paper/ParametricDFT-Benchmarks.jl
git add generate_report.jl
git commit -m "Add paper plot generation organized by loss type (mse/l1norm/topology)"
```

---

## Task 2: Create Typst Diagram Wrappers

**Files:**
- Create: `scripts/diagrams/fft_tensor_network.typ`
- Create: `scripts/diagrams/entangled_qft_circuit.typ`
- Create: `scripts/diagrams/tebd_circuit.typ`
- Create: `scripts/diagrams/mera_circuit.typ`

Each file is a standalone Typst document that extracts one diagram from `ParametricDFT.jl/note/main.typ`. They share the `ngate` helper function and use `#set page(width: auto, height: auto, margin: 5pt)` for tight cropping.

- [ ] **Step 1: Create fft_tensor_network.typ**

Create `scripts/diagrams/fft_tensor_network.typ` containing the `ngate` helper (lines 20-39 of main.typ), the `cphase` helper (lines 193-200), and the fully-decomposed FFT tensor network diagram (lines 223-254 of main.typ — the final "Step 2" diagram showing all H gates and M gates). Wrap in `#set page(width: auto, height: auto, margin: 5pt)`.

The diagram code to extract is the `#figure(canvas({...}))` block at lines 223-254 of `ParametricDFT.jl/note/main.typ`.

- [ ] **Step 2: Create entangled_qft_circuit.typ**

Create `scripts/diagrams/entangled_qft_circuit.typ` containing the `ngate` helper, `cphase` helper, `egate` helper (lines 280-287), and the Entangled QFT circuit diagram (lines 289-383 of main.typ — the large 8-qubit circuit with E_k gates).

- [ ] **Step 3: Create tebd_circuit.typ**

Create `scripts/diagrams/tebd_circuit.typ` containing the `ngate` helper, `tebdgate` helper (lines 407-414), and the TEBD diagram (lines 416-459 of main.typ).

- [ ] **Step 4: Create mera_circuit.typ**

Create `scripts/diagrams/mera_circuit.typ` containing the `ngate` helper, `meragate` helper (lines 483-490), and the MERA diagram (lines 492-580 of main.typ).

- [ ] **Step 5: Test compile one diagram**

Run: `cd /home/claude-user/parametric-dft-paper && typst compile scripts/diagrams/fft_tensor_network.typ figures/diagrams/fft_tensor_network.pdf`

Expected: A tight-cropped PDF of just the FFT tensor network diagram. If typst is not installed, install it first: `curl -fsSL https://typst.community/typst-install/install.sh | sh` or check if it's available.

- [ ] **Step 6: Commit**

```bash
cd /home/claude-user/parametric-dft-paper
git add scripts/diagrams/
git commit -m "Add standalone Typst diagram wrappers for paper figures"
```

---

## Task 3: Create Build Scripts

**Files:**
- Create: `scripts/export_diagrams.sh`
- Create: `scripts/copy_benchmarks.sh`
- Create: `scripts/generate_tables.jl`

- [ ] **Step 1: Create export_diagrams.sh**

```bash
#!/bin/bash
# Compile standalone Typst diagram wrappers to PDF
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DIAGRAMS_DIR="$SCRIPT_DIR/diagrams"
OUTPUT_DIR="$REPO_DIR/figures/diagrams"

mkdir -p "$OUTPUT_DIR"

for typ_file in "$DIAGRAMS_DIR"/*.typ; do
    name="$(basename "$typ_file" .typ)"
    echo "Compiling $name.typ -> $name.pdf"
    typst compile "$typ_file" "$OUTPUT_DIR/$name.pdf"
done

echo "Diagrams exported to $OUTPUT_DIR"
```

- [ ] **Step 2: Create copy_benchmarks.sh**

```bash
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
```

- [ ] **Step 3: Create generate_tables.jl**

```julia
#!/usr/bin/env julia
# Generate LaTeX table snippets from benchmark JSON data
#
# Usage: julia scripts/generate_tables.jl
#
# Reads metrics.json files from ParametricDFT-Benchmarks.jl/results/
# and writes LaTeX tabular blocks to tables/

using JSON3
using Printf

const BENCH_DIR = joinpath(@__DIR__, "..", "ParametricDFT-Benchmarks.jl", "results")
const OUTPUT_DIR = joinpath(@__DIR__, "..", "tables")
mkpath(OUTPUT_DIR)

const KEEP_RATIOS = [0.05, 0.10, 0.15, 0.20]
const BASIS_ORDER = ["fft", "dct", "qft", "entangled_qft", "tebd", "mera"]
const BASIS_LABELS = Dict(
    "fft" => "FFT (fixed)",
    "dct" => "DCT (fixed)",
    "qft" => "QFT (learned)",
    "entangled_qft" => "Ent.\\ QFT (learned)",
    "tebd" => "TEBD (learned)",
    "mera" => "MERA (learned)",
)

function load_metrics(path::String)
    isfile(path) || return nothing
    return JSON3.read(read(path, String))
end

function format_val(val, std; bold=false)
    s = @sprintf("%.2f", val)
    if std !== nothing && std > 0
        s *= @sprintf(" (±%.2f)", std)
    end
    return bold ? "\\textbf{$s}" : s
end

function generate_rate_distortion_table(metrics, output_path::String;
                                         caption="", label="")
    available_bases = [b for b in BASIS_ORDER if haskey(metrics, b)]
    isempty(available_bases) && return

    # Find best PSNR per ratio (among learned bases only)
    learned_bases = filter(b -> b ∉ ["fft", "dct"], available_bases)
    best_psnr = Dict{Float64,Float64}()
    best_ssim = Dict{Float64,Float64}()
    for ratio in KEEP_RATIOS
        ratio_key = string(ratio)
        best_p = -Inf
        best_s = -Inf
        for basis_name in learned_bases
            m = metrics[basis_name]
            haskey(m, "metrics") || continue
            mets = m["metrics"]
            haskey(mets, ratio_key) || continue
            p = Float64(mets[ratio_key]["mean_psnr"])
            s = Float64(mets[ratio_key]["mean_ssim"])
            best_p = max(best_p, p)
            best_s = max(best_s, s)
        end
        best_psnr[ratio] = best_p
        best_ssim[ratio] = best_s
    end

    n_cols = length(KEEP_RATIOS)
    open(output_path, "w") do io
        println(io, "\\begin{tabular}{@{}l" * "c"^n_cols * "@{}}")
        println(io, "\\toprule")
        print(io, "\\textbf{Method}")
        for ratio in KEEP_RATIOS
            @printf(io, " & \\textbf{%d\\%%}", round(Int, ratio * 100))
        end
        println(io, " \\\\")
        println(io, "\\midrule")

        first_learned = true
        for basis_name in available_bases
            m = metrics[basis_name]
            haskey(m, "metrics") || continue
            mets = m["metrics"]

            # Add midrule before first learned basis
            if basis_name ∉ ["fft", "dct"] && first_learned
                first_learned = false
            elseif basis_name ∈ ["fft", "dct"]
                # noop
            end

            print(io, BASIS_LABELS[basis_name])
            for ratio in KEEP_RATIOS
                ratio_key = string(ratio)
                if haskey(mets, ratio_key)
                    p = Float64(mets[ratio_key]["mean_psnr"])
                    s = Float64(mets[ratio_key]["mean_ssim"])
                    p_std = haskey(mets[ratio_key], "std_psnr") ? Float64(mets[ratio_key]["std_psnr"]) : nothing
                    s_std = haskey(mets[ratio_key], "std_ssim") ? Float64(mets[ratio_key]["std_ssim"]) : nothing

                    p_bold = (basis_name ∉ ["fft", "dct"]) && (p ≈ best_psnr[ratio])
                    s_bold = (basis_name ∉ ["fft", "dct"]) && (s ≈ best_ssim[ratio])

                    p_str = p_bold ? @sprintf("\\textbf{%.2f}", p) : @sprintf("%.2f", p)
                    s_str = s_bold ? @sprintf("\\textbf{%.3f}", s) : @sprintf("%.3f", s)
                    print(io, " & $p_str / $s_str")
                else
                    print(io, " & N/A")
                end
            end
            println(io, " \\\\")

            # Add midrule after last fixed basis
            if basis_name ∈ ["fft", "dct"]
                # Check if this is the last fixed basis in available_bases
                fixed_bases = filter(b -> b ∈ ["fft", "dct"], available_bases)
                if basis_name == last(fixed_bases)
                    println(io, "\\midrule")
                end
            end
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    @info "Generated $output_path"
end

function generate_timing_table(output_path::String)
    # Collect timing from all available result directories
    datasets = [
        (:quickdraw, "quickdraw_moderate_mse_old", "Quick Draw"),
        (:div2k, "div2k_mse_old", "DIV2K"),
        (:clic, "clic_mse_old", "CLIC"),
    ]

    all_times = Dict{String,Dict{Symbol,Float64}}()
    for (dataset_sym, subdir, _) in datasets
        path = joinpath(BENCH_DIR, subdir, "metrics.json")
        metrics = load_metrics(path)
        metrics === nothing && continue
        for basis_name in BASIS_ORDER
            haskey(metrics, basis_name) || continue
            haskey(metrics[basis_name], "time") || continue
            if !haskey(all_times, basis_name)
                all_times[basis_name] = Dict{Symbol,Float64}()
            end
            all_times[basis_name][dataset_sym] = Float64(metrics[basis_name]["time"])
        end
    end

    isempty(all_times) && return

    available_datasets = [(sym, name) for (sym, _, name) in datasets
                          if any(haskey(get(all_times, b, Dict()), sym) for b in BASIS_ORDER)]

    open(output_path, "w") do io
        n_cols = length(available_datasets)
        println(io, "\\begin{tabular}{@{}l" * "c"^n_cols * "@{}}")
        println(io, "\\toprule")
        print(io, "\\textbf{Method}")
        for (_, name) in available_datasets
            print(io, " & \\textbf{$name (s)}")
        end
        println(io, " \\\\")
        println(io, "\\midrule")

        for basis_name in BASIS_ORDER
            haskey(all_times, basis_name) || continue
            print(io, BASIS_LABELS[basis_name])
            for (sym, _) in available_datasets
                if haskey(all_times[basis_name], sym)
                    @printf(io, " & %.1f", all_times[basis_name][sym])
                else
                    print(io, " & N/A")
                end
            end
            println(io, " \\\\")
        end
        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    @info "Generated $output_path"
end

function main()
    println("Generating LaTeX tables from benchmark data...")

    # MSE tables (primary)
    for (dataset, subdir, filename) in [
        ("Quick Draw", "quickdraw_moderate_mse_old", "quickdraw_mse.tex"),
        ("DIV2K", "div2k_mse_old", "div2k_mse.tex"),
        ("CLIC", "clic_mse_old", "clic_mse.tex"),
    ]
        path = joinpath(BENCH_DIR, subdir, "metrics.json")
        metrics = load_metrics(path)
        if metrics !== nothing
            generate_rate_distortion_table(metrics, joinpath(OUTPUT_DIR, filename))
        else
            @warn "No metrics found for $dataset at $path"
        end
    end

    # L1 Norm summary table
    l1_metrics = Dict{String,Any}()
    for (dataset_sym, subdir) in [
        ("quickdraw", joinpath("moderate", "quickdraw")),
        ("div2k", joinpath("moderate", "div2k")),
        ("clic", joinpath("moderate", "clic")),
    ]
        path = joinpath(BENCH_DIR, subdir, "metrics.json")
        m = load_metrics(path)
        m !== nothing && merge!(l1_metrics, Dict(string(dataset_sym) => m))
    end
    # For L1, we generate per-dataset tables combined into one file
    if !isempty(l1_metrics)
        # Pick the first available dataset for a representative table
        for (ds_name, ds_key, filename) in [
            ("Quick Draw", "quickdraw", "l1norm_quickdraw.tex"),
            ("DIV2K", "div2k", "l1norm_div2k.tex"),
            ("CLIC", "clic", "l1norm_clic.tex"),
        ]
            if haskey(l1_metrics, ds_key)
                generate_rate_distortion_table(l1_metrics[ds_key],
                    joinpath(OUTPUT_DIR, filename))
            end
        end
    end

    # Topology table (8q)
    topo_path = joinpath(BENCH_DIR, "div2k_8q", "metrics.json")
    topo_metrics = load_metrics(topo_path)
    if topo_metrics !== nothing
        generate_rate_distortion_table(topo_metrics, joinpath(OUTPUT_DIR, "div2k_8q.tex"))
    end

    # Timing table
    generate_timing_table(joinpath(OUTPUT_DIR, "timing.tex"))

    println("Table generation complete! Files in: $OUTPUT_DIR")
end

main()
```

- [ ] **Step 4: Make shell scripts executable**

```bash
chmod +x scripts/export_diagrams.sh scripts/copy_benchmarks.sh
```

- [ ] **Step 5: Test generate_tables.jl**

Run: `cd /home/claude-user/parametric-dft-paper && julia scripts/generate_tables.jl`

Expected: Creates `tables/*.tex` files. Check one output file to verify LaTeX formatting.

- [ ] **Step 6: Commit**

```bash
cd /home/claude-user/parametric-dft-paper
git add scripts/export_diagrams.sh scripts/copy_benchmarks.sh scripts/generate_tables.jl
git commit -m "Add build scripts: diagram export, table generation, benchmark copy"
```

---

## Task 4: Update Makefile

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Replace the Makefile with the extended version**

```makefile
MAIN = main
LATEX = pdflatex
BIBTEX = bibtex

.PHONY: all paper diagrams tables benchmarks update clean

all: diagrams tables benchmarks paper

paper: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex references.bib $(wildcard tables/*.tex)
	$(LATEX) $(MAIN)
	$(BIBTEX) $(MAIN)
	$(LATEX) $(MAIN)
	$(LATEX) $(MAIN)

diagrams:
	bash scripts/export_diagrams.sh

tables:
	julia scripts/generate_tables.jl

benchmarks:
	bash scripts/copy_benchmarks.sh

update:
	git submodule update --remote
	$(MAKE) all

clean:
	rm -f $(MAIN).aux $(MAIN).bbl $(MAIN).blg $(MAIN).log $(MAIN).out \
	      $(MAIN).toc $(MAIN).pdf $(MAIN).fdb_latexmk $(MAIN).fls $(MAIN).synctex.gz
	rm -rf figures/diagrams/ figures/benchmarks/ tables/
```

- [ ] **Step 2: Commit**

```bash
cd /home/claude-user/parametric-dft-paper
git add Makefile
git commit -m "Extend Makefile with diagrams, tables, benchmarks, and update targets"
```

---

## Task 5: Update .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Update .gitignore**

Add generated output directories to `.gitignore`. Keep `figures/diagrams/` tracked (Typst PDFs are small and useful to have in the repo for people without Typst installed), but ignore benchmark copies and generated tables:

```gitignore
# LaTeX build artifacts
*.aux
*.bbl
*.blg
*.log
*.out
*.toc
*.fdb_latexmk
*.fls
*.synctex.gz

# Generated outputs (rebuilt by make)
figures/benchmarks/
tables/
```

- [ ] **Step 2: Commit**

```bash
cd /home/claude-user/parametric-dft-paper
git add .gitignore
git commit -m "Update .gitignore for generated figures and tables"
```

---

## Task 6: Rewrite main.tex

**Files:**
- Modify: `main.tex`

This is the largest task. The paper needs to be restructured to include figures and auto-generated tables while preserving all existing mathematical content.

- [ ] **Step 1: Update the preamble**

Add `\graphicspath` and ensure graphicx is loaded. The preamble (lines 1-34) should be updated:

After `\usepackage{xcolor}` (line 15), add:
```latex
\graphicspath{{figures/diagrams/}{figures/benchmarks/}}
```

Remove the commented-out quantikz line (line 12) since we're using Typst PDFs instead.

- [ ] **Step 2: Add Figure 1 in Background section**

After the tensor network explanation text in Section 2 (around line 139, after the text about the Cooley-Tukey decomposition), add:

```latex
\begin{figure}[t]
\centering
\includegraphics[width=0.9\columnwidth]{fft_tensor_network.pdf}
\caption{Complete tensor network decomposition of the 4-qubit FFT. The input tensor $\mathbf{x}$ is decomposed through Hadamard gates $H$ and controlled-phase gates $M_k$, yielding the butterfly structure of the Cooley--Tukey algorithm.}
\label{fig:fft_tn}
\end{figure}
```

- [ ] **Step 3: Add Figures 2-5 in Parametric Circuit Topologies section**

After each topology description, add the corresponding figure. For the Entangled QFT (after line ~195):

```latex
\begin{figure*}[t]
\centering
\includegraphics[width=0.85\textwidth]{entangled_qft_circuit.pdf}
\caption{Entangled QFT circuit for $n=4$ qubits per dimension. Row qubits $x_k$ and column qubits $y_k$ each pass through independent QFT circuits (Hadamard gates $H$ and controlled-phase gates $M_j$). Entanglement gates $E_k$ couple corresponding row--column pairs, introducing cross-dimensional correlations.}
\label{fig:entangled_qft}
\end{figure*}
```

Similarly for TEBD and MERA:

```latex
\begin{figure}[t]
\centering
\includegraphics[width=0.9\columnwidth]{tebd_circuit.pdf}
\caption{TEBD circuit for $n=4$ row and column qubits with ring topology. Hadamard gates $H$ precede nearest-neighbor controlled-phase gates $T_{xk}$ (row ring) and $T_{yk}$ (column ring). Wrap-around gates close each ring.}
\label{fig:tebd}
\end{figure}
```

```latex
\begin{figure*}[t]
\centering
\includegraphics[width=0.85\textwidth]{mera_circuit.pdf}
\caption{MERA-inspired circuit for $n=8$ row and column qubits. Disentanglers $D$ and isometries $W$ follow hierarchical connectivity: layer~1 (stride~1) connects nearest neighbors, layer~2 (stride~2) at distance~2, layer~3 (stride~4) connects distant qubits. Row and column qubits are processed independently.}
\label{fig:mera}
\end{figure*}
```

- [ ] **Step 4: Restructure the Experiments section**

Replace the entire Experiments section (lines 340-444) with the new structure. The key changes:

1. **Section 5.1 (Setup)**: Update datasets to include CLIC, update training config to describe both MSE and L1 settings, add DCT baseline.

2. **Section 5.2 (MSE Loss Results)**: Replace hand-written tables with `\input{}`:

```latex
\subsection{MSE Loss Results (Primary)}

\begin{table}[h]
\centering
\caption{Compression quality on Quick Draw ($32 \times 32$, MSE loss). PSNR (dB) / SSIM. Best learned result in \textbf{bold}.}
\label{tab:quickdraw_mse}
\input{tables/quickdraw_mse}
\end{table}

\begin{table}[h]
\centering
\caption{Compression quality on DIV2K ($256 \times 256$, MSE loss). PSNR (dB) / SSIM.}
\label{tab:div2k_mse}
\input{tables/div2k_mse}
\end{table}

\begin{table}[h]
\centering
\caption{Compression quality on CLIC ($512 \times 512$, MSE loss). PSNR (dB) / SSIM.}
\label{tab:clic_mse}
\input{tables/clic_mse}
\end{table}

\begin{figure*}[t]
\centering
\includegraphics[width=0.32\textwidth]{mse/quickdraw_reconstruction_grid.png}
\includegraphics[width=0.32\textwidth]{mse/div2k_reconstruction_grid.png}
\includegraphics[width=0.32\textwidth]{mse/clic_reconstruction_grid.png}
\caption{Reconstruction quality comparison across datasets (MSE loss). Each grid shows the original image and reconstructions at 5\%, 10\%, 15\%, and 20\% coefficient retention for each basis type.}
\label{fig:recon_mse}
\end{figure*}

\begin{figure}[t]
\centering
\includegraphics[width=0.48\columnwidth]{mse/cross_dataset_psnr.png}
\includegraphics[width=0.48\columnwidth]{mse/cross_dataset_ssim.png}
\caption{Cross-dataset comparison of PSNR and SSIM at 10\% coefficient retention (MSE loss).}
\label{fig:cross_mse}
\end{figure}
```

3. **Section 5.3 (L1 Norm Results)**:

```latex
\subsection{L1 Norm Results}

To compare the effect of loss function choice, we also train all bases using the L1 norm loss, which promotes sparsity via compressed sensing theory.

\begin{table}[h]
\centering
\caption{Compression quality on Quick Draw ($32 \times 32$, L1 norm loss). PSNR (dB) / SSIM.}
\label{tab:quickdraw_l1}
\input{tables/l1norm_quickdraw}
\end{table}

\begin{figure*}[t]
\centering
\includegraphics[width=0.32\textwidth]{l1norm/quickdraw_reconstruction_grid.png}
\includegraphics[width=0.32\textwidth]{l1norm/div2k_reconstruction_grid.png}
\includegraphics[width=0.32\textwidth]{l1norm/clic_reconstruction_grid.png}
\caption{Reconstruction quality comparison (L1 norm loss).}
\label{fig:recon_l1}
\end{figure*}
```

4. **Section 5.4 (Topology Comparison)**:

```latex
\subsection{Topology Comparison (8-qubit, $256 \times 256$)}

To compare all four topologies including MERA (which requires power-of-two qubit counts), we evaluate on DIV2K at $256 \times 256$ resolution ($m = n = 8$ qubits).

\begin{table}[h]
\centering
\caption{Topology comparison on DIV2K ($256 \times 256$, 8 qubits). All four circuit topologies including MERA.}
\label{tab:topology}
\input{tables/div2k_8q}
\end{table}

\begin{figure}[t]
\centering
\includegraphics[width=0.9\columnwidth]{topology/div2k_8q_reconstruction_grid.png}
\caption{Reconstruction grid for all four topologies on DIV2K ($256 \times 256$, 8 qubits).}
\label{fig:recon_topology}
\end{figure}

\begin{figure}[t]
\centering
\includegraphics[width=0.9\columnwidth]{topology/div2k_8q_training_curves.png}
\caption{Training convergence for all four topologies on DIV2K (8 qubits).}
\label{fig:training_topology}
\end{figure}
```

5. **Section 5.5 (Training Dynamics)**:

```latex
\subsection{Training Dynamics}

\begin{table}[h]
\centering
\caption{Training time (seconds) across datasets (MSE loss).}
\label{tab:timing}
\input{tables/timing}
\end{table}

\begin{figure}[t]
\centering
\includegraphics[width=0.48\columnwidth]{mse/quickdraw_training_curves.png}
\includegraphics[width=0.48\columnwidth]{mse/div2k_training_curves.png}
\caption{Training convergence curves (MSE loss). Validation loss vs.\ epoch on log scale.}
\label{fig:training_curves}
\end{figure}

\begin{figure}[t]
\centering
\includegraphics[width=0.48\columnwidth]{mse/quickdraw_step_losses.png}
\includegraphics[width=0.48\columnwidth]{mse/div2k_step_losses.png}
\caption{Per-step training loss (MSE loss).}
\label{fig:step_losses}
\end{figure}
```

- [ ] **Step 5: Update Discussion section**

Update the Discussion to reference the new results (CLIC dataset, L1 vs MSE comparison, MERA results from topology section). Remove the TODO about DCT/wavelet baselines since DCT is now included.

- [ ] **Step 6: Update Appendix B**

Update the benchmark configurations table to reflect both MSE and L1 training configurations and the three datasets.

- [ ] **Step 7: Verify compilation**

Run: `cd /home/claude-user/parametric-dft-paper && make tables` (tables must exist for \input{} to work)

Then: `pdflatex main && bibtex main && pdflatex main && pdflatex main`

Expected: Compiles without errors. May show warnings about missing figures (benchmark PNGs) until `make benchmarks` is run, but should not fail.

- [ ] **Step 8: Commit**

```bash
cd /home/claude-user/parametric-dft-paper
git add main.tex
git commit -m "Restructure paper with auto-generated tables and figure includes"
```

---

## Task 7: Integration Test

**Files:** None new — this validates the full pipeline.

- [ ] **Step 1: Run make tables**

Run: `cd /home/claude-user/parametric-dft-paper && make tables`

Expected: `tables/` directory created with .tex files. Check that at least `quickdraw_mse.tex` contains valid LaTeX tabular.

- [ ] **Step 2: Run make diagrams (if typst available)**

Run: `cd /home/claude-user/parametric-dft-paper && make diagrams`

Expected: `figures/diagrams/` directory created with .pdf files. If typst is not installed, skip and note this dependency.

- [ ] **Step 3: Run make benchmarks**

Run: `cd /home/claude-user/parametric-dft-paper && make benchmarks`

Expected: `figures/benchmarks/` directory created with PNG files copied from submodule. May warn if `generate_report.jl` hasn't been run in the submodule yet.

- [ ] **Step 4: Run make paper**

Run: `cd /home/claude-user/parametric-dft-paper && make paper`

Expected: `main.pdf` compiles successfully. Open and verify figures and tables are present.

- [ ] **Step 5: Update submodule reference and final commit**

```bash
cd /home/claude-user/parametric-dft-paper
git add ParametricDFT-Benchmarks.jl
git commit -m "Update benchmark submodule with paper plot generation"
```
