#!/usr/bin/env julia
# Appendix variation plots driven by the Python pdft benchmark dump under
# /home/claude-user/parametric-dft-python/benchmarks/results/.
#
# Emits four PDFs under figures/benchmarks/variations/:
#   variations_rd.pdf            — PSNR vs keep ratio across topology variants
#   variations_block_size.pdf    — PSNR @ 20% keep vs block size
#   variations_rich_ablation.pdf — bar chart over rich-basis ablations
#   variations_resolution.pdf    — 8q (256x256) vs 10q (1024x1024) RD curves

using CSV
using DataFrames
using JSON3
using CairoMakie

const REPO          = normpath(joinpath(@__DIR__, ".."))
const PY_BENCH_ROOT = "/home/claude-user/parametric-dft-python/benchmarks/results"
const OUT_DIR       = joinpath(REPO, "figures", "benchmarks", "variations")
mkpath(OUT_DIR)

function load_psnr(run::AbstractString)
    path = joinpath(PY_BENCH_ROOT, run, "rate_distortion_psnr.csv")
    isfile(path) || error("PSNR CSV not found: $path")
    return CSV.read(path, DataFrame)
end

function basis_row(df::DataFrame, basis::AbstractString, ks)
    sub = df[df.basis .== basis, :]
    isempty(sub) && return nothing
    out = Tuple{Float64,Float64,Float64}[]
    for k in ks
        r = sub[isapprox.(sub.keep_ratio, k; atol = 1e-6), :]
        isempty(r) && continue
        if any(isnan, r.mean) || any(isnan, r.std)
            continue
        end
        push!(out, (Float64(r.keep_ratio[1]), Float64(r.mean[1]), Float64(r.std[1])))
    end
    return out
end

# ---------------------------------------------------------------------------
# Figure A1: rate-distortion across topology + blocked variants (8q, 256x256)
# ---------------------------------------------------------------------------
function plot_variations_rd(output::AbstractString)
    ks = [0.05, 0.10, 0.15, 0.20]
    # Unblocked topologies live in two GPU shards.
    df_top0 = load_psnr("div2k_8q_generalized_20260425-102013_gpu0")
    df_top1 = load_psnr("div2k_8q_generalized_20260425-102013_gpu1")
    df_blocked = load_psnr("div2k_8q_blocked_generalized_20260426-085726")
    df_rich    = load_psnr("div2k_8q_blocked_rich_generalized_20260426-110840")
    df_real    = load_psnr("div2k_8q_REAL_20260426-123029")

    series = [
        ("QFT",                 df_top0, "qft",                   :solid, RGBf(0.12, 0.47, 0.71)),
        ("Entangled QFT",       df_top1, "entangled_qft",         :solid, RGBf(0.84, 0.15, 0.16)),
        ("TEBD",                df_top1, "tebd",                  :solid, RGBf(0.17, 0.63, 0.17)),
        ("MERA",                df_top0, "mera",                  :solid, RGBf(0.94, 0.55, 0.13)),
        ("Blocked QFT",         df_blocked, "blocked_qft",        :dash,  RGBf(0.12, 0.47, 0.71)),
        ("Blocked Ent. QFT",    df_blocked, "blocked_entangled_qft", :dash, RGBf(0.84, 0.15, 0.16)),
        ("Blocked TEBD",        df_blocked, "blocked_tebd",       :dash,  RGBf(0.17, 0.63, 0.17)),
        ("Blocked rich",        df_rich,    "blocked_rich",       :dot,   RGBf(0.40, 0.15, 0.55)),
        ("Blocked real",        df_real,    "blocked_real",       :dot,   RGBf(0.55, 0.27, 0.07)),
    ]

    fig = Figure(size = (820, 520))
    ax = Axis(fig[1, 1];
        xlabel = "Keep ratio",
        ylabel = "PSNR (dB)",
        title  = "Basis variations on DIV2K 256×256 (8 qubits)",
        xticks = (ks, ["5%", "10%", "15%", "20%"]))

    # Classical reference curves: BlockDCT-8 and DCT (full image).
    blockdct = basis_row(df_top0, "block_dct_8", ks)
    dctfull  = basis_row(df_top0, "dct", ks)
    if blockdct !== nothing
        xs = [t[1] for t in blockdct]; ys = [t[2] for t in blockdct]
        lines!(ax, xs, ys; color = (:black, 0.55), linestyle = :dashdot,
               linewidth = 1.6, label = "BlockDCT 8×8")
    end
    if dctfull !== nothing
        xs = [t[1] for t in dctfull]; ys = [t[2] for t in dctfull]
        lines!(ax, xs, ys; color = (:gray, 0.7), linestyle = :dashdot,
               linewidth = 1.4, label = "DCT (full image)")
    end

    for (label, df, basis, lstyle, c) in series
        rows = basis_row(df, basis, ks)
        rows === nothing && continue
        xs = [t[1] for t in rows]; ys = [t[2] for t in rows]
        lines!(ax, xs, ys; color = c, linestyle = lstyle,
               linewidth = 1.9, label = label)
        scatter!(ax, xs, ys; color = c, markersize = 7)
    end

    axislegend(ax; position = :lt, nbanks = 2, labelsize = 9,
               backgroundcolor = (:white, 0.88))
    save(output, fig; pt_per_unit = 1)
    println("Generated: $output")
