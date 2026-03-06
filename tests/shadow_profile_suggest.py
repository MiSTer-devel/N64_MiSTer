#!/usr/bin/env python3
"""Suggest a per-ROM shadow profile entry from ROM + RDP trace inputs."""

from __future__ import annotations

import argparse
from pathlib import Path

from rdp_trace_replay import parse_trace
from rom_signature import compute_signature


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Path to ROM file")
    parser.add_argument("trace", type=Path, help="Path to rdp_n64_sim.txt trace")
    parser.add_argument(
        "--override-mode",
        default=None,
        choices=("2'b00", "2'b01", "2'b10"),
        help="Optional manual mode override (default: use trace recommendation).",
    )
    args = parser.parse_args()

    size, h, sig = compute_signature(args.rom)
    trace_summary = parse_trace(args.trace)
    recommendation = trace_summary["recommended_shadow_mode"]
    mode_bits = args.override_mode or recommendation["mode_bits"]

    print(f"ROM: {args.rom}")
    print(f"Trace: {args.trace}")
    print(f"Size (bytes, 27-bit): 0x{size:07X} ({size})")
    print(f"FNV1a32: 0x{h:08X}")
    print(f"Signature (64-bit): 0x{sig:016X}")
    print(
        "Recommended shadow mode from trace: "
        f"{recommendation['mode_name']} ({recommendation['mode_bits']})"
    )
    print(f"Reason: {recommendation['reason']}")
    print(
        "Fill-rectangle commands: "
        f"{trace_summary['fillrect_commands']} across "
        f"{trace_summary['frames_with_fillrect']} frames"
    )
    print(
        "Shadow-usable fill commands (post-scissor): "
        f"{trace_summary['fillrect_shadow_commands']} across "
        f"{trace_summary['frames_with_shadow_fillrect']} frames "
        f"(clipped_out={trace_summary['fillrect_shadow_clipped_out_commands']})"
    )
    bounds_raw = trace_summary["fillrect_bounds_px_raw"]
    if bounds_raw is not None:
        print(
            "Aggregate fill bounds raw (VI pixels): "
            f"x={bounds_raw['x0']}..{bounds_raw['x1']} y={bounds_raw['y0']}..{bounds_raw['y1']}"
        )
    bounds = trace_summary["fillrect_bounds_px"]
    if bounds is not None:
        print(
            "Aggregate fill bounds post-scissor (VI pixels): "
            f"x={bounds['x0']}..{bounds['x1']} y={bounds['y0']}..{bounds['y1']}"
        )
    if args.override_mode is not None:
        print(f"Using override mode: {args.override_mode}")
    print("Case entry:")
    print(f"64'h{sig:016X}: profile_vi_shadow_mode = {mode_bits};")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
