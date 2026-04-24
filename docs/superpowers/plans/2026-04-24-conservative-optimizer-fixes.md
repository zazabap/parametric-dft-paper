# Conservative optimizer fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the per-batch inner optimizer loop with standard SGD + cosine LR schedule + gradient clipping + SWA in ParametricDFT.jl, rerun DIV2K 8-qubit generalized benchmarks with the improved optimizer, update all §5 artefacts in the paper, and file three follow-up GitHub issues against ParametricDFT.jl for the deferred improvements.

**Architecture:** Two-file change in ParametricDFT.jl (`src/optimizers.jl` for gradient clipping, `src/training.jl` for inner-loop removal + cosine LR schedule + SWA) plus a one-file change in ParametricDFT-Benchmarks.jl (`config.jl` preset knobs). No manifold or loss-function changes. After the rerun, the paper's `make` pipeline regenerates most artefacts automatically; a handful of prose sections need manual, targeted edits based on the new numbers.

**Tech Stack:** Julia 1.11, ParametricDFT.jl (library — matrix-manifold optimization + tensor-network contractions), ParametricDFT-Benchmarks.jl (runner), OMEinsum, Zygote, Manopt/Manifolds, CairoMakie, CUDA. Paper uses LaTeX (quantumarticle twocolumn) with Typst diagrams. Git submodules link the two Julia repos into the paper repo.

**Spec:** `docs/superpowers/specs/2026-04-24-conservative-optimizer-fixes-design.md`

---

## File structure

### ParametricDFT.jl (submodule at `ParametricDFT.jl/`)

- **Modify** `src/optimizers.jl` — add `max_grad_norm::Union{Nothing,Float64}` field to `RiemannianGD` and `RiemannianAdam`; add gradient clipping branch to `_optimization_loop`.
- **Modify** `src/training.jl` — add `_cosine_with_warmup` private helper, `_project_to_manifolds` private helper; drop `max_iter = steps_per_image * length(batch)` → `max_iter = 1`; reconstruct optimizer each batch with scheduled `lr`; maintain SWA running average + project at end.
- **Modify** `test/optimizer_tests.jl` — add three testsets for clipping (active/passthrough/backward-compat).
- **Modify** `test/training_tests.jl` — add testsets for cosine schedule, SWA projection, deprecation warning, end-to-end descent.
- Leave untouched: `src/manifolds.jl`, `src/loss.jl`, `src/basis.jl`, `src/qft.jl`, `src/entangled_qft.jl`, `src/tebd.jl`, `src/mera.jl`, `src/serialization.jl`, `src/compression.jl`, `src/visualization.jl`, `src/circuit_visualization.jl`.

### ParametricDFT-Benchmarks.jl (submodule at `ParametricDFT-Benchmarks.jl/`)

- **Modify** `config.jl` — replace `steps_per_image` with `max_grad_norm`, `warmup_frac`, `swa_start_frac`, `lr_peak`, `lr_final` in each `TRAINING_PRESETS` entry.
- Leave untouched: `run_div2k_8q.jl`, `run_quickdraw.jl`, `evaluation.jl`, `data_loading.jl`.

### Paper repo (`/home/claude-user/parametric-dft-paper/`)

- **Modify** `main.tex` §5.3 (bullet numbers), §5.4 (block-size prose), §5.5 (emergence prose), §5.7 (training-dynamics rewrite), App. B (hyperparameter table).
- **Possibly modify** `scripts/diagrams/hadamard_freezing.typ` (violet-border labels may change if frozen-gate count changes).
- Regenerated automatically by `make`: `tables/div2k_0390.tex`, `tables/qft_gate_summary.tex`, all `figures/benchmarks/freqspace/*.pdf`, `figures/benchmarks/mse/*.pdf`, `figures/diagrams/hadamard_freezing.pdf` (via typst recompile).
- Bump submodule pointers: `ParametricDFT.jl` and `ParametricDFT-Benchmarks.jl`.

### GitHub issues (remote)

- Three issues filed against `https://github.com/nzy1997/ParametricDFT.jl` — expm retraction, higher-order parallel transport, soft top-$k$.

---

## Task 1: Add `max_grad_norm` field to `RiemannianGD`

**Files:**
- Modify: `ParametricDFT.jl/src/optimizers.jl:156-164`
- Test: `ParametricDFT.jl/test/optimizer_tests.jl`

- [ ] **Step 1: Write the failing test** — append to `test/optimizer_tests.jl` inside the existing `@testset "Riemannian Optimizers (New API)"`:

```julia
@testset "RiemannianGD max_grad_norm field" begin
    opt_default = RiemannianGD()
    @test opt_default.max_grad_norm === nothing

    opt_clipped = RiemannianGD(max_grad_norm = 2.5)
    @test opt_clipped.max_grad_norm == 2.5
    @test opt_clipped.lr == 0.01
    @test opt_clipped.armijo_c == 1e-4
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ParametricDFT.jl
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["--filter", "RiemannianGD max_grad_norm field"])'
```

Expected: test errors (either `UndefKeywordError: keyword argument max_grad_norm not assigned` or `type RiemannianGD has no field max_grad_norm`).

- [ ] **Step 3: Modify the struct and keyword constructor**

Replace the current block at `src/optimizers.jl:156-164`:

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
```

- [ ] **Step 4: Run the new test — it should pass; run full suite — nothing should regress**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Expected: all tests pass, including the new `RiemannianGD max_grad_norm field` testset.

- [ ] **Step 5: Commit inside the ParametricDFT.jl submodule**

```bash
cd ParametricDFT.jl
git add src/optimizers.jl test/optimizer_tests.jl
git commit -m "optimizers: add max_grad_norm field to RiemannianGD"
```

---

## Task 2: Add `max_grad_norm` field to `RiemannianAdam`

**Files:**
- Modify: `ParametricDFT.jl/src/optimizers.jl:171-179`
- Test: `ParametricDFT.jl/test/optimizer_tests.jl`

- [ ] **Step 1: Write the failing test** — append inside the same testset as Task 1:

```julia
@testset "RiemannianAdam max_grad_norm field" begin
    opt_default = RiemannianAdam()
    @test opt_default.max_grad_norm === nothing

    opt_clipped = RiemannianAdam(max_grad_norm = 1.0)
    @test opt_clipped.max_grad_norm == 1.0
    @test opt_clipped.beta1 == 0.9
    @test opt_clipped.beta2 == 0.999
    @test opt_clipped.eps == 1e-8
end
```

- [ ] **Step 2: Run test — verify it fails**

```bash
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["--filter", "RiemannianAdam max_grad_norm field"])'
```

Expected: fails with missing keyword or missing field.

- [ ] **Step 3: Modify the struct and keyword constructor**

Replace at `src/optimizers.jl:171-179`:

```julia
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

