#!/usr/bin/env python3
"""Compute the per-ROM experimental VI signature used in N64.sv.

Signature format:
  {5'b0, rom_size_bytes[26:0], fnv1a32(rom byte stream)}
"""

from __future__ import annotations

import argparse
from pathlib import Path

FNV_OFFSET = 0x811C9DC5
FNV_PRIME = 0x01000193


def fnv1a32(data: bytes) -> int:
    h = FNV_OFFSET
    for b in data:
        h ^= b
        h = (h * FNV_PRIME) & 0xFFFFFFFF
    return h


def compute_signature(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    size = len(data) & ((1 << 27) - 1)
    h = fnv1a32(data)
    sig = (size << 32) | h
    return size, h, sig


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Path to ROM file")
    parser.add_argument(
        "--mode",
        default="auto",
        choices=("off", "auto", "bob", "weave"),
        help="Mode value to emit in the N64.sv case line (default: auto).",
    )
    args = parser.parse_args()

    size, h, sig = compute_signature(args.rom)
    mode_map = {
        "off": "2'b00",
        "auto": "2'b01",
        "bob": "2'b10",
        "weave": "2'b11",
    }
    mode_bits = mode_map[args.mode]
    print(f"ROM: {args.rom}")
    print(f"Size (bytes, 27-bit): 0x{size:07X} ({size})")
    print(f"FNV1a32: 0x{h:08X}")
    print(f"Signature (64-bit): 0x{sig:016X}")
    print("Case entry:")
    print(f"64'h{sig:016X}: profile_vi_experimental_mode = {mode_bits};")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
