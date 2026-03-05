# AGENTS.md

## Repository Policy
- This workspace is the fork at `alex-hall/N64_MiSTer`.
- This repository is public.
- Treat this fork as the only GitHub remote target unless the user explicitly asks otherwise.

## Public Repo Security Rules
- Never commit secrets of any kind.
  - No API keys, tokens, passwords, private keys, certificates, or license files.
- Treat all local config as sensitive unless proven safe.
- Before every commit/push, run a quick secret-pattern scan and review staged files for accidental credentials.
- If any secret is detected or suspected:
  - stop immediately
  - do not commit it
  - remove it from the working tree and history in this branch before pushing

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