end

# ---------------------------------------------------------------------------
# Figure A2: PSNR @ 20% keep vs block size (4, 16, 32, 64) for blocked
# parametric circuits and BlockDCT/BlockFFT.
# ---------------------------------------------------------------------------
function plot_variations_block_size(output::AbstractString)
    # (block side, run dir, classical-DCT basis name in that run, classical-FFT basis name).
    runs = [
        (4,  "div2k_8q_blocked_generalized_20260426-093846_bs4",  "block_dct_4",  "block_fft_4"),
        (8,  "div2k_8q_blocked_generalized_20260426-085726",      "block_dct_8",  "block_fft_8"),
        (16, "div2k_8q_blocked_generalized_20260426-093846_bs16", "block_dct_16", "block_fft_16"),
        (32, "div2k_8q_blocked_generalized_20260426-093846_bs32", "block_dct_32", "block_fft_32"),
        (64, "div2k_8q_blocked_generalized_20260426-093846_bs64", "block_dct_64", "block_fft_64"),
    ]
    rows = Dict{String,Vector{Tuple{Int,Float64,Float64}}}()
    push_row!(d, key, sz, m, s) = (haskey(d, key) || (d[key] = []); push!(d[key], (sz, m, s)))

    for (sz, run, dct_name, fft_name) in runs
        df = load_psnr(run)
        sub = df[isapprox.(df.keep_ratio, 0.20; atol = 1e-6), :]
        for r in eachrow(sub)
            b = String(r.basis)
            isnan(r.mean) && continue
            # Take only the run-specific BlockDCT/BlockFFT (not the bs=8 reference
            # row that the harness includes in every CSV).
            key = if b == dct_name
                "BlockDCT"
            elseif b == fft_name
                "BlockFFT"
            elseif b == "blocked_qft"
                "Blocked QFT"
            elseif b == "blocked_entangled_qft"
                "Blocked Ent. QFT"
            elseif b == "blocked_tebd"
                "Blocked TEBD"
            elseif b == "blocked_mera"
                "Blocked MERA"
            else
                continue
            end
            push_row!(rows, key, sz, Float64(r.mean), Float64(r.std))
        end
    end

    fig = Figure(size = (760, 460))
    ax = Axis(fig[1, 1];
        xlabel = "Block side (pixels)",
        ylabel = "PSNR @ 20% keep (dB)",
        title  = "Block-size axis on DIV2K 256×256",
        xscale = log2,
        xticks = ([4, 16, 32, 64], ["4", "16", "32", "64"]))

    color_for = Dict(
        "BlockDCT"          => (:black,  :dashdot, 1.6),
        "BlockFFT"          => (:gray,   :dashdot, 1.4),
        "Blocked QFT"       => (RGBf(0.12, 0.47, 0.71), :solid, 1.9),
        "Blocked Ent. QFT"  => (RGBf(0.84, 0.15, 0.16), :solid, 1.9),
        "Blocked TEBD"      => (RGBf(0.17, 0.63, 0.17), :solid, 1.9),
        "Blocked MERA"      => (RGBf(0.94, 0.55, 0.13), :solid, 1.9),
    )

    for (label, pts) in sort(collect(rows); by = first)
        sort!(pts; by = first)
        xs = [p[1] for p in pts]; ys = [p[2] for p in pts]
        c, ls, lw = color_for[label]
        lines!(ax, xs, ys; color = c, linestyle = ls, linewidth = lw,
               label = label)
        scatter!(ax, xs, ys; color = c, markersize = 8)
    end

    axislegend(ax; position = :rb, labelsize = 10,
               backgroundcolor = (:white, 0.88))
    save(output, fig; pt_per_unit = 1)
    println("Generated: $output")
end

