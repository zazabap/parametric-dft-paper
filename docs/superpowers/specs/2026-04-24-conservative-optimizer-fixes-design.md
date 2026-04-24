# Conservative optimizer fixes for ParametricDFT.jl

**Date**: 2026-04-24
**Scope**: Library change + benchmark rerun + paper update (current submission)
**Status**: Design approved, ready for implementation plan

## Context

The DIV2K 8-qubit training curves in the current paper (Figures 8–9 of `main.tex`) show pronounced zigzag in the per-step loss. Diagnosis in conversation identified four contributing mechanisms, in order of impact:

1. **Per-batch inner optimizer loop.** `src/training.jl` hands each mini-batch to `optimize!` with `max_iter = steps_per_image * batch_size`, so the optimizer runs many inner Armijo/Adam steps on the same batch before moving on. The loss drops sharply within a batch as parameters specialise to that batch's top-$k$ mask, then jumps back up on the next batch whose mask is different. This is the dominant cause of the visible zigzag.
2. **Top-$k$ mask churn across batches.** The straight-through estimator assumes the retained set $\mathcal{S}$ is locally stable; this is true within a batch, false between batches.
3. **Armijo + Cayley interaction.** Armijo always restarts from $\alpha_0 = 0.01$, producing bimodal step sizes; Cayley is second-order accurate only.
4. **First-order projection transport in Adam.** Accumulated first-moment drift over many iterations.

This design addresses (1)–(3) with standard machine-learning training hygiene. (4) and the deeper issues are deferred to separate GitHub issues.

## Goals

- Eliminate the per-batch inner optimizer loop; move to one optimizer step per mini-batch (strict SGD).
- Add gradient-norm clipping to `RiemannianGD` and `RiemannianAdam` (backward-compatible, default off).
- Add a cosine learning-rate schedule with linear warmup, driven from `src/training.jl`.
- Add Stochastic Weight Averaging (SWA) across the final fraction of training, with a manifold-respecting projection step at the end.
- Rerun the DIV2K 8-qubit `generalized` benchmark with the new optimizer and regenerate all §5 artefacts in the paper.
- File three GitHub issues in ParametricDFT.jl for the deferred improvements (options B and C from the brainstorming).

## Non-goals

- No changes to `manifolds.jl` (retractions/transport stay as-is).
- No changes to `loss.jl` or the top-$k$ truncation (the straight-through estimator stays).
- No changes to the benchmark datasets, metrics, or evaluation code.
- No new optimizer abstractions (`LRSchedule` type, `AbstractScheduler`, etc.) — the schedule lives as a private helper in `training.jl`. Extraction into a reusable type is deferred to a later PR when a second schedule justifies it.
- No changes to `RiemannianGD` beyond the `max_grad_norm` field (Armijo stays).
- Quick Draw 5-qubit and CLIC 9-qubit runs are not part of this rerun; only DIV2K 8-qubit generalized is regenerated for the paper.

## Architecture

### ParametricDFT.jl — files touched

- `src/optimizers.jl` (~20 lines added)
- `src/training.jl` (~80 lines changed / added)
- `test/optimizers_tests.jl` (~40 lines added)
- `test/training_tests.jl` (~40 lines added)

All other files in ParametricDFT.jl (`manifolds.jl`, `loss.jl`, `basis.jl`, `qft.jl`, `entangled_qft.jl`, `tebd.jl`, `mera.jl`, `serialization.jl`, `compression.jl`, etc.) are untouched.

### ParametricDFT-Benchmarks.jl — files touched

- `config.jl` — replace `steps_per_image` with `max_grad_norm`, `warmup_frac`, `swa_start_frac` in `TRAINING_PRESETS`. The `generalized` preset used by the DIV2K run picks up the new knobs.
- `run_div2k_8q.jl` — no logic changes.

All other files (`evaluation.jl`, `data_loading.jl`, other `run_*.jl` scripts) are untouched. Quick Draw and CLIC runners inherit the new `TRAINING_PRESETS` but are not rerun for this paper.

## Implementation details

### 1. Gradient clipping (optimizers.jl)

Add `max_grad_norm::Union{Nothing, Float64}` field to both structs:

```julia
struct RiemannianGD <: AbstractRiemannianOptimizer
    lr::Float64
    armijo_c::Float64
    armijo_tau::Float64
    max_ls_steps::Int
    max_grad_norm::Union{Nothing, Float64}
end

RiemannianGD(; lr=0.01, armijo_c=1e-4, armijo_tau=0.5,
               max_ls_steps=10, max_grad_norm=nothing) =
    RiemannianGD(lr, armijo_c, armijo_tau, max_ls_steps, max_grad_norm)

struct RiemannianAdam <: AbstractRiemannianOptimizer
    lr::Float64
    beta1::Float64
    beta2::Float64
    eps::Float64
    max_grad_norm::Union{Nothing, Float64}
end

RiemannianAdam(; lr=0.001, betas=(0.9, 0.999), eps=1e-8,
                 max_grad_norm=nothing) =
    RiemannianAdam(lr, betas[1], betas[2], eps, max_grad_norm)
```

