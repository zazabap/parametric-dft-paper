#!/usr/bin/env python3
"""Plot a histogram of empirical AR(1) lag-1 autocorrelation across the
test slices of both datasets used in the experiments (DIV2K natural
images and Quick Draw line drawings).

Output: figures/benchmarks/ar1_histogram.pdf
"""
from __future__ import annotations

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "pdft-benchmarks" / "src"))

from pdft_benchmarks.datasets import load_div2k, load_quickdraw


def empirical_rho(img: np.ndarray) -> float:
    """Lag-1 autocorrelation averaged over row and column directions."""
    p = img.astype(np.float64)
    p = p - p.mean()
    var = float(np.mean(p * p)) + 1e-12
    rho_row = float(np.mean(p[:, :-1] * p[:, 1:])) / var
    rho_col = float(np.mean(p[:-1, :] * p[1:, :])) / var
    return 0.5 * (rho_row + rho_col)


def main() -> None:
    n_train, n_test, seed = 500, 50, 42

    div2k_train, _ = load_div2k(n_train, n_test, seed=seed, size=256)
    qd_train, _ = load_quickdraw(n_train, n_test, seed=seed, img_size=32)

    div2k_rho = np.array([empirical_rho(x) for x in div2k_train])
    qd_rho = np.array([empirical_rho(x) for x in qd_train])

    fig, ax = plt.subplots(figsize=(5.0, 2.6))
    bins = np.linspace(0.4, 1.0, 25)

    ax.hist(qd_rho, bins=bins, alpha=0.65, color="#d95f02",
            label=f"Quick Draw  ($n={len(qd_rho)}$)", edgecolor="white", linewidth=0.4)
    ax.hist(div2k_rho, bins=bins, alpha=0.65, color="#1b9e77",
            label=f"DIV2K  ($n={len(div2k_rho)}$)", edgecolor="white", linewidth=0.4)

    ax.set_xlabel(r"empirical lag-1 autocorrelation $\hat{\rho}_{\mathrm{AR}}$")
    ax.set_ylabel("number of test images")
    ax.set_xlim(0.4, 1.0)
    ax.legend(loc="upper left", frameon=False, fontsize=9)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    out = REPO / "figures" / "benchmarks" / "ar1_histogram.pdf"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out)
    print(f"wrote {out}")
    print(f"DIV2K  ({len(div2k_rho)} train) rho: mean={div2k_rho.mean():.3f}, range=[{div2k_rho.min():.3f}, {div2k_rho.max():.3f}]")
    print(f"QuickDr ({len(qd_rho)} train) rho: mean={qd_rho.mean():.3f}, range=[{qd_rho.min():.3f}, {qd_rho.max():.3f}]")


if __name__ == "__main__":
    main()
