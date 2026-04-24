#!/usr/bin/env julia
# Generate the appendix figure showing 2D spectra and kept-coefficient masks
# for the three additional learned bases (Entangled QFT, TEBD, MERA) on
# image 0390, alongside the separable QFT as a reference. Output:
#   figures/benchmarks/freqspace/extra_spectra_0390.pdf

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "ParametricDFT-Benchmarks.jl"))

using CairoMakie
using FFTW
using FileIO, Images
using Printf
using Statistics
using ParametricDFT

const MakieAxis = Makie.Axis

const REPO        = joinpath(@__DIR__, "..")
const BENCH_DIR   = joinpath(REPO, "ParametricDFT-Benchmarks.jl")
const RESULTS_DIR = joinpath(BENCH_DIR, "results", "div2k_8q_generalized")
const IMAGE_PATH  = "/home/claude-user/ParametricDFT-Benchmarks.jl/data/DIV2K_train_HR/0390.png"
const OUT_DIR     = joinpath(REPO, "figures", "benchmarks", "freqspace")
const KEEP_RATIOS = [0.05, 0.10, 0.15, 0.20]

function load_image(path, target_size = 256)
    img = load(path)
    gray = Gray.(img)
    gray_matrix = Float64.(channelview(gray))
    h, w = Base.size(gray_matrix)
    side = min(h, w)
    y0 = (h - side) ÷ 2 + 1
    x0 = (w - side) ÷ 2 + 1
    crop = gray_matrix[y0:y0 + side - 1, x0:x0 + side - 1]
    return Float64.(imresize(crop, (target_size, target_size)))
end

function topk_mask(mag::AbstractMatrix, k::Int)
    flat = vec(mag)
    idx  = partialsortperm(flat, 1:k; rev = true)
    mask = falses(Base.size(mag))
    mask[idx] .= true
    return mask
end

function main()
    println("Loading image 0390 ...")
    img = load_image(IMAGE_PATH, 256)
    N = length(img)

    println("Loading bases ...")
    bases = (
        ("QFT",           load_basis(joinpath(RESULTS_DIR, "trained_qft.json"))),
        ("Entangled QFT", load_basis(joinpath(RESULTS_DIR, "trained_entangled_qft.json"))),
        ("TEBD",          load_basis(joinpath(RESULTS_DIR, "trained_tebd.json"))),
        ("MERA",          load_basis(joinpath(RESULTS_DIR, "trained_mera.json"))),
    )

    println("Computing spectra ...")
    coefs = [(name, forward_transform(b, img)) for (name, b) in bases]
    mags  = [(name, abs.(c)) for (name, c) in coefs]

    # Normalise magnitudes for heatmap (log10 of peak-normalized)
    norm_mag(m) = m ./ max(maximum(m), eps())
    logmags = [(name, log10.(norm_mag(m) .+ 1e-6)) for (name, m) in mags]
    zmin = minimum(minimum(lm) for (_, lm) in logmags)
    zmax = 0.0

    n_rows = length(bases)            # 4 methods
    n_cols = length(KEEP_RATIOS) + 1  # spectrum + 4 masks

    cell_px   = 220
    title_row = 36
    main_row  = 80
    bottom_pad = 50
    fig = Figure(size = (n_cols * cell_px + 160,
                         n_rows * cell_px + title_row + main_row + bottom_pad);
                 figure_padding = 12)

    Makie.Label(fig[0, 1:n_cols],
        "Spectra and kept-coefficient masks for the four learned bases on 0390.png";
        fontsize = 14, font = :bold)

    # Header row: "Spectrum" + per-ratio labels
    Makie.Label(fig[1, 1], "log|coef|"; fontsize = 11, font = :bold)
    for (j, r) in enumerate(KEEP_RATIOS)
        Makie.Label(fig[1, j + 1],
            "$(round(Int, r * 100))% kept"; fontsize = 11, font = :bold)
    end

    for (i, (name, lm)) in enumerate(logmags)
        # Row label
        Makie.Label(fig[i + 1, 0], name; rotation = π / 2,
            fontsize = 12, font = :bold)

        # Spectrum column
        ax_s = MakieAxis(fig[i + 1, 1]; aspect = DataAspect())
        hidedecorations!(ax_s); hidespines!(ax_s)
        heatmap!(ax_s, rotr90(lm); colormap = :inferno,
                 colorrange = (zmin, zmax), rasterize = 2)

        # Mask columns
        mag = mags[i][2]
        for (j, r) in enumerate(KEEP_RATIOS)
            k = max(1, round(Int, N * r))
            mask = topk_mask(mag, k)
            ax_m = MakieAxis(fig[i + 1, j + 1]; aspect = DataAspect())
            hidedecorations!(ax_m); hidespines!(ax_m)
            heatmap!(ax_m, rotr90(Float64.(mask)); colormap = :grays,
                     colorrange = (0, 1), rasterize = 2)
        end
    end

    rowsize!(fig.layout, 0, CairoMakie.Fixed(main_row))
    rowsize!(fig.layout, 1, CairoMakie.Fixed(title_row))
    for i in 2:(n_rows + 1)
        rowsize!(fig.layout, i, CairoMakie.Fixed(cell_px))
    end
    for j in 1:n_cols
        colsize!(fig.layout, j, CairoMakie.Fixed(cell_px))
    end

    mkpath(OUT_DIR)
    out = joinpath(OUT_DIR, "extra_spectra_0390.pdf")
    save(out, fig; pt_per_unit = 1)
    println("Wrote $out")
end

main()
