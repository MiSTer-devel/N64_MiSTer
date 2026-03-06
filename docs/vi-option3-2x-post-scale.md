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
- Shadow overlay (`VXS`) includes:
  - `U` = last frame unsupported-command count
  - `Q` = last frame fill-rectangle command count
  - `T` = last frame texture-rectangle command count
  - `V` = last frame fill-rectangle bounds-valid bit
  - `L` = last frame fill-rectangle commands dropped by 4-slot shadow list
  - `W` = consecutive output frames without shadow frame-strobe
  - `S` = consecutive shadow frames with unsupported commands
- Fallback reason encoding (current PoC):
  - `1`: unsupported VI mode (`VI_CTRL_TYPE=0` or zero width)
  - `2`: VI processing error (`error_linefetch`/`error_outProcess`)
  - `3`: persistent unsupported-command streak (unsupported commands seen for 8 consecutive shadow frames)
  - `4`: shadow frame-strobe watchdog timeout (no strobe observed for 8 consecutive output frames)
  - `5`: persistent fillrect-list overflow (dropped fill commands for 8 consecutive shadow frames with 4-slot list)
- Shadow subset mode mapping (current PoC):
  - mode `01`: `fill_only`
  - mode `10`: `fill_copy`

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
- Initial scaffolding implemented:
  - native/shadow display mux in `VI_videoout`
  - `VI_shadow_stub` module for shadow RGB generation
  - stub fallback behavior is mode-aware:
    - `fill_only`: checker fallback when no fill metadata is present
    - `fill_copy`: pass-through fallback when no fill metadata is present
  - RDP per-frame fill metadata (`fillrect_count`, `fill_color`) piped into shadow path
  - RDP per-frame texture-rectangle command count (`texrect_count`) piped into overlay telemetry
  - RDP per-frame fill bounds (`x0/x1/y0/y1`, valid bit) piped into shadow path
  - fill bounds converted from RDP 10.2 fixed-point into VI pixel coordinates before masking
  - fill bounds are clipped against the active RDP scissor region before masking
  - latest-four clipped fill rectangles (with per-rectangle colors) are forwarded each frame for command-aware masking priority
  - fill-rectangle subset now rasterizes four 2x subpixels per output pixel and composites coverage back onto the native pixel
  - per-frame dropped counter reports clipped fillrect commands that overflow the 4-slot list
  - timing remains sourced from native VI output path

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

## Per-ROM Onboarding Workflow (Current)
1. Capture a simulation trace (`rdp_n64_sim.txt`) for a representative scene.
2. Run trace analysis:
   - `python3 tests/rdp_trace_replay.py /path/to/rdp_n64_sim.txt`
   - check `aggregate_fillrect_bounds_px` in the summary to validate region alignment against expected UI/gameplay areas
   - check `shadow-slot overflow` metrics; high dropped-command counts indicate 4-slot list pressure
3. Read recommendation:
   - `fill_only` => use shadow mode `2'b01`
   - `fill_copy` => use shadow mode `2'b10`
   - `off` => do not opt in yet
4. Compute ROM signature and emit case line:
   - `tests/rom_signature.py /path/to/game.z64 --shadow-mode fill_only`
5. Add entry to `profile_vi_shadow_mode(...)` in `N64.sv`.
6. Run regression and hardware test with overlay enabled.

## Tracking Checklist
- [x] Phase 1 complete
- [x] Phase 2 complete
- [x] Phase 3 complete
- [x] Phase 4 complete
- [ ] Phase 5 complete
- [ ] Phase 6 complete
- [ ] Phase 7 complete
