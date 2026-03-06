# VI Option #3 Implementation Plan (PoC First)

Date: 2026-03-05

## Objective
Implement an experimental, per-ROM opt-in rendering path that goes beyond generic output scaling by introducing a shadow high-resolution renderer path. Prioritize instrumentation and correctness signals over framerate.

`docs/vi-force-480p.md` remains the active plan for the current VI forcing path.

## PoC Rules
- Per-ROM explicit opt-in only.
- Global default remains off.
- Native path remains authoritative and always available.
- Automatic fallback to native path on any shadow instability.
- Framerate is not a gate for initial milestones.

## Non-Goals (Initial Milestones)
- Full RDP feature parity.
- Timing closure optimization.
- Universal title support.
- Replacing existing VI forcing path.

## Deliverables by Phase

### Phase 1: Control Plane Scaffolding
Purpose:
- Add configuration plumbing for Option #3 without changing output behavior.

File targets:
- `N64.sv`
- `rtl/VI.vhd` (only if needed for mode plumbing)

Changes:
- Add `profile_vi_shadow_mode(signature)` function in `N64.sv`.
- Add mode enum/wires (`Off`, `ShadowPoC` at minimum).
- Pass mode into downstream video path as experimental control signal.

Acceptance:
- Compile succeeds.
- Default output is bit-identical to baseline when mode is `Off`.

---

### Phase 2: Instrumentation and Overlay
Purpose:
- Make shadow path state observable before enabling rendering changes.

File targets:
- `rtl/VI_videoout.vhd` and/or `rtl/VI.vhd` overlay path
- `N64.sv` (signature/mode exposure)

Changes:
- Add counters/flags:
  - shadow enabled
  - shadow frame produced
  - shadow/native divergence count
  - fallback count/reason
- Extend overlay (`VIX`) with compact shadow status fields.

Acceptance:
- Overlay shows stable counters in `Off` mode.
- No behavior change in output image with shadow disabled.

---

### Phase 3: Command Capture Plumbing
Purpose:
- Collect deterministic graphics command traces for replay and shadow validation.

File targets:
- RDP/DP command ingress module(s) in `rtl/` (exact module to be selected during implementation)
- Optional sim-only dump hooks (`synthesis translate_off`)

Changes:
- Add command stream tap with lightweight framing metadata (frame id, command count, checksum).
- Add optional sim/debug output format for offline replay input.

Acceptance:
- Captured traces are deterministic across repeated runs of the same scene.
- Capture can be enabled/disabled without changing native rendering behavior.

---

### Phase 4: Offline Replay Harness
Purpose:
- Enable rapid iteration independent of full core runtime.

File targets:
- `tests/` tooling scripts (new script/module)
- Optional `docs/` usage notes

Changes:
- Build parser/replay tool for captured command traces.
- Produce frame dumps and divergence stats against native references.

Acceptance:
- Replay runs on at least one captured scene.
- Outputs per-frame stats and image dumps suitable for diffing.

---

### Phase 5: Shadow Renderer Minimal Subset
Purpose:
- Prove end-to-end shadow rendering path with bounded feature scope.

Feature scope:
- Start with copy/fill style operations only.
- Display-only shadow output (no bus-visible side effects).

File targets:
- New shadow renderer module(s) under `rtl/`
- Video mux integration point in output pipeline

Changes:
- Render shadow buffer at 2x for supported commands.
- Keep unsupported commands on native output path.

Acceptance:
- Supported scenes show visible 2x shadow output.
- Unsupported scenes remain stable via native path.

---

### Phase 6: Runtime Mux and Fallback Gate
Purpose:
- Make experimental output safe for on-device testing.

File targets:
- Video output mux location (likely in `N64.sv`/VI output path)

Changes:
- Add frame-level mux (`native` vs `shadow`).
- Add confidence/fault gate:
  - parser error
  - missing command class
  - divergence threshold exceeded
  - watchdog timeout
- On trigger, switch to native and increment fallback reason counter.

Acceptance:
- Fault injection forces clean fallback.
- No lockups or persistent invalid video states when shadow path fails.

---

### Phase 7: Per-ROM Bring-Up
Purpose:
- Constrain blast radius while validating usefulness.

File targets:
- `N64.sv` profile table entries
- `docs/` compatibility notes

Changes:
- Add 1-3 initial ROM signatures to Option #3 allowlist.
- Record scene-level observations and fallback stats.

Acceptance:
- At least one title shows meaningful visual difference under shadow path.
- Fallback behavior is predictable and recoverable.

## Test and Verification Commands
- Baseline regression:
  - `tests/run_regression.sh --allow-missing-required-roms`
- Quartus compile:
  - `tests/run_regression.sh --allow-missing-required-roms --quartus-compile`
- Optional simulation frame dump checks:
  - use existing VI sim export hooks and new replay tooling outputs.

## PoC Success Criteria
- Default-off behavior remains unchanged.
- Shadow instrumentation and capture/replay pipeline are operational.
- Shadow minimal subset renders on hardware for selected scenes.
- Fallback safety gate works reliably.
- Framerate can be below real time for PoC milestones.

## Tracking Checklist
- [x] Phase 1 complete
- [x] Phase 2 complete
- [x] Phase 3 complete
- [x] Phase 4 complete
- [ ] Phase 5 complete
- [ ] Phase 6 complete
- [ ] Phase 7 complete
