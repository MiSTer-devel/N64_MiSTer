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
