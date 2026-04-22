#!/usr/bin/env python3
"""Classify each gate in a trained QFT basis and emit a LaTeX summary table.

Reads `ParametricDFT-Benchmarks.jl/results/div2k_8q/trained_qft.json` and writes:
  - `tables/qft_gate_classification.tex`
  - `tables/qft_gate_summary.tex` (compact per-dimension summary)

Classification of each 2x2 gate tensor (magnitudes):
  - H         : all four |e| ~ 1/sqrt(2)         (proper Hadamard / superposition step)
  - Z-like    : |e00|,|e11| ~ 1 ; |e01|,|e10| ~ 0  (near-diagonal, no superposition)
  - X-like    : |e01|,|e10| ~ 1 ; |e00|,|e11| ~ 0  (near-anti-diagonal, bit flip)
  - phase     : all four |e| ~ 1                  (full U(1)^4 diagonal CPHASE)
  - other     : none of the above

The first 2*m Hadamard-role gates in the tensor list are the per-dimension
superposition steps (m per dimension). The remaining m(m-1) gates are the
CPHASE layer. A qubit whose Hadamard has decayed to Z-like or X-like is
effectively a classical block-index bit: the DFT no longer mixes across it,
so the effective transform factors into blocks along that axis.
"""
import json
import math
import cmath
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
# Use the generalized (newer) training run as the canonical trained QFT.
# It yields a symmetric 16x16 block decomposition vs the earlier 16x32.
TRAINED = REPO / "ParametricDFT-Benchmarks.jl" / "results" / "div2k_8q_generalized" / "trained_qft.json"
TABLES = REPO / "tables"
EPS = 0.05

def classify(T):
    m = [abs(e) for e in T]
    def near(x, y):
        return abs(x - y) < EPS
    if all(near(x, 1/math.sqrt(2)) for x in m):
        return "H"
    if near(m[0], 1) and near(m[3], 1) and near(m[1], 0) and near(m[2], 0):
        return "Z-like"
    if near(m[1], 1) and near(m[2], 1) and near(m[0], 0) and near(m[3], 0):
        return "X-like"
    if all(near(x, 1) for x in m):
        return "phase"
    return "other"

def main():
    d = json.loads(TRAINED.read_text())
    m, n = d["m"], d["n"]
    tensors = [[complex(a, b) for a, b in t] for t in d["tensors"]]
    assert len(tensors) == 2 * m + m * (m - 1), \
        f"expected {2*m + m*(m-1)} tensors, got {len(tensors)}"

    # Per-dimension Hadamard-role gates: first m are row, next m are col.
    row_H = [classify(tensors[i]) for i in range(m)]
    col_H = [classify(tensors[m + i]) for i in range(m)]
    # CPHASE gates: remaining m*(m-1) tensors.
    cphase_classes = [classify(tensors[2 * m + i]) for i in range(m * (m - 1))]

    # Per-qubit table (row/col).
    lines = []
    lines.append(r"\begin{tabular}{ccc}")
    lines.append(r"\toprule")
    lines.append(r"Qubit index & Row dim & Column dim \\")
    lines.append(r"\midrule")
    for i in range(m):
        lines.append(f"{i} & {_latex_label(row_H[i])} & {_latex_label(col_H[i])} \\\\")
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    TABLES.mkdir(parents=True, exist_ok=True)
    out1 = TABLES / "qft_gate_classification.tex"
    out1.write_text("\n".join(lines) + "\n")
    print(f"Generated: {out1}")

    # Compact summary: count of mixing vs frozen qubits per dim, plus CPHASE trivial count.
    def summarize(labels):
        mix = sum(1 for l in labels if l == "H")
        frozen = sum(1 for l in labels if l in ("Z-like", "X-like"))
        return mix, frozen
    r_mix, r_frozen = summarize(row_H)
    c_mix, c_frozen = summarize(col_H)
    phase_n = sum(1 for c in cphase_classes if c == "phase")
    phase_trivial = 0
    for i, c in enumerate(cphase_classes):
        if c == "phase":
            phs = [cmath.phase(e) / math.pi for e in tensors[2 * m + i]]
            if all(abs(p) < 0.02 for p in phs):
                phase_trivial += 1

    lines = []
    lines.append(r"\begin{tabular}{lcc}")
    lines.append(r"\toprule")
    lines.append(r" & Row dim & Column dim \\")
    lines.append(r"\midrule")
    lines.append(rf"Mixing Hadamards (H) & {r_mix} & {c_mix} \\")
    lines.append(rf"Frozen gates (Z-/X-like) & {r_frozen} & {c_frozen} \\")
    lines.append(rf"Effective block size (px) & {2**r_frozen * (2 ** (m - r_frozen - r_mix))}\(\,\)$\times\cdot$ "
                 rf"& $\cdot\,\times\,${2**c_frozen * (2 ** (m - c_frozen - c_mix))} \\")
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    # simpler: effective block size = 2^(m - frozen) pixels along that axis, as the
    # frozen qubits index classical blocks.
    # Rebuild lines with the simple formula.
    lines = [
        r"\begin{tabular}{lcc}",
        r"\toprule",
        r" & Row dim & Column dim \\",
        r"\midrule",
        rf"Mixing Hadamards (H) & {r_mix} & {c_mix} \\",
        rf"Frozen gates (Z-/X-like) & {r_frozen} & {c_frozen} \\",
        rf"Effective block side (pixels) & {2**(m - r_frozen)} & {2**(m - c_frozen)} \\",
        rf"Full-\(U(1)^4\) CPHASE gates & \multicolumn{{2}}{{c}}{{{phase_n} of {m*(m-1)}}} \\",
        rf"Near-trivial CPHASE gates & \multicolumn{{2}}{{c}}{{{phase_trivial} of {m*(m-1)}}} \\",
        r"\bottomrule",
        r"\end{tabular}",
    ]
    out2 = TABLES / "qft_gate_summary.tex"
    out2.write_text("\n".join(lines) + "\n")
    print(f"Generated: {out2}")
    print(f"\nSummary: row {r_mix} mixing / {r_frozen} frozen (block side {2**(m-r_frozen)} px); "
          f"col {c_mix} mixing / {c_frozen} frozen (block side {2**(m-c_frozen)} px).")

def _latex_label(k):
    return {
        "H":      r"H",
        "Z-like": r"\textbf{Z-like}",
        "X-like": r"\textbf{X-like}",
        "phase":  r"phase",
        "other":  r"other",
    }.get(k, k)

if __name__ == "__main__":
    main()
