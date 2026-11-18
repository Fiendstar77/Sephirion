"""Optional report rendering only; all simulation and checks run in Common Lisp.

Requires matplotlib. Run from any working directory.
"""
import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

directory = Path(__file__).resolve().parents[1] / "reports" / "experiment-0001"
with (directory / "sweep.csv").open() as stream:
    rows = [{key: float(value) for key, value in row.items()}
            for row in csv.DictReader(stream)]

omega = [row["omega"] for row in rows]
fig, axes = plt.subplots(3, 1, figsize=(9, 10), sharex=True)
for index, color in [(1, "#245fbd"), (2, "#bd5424")]:
    label = f"Resonator {index}"
    axes[0].plot(omega, [r[f"analytical_amplitude{index}"] for r in rows],
                 color=color, label=f"{label}: analytical")
    axes[0].plot(omega, [r[f"amplitude{index}"] for r in rows], ".",
                 color=color, label=f"{label}: RK4")
    axes[1].plot(omega, [r[f"analytical_phase{index}"] for r in rows], color=color)
    axes[1].plot(omega, [r[f"phase{index}"] for r in rows], ".", color=color)
    axes[2].semilogy(omega, [r[f"complex_error{index}"] for r in rows],
                     color=color, label=label)

axes[0].set_ylabel("Volume-displacement amplitude\n(normalized)")
axes[0].legend(fontsize=9)
axes[1].set_ylabel("Phase relative to drive (rad)")
axes[2].set_ylabel("Absolute complex-response error")
axes[2].set_xlabel("Drive angular frequency (inverse reference time)")
axes[2].legend()
for axis in axes:
    axis.grid(alpha=0.25)
fig.suptitle("SEPHIRION · Experiment 0001\nCoupled damped acoustic analogue; normalized coefficients")
fig.tight_layout()
fig.savefig(directory / "response.png", dpi=160)
plt.close(fig)
