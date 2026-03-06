# VI 480p Forcing Plan (Active)

Date: 2026-03-05

Note: "Option #3" (2x post-scale enhancement path) is documented separately in `docs/vi-option3-2x-post-scale.md`.

## Goal
Ship a safe, per-ROM opt-in experimental VI path that can improve 480i/direct-FB output behavior without changing default behavior for other titles.

## Non-Negotiables
- Default remains off for all ROMs unless explicitly profiled.
- Behavior changes are applied through effective VI signals only; bus-visible VI registers remain unchanged.
- Experimental behavior is intended for direct-FB (`Clean HDMI`) paths.

## Active Strategy
1. Keep the effective VI layer and mode policy in place.
2. Use per-ROM profiles to choose mode: `Off`, `Auto`, `Force Bob`, `Force Weave`.
3. Prefer `Auto` for first-pass title bring-up with conservative guardrails.
4. Use runtime instrumentation (`VIX`) to observe stability and fallback behavior.
5. Expand allowlist only after title-specific validation.

## Current Mode Behavior
- `Off`: native path.
- `Auto`:
  - only engages weave when confidence is high
  - requires direct-FB, interlaced, width/scale checks, stable origin, and minimum stable-frame history
  - includes hysteresis cooldown after repeated instability before re-engaging weave
  - falls back to native path when confidence drops
- `Force Bob`: forces bob behavior (`SERRATE` effective off, no FB block combine).
- `Force Weave`: forces weave behavior when direct-FB/interlace preconditions are valid.

## Runtime Instrumentation (`VIX`)
Overlay shown only when experimental profile is enabled:
- `VIX Mx Shhhh Fhhhh Cxx Ux`

Fields:
- `Mx`: mode (`A`, `B`, `W`, `O`)
- `Shhhh`: low 16 bits of profile signature
- `Fhhhh`: fallback counter (saturates at `FFFF`)
- `Cxx`: `Auto` cooldown frames remaining
- `Ux`: `Auto` instability streak bucket

## Status
Last updated: 2026-03-05

- [x] Effective VI layer scaffolded
- [x] Mode policy wired (`Off/Auto/Bob/Weave`)
- [x] Runtime instrumentation overlay added
- [x] Initial `Auto` guardrails implemented
- [x] `Auto` hysteresis cooldown implemented
- [x] First per-ROM profile entry added
- [ ] Retail compatibility matrix complete
- [ ] Allowlist expansion complete

## Current Profile Entries
- `64'h0080000047C44157` -> `Auto` (`Super Mario 64 (USA)`)

## Per-ROM Opt-In Workflow
1. Compute signature:
   - `tests/rom_signature.py /path/to/rom.z64`
   - optional mode emit: `--mode auto|bob|weave|off`
2. Add `case` entry in `profile_vi_experimental_mode(...)` in `N64.sv`.
3. Rebuild and test on-device.
4. Review `VIX` overlay values for stability/fallback trends.

## Validation Workflow
Automated baseline:
- `tests/run_regression.sh --allow-missing-required-roms`

On-device checks:
- verify stable framebuffer dimensions
- verify no new VI processing errors
- verify motion behavior (no severe combing/jitter regressions)
- compare `Auto` vs forced modes where needed

Suggested matrix categories:
- known 480i/interlaced titles
- VI-heavy 240p titles (regression check)
- candidate titles previously improved by ROM hacks

## Next Steps
1. Run and log `Super Mario 64 (USA)` observations with `VIX` fields.
2. Add 2-5 additional candidate ROM profiles in `Auto` and compare behavior.
3. Tune `Auto` thresholds/cooldown from observed fallback patterns.
4. Promote titles from `Auto` to forced modes only if behavior is consistently better.