In `_optimization_loop`, after `_batched_project` computes `rg_batches, grad_norm`, apply scaling in place when `max_grad_norm` is set:

```julia
max_norm = _max_grad_norm(opt)       # returns the field for either optimizer
if max_norm !== nothing && grad_norm > max_norm
    clip_factor = max_norm / grad_norm
    for (_, batch) in rg_batches
        batch .*= clip_factor
    end
    grad_norm = max_norm
    grad_norm_sq = grad_norm^2
end
```

`_max_grad_norm` is a two-method dispatch helper (one per optimizer struct). Direction is preserved; the magnitude is capped at `max_grad_norm`. The post-clip `grad_norm` is written back because `_update_step!` uses it for Armijo / convergence-check bookkeeping.

### 2. Drop the inner loop (training.jl)

Current (around line 154):

```julia
batch_max_iter = steps_per_image * length(batch)
current_tensors = optimize!(opt, current_tensors, batch_loss_fn, batch_grad_fn;
                             max_iter=batch_max_iter, tol=1e-8,
                             loss_trace=batch_loss_trace)
```

New:

```julia
current_tensors = optimize!(opt, current_tensors, batch_loss_fn, batch_grad_fn;
                             max_iter=1, tol=0.0,
                             loss_trace=batch_loss_trace)
```

The `steps_per_image` kwarg on `train_basis` stays in the signature for one release and is annotated with `Base.depwarn("steps_per_image is ignored …", :train_basis)` when the user passes it. It is removed in the following release. This keeps the public API change non-breaking for one cycle.

### 3. Cosine LR schedule with warmup (training.jl)

New private helper:

```julia
function _cosine_with_warmup(step::Int, total_steps::Int;
                              warmup_frac::Float64 = 0.05,
                              lr_peak::Float64 = 0.01,
                              lr_final::Float64 = 0.001)
    warmup_steps = max(1, round(Int, warmup_frac * total_steps))
    if step <= warmup_steps
        return lr_peak * (step / warmup_steps)
    end
    progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
    return lr_final + 0.5 * (lr_peak - lr_final) * (1 + cos(pi * progress))
end
```

At the start of `train_basis`, compute `total_steps = epochs * n_batches_per_epoch` and thread it through the batch loop along with `warmup_frac`, `lr_peak`, `lr_final`. Inside the batch loop:

```julia
lr_t = _cosine_with_warmup(global_step, total_steps;
                           warmup_frac=warmup_frac,
                           lr_peak=lr_peak, lr_final=lr_final)
opt_t = RiemannianAdam(lr=lr_t, betas=(0.9, 0.999), eps=1e-8,
                       max_grad_norm=max_grad_norm)
```

Reconstructing the optimizer struct each step is cheap (`max_iter=1` means `_optimization_loop` does not persist internal state across `optimize!` calls; each call does its own `_init_optimizer_state`). Adam's first and second moments are **not** carried across batches in this design — which is in line with how per-batch mini-batch SGD/Adam is usually written for Riemannian settings where the iterate has moved and tangent spaces differ, and matches what (a) said about keeping the schedule in `training.jl`. This is a deliberate simplification: preserving full Adam moments across batches would require moment-transport between tangent spaces, which is exactly the issue deferred to follow-up option B.

Note: because moments are not carried, the Adam+warmup schedule here behaves close to momentum-SGD with decaying LR. The practical effect on convergence for the parametric-circuit case is expected to be small given the short 5-epoch training and the magnitude of the other fixes; this will be validated during the smoke run.

### 4. SWA in the final training phase (training.jl)

At the start of training:

```julia
swa_start = ceil(Int, swa_start_frac * total_steps)   # e.g. step 0.7 * total
swa_accum = nothing   # Vector{Matrix{ComplexF64}} once initialized
swa_count = 0
```

After each batch update, if `global_step >= swa_start`:

```julia
if swa_accum === nothing
    swa_accum = [copy(T) for T in current_tensors]
    swa_count = 1
else
    for i in eachindex(swa_accum)
        swa_accum[i] .= (swa_accum[i] * swa_count .+ current_tensors[i]) ./ (swa_count + 1)
    end
    swa_count += 1
end
```

At the end of training, project the SWA average back onto the manifolds before returning:

```julia
function _project_to_manifolds(tensors, basis_type)
    # For each 2x2 unitary-role tensor: polar decomposition SVD-based
    #   M = U * Σ * V';  projection = U * V'
    # For each phase-role tensor (diag(1,1,1,e^{iφ})): renormalize the
    #   (4,4) entry to unit modulus.
    ...
end
```

