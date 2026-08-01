# Repository rename design

## Decision

Rename the GitHub repository from `codex-sol-luna-orchestrator` to
`codex-sol-luna`.

The shorter name keeps the three useful search terms—Codex, Sol, and Luna—while
removing `orchestrator`, which implies a heavier product than the current
two-role design.

## Naming map

| Surface | Current | Target |
| --- | --- | --- |
| GitHub repository | `yehyakin/codex-sol-luna-orchestrator` | `yehyakin/codex-sol-luna` |
| Local source checkout | `/Users/kin3/Projects/codex-sol-luna-orchestrator` | `/Users/kin3/Projects/codex-sol-luna` |
| Git remote | old GitHub URL | new GitHub URL |
| README title | `Sol Luna` | unchanged |
| Skill invocation | `$sol-luna` | unchanged |
| Sol agent | `sol-controller` | unchanged |
| Luna agent | `luna-max-worker` | unchanged |
| Global Skill path | `~/.agents/skills/sol-luna` | unchanged |
| Release tag | `v0.2.0` | unchanged |

## Scope

1. Rename the repository through GitHub.
2. Update the local `origin` URL to the new canonical URL.
3. Update repository-owned documentation that names or links to the old
   repository.
4. Rename the local source checkout after GitHub and Git references are stable.
5. Re-run repository validation and confirm the installed Skill and agent files
   still match source.

## Non-goals

- Do not rename the Skill, agents, internal install-state directory, backup
  paths, or release tag.
- Do not create a new orchestration abstraction or compatibility alias inside
  the Skill.
- Do not modify global Codex configuration or any business repository.
- Do not create a new release solely for the repository rename.

## Execution order

1. Start from a clean branch and record the current repository ID, URL, default
   branch, remote, and `v0.2.0` target.
2. Find every repository-owned old-name reference and classify it as current
   metadata, historical evidence, or an intentional migration identifier.
3. Update current documentation references; retain historical names only where
   they explain v0.1 migration behavior.
4. Commit and push the documentation changes before changing the GitHub name.
5. Rename the GitHub repository to `codex-sol-luna`.
6. Resolve the new canonical URL from GitHub, update `origin`, fetch, and verify
   that `main`, the working branch, and `v0.2.0` resolve to the same commits as
   before the rename.
7. Rename the local checkout directory, reopen it at the new path, and rerun all
   validation.

## Safety and rollback

- Stop if `yehyakin/codex-sol-luna` already exists or GitHub refuses the rename.
- Stop if the worktree is dirty outside the approved documentation changes.
- Record commit and tag IDs before the external rename; repository identity must
  not change those objects.
- GitHub normally redirects the old repository URL, but the new canonical URL
  must still be verified directly.
- If local path migration fails, keep the checkout at its old path and update
  only the remote; no source data needs to be deleted.
- If the GitHub rename must be reversed, rename it back and restore the recorded
  remote URL. Do not force-push or rewrite tags.

## Verification

- `bash scripts/validate.sh` exits 0.
- `/opt/homebrew/bin/python3.13 -m unittest discover -s tests -v` reports all
  tests passing.
- Skill Creator validation passes for `.agents/skills/sol-luna`.
- `git diff --check` exits 0.
- `git remote get-url origin` returns the new canonical URL.
- GitHub reports `codex-sol-luna` with default branch `main`.
- Remote `main` and dereferenced `v0.2.0` retain their recorded commit IDs.
- Repository Skill and agent definitions still match the globally installed
  copies.

## Success condition

GitHub search and the canonical clone URL use `codex-sol-luna`, while runtime
names and installed behavior remain unchanged and the old GitHub URL continues
to redirect safely.
