# Regression Test Suite

This repository currently relies on manual/hardware validation for full compatibility testing.
The scripts here provide an automated baseline so changes can be checked consistently.

## What Is Automated
- RTL project file integrity checks (`files.qip`, `rtl/N64.qip`)
- Merge-marker and basic repository hygiene checks
- Test ROM presence checks from a manifest
- Optional Quartus compile pass (if toolchain is installed)

## What Is Not Yet Automated
- Full game compatibility testing
- FPGA-on-hardware behavioral assertions
- Comprehensive VI pixel-by-pixel simulation comparisons

## Quick Start
Run from repository root:

```bash
tests/run_regression.sh
```

Run with optional Quartus compile:

```bash
tests/run_regression.sh --quartus-compile
```

Run in CI environments without staged ROM assets:

```bash
tests/run_regression.sh --allow-missing-required-roms
```

Run replay validation on a captured RDP trace:

```bash
tests/run_regression.sh --allow-missing-required-roms --rdp-trace /path/to/rdp_n64_sim.txt
```

Run replay validation with strict subset gating:

```bash
tests/run_regression.sh --allow-missing-required-roms --rdp-trace /path/to/rdp_n64_sim.txt --rdp-subset fill_only
```

## GitHub Actions
- Hosted baseline checks run via `.github/workflows/regression.yml`.
- Quartus compilation is defined in `.github/workflows/quartus-self-hosted.yml` and is intended for a self-hosted Linux runner labeled `quartus`.

## Test ROM Staging
Place local test ROM files under `tests/roms/`.
Expected patterns are defined in `tests/manifest/test_roms.tsv`.

## Per-ROM Signature Helper
To compute a signature for the experimental VI allowlist:

```bash
tests/rom_signature.py /path/to/your.rom.z64
```

Use the printed `case` line in `N64.sv` inside `profile_vi_experimental_mode(...)`.

To also print a shadow mode case entry:

```bash
tests/rom_signature.py /path/to/your.rom.z64 --shadow-mode fill_only
```

## RDP Trace Replay Validator (Option #3)
Use the replay validator to inspect simulation command traces emitted by `rtl/RDP.vhd`:

```bash
python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt
```

Strict mode exits non-zero when any mismatch is found:

```bash
python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt --strict
```

Optional outputs:
- Write JSON summary:
  - `python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt --json-out /tmp/rdp_summary.json`
- Dump one frame's command words:
  - `python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt --dump-frame 42`
- Analyze PoC subset coverage:
  - `python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt --subset fill_only`
- Fail CI when subset is exceeded:
  - `python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt --subset fill_only --strict-subset`
- Print shadow-mode recommendation:
  - always included in summary (`fill_only`, `fill_copy`, or `off`)
