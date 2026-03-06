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
    if args.override_mode is not None:
        print(f"Using override mode: {args.override_mode}")
    print("Case entry:")
    print(f"64'h{sig:016X}: profile_vi_shadow_mode = {mode_bits};")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
