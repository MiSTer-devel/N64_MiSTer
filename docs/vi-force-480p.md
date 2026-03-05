# VI 480p Framebuffer Forcing Notes

Date: 2026-03-05

## Goal
Explore emulator-side approaches to force a 480p framebuffer path for titles that do not naturally drive a full progressive output configuration.

## Current Behavior (Observed)
- Direct framebuffer output is only active in "Clean HDMI" mode.
  - `N64.sv` ties `VI_DIRECTFBMODE` to `status[105]` (`Video Out, Clean HDMI`).
- In direct FB mode, normal VI pixel output is blanked and framebuffer output is used.
  - `rtl/VI_videoout_async.vhd` forces black output when `VI_DIRECTFBMODE = '1'`.
- Reported FB dimensions are derived from VI fetch/output pipeline state, not a fixed mode.
  - `rtl/VI_videoout.vhd`
    - `video_FB_sizeX <= ...`
    - `video_FB_sizeY <= FetchLineCount ...`
- Interlace combine behavior already exists through `video_blockVIFB`, but is heuristic-driven.
  - `rtl/VI.vhd` sets `video_blockVIFB` based on repeated `VI_ORIGIN` frames and `VI_CTRL_SERRATE`.

## Relevant Hook Points

### 1) VI register write path (game-visible behavior)
- `rtl/VI.vhd` bus write case for VI registers.
- This is where register virtualization/interception could be added if needed.

### 2) Vertical fetch cadence and field behavior
- `rtl/VI_linefetch.vhd`
  - uses `VI_Y_SCALE_FACTOR`, `VI_Y_SCALE_OFFSET`, `VI_CTRL_SERRATE`, `interlacedField`
  - determines line fetch rate and `FetchLineCount`.

### 3) Line processing and FB packing
- `rtl/VI_lineProcess.vhd`
  - packs pixels into `VIFBfifo_*`
  - currently writes every other pixel pair for direct FB flow (`fb_count` behavior).

### 4) Reported FB dimensions
- `rtl/VI_videoout.vhd`
  - `video_FB_sizeX`, `video_FB_sizeY` are final dimensions exported to MiSTer FB interface.

### 5) DDR3 write path for VI framebuffer
- `rtl/DDR3Mux.vhd`
  - writes VI FB FIFO payload into DDR3 at mapped FB addresses.

## Option Set

### Option A: Force existing interlace-combine path
Low code risk, fastest to prototype.

- Add a toggle that forces combine semantics instead of relying on `video_blockVIFB` heuristic.
- Keep most existing fetch/pack behavior and expose "forced progressive" for interlaced games.
- Risk: weaving/combing artifacts on motion and title-dependent visual issues.

### Option B: Explicit 2-field 480-line compositor
Best quality/control, higher implementation cost.

- Accumulate both fields into one deterministic 480-line output buffer.
- Support explicit bob/weave mode selection.
- Expected tradeoffs:
  - extra buffering/control complexity
  - likely 1-field latency increase

### Option C: VI register virtualization (effective override only)
Most invasive to behavior, can mimic ROM patch style logic in hardware.

- Preserve game-visible register reads while overriding "effective" VI parameters in fetch/output path.
- Could force scaling/field behavior without patching ROM.
- Highest compatibility risk due to timing and game assumptions.

### Option D: Per-game profile gating for A/B/C
Recommended for safe rollout.

- Enable forcing only for known-good titles (hash/header match).
- Current OSD advertises DB/patch controls, but dynamic `status_set` is disabled in top-level integration.
- If per-game policy is desired, explicit profile plumbing is needed.
- For experimental rollout, this should be explicit per-ROM opt-in (default disabled).

### Option E: Non-FB baseline using bob-deinterlace output only
Useful as a quick visual baseline, not true FB forcing.

- Can be used for comparison before changing VI fetch/composition internals.

## Recommended Staged Plan (Option C Primary)
1. Create an "effective VI" layer (Option C) with no behavior change:
   - keep bus-visible VI registers unchanged for software reads/writes
   - route VI fetch/output from mirrored "effective" signals initially equal to original.
2. Add policy controls on effective VI only:
   - `Off / Auto / Force Bob / Force Weave`
   - active only when `VI_DIRECTFBMODE = '1'`.
3. Add instrumentation:
   - runtime counters/log overlay for `FetchLineCount`, interlace field toggles, inferred mode, and fallback events.
4. Run regression and compatibility passes:
   - test ROM suite first (`tests/run_regression.sh`)
   - then retail matrix (480i/interlaced + 240p/VI-heavy + known patchable titles).
5. Add strict guardrails for `Auto`:
   - only engage when mode confidence is high
   - instant fallback to native path on instability/artifacts.
