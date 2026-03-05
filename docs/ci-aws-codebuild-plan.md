# AWS CodeBuild Route Plan

Date: 2026-03-05

## Goal
Set up a pay-per-use Quartus CI path using AWS CodeBuild integrated with GitHub Actions, while keeping risk and cost controlled.

## Scope
- Quartus compile for this repository's `N64` project.
- Manual trigger first (`workflow_dispatch`), then optional expansion.
- Artifact upload of build reports and output files.

## Success Criteria
- GitHub workflow triggers CodeBuild-backed runner jobs successfully.
- Quartus compile completes reliably.
- Build artifacts are captured in CI.
- Cost per build and average build time are measured and acceptable.

## Status
Last updated: 2026-03-05

- [x] Workflow scaffold added: `.github/workflows/quartus-codebuild.yml`
- [x] Setup guide added: `docs/ci-aws-codebuild-runner-setup.md`
- [ ] AWS CodeBuild runner project created
- [ ] IAM/OIDC trust configured
- [ ] First successful pilot run completed

## Phased Plan

### Phase 1: Foundation
1. Pick region and initial compute class.
   - Start in `us-east-1`.
   - Start size: `general1.large`; move to `xlarge` only if runtime is too high.
2. Set build timeout and budget controls.
   - Set CodeBuild timeout to 180 minutes.
   - Add monthly AWS budget alarm and billing alerts.
3. Define environment storage expectations.
   - Account for Quartus container/image size (~18GB) and temporary build outputs.

### Phase 2: Security and Identity
1. Create least-privilege IAM role for CodeBuild.
2. Use GitHub OIDC federation (preferred) to avoid long-lived AWS keys.
3. Restrict role permissions to only required services.
   - Typical scope: CodeBuild, ECR (if used), S3 (artifacts), CloudWatch Logs.
4. Pin container images by digest, not floating tags.

### Phase 3: Build Environment
1. Choose build image strategy.
   - Preferred: maintain a vetted Quartus image in ECR.
   - Alternative: reference a trusted upstream image, then mirror internally.
2. Validate toolchain in image.
   - Confirm `quartus_sh --version`.
   - Confirm required device support and project compatibility.

### Phase 4: GitHub Integration
1. Create CodeBuild project configured for GitHub Actions runner integration.
2. Map runner labels for Quartus jobs (for example: `codebuild`, `quartus`).
3. Add repository workflow:
   - `.github/workflows/quartus-codebuild.yml`
   - Trigger: `workflow_dispatch` only at first.
4. Upload artifacts:
   - `output_files/*.rpt`
   - `output_files/*.summary`
   - `output_files/*.sof`
   - `output_files/*.pof`
   - `output_files/*.jic`

### Phase 5: Pilot and Tuning
1. Run a 5-build pilot.
2. Capture metrics:
   - queue time
   - image pull/startup overhead
   - total build runtime
   - cost per run
3. Tune compute size based on measured runtime/cost tradeoff.

### Phase 6: Guardrails and Rollout
1. Keep Quartus workflow manual until stable.
2. Add concurrency guard (single Quartus build at a time).
3. Avoid exposing heavy runner path to untrusted PR code.
4. Promote to broader triggers only after pilot targets are met.

## Decision Gate
After pilot:
- Keep CodeBuild path if startup overhead and cost per build are acceptable.
- If startup overhead is consistently too high, move Quartus builds to a persistent self-hosted Linux VM runner and keep CodeBuild for lighter CI jobs.

## Risks
- Large image/toolchain startup overhead can dominate run time.
- Mis-scoped IAM can increase security risk.
- Insufficient compute may cause long queue/run times and poor developer feedback loops.

## Immediate Next Steps
1. Create IAM + OIDC trust and CodeBuild project skeleton.
2. Add `quartus-codebuild.yml` (manual trigger only).
3. Run first pilot build and record baseline metrics.
