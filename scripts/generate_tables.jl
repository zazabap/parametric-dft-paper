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
    # Collect timing from canonical MSE result directories (top-level).
    mse_dirs = [
        ("QuickDraw", "quickdraw"),
        ("DIV2K", "div2k_8q"),
        ("CLIC", "clic"),
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

# ============================================================================
# Frequency-space summary table (parses analysis/<dataset>/summary_all_images.txt)
# ============================================================================

# Parses the consolidated 20-image PSNR/SSIM summary into two Dicts
#   psnr[method][ratio] = Vector{Float64} (per-image values)
#   ssim[method][ratio] = Vector{Float64}
# Methods: "FFT","DCT","BDCT","QFT". Ratios: "5%","10%","15%","20%".
function parse_freq_summary(path::String)
    @assert isfile(path) "summary file not found: $path"
    lines = readlines(path)

    methods = ["FFT", "DCT", "BDCT", "QFT"]
    ratios  = ["5%", "10%", "15%", "20%"]
    psnr = Dict(m => Dict(r => Float64[] for r in ratios) for m in methods)
    ssim = Dict(m => Dict(r => Float64[] for r in ratios) for m in methods)

    # Find the PSNR and SSIM blocks.
    psnr_start = findfirst(l -> occursin("PSNR (dB) per image", l), lines)
    ssim_start = findfirst(l -> occursin("SSIM per image", l), lines)
    @assert psnr_start !== nothing "could not locate PSNR block"
    @assert ssim_start !== nothing "could not locate SSIM block"

    # Column order is method × ratio, fastest-varying is method within each ratio.
    #   FFT@5% DCT@5% BDCT@5% QFT@5% | FFT@10% ... QFT@20%
    cols = [(m, r) for r in ratios for m in methods]

    function parse_block(start_idx::Int, target::Dict)
        i = start_idx + 1  # skip the "PSNR (dB) per image..." title line
        saw_data = false
        while i <= length(lines)
            line = strip(lines[i])
            i += 1
            # Skip column headers and underlines above the data rows.
            (isempty(line) || startswith(line, "---") || startswith(line, "image")) && continue
            # End of block: MEAN row, or start of next section.
            startswith(line, "MEAN") && break
            startswith(line, "SSIM") && break
            occursin(":", line) && continue  # stray header / label lines
            # Row: "<image>.png  v1  v2  ... v_{cols}"
            toks = split(line)
            length(toks) < 1 + length(cols) && continue
            # First token must look like a filename (contains a dot).
            occursin(".", toks[1]) || continue
            vals = try
                [parse(Float64, t) for t in toks[2:1+length(cols)]]
            catch
                continue
            end
            for (j, (m, r)) in enumerate(cols)
                push!(target[m][r], vals[j])
            end
            saw_data = true
        end
        @assert saw_data "parse_block: no data rows found starting at line $start_idx"
    end

    parse_block(psnr_start, psnr)
    parse_block(ssim_start, ssim)
    return psnr, ssim
end

function generate_freqspace_table(summary_path::String, output_path::String)
    psnr, ssim = parse_freq_summary(summary_path)
    methods = ["FFT", "DCT", "BDCT", "QFT"]
    method_labels = Dict(
        "FFT"  => "FFT",
        "DCT"  => "DCT (full-image)",
        "BDCT" => "BlockDCT (8\\(\\times\\)8)",
        "QFT"  => "QFT (learned)",
    )
    ratios = ["5%", "10%", "15%", "20%"]
    ratio_headers = ["5\\%", "10\\%", "15\\%", "20\\%"]

    # Find best method per ratio, by PSNR mean.
    best_psnr = Dict{String,String}()
    for r in ratios
        best_psnr[r] = argmax(m -> mean(psnr[m][r]), methods)
    end

    lines = String[]
    push!(lines, "\\begin{tabular}{l" * repeat("c", length(ratios)) * "}")
    push!(lines, "\\toprule")
    push!(lines, "Method & " * join(ratio_headers, " & ") * " \\\\")
    push!(lines, "\\midrule")
    for m in methods
        cells = String[]
        for r in ratios
            p = mean(psnr[m][r])
            s = mean(ssim[m][r])
            cell = @sprintf("%.2f / %.3f", p, s)
            if best_psnr[r] == m
                cell = "\\textbf{" * cell * "}"
            end
            push!(cells, cell)
        end
        push!(lines, method_labels[m] * " & " * join(cells, " & ") * " \\\\")
    end
    push!(lines, "\\bottomrule")
    push!(lines, "\\end{tabular}")

    mkpath(dirname(output_path))
    write(output_path, join(lines, "\n") * "\n")
    println("Generated: $output_path")
end

using Statistics: mean

function main()
    mkpath(TABLES_DIR)

    # Rate-distortion tables (canonical top-level MSE runs).
    mse_configs = [
        ("quickdraw", "quickdraw_mse.tex"),
        ("clic", "clic_mse.tex"),
        ("div2k_8q", "div2k_8q.tex"),
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

    # Timing table
    generate_timing_table(joinpath(TABLES_DIR, "timing.tex"))

    # Frequency-space summary table (FFT / DCT / BlockDCT / QFT over 20 images).
    # Use the generalized (newer) run; it delivers a cleaner 16x16 block.
    freq_summary = joinpath(RESULTS_DIR, "..", "analysis", "div2k_8q_generalized", "summary_all_images.txt")
    if isfile(freq_summary)
        generate_freqspace_table(freq_summary, joinpath(TABLES_DIR, "freqspace_div2k_8q.tex"))
    else
        println("Warning: $freq_summary not found, skipping freqspace_div2k_8q.tex")
    end

    println("Done generating tables.")
end

main()
