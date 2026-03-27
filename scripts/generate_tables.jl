#!/usr/bin/env julia
# Generate LaTeX tabular blocks from benchmark JSON results
using JSON3
using Printf

const RESULTS_DIR = joinpath(@__DIR__, "..", "ParametricDFT-Benchmarks.jl", "results")
const TABLES_DIR = joinpath(@__DIR__, "..", "tables")

const KEEP_RATIOS = [0.05, 0.10, 0.15, 0.20]
const BASIS_ORDER = ["fft", "dct", "qft", "entangled_qft", "tebd", "mera"]
const BASIS_LABELS = Dict(
    "fft" => "FFT",
    "dct" => "DCT",
    "qft" => "QFT",
    "entangled_qft" => "Entangled QFT",
    "tebd" => "TEBD",
    "mera" => "MERA",
)

const FIXED_BASES = Set(["fft", "dct"])

function load_metrics(path::String)
    isfile(path) || error("Metrics file not found: $path")
    return JSON3.read(read(path, String))
end

function format_psnr_ssim(metrics, ratio_key::String)
    haskey(metrics, Symbol(ratio_key)) || return "—"
    m = metrics[Symbol(ratio_key)]
    psnr = m[:mean_psnr]
    ssim = m[:mean_ssim]
    return @sprintf("%.2f / %.3f", psnr, ssim)
end

function find_best_learned(data, ratio_key::String, metric::Symbol)
    best_val = -Inf
    best_basis = ""
    for basis in BASIS_ORDER
        basis in FIXED_BASES && continue
        haskey(data, Symbol(basis)) || continue
        m = data[Symbol(basis)][:metrics]
        haskey(m, Symbol(ratio_key)) || continue
        val = m[Symbol(ratio_key)][metric]
        if val > best_val
            best_val = val
            best_basis = basis
        end
    end
    return best_basis
end

function generate_rate_distortion_table(metrics, output_path::String)
    ratio_strs = [string(r) for r in KEEP_RATIOS]
    # Column headers: 5%, 10%, 15%, 20%
    pct_headers = [string(Int(r * 100), "\\%") for r in KEEP_RATIOS]

    # Find best learned basis per ratio (by PSNR)
    best_per_ratio = Dict{String,String}()
    for rs in ratio_strs
        best_per_ratio[rs] = find_best_learned(metrics, rs, :mean_psnr)
    end

    lines = String[]
    push!(lines, "\\begin{tabular}{l" * repeat("c", length(KEEP_RATIOS)) * "}")
    push!(lines, "\\toprule")
    push!(lines, "Method & " * join(pct_headers, " & ") * " \\\\")
    push!(lines, "\\midrule")

    # Fixed baselines first
    wrote_fixed = false
    for basis in BASIS_ORDER
        basis in FIXED_BASES || continue
        haskey(metrics, Symbol(basis)) || continue
        label = BASIS_LABELS[basis]
        cells = String[]
        for rs in ratio_strs
            push!(cells, format_psnr_ssim(metrics[Symbol(basis)][:metrics], rs))
        end
        push!(lines, label * " & " * join(cells, " & ") * " \\\\")
        wrote_fixed = true
    end

    if wrote_fixed
        push!(lines, "\\midrule")
    end

    # Learned bases
    for basis in BASIS_ORDER
        basis in FIXED_BASES && continue
        haskey(metrics, Symbol(basis)) || continue
        label = BASIS_LABELS[basis]
        cells = String[]
        for rs in ratio_strs
            val = format_psnr_ssim(metrics[Symbol(basis)][:metrics], rs)
            if best_per_ratio[rs] == basis
                val = "\\textbf{" * val * "}"
            end
            push!(cells, val)
        end
        push!(lines, label * " & " * join(cells, " & ") * " \\\\")
    end

    push!(lines, "\\bottomrule")
    push!(lines, "\\end{tabular}")

    mkpath(dirname(output_path))
    write(output_path, join(lines, "\n") * "\n")
    println("Generated: $output_path")
