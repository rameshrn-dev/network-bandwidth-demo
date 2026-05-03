#!/usr/bin/env python3
"""
plot_results.py — Generate a throughput chart from the demo CSV.

Usage:
    python3 scripts/plot_results.py results/stream_throughput.csv [output.png]
"""

import csv
import sys
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
except ImportError:
    print("matplotlib not found. Install with: pip install matplotlib")
    sys.exit(1)

PHASE_LABELS = {
    1:  "P1\nBaseline\n50 Mbps",
    2:  "P2\n+SCP×1\n50 Mbps",
    3:  "P3\n+SCP×2\n50 Mbps",
    4:  "P4\n+SCP×3\n50 Mbps",
    5:  "P5\n−SCP×1\n50 Mbps",
    6:  "P6\n−SCP×2\n50 Mbps",
    7:  "P7\nRecovered\n50 Mbps",
    8:  "P8\nStream only\n20 Mbps",
    9:  "P9\n+SCP×1\n20 Mbps",
    10: "P10\n+SCP×2\n20 Mbps",
    11: "P11\nRecovered\n20 Mbps",
    12: "P12\nRestored\n50 Mbps",
}

PHASE_COLORS = [
    "#d4e6f1", "#aed6f1", "#85c1e9", "#5dade2",  # phases 1-4 (50 Mbps, adding)
    "#a9dfbf", "#7dcea0", "#52be80",              # phases 5-7 (50 Mbps, removing)
    "#fdebd0", "#fad7a0", "#f8c471",              # phases 8-10 (20 Mbps)
    "#a9cce3", "#d5d8dc",                         # phases 11-12 (recovery)
]


def main():
    csv_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("results/stream_throughput.csv")
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else csv_path.with_name("throughput_chart.png")

    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    "ts": row["timestamp"],
                    "phase": int(row["phase"]),
                    "mbps": float(row["mbps"]),
                })
            except (ValueError, KeyError):
                continue

    if not rows:
        print("No data rows found in CSV.")
        sys.exit(1)

    times = list(range(len(rows)))
    mbps = [r["mbps"] for r in rows]
    phases = [r["phase"] for r in rows]

    fig, (ax_main, ax_bar) = plt.subplots(
        2, 1, figsize=(16, 8),
        gridspec_kw={"height_ratios": [3, 1]},
    )
    fig.suptitle("Streaming Throughput Under Competing SCP Traffic", fontsize=14, fontweight="bold")

    # ── main throughput line ────────────────────────────────────────────────────
    ax_main.plot(times, mbps, linewidth=1.5, color="#2c7bb6", label="Stream throughput (Mbps)")
    ax_main.axhline(50, linestyle="--", linewidth=0.8, color="gray", alpha=0.6, label="50 Mbps cap")
    ax_main.axhline(20, linestyle=":",  linewidth=0.8, color="gray", alpha=0.6, label="20 Mbps cap")
    ax_main.set_ylabel("Throughput (Mbps)", fontsize=11)
    ax_main.set_ylim(bottom=0)
    ax_main.grid(axis="y", linestyle="--", alpha=0.4)
    ax_main.legend(loc="upper right", fontsize=9)

    # shade each phase with a distinct colour and label it
    prev_idx, prev_phase = 0, phases[0]
    for i, p in enumerate(phases + [None]):  # sentinel triggers final flush
        if p != prev_phase:
            color = PHASE_COLORS[(prev_phase - 1) % len(PHASE_COLORS)]
            ax_main.axvspan(prev_idx, i, alpha=0.35, color=color, linewidth=0)
            mid = (prev_idx + i) // 2
            ymax = ax_main.get_ylim()[1]
            ax_main.text(mid, ymax * 0.96, PHASE_LABELS.get(prev_phase, f"P{prev_phase}"),
                         ha="center", va="top", fontsize=6.5, multialignment="center")
            prev_idx, prev_phase = i, p

    ax_main.set_xlim(0, len(times))

    # ── phase bar (bottom strip) ────────────────────────────────────────────────
    ax_bar.set_xlim(0, len(times))
    ax_bar.set_ylim(0, 1)
    ax_bar.set_yticks([])
    ax_bar.set_xlabel("Sample number (1 sample ≈ 2 seconds)", fontsize=10)

    prev_idx, prev_phase = 0, phases[0]
    for i, p in enumerate(phases + [None]):
        if p != prev_phase:
            color = PHASE_COLORS[(prev_phase - 1) % len(PHASE_COLORS)]
            ax_bar.barh(0.5, i - prev_idx, left=prev_idx, height=1,
                        color=color, edgecolor="white", linewidth=0.5)
            mid = (prev_idx + i) // 2
            ax_bar.text(mid, 0.5, f"P{prev_phase}", ha="center", va="center",
                        fontsize=7, fontweight="bold")
            prev_idx, prev_phase = i, p

    # ── per-phase average table ─────────────────────────────────────────────────
    phase_stats: dict[int, list[float]] = {}
    for r in rows:
        phase_stats.setdefault(r["phase"], []).append(r["mbps"])

    print("\nPhase summary:")
    print(f"{'Phase':<7} {'Label':<30} {'Avg Mbps':>10} {'Min':>8} {'Max':>8} {'Samples':>8}")
    print("-" * 75)
    for ph in sorted(phase_stats):
        vals = phase_stats[ph]
        label = PHASE_LABELS.get(ph, f"Phase {ph}").replace("\n", " ")
        print(f"{ph:<7} {label:<30} {sum(vals)/len(vals):>10.2f} "
              f"{min(vals):>8.2f} {max(vals):>8.2f} {len(vals):>8}")

    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"\nChart saved to: {out_path}")


if __name__ == "__main__":
    main()
