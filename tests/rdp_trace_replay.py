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

COMMAND_RE = re.compile(
    r"^Command:\s+I\s+(\d+)\s+F\s+(\d+)\s+C\s+(\d+)\s+A\s+([0-9A-Fa-f]+)\s+D\s+([0-9A-Fa-f]+)\s+X\s+([0-9A-Fa-f]+)\s*$"
)
FRAME_RE = re.compile(r"^Frame:\s+I\s+(\d+)\s+C\s+(\d+)\s+X\s+([0-9A-Fa-f]+)\s*$")


@dataclass
class FrameState:
    command_count: int = 0
    checksum: int = 0
    summary_count: int | None = None
    summary_checksum: int | None = None


def parse_trace(path: Path, dump_frame: int | None = None) -> dict:
    frames: dict[int, FrameState] = {}
    dump_commands: list[tuple[int, int]] = []

    total_commands = 0
    total_frame_summaries = 0
    bad_global_idx = 0
    bad_frame_cmd_idx = 0
    bad_running_checksum = 0
    bad_frame_summary_count = 0
    bad_frame_summary_checksum = 0
    bad_parse_lines = 0

    expected_global_idx = 1

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
    args = parser.parse_args()

    summary = parse_trace(args.trace, dump_frame=args.dump_frame)
    mismatches = summary["mismatches"]

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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
