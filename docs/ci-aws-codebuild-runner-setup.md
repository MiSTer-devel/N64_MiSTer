# AWS CodeBuild GitHub Runner Setup (Quartus)

Date: 2026-03-05

## Purpose
Set up AWS CodeBuild as a pay-per-use GitHub Actions runner path for Quartus builds.

## What This Repo Provides
- Workflow: `.github/workflows/quartus-codebuild.yml`
- Trigger: manual (`workflow_dispatch`)
- Inputs:
  - `codebuild_project` (required)
  - `instance_size` (`small|medium|large|xlarge|2xlarge`)

## AWS Side Setup
1. Create a CodeBuild project configured for GitHub Actions runner integration.
2. Ensure the project can receive GitHub `workflow_job` events.
3. Ensure the build environment includes Quartus in `PATH`.
4. Use least-privilege IAM for the runner project.

Reference:
- AWS docs: https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner-overview.html

## GitHub Side Usage
1. Open Actions -> `Quartus Compile (CodeBuild)`.
2. Run workflow.
3. Enter `codebuild_project` matching your AWS runner project name.
4. Select `instance_size`.
5. Review logs and download artifacts (`quartus-codebuild-output-files`).

## Notes
- Keep this workflow manual while validating costs and stability.
- `instance_size` is passed as a runner label override.
- The workflow still uses the repository regression script:
  - `tests/run_regression.sh --allow-missing-required-roms --quartus-compile`

## Validation Checklist
- `quartus_sh --version` succeeds in job logs.
- Compile completes without runner timeout.
- Artifacts are uploaded from `output_files/`.
- Runtime and cost per run are recorded for sizing decisions.
