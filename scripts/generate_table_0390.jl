#!/usr/bin/env julia
# Compute PSNR/SSIM at four keep ratios on DIV2K image 0390 for all seven
# methods (FFT, DCT, BlockDCT 8x8, QFT, Entangled QFT, TEBD, MERA) using the
# four trained bases in results/div2k_8q_generalized/. Writes a single
# LaTeX tabular block to tables/div2k_0390.tex.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "ParametricDFT-Benchmarks.jl"))

using FFTW
using FileIO, Images
using ImageQualityIndexes: assess_ssim
using Printf
using Statistics
using ParametricDFT

const REPO            = joinpath(@__DIR__, "..")
const BENCH_DIR       = joinpath(REPO, "ParametricDFT-Benchmarks.jl")
const RESULTS_DIR     = joinpath(BENCH_DIR, "results", "div2k_8q_generalized")
const IMAGE_PATH      = "/home/claude-user/ParametricDFT-Benchmarks.jl/data/DIV2K_train_HR/0390.png"
const TABLES_DIR      = joinpath(REPO, "tables")
const BLOCK_SIZE      = 8
const KEEP_RATIOS     = [0.05, 0.10, 0.15, 0.20]

function load_image(path, target_size = 256)
    # Matches ParametricDFT-Benchmarks.jl/data_loading.jl:load_grayscale_image
    # (center-crop to largest square, then resize) so numbers match the
    # benchmark submodule's per-image summary.
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

function compute_psnr_ssim(original, recovered)
    recovered_clamped = clamp.(real.(recovered), 0.0, 1.0)
    mse = mean((original .- recovered_clamped) .^ 2)
    psnr = mse > 0 ? 10 * log10(1.0 / mse) : Inf
    ssim = assess_ssim(Gray.(original), Gray.(recovered_clamped))
    return psnr, ssim
end

# ----- classical transforms -----
fft_forward(img)   = fftshift(fft(img))
fft_inverse(coef)  = real.(ifft(ifftshift(coef)))

dct_forward(img)   = dct(img)
dct_inverse(coef)  = idct(coef)

function block_dct(img, bs = BLOCK_SIZE)
    H, W = Base.size(img)
    freq = zeros(Float64, H, W)
    @inbounds for by in 1:bs:H, bx in 1:bs:W
        freq[by:by + bs - 1, bx:bx + bs - 1] =
            dct(img[by:by + bs - 1, bx:bx + bs - 1])
    end
    return freq
end

function block_idct(freq, bs = BLOCK_SIZE)
    H, W = Base.size(freq)
    img = zeros(Float64, H, W)
    @inbounds for by in 1:bs:H, bx in 1:bs:W
        img[by:by + bs - 1, bx:bx + bs - 1] =
            idct(freq[by:by + bs - 1, bx:bx + bs - 1])
    end
    return img
end

# ----- per-method evaluation at all keep ratios -----
function eval_classical(img, forward, inverse, keep_ratios)
    coef = forward(img)
    mag = abs.(coef)
    N = length(coef)
    out = Tuple{Float64,Float64}[]
    for r in keep_ratios
        k = max(1, round(Int, N * r))
        mask = topk_mask(mag, k)
        kept = zero(coef)
        kept[mask] .= coef[mask]
        rec = inverse(kept)
        push!(out, compute_psnr_ssim(img, rec))
    end
    return out
end

function eval_basis(img, basis, keep_ratios)
    coef = forward_transform(basis, img)
    mag = abs.(coef)
    N = length(coef)
    out = Tuple{Float64,Float64}[]
    for r in keep_ratios
        k = max(1, round(Int, N * r))
        mask = topk_mask(mag, k)
        kept = zeros(ComplexF64, Base.size(coef))
        kept[mask] .= coef[mask]
        rec = real.(inverse_transform(basis, kept))
        push!(out, compute_psnr_ssim(img, rec))
    end
    return out
end

function main()
    println("Loading image 0390 ...")
    img = load_image(IMAGE_PATH, 256)
    println("Image shape: $(Base.size(img))")

    println("Loading bases ...")
    qft_basis       = load_basis(joinpath(RESULTS_DIR, "trained_qft.json"))
    eqft_basis      = load_basis(joinpath(RESULTS_DIR, "trained_entangled_qft.json"))
    tebd_basis      = load_basis(joinpath(RESULTS_DIR, "trained_tebd.json"))
    mera_basis      = load_basis(joinpath(RESULTS_DIR, "trained_mera.json"))

    println("Evaluating methods ...")
    results = Dict{String,Vector{Tuple{Float64,Float64}}}()
    results["FFT"]                = eval_classical(img, fft_forward, fft_inverse, KEEP_RATIOS)
    results["DCT (full-image)"]   = eval_classical(img, dct_forward, dct_inverse, KEEP_RATIOS)
    results["BlockDCT (\$8 \\times 8\$)"] = eval_classical(img, block_dct, block_idct, KEEP_RATIOS)
    results["QFT"]                = eval_basis(img, qft_basis, KEEP_RATIOS)
    results["Entangled QFT"]      = eval_basis(img, eqft_basis, KEEP_RATIOS)
    results["TEBD"]               = eval_basis(img, tebd_basis, KEEP_RATIOS)
    results["MERA"]               = eval_basis(img, mera_basis, KEEP_RATIOS)

    row_order = [
        "FFT", "DCT (full-image)", "BlockDCT (\$8 \\times 8\$)",
        "QFT", "Entangled QFT", "TEBD", "MERA",
    ]
    fixed_rows = Set(["FFT", "DCT (full-image)", "BlockDCT (\$8 \\times 8\$)"])

    # find best learned PSNR per keep ratio (learned = not in fixed_rows)
    best_per_col = fill(-Inf, length(KEEP_RATIOS))
    for name in row_order
        name in fixed_rows && continue
        for (j, (p, _)) in enumerate(results[name])
            if p > best_per_col[j]
                best_per_col[j] = p
            end
        end
    end

    mkpath(TABLES_DIR)
    out_path = joinpath(TABLES_DIR, "div2k_0390.tex")
    open(out_path, "w") do io
        println(io, "\\begin{tabular}{lcccc}")
        println(io, "\\toprule")
        println(io, "Method & 5\\% & 10\\% & 15\\% & 20\\% \\\\")
        println(io, "\\midrule")

        last_learned_label = ""
        for (idx, name) in enumerate(row_order)
            # add midrule before first learned row
            if !(name in fixed_rows) && last_learned_label == ""
                println(io, "\\midrule")
                last_learned_label = name
            end
            cells = String[]
            for (j, (p, s)) in enumerate(results[name])
                cell = @sprintf("%.2f / %.3f", p, s)
                if !(name in fixed_rows) && isapprox(p, best_per_col[j]; atol = 0.005)
                    cell = "\\textbf{" * cell * "}"
                end
                push!(cells, cell)
            end
            println(io, "$name & $(join(cells, " & ")) \\\\")
        end

        println(io, "\\bottomrule")
        println(io, "\\end{tabular}")
    end
    println("Wrote $out_path")

    # Also print a readable dump
    println("\nPer-method PSNR (dB) / SSIM on image 0390:")
    @printf("  %-30s %12s %12s %12s %12s\n", "Method", "5%", "10%", "15%", "20%")
    for name in row_order
        row = results[name]
        @printf("  %-30s", name)
        for (p, s) in row
            @printf("  %5.2f/%.3f", p, s)
        end
        println()
    end
end

main()
