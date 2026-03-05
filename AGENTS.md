# AGENTS.md

## Repository Policy
- This workspace is the fork at `alex-hall/N64_MiSTer`.
- Treat this fork as the only GitHub remote target unless the user explicitly asks otherwise.

## GitHub CLI Safety Rules
- Always pass an explicit repo to `gh` commands:
  - `-R alex-hall/N64_MiSTer`
- Never create/view/edit/merge PRs against `MiSTer-devel/N64_MiSTer` unless explicitly requested.
- Before running `gh pr create`, verify:
  - current branch is correct
  - push target is `origin` pointing to `https://github.com/alex-hall/N64_MiSTer`

## PR Defaults
- Preferred base branch: `main`
- Head branch: current `codex/*` working branch
