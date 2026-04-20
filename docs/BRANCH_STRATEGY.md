# Branch Strategy

## Long-lived branches
- `develop`: integration branch for feature and fix work.
- `main`: release branch. Only verified release candidates are merged.

## Short-lived branch naming
- `feat/<slug>`: feature work.
- `fix/<slug>`: bug fixes.
- `exp/<slug>`: experiments and demos.
- `release/<yyyymmdd>-<slug>`: release candidate hardening.

## Merge flow
1. `feat/*`, `fix/*`, `exp/*` -> `develop`
2. Create `release/*` from `develop` for pre-release checks.
3. Merge `release/*` -> `main` and create release tag.

## Baseline retention
- Baseline demo branch: `exp/ppt-demo-baseline`
- Baseline tag: `baseline/ppt-demo-2026-04-21`

## Naming deprecation
- Do not create new `codex/*` or `feature/*` branches.
- Existing branches with old prefixes remain as legacy references only.