# ---------------------------------------------------------------------------
# Figure A3: rich-basis ablation bar chart at 20% keep.
# ---------------------------------------------------------------------------
# Count real scalars stored in `trained_*.json` for a single trained basis
# (one image). We use the file's first entry as representative — every entry
# has identical structure since the harness trains the same architecture
# per image.
function trained_param_count(rel_path::AbstractString)
    p = joinpath(PY_BENCH_ROOT, rel_path)
    isfile(p) || return missing
    arr = JSON3.read(read(p, String))
    first = arr isa AbstractVector ? arr[1] : arr
    n = 0
    function walk(x)
        if x isa AbstractVector
            if !isempty(x) && x[1] isa Number
                n += length(x)
            else
                for y in x; walk(y); end
            end
        elseif x isa AbstractDict || x isa JSON3.Object
            for (_, v) in x; walk(v); end
        end
    end
    walk(first[:tensors])
    return n
end

function plot_variations_rich_ablation(output::AbstractString)
    # (label, run dir, basis-name-in-csv, trained-json-relpath-or-nothing).
    runs = [
        ("Blocked QFT (ref.)",       "div2k_8q_blocked_generalized_20260426-085726",       "blocked_qft",
            "div2k_8q_blocked_generalized_20260426-085726/trained_blocked_qft.json"),
        ("Blocked rich",             "div2k_8q_blocked_rich_generalized_20260426-110840",  "blocked_rich",
            "div2k_8q_blocked_rich_generalized_20260426-110840/trained_blocked_rich.json"),
        ("Rich + DCT init",          "div2k_8q_rich_DCTINIT_20260426-111726",              "blocked_rich",
            "div2k_8q_rich_DCTINIT_20260426-111726/trained_blocked_rich.json"),
        ("Rich + dense",             "div2k_8q_rich_DENSE_20260426-113814",                "blocked_rich",
            "div2k_8q_rich_DENSE_20260426-113814/trained_blocked_rich.json"),
        ("Rich + dense + DCT init",  "div2k_8q_rich_DENSE_DCTINIT_20260426-113814",        "blocked_rich",
            "div2k_8q_rich_DENSE_DCTINIT_20260426-113814/trained_blocked_rich.json"),
        ("Rich (longer training)",   "div2k_8q_rich_LONG_20260426-111726",                 "blocked_rich",
            "div2k_8q_rich_LONG_20260426-111726/trained_blocked_rich.json"),
        ("Stacked depth K=3 (Ent.)", "div2k_8q_blocked_stacked_20260426-103547_K3",        "blocked_entangled_qft_K3",
            "div2k_8q_blocked_stacked_20260426-103547_K3/trained_blocked_entangled_qft_K3.json"),
        ("BlockDCT 8×8",             "div2k_8q_blocked_generalized_20260426-085726",       "block_dct_8",
            nothing),  # 0 trainable parameters
    ]

    pts = Tuple{String,Int,Float64}[]
    for (lbl, run, basis, jsonrel) in runs
        df = load_psnr(run)
        rows = basis_row(df, basis, [0.20])
        (rows === nothing || isempty(rows)) && continue
        psnr = rows[1][2]
        nparams = jsonrel === nothing ? 0 : trained_param_count(jsonrel)
        nparams === missing && continue
        push!(pts, (lbl, Int(nparams), psnr))
    end

    palette = [
        RGBf(0.55, 0.55, 0.55),
        RGBf(0.40, 0.15, 0.55),
        RGBf(0.20, 0.40, 0.65),
        RGBf(0.65, 0.30, 0.25),
        RGBf(0.30, 0.55, 0.30),
        RGBf(0.85, 0.55, 0.15),
        RGBf(0.10, 0.50, 0.55),
        RGBf(0.20, 0.20, 0.20),
    ]

    fig = Figure(size = (820, 460))
    ax = Axis(fig[1, 1];
        xlabel = "Trainable real parameters per image",
        ylabel = "PSNR @ 20% keep (dB)",
        title  = "Rich-basis ablation on DIV2K 256×256")

    # Plot each point individually so the legend has one entry per variant.
    markers = [:circle, :diamond, :rect, :utriangle, :dtriangle, :star5, :pentagon, :cross]
    for (i, (lbl, nparams, psnr)) in enumerate(pts)
        c = palette[mod1(i, length(palette))]
        m = markers[mod1(i, length(markers))]
        scatter!(ax, [nparams], [psnr]; color = c, marker = m,
                 markersize = 14, strokecolor = :black, strokewidth = 0.6,
                 label = lbl)
    end

    # Annotate every point with its PSNR value just above the marker, leaving
    # the variant identity to the legend.
    for (lbl, nparams, psnr) in pts
        text!(ax, string(round(psnr; digits = 2));
              position = (nparams, psnr),
              offset = (0.0, 8.0),
              align = (:center, :bottom),
              fontsize = 9)
    end

    # Custom x ticks at the parameter counts we actually have.
    xs = sort(unique([p[2] for p in pts]))
    ax.xticks = (xs, [string(x) for x in xs])
    ymin = floor(minimum(p[3] for p in pts)) - 0.5
    ymax = ceil(maximum(p[3] for p in pts))  + 0.5
    xmax = maximum(xs) + 60
    xlims!(ax, -30.0, xmax)
    ylims!(ax, ymin, ymax)

    axislegend(ax; position = :rb, labelsize = 9, nbanks = 1,
               backgroundcolor = (:white, 0.92))
    save(output, fig; pt_per_unit = 1)
    println("Generated: $output")
