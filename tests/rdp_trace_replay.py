#!/usr/bin/env python3
"""Parse and validate RDP command traces for shadow-renderer replay work.

Expected command format (current exporter):
  Command: I <global_idx> F <frame_id> C <frame_cmd_idx> A <addr> D <data64> X <running_checksum>

Expected frame summary format:
  Frame:   I <frame_id> C <frame_cmd_count> X <frame_checksum>
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from statistics import mean
from typing import Iterable

COMMAND_RE = re.compile(
    r"^Command:\s+I\s+(\d+)\s+F\s+(\d+)\s+C\s+(\d+)\s+A\s+([0-9A-Fa-f]+)\s+D\s+([0-9A-Fa-f]+)\s+X\s+([0-9A-Fa-f]+)\s*$"
)
FRAME_RE = re.compile(r"^Frame:\s+I\s+(\d+)\s+C\s+(\d+)\s+X\s+([0-9A-Fa-f]+)\s*$")

OPCODE_NAMES = {
    0x00: "nop",
    0x08: "tri_no_shade",
    0x09: "tri_no_shade_z",
    0x0A: "tri_tex",
    0x0B: "tri_tex_z",
    0x0C: "tri_shade",
    0x0D: "tri_shade_z",
    0x0E: "tri_shade_tex",
    0x0F: "tri_shade_tex_z",
    0x24: "texture_rectangle",
    0x25: "texture_rectangle_flip",
    0x26: "sync_load",
    0x27: "sync_pipe",
    0x28: "sync_tile",
    0x29: "sync_full",
    0x2A: "set_key_gb",
    0x2B: "set_key_r",
    0x2C: "set_convert",
    0x2D: "set_scissor",
    0x2E: "set_prim_depth",
    0x2F: "set_other_modes",
    0x30: "load_tlut",
    0x32: "set_tile_size",
    0x33: "load_block",
    0x34: "load_tile",
    0x35: "set_tile",
    0x36: "fill_rectangle",
    0x37: "set_fill_color",
    0x38: "set_fog_color",
    0x39: "set_blend_color",
    0x3A: "set_prim_color",
    0x3B: "set_env_color",
    0x3C: "set_combine_mode",
    0x3D: "set_texture_image",
    0x3E: "set_z_image",
    0x3F: "set_color_image",
}

SUBSETS: dict[str, set[int]] = {
    # Conservative command subset for a fill-only shadow PoC.
    "fill_only": {0x00, 0x26, 0x27, 0x28, 0x29, 0x2D, 0x2F, 0x36, 0x37, 0x3F},
    # Broader prep subset including texture-rectangle/copy style setup commands.
    "fill_copy": {
        0x00,
        0x24,
        0x25,
        0x26,
        0x27,
        0x28,
        0x29,
        0x2D,
        0x2F,
        0x30,
        0x32,
        0x33,
        0x34,
        0x35,
        0x36,
        0x37,
        0x3D,
        0x3F,
    },
}


@dataclass
class FrameState:
    command_count: int = 0
    checksum: int = 0
    summary_count: int | None = None
    summary_checksum: int | None = None


def _opcode_from_command(data64: int) -> int:
    # Matches RTL decode in rtl/RDP_command.vhd: CommandData(61 downto 56)
    return (data64 >> 56) & 0x3F


def _sorted_histogram_items(hist: dict[int, int]) -> list[dict]:
    return [
        {
            "opcode": f"0x{opcode:02X}",
            "name": OPCODE_NAMES.get(opcode, "unknown"),
            "count": count,
        }
        for opcode, count in sorted(hist.items(), key=lambda item: (-item[1], item[0]))
    ]


def _first_n_sorted(values: Iterable[int], limit: int) -> list[int]:
    return sorted(values)[:limit]


def parse_trace(path: Path, dump_frame: int | None = None, subset: str | None = None) -> dict:
    frames: dict[int, FrameState] = {}
    dump_commands: list[tuple[int, int]] = []
    opcode_hist: dict[int, int] = {}
    subset_unsupported_hist: dict[int, int] = {}
    subset_violation_frames: set[int] = set()

    total_commands = 0
    total_frame_summaries = 0
    bad_global_idx = 0
    bad_frame_cmd_idx = 0
    bad_running_checksum = 0
    bad_frame_summary_count = 0
    bad_frame_summary_checksum = 0
    bad_parse_lines = 0
    subset_unsupported_commands = 0

    expected_global_idx = 1
    allowed_opcodes = SUBSETS.get(subset) if subset is not None else None

    with path.open("r", encoding="utf-8", errors="replace") as f:
        for lineno, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line:
                continue

            m_cmd = COMMAND_RE.match(line)
            if m_cmd:
                global_idx = int(m_cmd.group(1))
                frame_id = int(m_cmd.group(2))
                frame_cmd_idx = int(m_cmd.group(3))
                data64 = int(m_cmd.group(5), 16) & 0xFFFFFFFFFFFFFFFF
                running_checksum = int(m_cmd.group(6), 16) & 0xFFFFFFFF

                total_commands += 1
                state = frames.setdefault(frame_id, FrameState())

                if global_idx != expected_global_idx:
                    bad_global_idx += 1
                expected_global_idx = global_idx + 1

                expected_frame_cmd_idx = state.command_count + 1
                if frame_cmd_idx != expected_frame_cmd_idx:
                    bad_frame_cmd_idx += 1

                state.command_count += 1
                state.checksum ^= (data64 & 0xFFFFFFFF) ^ ((data64 >> 32) & 0xFFFFFFFF)
                state.checksum &= 0xFFFFFFFF

                if running_checksum != state.checksum:
                    bad_running_checksum += 1

                opcode = _opcode_from_command(data64)
                opcode_hist[opcode] = opcode_hist.get(opcode, 0) + 1
                if allowed_opcodes is not None and opcode not in allowed_opcodes:
                    subset_unsupported_commands += 1
                    subset_unsupported_hist[opcode] = subset_unsupported_hist.get(opcode, 0) + 1
                    subset_violation_frames.add(frame_id)

                if dump_frame is not None and frame_id == dump_frame:
                    dump_commands.append((frame_cmd_idx, data64))

                continue

            m_frame = FRAME_RE.match(line)
            if m_frame:
                frame_id = int(m_frame.group(1))
                summary_count = int(m_frame.group(2))
                summary_checksum = int(m_frame.group(3), 16) & 0xFFFFFFFF

                total_frame_summaries += 1
                state = frames.setdefault(frame_id, FrameState())
                state.summary_count = summary_count
                state.summary_checksum = summary_checksum

                if summary_count != state.command_count:
                    bad_frame_summary_count += 1
                if summary_checksum != state.checksum:
                    bad_frame_summary_checksum += 1
                continue

            bad_parse_lines += 1
            print(f"[WARN] Unparsed line {lineno}: {line}")

    frame_ids = sorted(frames.keys())
    command_counts = [frames[fid].command_count for fid in frame_ids]
    summary_missing = sum(
        1 for fid in frame_ids if frames[fid].summary_count is None or frames[fid].summary_checksum is None
    )
    subset_frames_clean = 0
    if allowed_opcodes is not None:
        subset_frames_clean = len(frame_ids) - len(subset_violation_frames)

    return {
        "trace_file": str(path),
        "total_commands": total_commands,
        "total_frames_from_commands": len(frame_ids),
        "total_frame_summaries": total_frame_summaries,
        "frame_command_count_min": min(command_counts) if command_counts else 0,
        "frame_command_count_max": max(command_counts) if command_counts else 0,
        "frame_command_count_avg": (mean(command_counts) if command_counts else 0.0),
        "mismatches": {
            "global_index": bad_global_idx,
            "frame_command_index": bad_frame_cmd_idx,
            "running_checksum": bad_running_checksum,
            "frame_summary_count": bad_frame_summary_count,
            "frame_summary_checksum": bad_frame_summary_checksum,
            "missing_frame_summaries": summary_missing,
            "unparsed_lines": bad_parse_lines,
        },
        "opcode_histogram": _sorted_histogram_items(opcode_hist),
        "subset_analysis": (
            {
                "subset": subset,
                "allowed_opcodes": [
                    {
                        "opcode": f"0x{opcode:02X}",
                        "name": OPCODE_NAMES.get(opcode, "unknown"),
                    }
                    for opcode in sorted(allowed_opcodes or [])
                ],
                "unsupported_commands": subset_unsupported_commands,
                "unsupported_histogram": _sorted_histogram_items(subset_unsupported_hist),
                "frames_total": len(frame_ids),
                "frames_clean": subset_frames_clean,
                "frames_with_unsupported": len(subset_violation_frames),
                "sample_frames_with_unsupported": _first_n_sorted(subset_violation_frames, limit=16),
            }
            if allowed_opcodes is not None
            else None
        ),
        "frames": [
            {
                "frame_id": fid,
                "command_count": frames[fid].command_count,
                "checksum": f"0x{frames[fid].checksum:08X}",
                "summary_count": frames[fid].summary_count,
                "summary_checksum": (
                    f"0x{frames[fid].summary_checksum:08X}"
                    if frames[fid].summary_checksum is not None
                    else None
                ),
            }
            for fid in frame_ids
        ],
        "dump_commands": dump_commands,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="Path to rdp_n64_sim.txt trace")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with code 1 if any mismatch/unparsed lines are detected.",
    )
    parser.add_argument(
        "--json-out",
        type=Path,
        help="Optional path to write machine-readable JSON summary.",
    )
    parser.add_argument(
        "--dump-frame",
        type=int,
        default=None,
        help="Optional frame id to dump command words for.",
    )
    parser.add_argument(
        "--subset",
        choices=sorted(SUBSETS.keys()),
        default=None,
        help="Optional command subset profile for PoC coverage analysis.",
    )
    parser.add_argument(
        "--strict-subset",
        action="store_true",
        help="Exit with code 2 if --subset is set and unsupported commands are found.",
    )
    args = parser.parse_args()

    summary = parse_trace(args.trace, dump_frame=args.dump_frame, subset=args.subset)
    mismatches = summary["mismatches"]
    subset_analysis = summary["subset_analysis"]

    print(f"Trace: {summary['trace_file']}")
    print(f"Commands: {summary['total_commands']}")
    print(f"Frames (from commands): {summary['total_frames_from_commands']}")
    print(f"Frame summaries: {summary['total_frame_summaries']}")
    print(
        "Per-frame command count: "
        f"min={summary['frame_command_count_min']} "
        f"max={summary['frame_command_count_max']} "
        f"avg={summary['frame_command_count_avg']:.2f}"
    )
    print("Mismatches:")
    print(f"  global_index: {mismatches['global_index']}")
    print(f"  frame_command_index: {mismatches['frame_command_index']}")
    print(f"  running_checksum: {mismatches['running_checksum']}")
    print(f"  frame_summary_count: {mismatches['frame_summary_count']}")
    print(f"  frame_summary_checksum: {mismatches['frame_summary_checksum']}")
    print(f"  missing_frame_summaries: {mismatches['missing_frame_summaries']}")
    print(f"  unparsed_lines: {mismatches['unparsed_lines']}")

    print(f"Opcodes observed: {len(summary['opcode_histogram'])}")
    for item in summary["opcode_histogram"][:10]:
        print(f"  {item['opcode']} {item['name']}: {item['count']}")

    if subset_analysis is not None:
        print(f"Subset analysis: {subset_analysis['subset']}")
        print(f"  unsupported_commands: {subset_analysis['unsupported_commands']}")
        print(
            "  frames_clean: "
            f"{subset_analysis['frames_clean']}/{subset_analysis['frames_total']}"
        )
        print(f"  frames_with_unsupported: {subset_analysis['frames_with_unsupported']}")
        if subset_analysis["sample_frames_with_unsupported"]:
            print(
                "  sample_frames_with_unsupported: "
                + ", ".join(str(fid) for fid in subset_analysis["sample_frames_with_unsupported"])
            )

    if args.dump_frame is not None:
        dump_commands: list[tuple[int, int]] = summary["dump_commands"]
        print(f"Frame {args.dump_frame} commands: {len(dump_commands)}")
        for idx, cmd in dump_commands:
            print(f"  C {idx:06d} D {cmd:016X}")

    if args.json_out is not None:
        args.json_out.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote JSON summary: {args.json_out}")

    has_mismatch = any(value != 0 for value in mismatches.values())
    if args.strict and has_mismatch:
        return 1
    if args.strict_subset and subset_analysis is not None and subset_analysis["unsupported_commands"] != 0:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
