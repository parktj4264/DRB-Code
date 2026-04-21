# Branch Strategy

## Branch roles
- `main`: final release code only.
- `develop`: clean baseline branch for integration. Direct push is not allowed.
- `feature/<slug>`: system engineering and infrastructure work.
- `stats/<slug>`: new statistical logic, mathematical modeling, and metric functions (including one-sigma related changes).
- `exp/<YYMMDD>-<slug>`: one-off integration sandbox branch for mixed testing.
- `backup/<slug>`: temporary safety snapshot before risky structural changes (for example: rebase and large refactor).

## Naming rules
- Use lowercase and hyphen-separated slugs.
- For `exp/*`, use a date prefix to make cleanup easy.
- Recommended `feature/*` pattern: `feature/<domain>-<change>`
- Recommended `stats/*` pattern: `stats/<metric>-<change>`
- Recommended `exp/*` pattern: `exp/<YYMMDD>-<test-desc>`
- Recommended `backup/*` pattern: `backup/<topic>-<YYYYMMDD>`

## Core workflow
1. Create every work branch (`feature/*`, `stats/*`) from latest `develop`.
2. When integrated testing is needed, create `exp/*` from `develop`.
3. Merge selected `feature/*` and `stats/*` branches into `exp/*` for sandbox validation.
4. Never merge `exp/*` into `develop`.
5. After validation, open PRs from the original `feature/*` or `stats/*` branches into `develop`.
6. Merge `develop` into `main` only for confirmed releases.

## Guardrails
- Protect `develop`: no direct push, PR required, and CI/tests must pass.
- Keep `develop` always releasable and bug-free.
- Treat `exp/*` as disposable: close/delete after experiment ends.
- Treat `backup/*` as temporary insurance: delete when risky work is completed.

## Command templates
```bash
# sync local develop
git switch develop
git pull origin develop

# create work branch from develop
git switch -c feature/<slug> develop
git switch -c stats/<slug> develop

# create experiment branch from develop
git switch -c exp/<YYMMDD>-<desc> develop

# merge candidate branches into experiment sandbox
git switch exp/<YYMMDD>-<desc>
git merge feature/<slug>
git merge stats/<slug>

# do NOT merge exp/* into develop
# instead: open PR feature/* -> develop or stats/* -> develop
```