- [ ] **Step 4: Run tests — new test passes, full suite stays green**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/optimizers.jl test/optimizer_tests.jl
git commit -m "optimizers: add max_grad_norm field to RiemannianAdam"
```

---

## Task 3: Apply gradient clipping in `_optimization_loop`

**Files:**
- Modify: `ParametricDFT.jl/src/optimizers.jl` — add `_max_grad_norm` helpers and clipping branch inside `_optimization_loop` (around lines 355-366 where `grad_norm` is computed).
- Test: `ParametricDFT.jl/test/optimizer_tests.jl`

- [ ] **Step 1: Write the failing test** — append to `test/optimizer_tests.jl`:

```julia
@testset "Gradient clipping active path" begin
    # Construct a toy problem with a large gradient, check that optimize!
    # with max_grad_norm caps the effective step by the clip ratio.
    m, n = 2, 2
    Random.seed!(1111)
    pic = rand(ComplexF64, 2^m, 2^n)
    optcode, tensors_raw = ParametricDFT.qft_code(m, n)
    optcode_inv, _ = ParametricDFT.qft_code(m, n; inverse=true)
    tensors = Matrix{ComplexF64}[Matrix{ComplexF64}(t) for t in tensors_raw]
    loss_obj = ParametricDFT.MSELoss(4)
    loss_fn = ts -> ParametricDFT.loss_function(ts, m, n, optcode, pic, loss_obj;
                                                 inverse_code=optcode_inv)
    grad_fn = ts -> begin
        _, back = Zygote.pullback(loss_fn, ts)
        # Scale gradients by 100 so they clearly exceed any normal threshold
        raw = back(1.0)[1]
        [100 .* g for g in raw]
    end

    # Small clip: 0.01; large clip: 100.0 (effectively disabled)
    ts_clipped  = [copy(t) for t in tensors]
    ts_unclipped = [copy(t) for t in tensors]
    opt_clipped   = RiemannianAdam(lr=0.01, max_grad_norm=0.01)
    opt_unclipped = RiemannianAdam(lr=0.01, max_grad_norm=100.0)

    ParametricDFT.optimize!(opt_clipped,   ts_clipped,   loss_fn, grad_fn;
                             max_iter=1, tol=0.0)
    ParametricDFT.optimize!(opt_unclipped, ts_unclipped, loss_fn, grad_fn;
                             max_iter=1, tol=0.0)

    # Clipped step should move the tensors by a much smaller amount
    disp_clipped   = sum(norm(a - b) for (a, b) in zip(ts_clipped,   tensors))
    disp_unclipped = sum(norm(a - b) for (a, b) in zip(ts_unclipped, tensors))
    @test disp_clipped < 0.1 * disp_unclipped
end

@testset "Gradient clipping passthrough" begin
    m, n = 2, 2
    Random.seed!(2222)
    pic = rand(ComplexF64, 2^m, 2^n)
    optcode, tensors_raw = ParametricDFT.qft_code(m, n)
    optcode_inv, _ = ParametricDFT.qft_code(m, n; inverse=true)
    tensors = Matrix{ComplexF64}[Matrix{ComplexF64}(t) for t in tensors_raw]
    loss_obj = ParametricDFT.MSELoss(4)
    loss_fn = ts -> ParametricDFT.loss_function(ts, m, n, optcode, pic, loss_obj;
                                                 inverse_code=optcode_inv)
    grad_fn = ts -> Zygote.pullback(loss_fn, ts)[2](1.0)[1]

    ts_no_clip = [copy(t) for t in tensors]
    ts_hi_clip = [copy(t) for t in tensors]
    ParametricDFT.optimize!(RiemannianAdam(lr=0.001),
                             ts_no_clip, loss_fn, grad_fn; max_iter=1, tol=0.0)
    ParametricDFT.optimize!(RiemannianAdam(lr=0.001, max_grad_norm=1e6),
                             ts_hi_clip, loss_fn, grad_fn; max_iter=1, tol=0.0)
    for (a, b) in zip(ts_no_clip, ts_hi_clip)
        @test isapprox(a, b; atol=1e-12)
    end
end
```

- [ ] **Step 2: Run tests — expect both new ones to fail**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Expected: "Gradient clipping active path" fails (displacement is the same whether clipped or unclipped because clipping is not implemented).

- [ ] **Step 3: Add the clipping branch and dispatch helper**

At the top of `src/optimizers.jl`, just above `_optimization_loop`, add:

```julia
_max_grad_norm(opt::RiemannianGD)   = opt.max_grad_norm
_max_grad_norm(opt::RiemannianAdam) = opt.max_grad_norm
```

Inside `_optimization_loop`, after the existing block (around lines 356-361):

```julia
rg_batches, grad_norm = _batched_project(
    state.manifold_groups, state.point_batches, state.grad_buf_batches, euclidean_grads
)

grad_norm_sq = grad_norm^2
```

insert immediately below (before `if grad_norm < tol`):

```julia
max_norm = _max_grad_norm(opt)
if max_norm !== nothing && grad_norm > max_norm
    clip_factor = max_norm / grad_norm
    for (_, batch) in rg_batches
        batch .*= clip_factor
    end
    grad_norm    = max_norm
    grad_norm_sq = grad_norm^2
end
```

- [ ] **Step 4: Run tests — both new tests and the full suite pass**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/optimizers.jl test/optimizer_tests.jl
git commit -m "optimizers: apply max_grad_norm clipping in _optimization_loop"
```

---

## Task 4: Add `_cosine_with_warmup` private helper

**Files:**
- Modify: `ParametricDFT.jl/src/training.jl` — add private helper near the top of the file, below the existing imports.
- Test: `ParametricDFT.jl/test/training_tests.jl`

- [ ] **Step 1: Write the failing test**

Append to `test/training_tests.jl`:

```julia
@testset "_cosine_with_warmup schedule" begin
    total = 1000
    warmup_frac = 0.1
    lr_peak  = 0.01
    lr_final = 0.001
    f(step) = ParametricDFT._cosine_with_warmup(step, total;
                 warmup_frac=warmup_frac, lr_peak=lr_peak, lr_final=lr_final)

    # Step 0 during warmup → near 0 (at most lr_peak / warmup_steps)
    @test f(0) < lr_peak * 0.01

    # End of warmup (step = warmup_steps = 100) → approximately lr_peak
    @test isapprox(f(100), lr_peak; rtol=1e-10)

    # Last step → approximately lr_final
    @test isapprox(f(total), lr_final; rtol=1e-10)

    # Midway between warmup end and total → between lr_peak and lr_final, strictly
    mid = f(round(Int, (100 + total) / 2))
    @test lr_final < mid < lr_peak
end
```

- [ ] **Step 2: Run — expect UndefVarError**

```bash
cd ParametricDFT.jl
julia --project=. -e 'using Pkg; Pkg.test()'
```

Expected: `UndefVarError: _cosine_with_warmup not defined in ParametricDFT`.

- [ ] **Step 3: Add the helper**

At the top of `src/training.jl`, directly after the `using` statements, add:

```julia
"""
    _cosine_with_warmup(step, total_steps; warmup_frac, lr_peak, lr_final)

Linear warmup followed by cosine decay. `step` is 0-indexed global step;
`warmup_frac ∈ (0, 1)` sets the warmup portion of total steps.
"""
function _cosine_with_warmup(step::Int, total_steps::Int;
                              warmup_frac::Float64 = 0.05,
                              lr_peak::Float64  = 0.01,
                              lr_final::Float64 = 0.001)
    warmup_steps = max(1, round(Int, warmup_frac * total_steps))
    if step <= warmup_steps
        return lr_peak * (step / warmup_steps)
    end
    progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
    return lr_final + 0.5 * (lr_peak - lr_final) * (1 + cos(pi * progress))
end
```

- [ ] **Step 4: Run tests — new one passes**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/training.jl test/training_tests.jl
git commit -m "training: add _cosine_with_warmup LR schedule helper"
```

---

## Task 5: Add `_project_to_manifolds` private helper

**Files:**
- Modify: `ParametricDFT.jl/src/training.jl` — add the helper below `_cosine_with_warmup`.
- Test: `ParametricDFT.jl/test/training_tests.jl`

- [ ] **Step 1: Write the failing test**

Append to `test/training_tests.jl`:

```julia
@testset "_project_to_manifolds preserves unitarity" begin
    # Build a small QFTBasis and take a noisy average of its tensors to
    # simulate an SWA iterate that drifts off-manifold.
    Random.seed!(3333)
    m, n = 2, 2
    optcode, tensors_raw = ParametricDFT.qft_code(m, n)
    tensors = Matrix{ComplexF64}[Matrix{ComplexF64}(t) for t in tensors_raw]

    # Add small perturbations, then average two perturbed copies
    noisy_a = [t .+ 1e-3 .* randn(ComplexF64, size(t)) for t in tensors]
    noisy_b = [t .+ 1e-3 .* randn(ComplexF64, size(t)) for t in tensors]
    avg     = [(a .+ b) ./ 2 for (a, b) in zip(noisy_a, noisy_b)]

    # Identify which tensors are unitary-role for QFTBasis:
    # first 2m (= 4) are Hadamard-role 2x2 unitaries, rest are controlled-phase.
    unitary_indices = 1:(2m)
    phase_indices   = (2m + 1):length(avg)

    projected = ParametricDFT._project_to_manifolds(avg, unitary_indices, phase_indices)

    for i in unitary_indices
        U = projected[i]
        @test size(U) == (2, 2)
        @test isapprox(U * U', I; atol=1e-10)
    end
    for i in phase_indices
        T = projected[i]
        # Controlled-phase: diag(1,1,1,e^{iφ}) — the (4,4) entry should be on
        # the unit circle to 1e-10 after projection.
        @test isapprox(abs(T[4, 4]), 1.0; atol=1e-10)
    end
end
```

- [ ] **Step 2: Run — expect UndefVarError**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Expected: `UndefVarError: _project_to_manifolds not defined`.

- [ ] **Step 3: Add the helper**

Below `_cosine_with_warmup` in `src/training.jl`:

```julia
"""
    _project_to_manifolds(tensors, unitary_indices, phase_indices)

Project a list of tensors back onto their manifolds after averaging, so that
the SWA iterate lies exactly on U(2) × U(1)^4 × ....

- `unitary_indices`: indices of 2×2 tensors whose target manifold is U(2).
  Uses polar decomposition via SVD: `M = U Σ V'` → `U V'` is the nearest
  unitary in Frobenius norm.
- `phase_indices`: indices of 4×4 diagonal controlled-phase tensors. Only
  the (4,4) entry is free; renormalize it to unit modulus.
"""
function _project_to_manifolds(tensors, unitary_indices, phase_indices)
    projected = [copy(T) for T in tensors]
    for i in unitary_indices
        M = projected[i]
        F = svd(M)
        projected[i] = F.U * F.Vt
    end
    for i in phase_indices
        T = projected[i]
        phase = T[4, 4]
        mag   = abs(phase)
        if mag > eps()
            T[4, 4] = phase / mag
        end
        projected[i] = T
    end
    return projected
end
```

If `svd` or `I` are not already imported in `src/training.jl`, add `using LinearAlgebra` near the top.

- [ ] **Step 4: Run tests — new one passes**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/training.jl test/training_tests.jl
git commit -m "training: add _project_to_manifolds helper for SWA retraction"
```

---

## Task 6: Drop per-batch inner loop, integrate cosine LR schedule

**Files:**
- Modify: `ParametricDFT.jl/src/training.jl` — `_train_basis_core` function (around lines 20-180).
- Test: `ParametricDFT.jl/test/training_tests.jl`

- [ ] **Step 1: Add a descent test for the refactored training loop**

Append to `test/training_tests.jl`:

```julia
@testset "train_basis one-step-per-batch descent" begin
    Random.seed!(4444)
    images = [rand(Float64, 4, 4) for _ in 1:8]
    # Use the smallest reasonable preset: m=n=2, 2 epochs, batch_size=4
    basis, losses_train, losses_val = ParametricDFT.train_basis(QFTBasis, images;
        m = 2, n = 2,
        loss = ParametricDFT.MSELoss(4),
        epochs = 2,
        batch_size = 4,
        optimizer = :adam,
        validation_split = 0.25,
        early_stopping_patience = 10,  # disable early stop for this test
        warmup_frac = 0.1,
        lr_peak  = 0.01,
        lr_final = 0.001,
        max_grad_norm = nothing,
        swa_start_frac = 1.0,  # disable SWA — exercised in Task 7
        shuffle = false,
    )
    # Loss should decrease from first to last epoch on average
    @test last(losses_train) <= first(losses_train)
    # Unitarity preserved
    for t in basis.tensors[1:2]
        @test isapprox(t * t', I; atol=1e-8)
    end
end
```

- [ ] **Step 2: Run — expect UndefKeywordError on new kwargs**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 3: Refactor `_train_basis_core`**

Key changes inside `src/training.jl::_train_basis_core`:

1. Extend the keyword signature with the new knobs (add near existing `opt::AbstractRiemannianOptimizer = ...`):

```julia
warmup_frac::Float64    = 0.05,
lr_peak::Float64        = 0.01,
lr_final::Float64       = 0.001,
max_grad_norm::Union{Nothing, Float64} = nothing,
swa_start_frac::Float64 = 0.7,
steps_per_image          = nothing,  # deprecated, no-op
```

2. At the start of `_train_basis_core`, after `n_batches` is computed:

```julia
if steps_per_image !== nothing
    Base.depwarn("`steps_per_image` is ignored; use warmup_frac / lr_peak / lr_final / max_grad_norm / swa_start_frac instead.", :train_basis)
end
total_steps = epochs * n_batches
swa_start   = ceil(Int, swa_start_frac * total_steps)
global_step = 0
swa_accum   = nothing
swa_count   = 0
```

3. Replace the current `batch_max_iter = steps_per_image * length(batch)` block and the following `optimize!` call with:

```julia
global_step += 1
lr_t = _cosine_with_warmup(global_step, total_steps;
                            warmup_frac = warmup_frac,
                            lr_peak  = lr_peak,
                            lr_final = lr_final)
opt_t = RiemannianAdam(lr = lr_t,
                        betas = (0.9, 0.999), eps = 1e-8,
                        max_grad_norm = max_grad_norm)
batch_loss_trace = Float64[]
current_tensors = optimize!(opt_t, current_tensors, batch_loss_fn, batch_grad_fn;
                             max_iter = 1, tol = 0.0,
                             loss_trace = batch_loss_trace)
```

Keep the existing `append!(step_train_losses, batch_loss_trace)` and epoch accounting intact. (SWA plumbing is added in Task 7.)

4. Remove the now-orphaned `steps_per_image` usage in the local `_train_basis_core` scope; leave it in the **outer** `train_basis` signature with `nothing` default.

- [ ] **Step 4: Run tests — the new descent test plus all existing training_tests should pass**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

If preexisting tests fail because they pass `steps_per_image` positionally, update call sites to use it as a keyword argument (no behaviour change, just silences the depwarn).

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/training.jl test/training_tests.jl
git commit -m "training: drop inner loop, integrate cosine LR schedule per batch"
```

---

## Task 7: Wire SWA tracking and final-iterate projection

**Files:**
- Modify: `ParametricDFT.jl/src/training.jl` — add SWA running mean in the batch loop, return projected SWA iterate at the end.
- Test: `ParametricDFT.jl/test/training_tests.jl`

- [ ] **Step 1: Add an end-to-end SWA test**

Append to `test/training_tests.jl`:

```julia
@testset "train_basis SWA returns on-manifold iterate" begin
    Random.seed!(5555)
    images = [rand(Float64, 4, 4) for _ in 1:16]
    basis, _, _ = ParametricDFT.train_basis(QFTBasis, images;
        m = 2, n = 2,
        loss = ParametricDFT.MSELoss(4),
        epochs = 2,
        batch_size = 4,
        optimizer = :adam,
        validation_split = 0.25,
        early_stopping_patience = 10,
        warmup_frac = 0.1,
        lr_peak  = 0.01,
        lr_final = 0.001,
        max_grad_norm = 1.0,
        swa_start_frac = 0.5,   # enable SWA from halfway point
        shuffle = false,
    )
    # Hadamard-role tensors (indices 1:2m = 1:4) must stay unitary
    for t in basis.tensors[1:(2 * 2)]
        @test isapprox(t * t', I; atol=1e-8)
    end
end
```

- [ ] **Step 2: Run — expect unitarity to fail (averaged iterate is off-manifold and not yet projected)**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 3: Implement the SWA tracker and projection**

Inside `_train_basis_core`, after the `optimize!` call (inside the batch loop, in Task 6's block):

```julia
if global_step >= swa_start
    if swa_accum === nothing
        swa_accum = [copy(T) for T in current_tensors]
        swa_count = 1
    else
        for i in eachindex(swa_accum)
            swa_accum[i] .= (swa_accum[i] .* swa_count .+ current_tensors[i]) ./ (swa_count + 1)
        end
        swa_count += 1
    end
end
```

At the very end of `_train_basis_core`, just before returning the basis, add:

```julia
if swa_accum !== nothing && swa_count > 0
    # Partition tensor indices into unitary (Hadamard) vs phase (controlled-phase)
    # roles. The convention in qft_code / entangled_qft_code / tebd_code / mera_code
    # is: first 2m + 2n tensors are U(2) Hadamard-role; rest are 4x4 diagonal
    # U(1)^4 phase tensors.
    n_unitary       = 2 * (m + n) ÷ 2  # i.e. m + n for separable circuits; overridden below
    # Robust fallback: classify by shape
    unitary_indices = [i for (i, T) in enumerate(swa_accum) if size(T) == (2, 2)]
    phase_indices   = [i for (i, T) in enumerate(swa_accum) if size(T) == (4, 4)]
    current_tensors = _project_to_manifolds(swa_accum, unitary_indices, phase_indices)
end
```

The shape-based classification is robust across all basis types (QFT, EntangledQFT, TEBD, MERA), all of which use 2×2 Hadamard-role tensors and 4×4 diagonal phase tensors.

- [ ] **Step 4: Run tests — SWA test passes, suite stays green**

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/training.jl test/training_tests.jl
git commit -m "training: add SWA running mean with manifold projection at end"
```

---

## Task 8: Add deprecation warning for `steps_per_image`

**Files:**
- Modify: `ParametricDFT.jl/src/training.jl` — ensure `train_basis` (the public API) passes `steps_per_image` through and warns once.
- Test: `ParametricDFT.jl/test/training_tests.jl`

- [ ] **Step 1: Write the test**

Append to `test/training_tests.jl`:

```julia
@testset "train_basis deprecation warning for steps_per_image" begin
    Random.seed!(6666)
    images = [rand(Float64, 4, 4) for _ in 1:4]
    @test_logs (:warn, r"steps_per_image") begin
        ParametricDFT.train_basis(QFTBasis, images;
            m = 2, n = 2,
            loss = ParametricDFT.MSELoss(4),
            epochs = 1, batch_size = 4,
            optimizer = :adam,
            validation_split = 0.25,
            early_stopping_patience = 10,
            steps_per_image = 5,     # triggers the depwarn
            warmup_frac = 0.1, lr_peak = 0.01, lr_final = 0.001,
            swa_start_frac = 1.0,
            shuffle = false,
        )
    end
end
```

`Base.depwarn` routes to `:warn` when `--depwarn=yes` is set. Our runtests normally has it on for this package; if not, use `@test_warn` instead of `@test_logs`.

- [ ] **Step 2: Run — expect failure if depwarn was dropped from Task 6's rework, or test log mismatch**

```bash
julia --project=. --depwarn=yes -e 'using Pkg; Pkg.test()'
```

- [ ] **Step 3: Confirm `Base.depwarn("...", :train_basis)` call from Task 6 is still in place**

If it is, the test should now pass. If Task 6 accidentally removed it, re-add the block at the top of `_train_basis_core`:

```julia
if steps_per_image !== nothing
    Base.depwarn("`steps_per_image` is ignored; use warmup_frac / lr_peak / lr_final / max_grad_norm / swa_start_frac instead.", :train_basis)
end
```

- [ ] **Step 4: Run tests**

```bash
julia --project=. --depwarn=yes -e 'using Pkg; Pkg.test()'
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
cd ParametricDFT.jl
git add src/training.jl test/training_tests.jl
git commit -m "training: deprecation warning for steps_per_image kwarg"
```

---

## Task 9: Update `TRAINING_PRESETS` in ParametricDFT-Benchmarks.jl

**Files:**
- Modify: `ParametricDFT-Benchmarks.jl/config.jl:TRAINING_PRESETS` definition (around lines 18-80).

- [ ] **Step 1: Inspect current preset structure**

```bash
cd ParametricDFT-Benchmarks.jl
sed -n '15,90p' config.jl
```

Note the field names currently in each preset. The `generalized` preset is the one that drives the DIV2K 8-qubit rerun.

- [ ] **Step 2: Replace `steps_per_image` with the new knobs in every preset**

For each preset (`smoke`, `light`, `moderate`, `heavy`, `generalized`), remove the `steps_per_image = X,` line and add:

```julia
        max_grad_norm  = 1.0,
        warmup_frac    = 0.05,
        swa_start_frac = 0.70,
        lr_peak        = 0.01,
        lr_final       = 0.001,
```

The `generalized` preset keeps its existing `batch_size = 64`, `epochs = 5`, `optimizer = :adam` fields.

- [ ] **Step 3: Update the runner paths that consume these knobs**

```bash
grep -n "steps_per_image" *.jl
```

In each `run_*.jl` that forwards `steps_per_image` into `ParametricDFT.train_basis`, replace that kwarg with forwarding the new knobs:

```julia
ParametricDFT.train_basis(BasisType, training_images;
    m = m, n = n,
    loss = loss,
    epochs = preset.epochs,
    batch_size = preset.batch_size,
    optimizer = preset.optimizer,
    warmup_frac    = preset.warmup_frac,
    lr_peak        = preset.lr_peak,
    lr_final       = preset.lr_final,
    max_grad_norm  = preset.max_grad_norm,
    swa_start_frac = preset.swa_start_frac,
    # ... existing other kwargs ...
)
```

- [ ] **Step 4: Sanity-check the runner imports the updated preset fields with no error**

```bash
cd ParametricDFT-Benchmarks.jl
julia --project=. -e 'include("config.jl"); @assert haskey(TRAINING_PRESETS[:generalized], :warmup_frac); println("ok")'
```

Expected: `ok`.

- [ ] **Step 5: Commit inside the ParametricDFT-Benchmarks.jl submodule**

```bash
cd ParametricDFT-Benchmarks.jl
git add config.jl run_div2k_8q.jl run_quickdraw.jl run_clic.jl run_div2k.jl run_div2k_7q.jl run_mse.jl 2>/dev/null
git commit -m "config: replace steps_per_image with cosine-schedule + SWA knobs"
```

(`2>/dev/null` because not all files may have changed; git handles missing paths gracefully when mixed with changed ones via `git add`'s error behaviour — verify with `git status` that the right set is staged.)

---

## Task 10: Quick Draw smoke run

**Files:** none — runs and inspects existing scripts.

- [ ] **Step 1: Run the smoke preset**

```bash
cd ParametricDFT-Benchmarks.jl
julia --project=. run_quickdraw.jl smoke 2>&1 | tee /tmp/quickdraw_smoke.log
```

- [ ] **Step 2: Verify no NaN/Inf in the loss trajectory**

```bash
grep -E "NaN|Inf" /tmp/quickdraw_smoke.log || echo "CLEAN"
```

Expected: `CLEAN`.

- [ ] **Step 3: Inspect the generated metrics**

```bash
python3 -c "
import json
d = json.loads(open('ParametricDFT-Benchmarks.jl/results/quickdraw/metrics.json').read())
for k in ['qft', 'entangled_qft', 'tebd', 'mera']:
    if k in d:
        h = d[k]['history']
        steps = h['step_train_losses']
        print(f'{k}: {len(steps)} steps, first={steps[0]:.2f} last={steps[-1]:.2f}')
"
```

Expected: reasonable per-step counts (≪ what `steps_per_image * batch_size` would have produced), first loss > last loss by a clear margin on all four bases.

- [ ] **Step 4: No commit here — this is a verification step only.** If anything looks wrong (NaN, loss not decreasing, runtime errors), stop and investigate before proceeding to the expensive DIV2K rerun.

---

## Task 11: Full DIV2K 8-qubit generalized rerun

**Files:** overwrites `ParametricDFT-Benchmarks.jl/results/div2k_8q_generalized/{metrics.json, trained_*.json, loss_history/, ...}`.

- [ ] **Step 1: Archive the current results for safety**

```bash
cd ParametricDFT-Benchmarks.jl
cp -r results/div2k_8q_generalized results/archive/div2k_8q_generalized_pre_optimizer_fix_$(date +%Y%m%d)
```

- [ ] **Step 2: Kick off the rerun**

The runner for the generalized preset is `run_div2k_8q.jl generalized` (or whichever argument triggers the generalized preset — inspect the script to confirm):

```bash
grep -n "generalized" run_div2k_8q.jl | head
julia --project=. run_div2k_8q.jl generalized 2>&1 | tee /tmp/div2k_generalized_rerun.log
```

If the run takes long, invoke it via `run_in_background=true` and wait; otherwise run in foreground.

- [ ] **Step 3: Validate the new metrics**

```bash
python3 -c "
import json
d = json.loads(open('ParametricDFT-Benchmarks.jl/results/div2k_8q_generalized/metrics.json').read())
for k in ['qft', 'entangled_qft', 'tebd', 'mera']:
    m = d[k]['metrics']
    for ratio in ['0.05', '0.10', '0.15', '0.20']:
        mse  = m[ratio]['mean_mse']
        psnr = m[ratio]['mean_psnr']
        print(f'{k} @{ratio}: PSNR={psnr:.2f} dB, MSE={mse:.5f}')
    print()
"
```

Expected: no NaN, PSNR values in a believable range (20–30 dB), learned bases beat FFT. **If PSNR dropped more than a few dB relative to pre-rerun numbers, pause and investigate the schedule knobs before proceeding.**

- [ ] **Step 4: Commit the new results inside the benchmarks submodule**

```bash
cd ParametricDFT-Benchmarks.jl
git add results/div2k_8q_generalized/
git commit -m "results(div2k_8q_generalized): rerun with improved optimizer"
```

---

## Task 12: Rerun frequency-space analysis on the new bases

**Files:** overwrites `ParametricDFT-Benchmarks.jl/analysis/div2k_8q_generalized/*/summary.txt` and the consolidated `summary_all_images.txt`.

- [ ] **Step 1: Run the analysis script**

```bash
cd ParametricDFT-Benchmarks.jl
julia --project=. analysis/analyze_frequency_space.jl generalized 2>&1 | tail -20
```

- [ ] **Step 2: Inspect 0390 numbers for the new trained QFT**

```bash
grep -E "^MEAN|0390.png" analysis/div2k_8q_generalized/summary_all_images.txt | head
cat analysis/div2k_8q_generalized/0390/summary.txt
```

Record the new FFT / DCT / BDCT / QFT PSNR @ 20% keep on image 0390; these will drive the §5.3 bullet-number edits.

- [ ] **Step 3: Commit the regenerated analysis files**

```bash
cd ParametricDFT-Benchmarks.jl
git add analysis/div2k_8q_generalized/
git commit -m "analysis(div2k_8q_generalized): regenerate freqspace summaries for reruns"
```

---

## Task 13: Regenerate paper tables and benchmark-copied figures via `make`

**Files:** overwrites many files in `figures/benchmarks/` and `tables/` in the paper repo.

- [ ] **Step 1: Run `make benchmarks` first (copies from submodule, regenerates 7-method cumulative-energy + extra-spectra figures)**

```bash
cd /home/claude-user/parametric-dft-paper
make benchmarks 2>&1 | tail -10
```

Expected: `copy_benchmarks.sh` prints "Frequency-space analysis -> …"; `generate_cumulative_energy_0390.jl` and `generate_extra_spectra_0390.jl` both print "Wrote …".

- [ ] **Step 2: Run `make tables` (regenerates `div2k_0390.tex` and `qft_gate_summary.tex`)**

```bash
make tables 2>&1 | tail -15
```

- [ ] **Step 3: Run `make training_plots` (regenerates Figures 8 and 9 with the smooth new curves)**

```bash
make training_plots 2>&1 | tail -5
```

- [ ] **Step 4: Inspect what changed**

```bash
cat tables/div2k_0390.tex
cat tables/qft_gate_summary.tex
```

Record: (a) the row ordering in `div2k_0390.tex`; (b) the `Mixing Hadamards`/`Frozen gates`/`Effective block side` counts in `qft_gate_summary.tex`. These feed the manual prose edits in the next tasks.

- [ ] **Step 5: Build the PDF to check nothing is broken**

```bash
pdflatex main 2>&1 | tail -2
```

Expected: clean build, no missing-figure warnings.

- [ ] **Step 6: No commit yet — we'll commit the full set of paper updates in Task 18.**

---

## Task 14: Update `hadamard_freezing.typ` if frozen-gate counts changed

**Files:**
- Possibly modify: `/home/claude-user/parametric-dft-paper/scripts/diagrams/hadamard_freezing.typ`.

- [ ] **Step 1: Compare old and new counts**

The previous trained basis had: row dim 4 H + 4 Z; column dim 4 H + 3 Z + 1 X. The 4-qubit schematic currently renders "H H Z Z" as the after-training labels (line where `draw_qft4(pb_ox, ..., ("H", "H", "Z", "Z"), "b")`).

If the new `tables/qft_gate_summary.tex` shows different counts, decide: does "half frozen, half H" still match the new pattern?

- **If new pattern is still 4/8 frozen per dim** → no changes needed.
- **If new pattern is 5/8 (e.g.)** → change `draw_qft4(..., ("H", "H", "Z", "Z"), "b")` in `hadamard_freezing.typ` to `("H", "H", "H", "Z")` (2/4 frozen, analog of 4/8) or `("H", "Z", "Z", "Z")` (3/4 frozen, analog of 6/8), whichever matches the new block-side claim.
- **Update the paper caption** — the `\label{fig:hadamard_freezing}` caption in `main.tex` says "half of them (violet border) have collapsed". Change "half" to the actual fraction if needed.

- [ ] **Step 2: If typst source changed, recompile**

```bash
cd /home/claude-user/parametric-dft-paper
typst compile scripts/diagrams/hadamard_freezing.typ figures/diagrams/hadamard_freezing.pdf
```

- [ ] **Step 3: No commit yet.**

---

## Task 15: Update §5.3 block-size bullet numbers and SSIM chain

**Files:**
- Modify: `/home/claude-user/parametric-dft-paper/main.tex` — §5.3 three-bullet list and the SSIM ordering sentence.

- [ ] **Step 1: Compute the new deltas from `tables/div2k_0390.tex`**

From the new table, read FFT / DCT / BDCT / QFT PSNR @ 20% keep on image 0390, and compute:

- `Δ(DCT, FFT)     = DCT_psnr - FFT_psnr`
- `Δ(BDCT, DCT)    = BDCT_psnr - DCT_psnr`
- `Δ(QFT,  DCT)    = QFT_psnr  - DCT_psnr`
- `Δ(BDCT, QFT)    = BDCT_psnr - QFT_psnr`

Same for SSIM at 20%.

- [ ] **Step 2: Edit the three bullets in `main.tex` §5.3**

Locate the `\begin{enumerate}` block starting at around line 423 (search for "Data-adaptive orientation gives"). Replace the three `\item` bullets with the new numbers, keeping the same structure:

```latex
  \item \emph{Data-adaptive orientation gives $+X.Y$~dB.} Full-image DCT (A.BB~dB) beats full-image FFT (C.DD~dB) by $+X.Y$~dB …
  \item \emph{Block structure gives $+X.Y$~dB.} BlockDCT at $8 \times 8$ (A.BB~dB) beats full-image DCT by $+X.Y$~dB …
  \item \emph{Training recovers about Z/W of the block-structure benefit.} The learned QFT (A.BB~dB) beats full-image DCT by $+X.Y$~dB and closes roughly Z/W of the gap to BlockDCT; the remaining $P.Q$~dB is the residual advantage …
```

The "about 2/3" fraction updates to `Δ(QFT, DCT) / Δ(BDCT, DCT)` rounded to the nearest simple fraction.

- [ ] **Step 3: Edit the SSIM chain line**

Locate the sentence `The same ordering holds on SSIM (FFT 0.751 $<$ DCT 0.765 $<$ QFT 0.936 $<$ BDCT 0.952)`. Replace with the new SSIM values.

- [ ] **Step 4: Rebuild, check**

```bash
pdflatex main 2>&1 | tail -2
```

- [ ] **Step 5: No commit yet.**

---

## Task 16: Update §5.4 block-size prose, §5.5 emergence prose, §5.7 training-dynamics prose, Appendix B

**Files:**
- Modify: `/home/claude-user/parametric-dft-paper/main.tex` — four prose regions.

- [ ] **Step 1: §5.4 (around line 442) "coarser, softer tiling" / "16×16-pixel block" prose**

Search for `$2^4 = 16$-pixel block` and `16 \times 16$`. If the new `tab:gate_summary` still shows "Effective block side = 16 pixels", leave unchanged. Otherwise, replace `$2^4 = 16$` with the new exponent/block-side.

Also update the `$32 \times 32 = 1024$ sharp $8 \times 8$ tiles` language if needed (this is about BlockDCT, which does not change).

- [ ] **Step 2: §5.5 emergence prose — frozen-gate count**

Search for `7 of the 16 Hadamard-role gates` and `8 per dimension`. Replace the `7` (total frozen across both dimensions) with the new total from `tab:gate_summary`. Example: if the new counts are "row: 4 H, 4 Z; col: 3 H, 4 Z, 1 X", then total frozen = 4 + 5 = 9 and you would write `9 of the 16 Hadamard-role gates`.

Same treatment for the `2^{m_{\text{free}}} \times 2^{n_{\text{free}}}` expression: confirm the dimension-wise free-qubit counts match the new table.

- [ ] **Step 3: §5.7 training-dynamics rewrite**

Locate the paragraph starting at around line 566 (`\cref{fig:training_curves,fig:step_losses} show the training dynamics of all four topologies`). Rewrite to describe the clean loss curves of the rerun (removing the zigzag / "entangled QFT converges fastest" observations if they no longer hold) and the observations specific to the new optimizer: cosine schedule warmup, SWA tail flattening, TEBD's relative convergence.

New prose template (adjust numbers as needed):

```latex
\cref{fig:training_curves,fig:step_losses} show the training dynamics of the four topologies on DIV2K at 8 qubits.
After a brief linear warmup the cosine learning-rate schedule drives a near-monotone decrease in per-step training loss; the stochastic weight averaging over the final $(1 - s)$ fraction of steps produces the visible flattening at the tail of each curve.
The four topologies converge at comparable rates, with the separable QFT reaching the lowest per-pixel MSE on this image, the Entangled QFT tracking it closely, and TEBD and MERA trailing by $\sim 1$~dB at convergence.
```

- [ ] **Step 4: Appendix B hyperparameter table**

Locate the table starting with `\caption{Hyperparameters used in the benchmark experiments.}` around line 703. Replace the current rows with the new knob set:

```latex
Optimizer              & Riemannian Adam (cosine schedule) \\
Peak learning rate $\eta_\text{peak}$      & 0.01 \\
Final learning rate $\eta_\text{final}$    & 0.001 \\
Warmup fraction        & 0.05 \\
Gradient clip $\|\cdot\|_{\max}$           & 1.0 \\
SWA start fraction     & 0.70 \\
Loss function          & MSE (\cref{eq:mse_loss}) \\
Training keep ratio $k/N$ & 10\% \\
Validation split       & 20\% \\
Early stopping patience & 2 epochs \\
Random seed            & 42 \\
```

Remove the old `Armijo constant`, `Backtracking factor`, `Max backtracking steps`, `Initial learning rate` entries; these only applied to the old GD+Armijo recipe.

- [ ] **Step 5: Rebuild**

```bash
pdflatex main 2>&1 | tail -2 && bibtex main 2>&1 | tail -3 && pdflatex main 2>&1 | tail -2 && pdflatex main 2>&1 | tail -2
```

Expected: clean build, no undefined-reference warnings.

- [ ] **Step 6: No commit yet.**

---

## Task 17: Bump submodule pointers in the paper repo

**Files:**
- `/home/claude-user/parametric-dft-paper/` — the git index entries for `ParametricDFT.jl` and `ParametricDFT-Benchmarks.jl` submodules.

- [ ] **Step 1: Push the library-side commits to the submodule remotes**

```bash
cd /home/claude-user/parametric-dft-paper/ParametricDFT.jl
git log --oneline -10
git push origin HEAD          # push the 8 library commits (Tasks 1-8)

cd ../ParametricDFT-Benchmarks.jl
git log --oneline -10
git push origin HEAD          # push the config + results + analysis commits (Tasks 9, 11, 12)
```

If HEAD is detached (typical when working from the paper-side submodule checkout), `git push origin HEAD:main` or explicitly create and push a branch.

- [ ] **Step 2: Stage submodule pointer updates in the paper repo**

```bash
cd /home/claude-user/parametric-dft-paper
git add ParametricDFT.jl ParametricDFT-Benchmarks.jl
git status | head -20
```

Expected: two submodule entries marked as modified, and various `tables/*.tex`, `figures/benchmarks/**/*.pdf`, `figures/diagrams/hadamard_freezing.pdf`, `main.tex`, and possibly `scripts/diagrams/hadamard_freezing.typ` as modified.

- [ ] **Step 3: No commit yet — we make one commit in the next task.**

---

## Task 18: Commit and push the paper update

**Files:** commits everything from Tasks 13–17 as one paper-repo commit.

- [ ] **Step 1: Stage the paper changes**

```bash
cd /home/claude-user/parametric-dft-paper
git add main.tex \
        tables/div2k_0390.tex tables/qft_gate_summary.tex \
        figures/benchmarks/ figures/diagrams/hadamard_freezing.pdf \
        scripts/diagrams/hadamard_freezing.typ 2>/dev/null
```

(`2>/dev/null` only in case `hadamard_freezing.typ` was not touched in Task 14.)

- [ ] **Step 2: Verify staged set**

```bash
git status
git diff --staged --stat
```

Expected: reasonable list, no stray untracked files staged.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
Rerun DIV2K 8-qubit with improved optimizer

Optimizer changes (submodule bump):
- Drop per-batch inner loop in training.jl (strict one Riemannian-Adam
  step per mini-batch).
- Add cosine learning-rate schedule with linear warmup.
- Add gradient-norm clipping (max_grad_norm field on RiemannianGD /
  RiemannianAdam).
- Add Stochastic Weight Averaging over the final 30% of training,
  with manifold-respecting projection of the averaged iterate.

Paper updates:
- Regenerated Table 2 (div2k_0390.tex) and Table 3 (qft_gate_summary.tex)
  from new metrics.json / trained_*.json.
- Regenerated Figures 5, 8, 9 and all §5.4 / Appendix C freqspace figures.
- Updated §5.3 block-size bullets, §5.5 emergence prose, §5.7 training
  dynamics rewrite, and Appendix B hyperparameter table.

Submodules:
- ParametricDFT.jl: optimizer improvements + tests.
- ParametricDFT-Benchmarks.jl: config preset knobs + rerun results +
  frequency-space analysis artifacts.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Push to remote master**

```bash
git push origin master
```

---

## Task 19: File GitHub issue — expm retraction on U(2)

**Files:** remote issue on `https://github.com/nzy1997/ParametricDFT.jl/issues`.

- [ ] **Step 1: Verify gh CLI access to the ParametricDFT.jl remote**

```bash
cd /home/claude-user/parametric-dft-paper/ParametricDFT.jl
gh repo view 2>&1 | head -5
```

- [ ] **Step 2: File the issue**

```bash
gh issue create \
  --title "Replace Cayley retraction with closed-form expm on U(2)" \
  --label enhancement \
  --body "$(cat <<'EOF'
## Problem

`RiemannianGD` and `RiemannianAdam` both use the Cayley retraction on
`UnitaryManifold{2}`. Cayley is second-order accurate only; for the
step sizes Armijo / Adam accept on `U(2)`, the retracted iterate can
deviate from the intended tangent direction. This is one of the
secondary sources of training-curve noise we observed in the
DIV2K 8-qubit run (see the parametric-dft-paper §5.7 discussion).

## Proposed approach

For `U(2)` we have a closed-form matrix exponential. Given a
skew-Hermitian `W ∈ 𝔲(2)`, decompose `W = i θ n̂·σ` (where `σ` are the
Pauli matrices); then `exp(αW) = cos(αθ) I + i sin(αθ) n̂·σ`.

- Add `retract_exp(U, αξ)` as an alternative retraction method on
  `UnitaryManifold`.
- Make the choice configurable on the manifold (e.g., `UnitaryManifold(2; retraction=:exp)`).
- Keep `retract_cayley` as the default for one release, then switch
  the default after the ablation lands.

## Acceptance

1. Unit test: 10,000 random retractions keep `||U U' − I||_F < 1e-14`.
2. Ablation: rerun DIV2K 8-qubit generalized with `retraction=:exp`.
   Report mean PSNR at 20% keep on image 0390 vs the Cayley baseline.
   PSNR should be stable (within 0.2 dB) or improved.
3. New / updated unit tests in `test/manifold_tests.jl`.

## Context

Deferred from the conservative-optimizer-fix spec
(`parametric-dft-paper/docs/superpowers/specs/2026-04-24-conservative-optimizer-fixes-design.md`).
EOF
)"
```

Record the issue URL printed by gh.

---

## Task 20: File GitHub issue — higher-order parallel transport

- [ ] **Step 1: File the issue**

```bash
cd /home/claude-user/parametric-dft-paper/ParametricDFT.jl
gh issue create \
  --title "Higher-order parallel transport for Riemannian Adam on U(2)" \
  --label enhancement \
  --body "$(cat <<'EOF'
## Problem

`RiemannianAdam` currently uses projection-based parallel transport
(\$U_{t+1} \cdot \text{skew}(U_{t+1}^\dagger m_t)\$) for Adam's first
and second moments. This is first-order accurate only; over many
iterations the transported moments drift away from the true
parallel-transported quantities, biasing the update direction.

This is the secondary compounding cause of the observed zigzag in
parametric-dft-paper §5.7.

## Proposed approach

Two options, roughly in order of implementation effort:

1. Pole-ladder parallel transport (Pennec). Two retractions + one
   tangent flip per step; closed form on `U(2)`.
2. True geodesic parallel transport via the closed-form exponential
   from issue #\[expm-retraction-issue-number\].

Implement as a new method on `UnitaryManifold`
(`parallel_transport_exact(U_old, U_new, tangent)`) and select via
an optimizer field (`RiemannianAdam(; transport=:pole_ladder)`).

## Acceptance

1. Closed-loop transport test: transporting a random tangent vector
   around a closed loop returns to the original within 1e-10.
2. Ablation vs projection-based transport on DIV2K 8-qubit generalized
   — training loss at convergence should be stable or improved.
3. Unit tests for the two directions (`projection` vs `pole_ladder`
   or `exact`) agreeing to first-order accuracy on small tangents.

## Context

Deferred from the conservative-optimizer-fix spec
(`parametric-dft-paper/docs/superpowers/specs/2026-04-24-conservative-optimizer-fixes-design.md`).
Depends on issue #\[expm-retraction-issue-number\] (same closed-form
`exp` machinery).
EOF
)"
```

Record the issue URL. Update the reference in the expm-retraction issue body (`gh issue edit`) to cross-link the two issues.

---

## Task 21: File GitHub issue — soft top-$k$ with temperature annealing

- [ ] **Step 1: File the issue**

```bash
cd /home/claude-user/parametric-dft-paper/ParametricDFT.jl
gh issue create \
  --title "Soft top-k with temperature annealing (differentiable mask)" \
  --label enhancement \
  --body "$(cat <<'EOF'