6. Add per-title policy gating once stable.
7. Revisit Option B compositor only if Option C cannot meet quality/compatibility targets.

## Rollout Policy (Agreed)
- Experimental features are disabled by default.
- Enable policy is explicit per ROM file/profile entry only (no global auto-enable).
- Profile identity should prefer ROM hash as the primary key (header as optional fallback/metadata).
- User-facing wording should clearly mark this as experimental.

### Current Profile Implementation
- Location: `N64.sv`
- Signature: `{5'b0, rom_size_bytes[26:0], fnv1a32(ioctl ROM byte stream)}`
- Lookup functions:
  - `profile_vi_experimental_mode(...)` -> `Off/Auto/Force Bob/Force Weave`
  - `profile_vi_experimental_enabled(...)` (derived from mode != Off)
- Default behavior: no entries enabled (all ROMs disabled, mode `Off`).

Currently implemented mode behavior:
- `Off`: pass-through (native behavior)
- `Auto`: conservative guarded weave engage
  - requires direct-FB on, interlaced (`SERRATE=1`), width >= 512, `Y_SCALE_FACTOR <= 0x400`,
    stable origin, and at least 2 prior stable frames
  - otherwise falls back to native behavior
- `Force Bob`: effective `VI_CTRL_SERRATE = 0` and `video_blockVIFB = 0`
- `Force Weave`: effective `VI_CTRL_SERRATE = 1` and force `video_blockVIFB = 1` in direct-FB mode

### Runtime Instrumentation (Current)
- A lightweight on-screen debug line is shown while an experimental profile is active:
  - `VIX Mx Shhhh Fhhhh`
- Field meanings:
  - `Mx`: active profile mode (`A` = Auto, `B` = Force Bob, `W` = Force Weave)
  - `Shhhh`: low 16 bits of the ROM profile signature (hex)
  - `Fhhhh`: fallback counter (hex, saturating at `FFFF`)
- Current fallback counter behavior:
  - increments once per frame when `Auto` falls back to native path
  - increments for `Force Weave` when direct-FB is off or interlace preconditions are not met
  - saturates at `FFFF`

To opt in a ROM:
1. Compute its signature:
   - `tests/rom_signature.py /path/to/rom.z64`
2. Add a `case` entry in `profile_vi_experimental_mode(...)` selecting desired mode.
3. Rebuild core and retest.

## Reference Test ROMs
These are useful for pre-flight regression before retail game testing.

- Nintendo 64 test cart dump package (runtime + reflasher):
  - https://www.gamingalexandria.com/wp/2023/07/nintendo-64-test-cart-rom/
  - https://archive.org/details/n64_testcart
- Existing CPU correctness suites (for instruction/exception sanity):
  - Krom CPU tests (already referenced in code comments)

Suggested use:
1. Run automated regression script: `tests/run_regression.sh`
2. Run N64 test cart ROM on core and record observed pass/fail
3. Run a short retail game matrix for visual/timing regressions

## Validation Checklist
- Confirm `FB_WIDTH`/`FB_HEIGHT` are stable frame-to-frame.
- Verify no new `error_vi`/line processing timeout behavior.
- Check field order correctness (no vertical jitter on motion).
- Compare latency and smoothness between bob/weave/progressive paths.
- Confirm non-Clean-HDMI mode behavior is unchanged.

## Candidate 480i/Interlaced Test Titles
Note: this list is for validation targeting only. It is not exhaustive, and some titles switch between progressive/interlaced depending on scene/menu/settings.

Likely 640x480i or dynamic 480i candidates:
- Pokemon Stadium 2
- Star Wars: Episode I Racer
- FIFA 99 ("Super High" mode)
- Vigilante 8 / Vigilante 8: 2nd Offense (hidden ultra modes)
- Resident Evil 2 (mixed progressive/interlaced by scene)

Additional interlaced high-res mode candidates:
- 40 Winks
- Armorines: Project S.W.A.R.M.
- Castlevania: Legacy of Darkness
- Command & Conquer
- Daikatana
- Duke Nukem: Zero Hour
- Hybrid Heaven
- Indiana Jones and the Infernal Machine
- Re-Volt
- Shadow Man
- South Park
- Star Wars: Battle for Naboo
- Star Wars: Rogue Squadron
- Turok 2: Seeds of Evil
- Turok 3: Shadow of Oblivion
- Turok: Rage Wars

Practical impact:
- This is a relatively small subset of the N64 library.
- Because of that, Option A (forced interlace handling) is useful for targeted testing, but likely not the best standalone long-term solution for broad image-quality improvement.

## Open Questions
- Should `Auto` stay debug-only until a minimum per-ROM allowlist size is reached?
- Should fallback trigger from hard metrics only (timing/state) or include visual heuristics?
- What is the acceptance bar to promote from experimental opt-in to broader availability?