end

# ---------------------------------------------------------------------------
# Figure A4: resolution scaling — 8q (256x256) vs 10q (1024x1024).
# ---------------------------------------------------------------------------
function plot_variations_resolution(output::AbstractString)
    ks = [0.05, 0.10, 0.15, 0.20]
    df8_0  = load_psnr("div2k_8q_generalized_20260425-102013_gpu0")
    df8_1  = load_psnr("div2k_8q_generalized_20260425-102013_gpu1")
    df10_0 = load_psnr("div2k_10q_generalized_20260426-055335_gpu0_bs2")
    df10_1 = load_psnr("div2k_10q_generalized_20260426-055335_gpu1_bs2")

    fig = Figure(size = (860, 460))
    axL = Axis(fig[1, 1];
        xlabel = "Keep ratio",
        ylabel = "PSNR (dB)",
        title  = "256×256 (8 qubits)",
        xticks = (ks, ["5%", "10%", "15%", "20%"]))
    axR = Axis(fig[1, 2];
        xlabel = "Keep ratio",
        ylabel = "PSNR (dB)",
        title  = "1024×1024 (10 qubits)",
        xticks = (ks, ["5%", "10%", "15%", "20%"]))

    plotone! = (ax, df, basis, label, c) -> begin
        rows = basis_row(df, basis, ks)
        rows === nothing && return
        xs = [t[1] for t in rows]; ys = [t[2] for t in rows]
        lines!(ax, xs, ys; color = c, linewidth = 1.9, label = label)
        scatter!(ax, xs, ys; color = c, markersize = 7)
    end

    plotone!(axL, df8_0, "qft",           "QFT",          RGBf(0.12, 0.47, 0.71))
    plotone!(axL, df8_1, "entangled_qft", "Entangled QFT",RGBf(0.84, 0.15, 0.16))
    plotone!(axL, df8_1, "tebd",          "TEBD",         RGBf(0.17, 0.63, 0.17))
    plotone!(axL, df8_0, "block_dct_8",   "BlockDCT 8×8", RGBf(0.30, 0.30, 0.30))
    plotone!(axL, df8_0, "dct",           "DCT (full)",   RGBf(0.55, 0.55, 0.55))

    plotone!(axR, df10_1, "qft",           "QFT",          RGBf(0.12, 0.47, 0.71))
    plotone!(axR, df10_0, "entangled_qft", "Entangled QFT",RGBf(0.84, 0.15, 0.16))
    plotone!(axR, df10_1, "tebd",          "TEBD",         RGBf(0.17, 0.63, 0.17))
    plotone!(axR, df10_0, "block_dct_8",   "BlockDCT 8×8", RGBf(0.30, 0.30, 0.30))
    plotone!(axR, df10_0, "dct",           "DCT (full)",   RGBf(0.55, 0.55, 0.55))

    axislegend(axL; position = :lt, labelsize = 9,
               backgroundcolor = (:white, 0.88))
    axislegend(axR; position = :lt, labelsize = 9,
               backgroundcolor = (:white, 0.88))
    save(output, fig; pt_per_unit = 1)
    println("Generated: $output")
end

function main()
    plot_variations_rd(joinpath(OUT_DIR, "variations_rd.pdf"))
    plot_variations_block_size(joinpath(OUT_DIR, "variations_block_size.pdf"))
    plot_variations_rich_ablation(joinpath(OUT_DIR, "variations_rich_ablation.pdf"))
    plot_variations_resolution(joinpath(OUT_DIR, "variations_resolution.pdf"))
end

main()
