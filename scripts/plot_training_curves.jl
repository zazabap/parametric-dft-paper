#!/usr/bin/env julia
# Plot training dynamics for the DIV2K 8-qubit run from the Python benchmark
# results in `parametric-dft-python/benchmarks/results/`. Each basis stores its
# loss trajectory in `loss_history/<basis>_loss.json` with fields
#   {step_losses (length=steps), val_losses (length=epochs_completed),
#    epochs_completed, steps}
# Per-epoch train loss is reconstructed by averaging step_losses inside each
# epoch (steps/epochs_completed steps per epoch). Emits vector PDFs under
# figures/benchmarks/mse/.

using JSON3
using CairoMakie

const REPO          = normpath(joinpath(@__DIR__, ".."))
const PY_BENCH_ROOT = "/home/claude-user/parametric-dft-python/benchmarks/results"
# Each basis lives in one of two GPU-shard directories from the same run.
const BASIS_SOURCES = Dict(
    "qft"           => "div2k_8q_generalized_20260425-102013_gpu0",
    "mera"          => "div2k_8q_generalized_20260425-102013_gpu0",
    "entangled_qft" => "div2k_8q_generalized_20260425-102013_gpu1",
    "tebd"          => "div2k_8q_generalized_20260425-102013_gpu1",
)
const OUT_DIR = joinpath(REPO, "figures", "benchmarks", "mse")
const BASES   = ["qft", "entangled_qft", "tebd", "mera"]
const BASIS_LABELS = Dict("qft" => "QFT", "entangled_qft" => "Entangled QFT",
                          "tebd" => "TEBD", "mera" => "MERA")
const BASIS_COLORS = Dict(
    "qft"           => RGBf(0.12, 0.47, 0.71),
    "entangled_qft" => RGBf(0.84, 0.15, 0.16),
    "tebd"          => RGBf(0.17, 0.63, 0.17),
    "mera"          => RGBf(0.94, 0.55, 0.13),
)

# DIV2K 8-qubit Python loss is summed-squared error per image (already divided
# by batch size). Divide by pixel count to get per-pixel MSE on the [0,1]
# image — the convention that maps to PSNR via PSNR = -10 log10(MSE).
const PIXELS_PER_IMAGE = 256 * 256

mkpath(OUT_DIR)

function load_history(basis)
    src = BASIS_SOURCES[basis]
    path = joinpath(PY_BENCH_ROOT, src, "loss_history", "$(basis)_loss.json")
    isfile(path) || error("loss_history not found: $path")
    return JSON3.read(read(path, String))
end

# Reconstruct per-epoch train loss by averaging step_losses within each epoch.
function epoch_train_losses(h)
    steps  = Int(h["steps"])
    epochs = Int(h["epochs_completed"])
    spe    = div(steps, epochs)
    sl     = Float64.(collect(h["step_losses"]))
    out    = Vector{Float64}(undef, epochs)
    @inbounds for e in 1:epochs
        lo = (e - 1) * spe + 1
        hi = min(e * spe, length(sl))
        out[e] = sum(@view sl[lo:hi]) / (hi - lo + 1)
    end
    return out
end

function moving_average(xs, w)
    n = length(xs)
    out = similar(xs, Float64)
    half = div(w, 2)
    @inbounds for i in 1:n
        lo = max(1, i - half)
        hi = min(n, i + half)
        out[i] = sum(xs[lo:hi]) / (hi - lo + 1)
    end
    return out
end

function plot_training_curves(output::String)
    fig = Figure(size = (760, 440))
    ax = Axis(fig[1, 1];
        xlabel = "Epoch",
        ylabel = "MSE per pixel",
        yscale = log10,
        title  = "Training convergence (DIV2K 256×256, 8 qubits)")
    for b in BASES
        h  = load_history(b)
        tr = epoch_train_losses(h) ./ PIXELS_PER_IMAGE
        vl = Float64.(collect(h["val_losses"])) ./ PIXELS_PER_IMAGE
        epochs = 1:length(tr)
        c = BASIS_COLORS[b]
        label = BASIS_LABELS[b]
        lines!(ax, epochs, tr; color = c, linewidth = 1.8,
               label = "$(label) (train)")
        scatter!(ax, epochs, tr; color = c, markersize = 7)
        lines!(ax, epochs, vl; color = c, linestyle = :dash, linewidth = 1.8,
               label = "$(label) (val)")
        scatter!(ax, epochs, vl; color = :white, strokecolor = c,
                 strokewidth = 1.5, markersize = 7)
    end
    axislegend(ax; position = :rt, nbanks = 2, labelsize = 9,
               backgroundcolor = (:white, 0.85))
    save(output, fig; pt_per_unit = 1)
    println("Generated: $output")
end

function plot_step_losses(output::String)
    fig = Figure(size = (760, 380))
    ax = Axis(fig[1, 1];
        xlabel = "Optimizer step",
        ylabel = "MSE per pixel",
        yscale = log10,
        title  = "Per-step training loss (DIV2K 256×256, 8 qubits)")
    for b in BASES
        h = load_history(b)
        losses = Float64.(collect(h["step_losses"])) ./ PIXELS_PER_IMAGE
        steps  = 1:length(losses)
        c = BASIS_COLORS[b]
        label = BASIS_LABELS[b]
        lines!(ax, steps, losses;
               color = (c, 0.22), linewidth = 0.5)
        smoothed = moving_average(losses, 21)
        lines!(ax, steps, smoothed;
               color = c, linewidth = 2.0, label = label)
    end
    axislegend(ax; position = :rt, labelsize = 10,
               backgroundcolor = (:white, 0.85))
    save(output, fig; pt_per_unit = 1)
    println("Generated: $output")
end

function main()
    plot_training_curves(joinpath(OUT_DIR, "div2k_training_curves.pdf"))
    plot_step_losses(joinpath(OUT_DIR, "div2k_step_losses.pdf"))
end

main()