The basis type (QFT / EntangledQFT / TEBD / MERA) determines which tensors are unitary-role and which are phase-role; this metadata is available via the existing `basis_to_json` plumbing.

If `swa_start_frac >= 1.0` the SWA code path is skipped entirely (no averaging, return final iterate).

### 5. TRAINING_PRESETS knobs (config.jl)

Replace the `steps_per_image` field with three new fields in each preset. For the `generalized` preset (used by DIV2K 8-qubit generalized rerun):

```julia
generalized = (
    # ... existing fields ...
    batch_size     = 64,
    epochs         = 5,
    optimizer      = :adam,
    max_grad_norm  = 1.0,
    warmup_frac    = 0.05,
    swa_start_frac = 0.70,
    lr_peak        = 0.01,
    lr_final       = 0.001,
)
```

Defaults for other presets (smoke, light, moderate, heavy) can be the same; these are not exercised by the paper rerun but should not break.

## Testing strategy

### ParametricDFT.jl unit tests

`test/optimizers_tests.jl` additions:
- Gradient clipping active path: construct synthetic `rg_batches` with controlled norm > `max_grad_norm`, assert post-clip `grad_norm ≈ max_grad_norm` and direction preserved (cosine similarity = 1 ± 1e-12).
- Gradient clipping passthrough: with norm < `max_grad_norm`, assert gradients unchanged (exact equality).
- Backward compatibility: constructing `RiemannianAdam()` without `max_grad_norm` keyword yields `max_grad_norm = nothing` and never clips.

`test/training_tests.jl` additions:
- `_cosine_with_warmup` boundary values: step 0 returns 0, step = warmup_steps returns `lr_peak` ± floating-point eps, last step returns `lr_final` ± floating-point eps.
- SWA projection preserves unitarity: average five slightly-perturbed unitaries, project, assert `UU' ≈ I` to tolerance 1e-10.
- Deprecation warning: calling `train_basis(; steps_per_image=5)` logs a depwarn once.
- End-to-end: training with a tiny synthetic dataset (2×2 images) for 3 epochs runs to completion, loss decreases monotonically on average (epoch-level), final basis is unitary.

All existing tests must keep passing.

### ParametricDFT-Benchmarks.jl smoke check

Before the full DIV2K rerun:
- Run Quick Draw 5-qubit at `smoke` preset (minutes on CPU). Verify: no NaN/Inf, `metrics.json` has the expected shape, loss trajectory shows no zigzag at the mini-batch scale.

### Full DIV2K rerun acceptance criteria

- 5 epochs × 800 images × 64 batch size runs to completion without NaN.
- `metrics.json` contains all four bases (qft, entangled_qft, tebd, mera) with the expected `train_losses`, `val_losses`, `step_train_losses` keys.
- Per-pixel MSE at end of training in the 0.003–0.008 range (PSNR 21–25 dB at 10% training keep); if outside this envelope, pause and investigate before updating the paper.
- Qualitative visual check of the new training-curve figure: no zigzag in the smoothed per-step curve.

## Paper update checklist (post-rerun)

Running `make` from the paper root regenerates most artefacts. Manual checks per file:

| Artefact | Generator | Action |
|---|---|---|
| `ParametricDFT-Benchmarks.jl/results/div2k_8q_generalized/metrics.json` | rerun | Overwritten by rerun |
| `ParametricDFT-Benchmarks.jl/results/div2k_8q_generalized/trained_*.json` | rerun | Overwritten by rerun |
| `ParametricDFT-Benchmarks.jl/analysis/div2k_8q_generalized/` | `analyze_frequency_space.jl` | Rerun with new bases |
| `tables/div2k_0390.tex` | `scripts/generate_table_0390.jl` | `make tables` auto |
| `tables/qft_gate_summary.tex` | `scripts/analyze_trained_qft.py` | `make tables` auto; **check frozen-gate count** — may change |
| `figures/benchmarks/freqspace/*.pdf` | `scripts/copy_benchmarks.sh` + cumulative + extra-spectra | `make benchmarks` auto |
| `figures/diagrams/hadamard_freezing.pdf` | typst `scripts/diagrams/hadamard_freezing.typ` | **Manual** — the 4-qubit schematic's "Z/Z/Z/Z" labels may need to become "Z/Z/Z/H" etc. if the new frozen count per dimension changes |
| `figures/benchmarks/mse/*.pdf` | `scripts/plot_training_curves.jl` | `make training_plots` auto |
| `main.tex` §5.2 | — | Update "QFT slightly ahead / MERA trailing" prose if ordering changes |
| `main.tex` §5.3 bullet numbers (+1.4 / +4.1 / +2.6 / +1.5 dB; SSIM chain) | — | Recompute from new Table 2, sed-edit |
| `main.tex` §5.4 prose (block-size = 16 explanation) | — | Keep if frozen count is still 4/8; update if not |
| `main.tex` §5.5 emergence prose (7/16 frozen, $m_\text{free}$ count) | — | Recompute from new `tab:gate_summary` |
| `main.tex` §5.7 training-dynamics prose (zigzag description, TEBD val < train observation) | — | **Rewrite** to describe the clean loss curves the new optimizer produces |
| `main.tex` Appendix B hyperparameter table | — | Update knob names: remove `steps_per_image`, add `max_grad_norm`, `warmup_frac`, `swa_start_frac`, `lr_peak`, `lr_final` |

