#!/usr/bin/env julia
# Plot training dynamics figures (training curves + per-step losses) from the
# loss_history JSONs of the generalized DIV2K 8-qubit run. Emits vector PDFs
# under figures/benchmarks/mse/ so main.tex can include them directly.
using JSON3
using CairoMakie

const REPO         = normpath(joinpath(@__DIR__, ".."))
const LOSS_DIR     = joinpath(REPO, "ParametricDFT-Benchmarks.jl", "results", "div2k_8q_generalized", "loss_history")
const OUT_DIR      = joinpath(REPO, "figures", "benchmarks", "mse")
const BASES        = ["qft", "entangled_qft", "tebd", "mera"]
const BASIS_LABELS = Dict("qft"=>"QFT", "entangled_qft"=>"Entangled QFT",
                          "tebd"=>"TEBD", "mera"=>"MERA")
const BASIS_COLORS = Dict("qft"=>:royalblue, "entangled_qft"=>:crimson,
                          "tebd"=>:seagreen, "mera"=>:darkorange)

mkpath(OUT_DIR)

function load_loss(path::String)
    isfile(path) || return nothing
    return JSON3.read(read(path, String))
end

# Training curves: epoch-level train+val loss, log scale.
function plot_training_curves(output::String)
    fig = Figure(size=(720, 420))
    ax = Axis(fig[1,1], xlabel="epoch", ylabel="loss (log)",
              yscale=log10, title="Training convergence (DIV2K 8-qubit, MSE loss)")
    for b in BASES
        path = joinpath(LOSS_DIR, "$(b)_loss.json")
        data = load_loss(path)
        data === nothing && continue
        epochs = [e.epoch for e in data.epoch_losses]
        tr = [e.train_loss for e in data.epoch_losses]
        vl = [e.val_loss   for e in data.epoch_losses]
        c = BASIS_COLORS[b]
        lines!(ax, epochs, tr; color=c, label="$(BASIS_LABELS[b]) train")
        lines!(ax, epochs, vl; color=c, linestyle=:dash, label="$(BASIS_LABELS[b]) val")
    end
    axislegend(ax; position=:rt, nbanks=2, labelsize=10)
    save(output, fig; pt_per_unit=1)
    println("Generated: $output")
end

# Per-step training loss, log scale.
function plot_step_losses(output::String)
    fig = Figure(size=(720, 360))
    ax = Axis(fig[1,1], xlabel="optimizer step", ylabel="loss (log)",
              yscale=log10, title="Per-step training loss (DIV2K 8-qubit, MSE loss)")
    for b in BASES
        path = joinpath(LOSS_DIR, "$(b)_loss.json")
        data = load_loss(path)
        data === nothing && continue
        steps  = [s.step for s in data.step_losses]
        losses = [s.loss for s in data.step_losses]
        lines!(ax, steps, losses; color=BASIS_COLORS[b], label=BASIS_LABELS[b], linewidth=0.8)
    end
    axislegend(ax; position=:rt, labelsize=10)
    save(output, fig; pt_per_unit=1)
    println("Generated: $output")
end

plot_training_curves(joinpath(OUT_DIR, "div2k_training_curves.pdf"))
plot_step_losses(joinpath(OUT_DIR, "div2k_step_losses.pdf"))