## Problem

The current `topk_truncate` in `loss.jl` performs hard top-$k$
selection, with gradients passed through by a custom straight-through
`rrule`. This is effective but introduces mask-churn noise between
mini-batches (two images have different top-$k$ supports, and as we
cycle through the batches the loss surface being descended keeps
swapping piecewise branches). This is the root-cause level noise
source observed in parametric-dft-paper §5.7 after the inner-loop,
clipping, schedule, and SWA fixes have already landed.

## Proposed approach

Replace the hard `topk_truncate` with a differentiable relaxation
and a temperature schedule. Two candidate operators:

- **SOFT top-$k$** (Xie & Ermon 2020, \"Differentiable top-$k$
  operator with optimal transport\"): solves an entropy-regularized
  OT problem; smooth in its inputs; recovers hard top-$k$ as $\\tau \\to 0$.
- **Gumbel top-$k$**: samples without replacement using Gumbel noise;
  supports straight-through relaxation (\$\\tau \\to 0\$).

Implementation:
- Add `SoftTopKLoss(k; schedule=CosineAnnealing(\$\\tau_{\\text{start}}\$, \$\\tau_{\\text{end}}\$))`
  as an `AbstractLoss` subtype.
- Pass the current step to the loss-function call so it can look up
  the current $\\tau$.
- At test / evaluation time, always use hard top-$k$ (the temperature
  schedule is a training-time device only).

## Acceptance

1. End-to-end DIV2K 8-qubit generalized run completes without NaN.
2. Final PSNR at 10% and 20% keep matches or beats the hard-top-$k$
   baseline (the post-conservative-fix numbers).
3. Training-curve smoothness (visible in the per-step plot) is
   substantially improved over the hard-top-$k$ baseline.
4. Evaluation still uses hard top-$k$ so reported PSNR is a fair
   comparison with the rest of the pipeline.

## Context

Deferred from the conservative-optimizer-fix spec
(`parametric-dft-paper/docs/superpowers/specs/2026-04-24-conservative-optimizer-fixes-design.md`).
Independent of issues #\[expm-retraction\] and #\[higher-order-transport\].
EOF
)"
```

- [ ] **Step 2: Final check — three issues filed, all cross-linked where appropriate**

```bash
gh issue list --label enhancement | head
```

Expected: the three new issues listed, with the titles matching.

---

## Self-review

**Spec coverage check (from `2026-04-24-conservative-optimizer-fixes-design.md`):**

- Goals:
  - Eliminate per-batch inner optimizer loop → Task 6. ✓
  - Gradient clipping on `RiemannianGD` / `RiemannianAdam` → Tasks 1–3. ✓
  - Cosine LR with linear warmup → Tasks 4, 6. ✓
  - SWA with manifold-respecting projection → Tasks 5, 7. ✓
  - Rerun DIV2K 8-qubit generalized + regenerate §5 artefacts → Tasks 11–18. ✓
  - Three follow-up issues filed → Tasks 19–21. ✓
- Non-goals: no changes to `manifolds.jl` / `loss.jl` / `basis.jl` — confirmed, the plan touches only `optimizers.jl` and `training.jl` in the library. ✓
- Testing strategy lines up (Tasks 1–8 each have TDD steps; Task 10 is the smoke check; Task 11 is the heavyweight run acceptance). ✓
- Paper-update checklist rows each have a corresponding task (Tasks 13–16 for regenerated + prose; Task 14 for the typst-diagram contingency). ✓
- Submodule bump / commit sequencing explicit in Tasks 17–18. ✓

**Placeholder scan:** No "TBD" / "TODO" / "add appropriate error handling" / "similar to Task N" instances. The one `2>/dev/null` in Task 18's `git add` is an intentional idempotent-git pattern, not a placeholder. ✓

**Type consistency:** `max_grad_norm`, `warmup_frac`, `lr_peak`, `lr_final`, `swa_start_frac`, `_cosine_with_warmup`, `_project_to_manifolds` are spelled consistently across Tasks 1–9. Test file is `test/optimizer_tests.jl` (singular — confirmed from `ls` in the planning step). Public API stays `train_basis`. ✓

**Issue cross-linking:** Task 20's body refers to Task 19's issue number via a placeholder-looking `#[expm-retraction-issue-number]`. This is intentional — the issue numbers are assigned by GitHub at creation time, so Task 20 explicitly instructs the engineer to cross-link them post hoc via `gh issue edit`. Same pattern in Task 21. The plan makes this mechanism explicit rather than hiding it behind a placeholder. ✓

No gaps found.

---

Plan complete and saved to `docs/superpowers/plans/2026-04-24-conservative-optimizer-fixes.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