No citation additions needed (`kingma2015adam`, `becigneul2019riemannian`, `bengio2013estimating` are already cited).

## Issues to file in ParametricDFT.jl

Three separate GitHub issues, each titled, labelled `enhancement`, with a clear problem statement, proposed approach, and acceptance criteria. Draft bodies:

**Issue 1: Replace Cayley retraction with closed-form expm on U(2)**
> Cayley retraction is second-order accurate; for typical step sizes accepted by Armijo on $U(2)$ the retracted iterate can deviate from the intended tangent direction. For $2\times 2$ we have a closed-form matrix exponential via the Rodrigues-like formula $\exp(\theta A) = \cos\theta I + \sin\theta A$ where $A \in \mathfrak{u}(2)$ is normalised. Implement `retract_exp(U, αξ)` on `UnitaryManifold`, keep `retract_cayley` as the current method, make the choice a field on `UnitaryManifold`. Acceptance: unitarity within 1e-14 after 10,000 retraction steps on random tangent vectors; ablation run on DIV2K generalized showing PSNR stable or improved.

**Issue 2: Higher-order parallel transport for Riemannian Adam on U(2)**
> Projection-based parallel transport is first-order accurate. For Adam, first-moment estimates accumulate transport error over many iterations, biasing the update direction. Implement pole-ladder (Pennec) or true geodesic parallel transport on $U(2)$ (closed form via the same Rodrigues-like construction as issue 1). Acceptance: transport test — transporting a random tangent along a closed loop returns to the original within 1e-10; ablation against current projection-based transport on DIV2K generalized.

**Issue 3: Soft top-$k$ with temperature annealing**
> The hard top-$k$ + straight-through estimator introduces mask-churn noise across mini-batches. A differentiable relaxation (e.g., SOFT operator of Xie & Ermon 2020, or Gumbel-top-$k$) with a temperature $\tau \to 0$ schedule gives a fully differentiable loss surface during training while converging to hard top-$k$ at the end. Acceptance: end-to-end DIV2K generalized run matches or beats the hard-top-$k$ baseline at 10%/20% keep on both training and test splits, with substantially smoother training curves. Validated at test time with hard top-$k$ (i.e., the temperature schedule is purely a training-time device).

## Implementation sequencing

1. Library changes (ParametricDFT.jl): optimizers.jl grad-clip, training.jl inner-loop / cosine / SWA, tests, CI green.
2. Runner changes (ParametricDFT-Benchmarks.jl): config.jl preset update.
3. Quick-Draw smoke run for sanity.
4. Full DIV2K 8-qubit generalized rerun.
5. Paper artefact regeneration via `make`, manual prose updates per the checklist.
6. File the three GitHub issues against ParametricDFT.jl repo.
7. Commit everything in the paper repo (library submodule bump + paper edits) as a single "Rerun DIV2K with improved optimizer" commit.

## Open risks

- **Training may plateau at a different PSNR.** The current zigzag hides the optimizer's true convergence rate; with one-step-per-batch + cosine schedule + SWA, final PSNR could be either higher or lower than the current 29.71 dB at 20% keep on image 0390. If lower, we need to either re-tune `lr_peak`/`lr_final` or decide whether the story of the paper still holds at the new numbers.
- **Frozen-gate count may change.** With a different optimizer trajectory, the number of Hadamard-role gates that collapse to $Z$/$X$ may differ from the current 4-per-dimension. The §5.5 "effective block side $2^4 = 16$" claim may become $2^3 = 8$ or $2^5 = 32$. Section prose and `hadamard_freezing.typ` labels will need targeted edits accordingly.
- **Moment-free Adam is weaker than full Adam.** Not carrying Adam moments across batches (see §4.3 above) is a deliberate simplification. If training suffers visibly, the fallback is to keep moments and transport them with current (first-order) projection — which reintroduces one of the zigzag sources but in a much smaller dose than the inner-loop removal eliminated.
- **SWA-project interaction with basis serialization.** The projected SWA tensors must still satisfy the `basis_hash` self-consistency check in `serialization.jl`; test this explicitly.