end

function generate_timing_table(output_path::String)
    # Collect timing from MSE result directories
    mse_dirs = [
        ("QuickDraw", "quickdraw_moderate_mse_old"),
        ("DIV2K", "div2k_mse_old"),
        ("CLIC", "clic_mse_old"),
    ]

    lines = String[]
    push!(lines, "\\begin{tabular}{l" * repeat("c", length(mse_dirs)) * "}")
    push!(lines, "\\toprule")
    push!(lines, "Method & " * join([d[1] for d in mse_dirs], " & ") * " \\\\")
    push!(lines, "\\midrule")

    # Collect all available bases across datasets
    all_data = Dict{String,Any}()
    for (label, dirname) in mse_dirs
        metrics_path = joinpath(RESULTS_DIR, dirname, "metrics.json")
        if isfile(metrics_path)
            all_data[label] = load_metrics(metrics_path)
        end
    end

    wrote_fixed = false
    for basis in BASIS_ORDER
        # Check if basis exists in any dataset
        has_basis = any(haskey(d, Symbol(basis)) for (_, d) in all_data)
        has_basis || continue

        label = BASIS_LABELS[basis]
        cells = String[]
        for (ds_label, _) in mse_dirs
            if haskey(all_data, ds_label) && haskey(all_data[ds_label], Symbol(basis))
                t = all_data[ds_label][Symbol(basis)][:time]
                push!(cells, @sprintf("%.1f s", t))
            else
                push!(cells, "—")
            end
        end

        if basis in FIXED_BASES
            push!(lines, label * " & " * join(cells, " & ") * " \\\\")
            wrote_fixed = true
        else
            if wrote_fixed
                push!(lines, "\\midrule")
                wrote_fixed = false
            end
            push!(lines, label * " & " * join(cells, " & ") * " \\\\")
        end
    end

    push!(lines, "\\bottomrule")
    push!(lines, "\\end{tabular}")

    mkpath(dirname(output_path))
    write(output_path, join(lines, "\n") * "\n")
    println("Generated: $output_path")
end

function main()
    mkpath(TABLES_DIR)

    # MSE rate-distortion tables
    mse_configs = [
        ("quickdraw_moderate_mse_old", "quickdraw_mse.tex"),
        ("div2k_mse_old", "div2k_mse.tex"),
        ("clic_mse_old", "clic_mse.tex"),
    ]

    for (dirname, texname) in mse_configs
        metrics_path = joinpath(RESULTS_DIR, dirname, "metrics.json")
        if isfile(metrics_path)
            data = load_metrics(metrics_path)
            generate_rate_distortion_table(data, joinpath(TABLES_DIR, texname))
        else
            println("Warning: $metrics_path not found, skipping $texname")
        end
    end

    # L1 norm tables
    l1_configs = [
        ("quickdraw", "l1norm_quickdraw.tex"),
        ("div2k", "l1norm_div2k.tex"),
        ("clic", "l1norm_clic.tex"),
    ]

    for (dataset, texname) in l1_configs
        metrics_path = joinpath(RESULTS_DIR, "moderate", dataset, "metrics.json")
        if isfile(metrics_path)
            data = load_metrics(metrics_path)
            generate_rate_distortion_table(data, joinpath(TABLES_DIR, texname))
        else
            println("Warning: $metrics_path not found, skipping $texname")
        end
    end

    # 8-qubit DIV2K table
    div2k_8q_path = joinpath(RESULTS_DIR, "div2k_8q", "metrics.json")
    if isfile(div2k_8q_path)
        data = load_metrics(div2k_8q_path)
        generate_rate_distortion_table(data, joinpath(TABLES_DIR, "div2k_8q.tex"))
    else
        println("Warning: $div2k_8q_path not found, skipping div2k_8q.tex")
    end

    # Timing table
    generate_timing_table(joinpath(TABLES_DIR, "timing.tex"))

    println("Done generating tables.")
end

main()
