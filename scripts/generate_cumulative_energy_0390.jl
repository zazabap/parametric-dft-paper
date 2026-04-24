#!/usr/bin/env julia
# Regenerate figures/benchmarks/freqspace/cumulative_energy_0390.pdf with all
# seven methods (FFT, DCT, BlockDCT 8x8, QFT, Entangled QFT, TEBD, MERA).
# Cumulative energy for each method is the sorted magnitude-squared coefficient
# sequence normalised so the last value = 1; plotted on a log-x axis.

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
const BLOCK_SIZE  = 8
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

function block_dct(img, bs = BLOCK_SIZE)
    H, W = Base.size(img)
    freq = zeros(Float64, H, W)
    @inbounds for by in 1:bs:H, bx in 1:bs:W
        freq[by:by + bs - 1, bx:bx + bs - 1] =
            dct(img[by:by + bs - 1, bx:bx + bs - 1])
    end
    return freq
end

function cumulative_energy(mag)
    e = sort(vec(mag) .^ 2; rev = true)
    c = cumsum(e)
    c ./= c[end]
    return c
end

function main()
    println("Loading image 0390 ...")
    img = load_image(IMAGE_PATH, 256)
    N = length(img)

    println("Loading trained bases ...")
    qft_basis  = load_basis(joinpath(RESULTS_DIR, "trained_qft.json"))
    eqft_basis = load_basis(joinpath(RESULTS_DIR, "trained_entangled_qft.json"))
    tebd_basis = load_basis(joinpath(RESULTS_DIR, "trained_tebd.json"))
    mera_basis = load_basis(joinpath(RESULTS_DIR, "trained_mera.json"))

    println("Computing transforms ...")
    mag_fft  = abs.(fftshift(fft(img)))
    mag_dct  = abs.(dct(img))
    mag_bdct = abs.(block_dct(img))
    mag_qft  = abs.(forward_transform(qft_basis,  img))
    mag_eqft = abs.(forward_transform(eqft_basis, img))
    mag_tebd = abs.(forward_transform(tebd_basis, img))
    mag_mera = abs.(forward_transform(mera_basis, img))

    println("Computing cumulative energy curves ...")
    ce = (
        ("Classical FFT",     cumulative_energy(mag_fft),  :solid,  RGBf(0.25, 0.25, 0.25)),
        ("Classical DCT",     cumulative_energy(mag_dct),  :solid,  RGBf(0.55, 0.55, 0.55)),
        ("Block DCT (8×8)",   cumulative_energy(mag_bdct), :solid,  RGBf(0.00, 0.45, 0.70)),
        ("QFT (trained)",     cumulative_energy(mag_qft),  :dash,   RGBf(0.80, 0.20, 0.20)),
        ("Entangled QFT",     cumulative_energy(mag_eqft), :dash,   RGBf(0.90, 0.50, 0.10)),
        ("TEBD",              cumulative_energy(mag_tebd), :dashdot, RGBf(0.35, 0.70, 0.30)),
        ("MERA",              cumulative_energy(mag_mera), :dot,    RGBf(0.50, 0.25, 0.60)),
    )

    xs = (1:N) ./ N
    fig = Figure(size = (900, 560); figure_padding = 14)
    ax = MakieAxis(fig[1, 1];
        title  = "Energy captured vs. fraction kept — 0390.png",
        xlabel = "Fraction of coefficients kept",
        ylabel = "Fraction of total L2 energy",
        xscale = log10)
    for (label, curve, style, color) in ce
        lines!(ax, xs, curve; label = label, linewidth = 2.2,
               linestyle = style, color = color)
    end
    for r in KEEP_RATIOS
        vlines!(ax, [r]; color = :gray, linestyle = :dash, linewidth = 1)
    end
    axislegend(ax; position = :rb, labelsize = 11)

    mkpath(OUT_DIR)
    out = joinpath(OUT_DIR, "cumulative_energy_0390.pdf")
    save(out, fig; pt_per_unit = 1)
    println("Wrote $out")

    # Also print a small summary — energy captured at 20% keep ratio.
    k = round(Int, 0.20 * N)
    println("\nEnergy captured at 20% keep:")
    for (label, curve, _, _) in ce
        @printf("  %-20s %.4f\n", label, curve[k])
    end
end

main()
