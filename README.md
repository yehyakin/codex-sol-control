# codex-sol-luna-orchestrator

A small, repository-owned routing package for bounded Codex work. It defines four routing levels, two named roles, and an explicit runtime mode.

## Routing

- **Level 0 — Direct:** Main handles a narrow task with no delegation.
- **Level 1 — Sol Assist:** Main uses one read-only `sol-planner` for planning or review; Luna is optional.
- **Level 2 — Sol → Luna:** Sol creates the task graph and packet, `luna-max-worker` performs bounded work, and Sol reviews evidence.
- **Level 3 — High-Risk:** explicit authorization, recovery checkpoints, exclusive writers, and stop conditions are required.

Sol plans, maps ownership, arbitrates, and reviews. Luna executes only a complete packet within its exact scope and does not spawn subagents. Main owns authorization, integration, final verification, and the user reply.

## Runtime modes

**Compatibility** is the default: Main launches Sol, then launches Luna with the approved packet, then obtains Sol review. **Native Nested** may be used only after a live probe proves custom-agent selection, the exact model and reasoning effort, inherited permissions, and effective nesting depth of at least two. Configuration text alone is not proof; the route fails closed when identity or permissions cannot be proved.

## Install, validate, uninstall

Run from a checkout of this repository:

```sh
bash scripts/validate.sh
bash scripts/install.sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

The installer accepts `ORCHESTRATE_HOME` for an isolated test or staging root; when unset it uses the current user home. The Windows-equivalent script is:

```powershell
pwsh ./scripts/install.ps1
```

On macOS and Linux, the shell installer is the supported path. The PowerShell file is a forward-looking Windows equivalent and is syntax/structure-validated on systems without `pwsh`.

## Safety and limits

The repository is the only source. Installation stages source files, records exact-target backups, replaces only the named skill and two named agent files, writes an install-state checksum record, and never overwrites `config.toml` or unrelated agents. Uninstall refuses to remove a target whose recorded checksum no longer matches. `--restore-latest` restores the previous exact skill and agent targets while leaving unrelated files and `config.toml` untouched.

Validation requires Python 3.11+ for TOML parsing. Ruby YAML parsing and PowerShell AST parsing are used when available; deterministic structural checks are used when they are not. Native nested routing must be live-proved by the surrounding runtime and is not guaranteed by this package.

## Inspirations / Prior Art

These projects informed ideas about routing, bounded delegation, dispatch, and orchestration. Their concepts are not presented as exclusive to this repository, and the implementation wording and code here are original unless later identified otherwise.

- [orchestrate-sol-luna](https://github.com/joeke80215/orchestrate-sol-luna/tree/eba163a9d48f023aeb3638b6809f0f8fb343f472) — Apache-2.0.
- [codex-parallel-subagent-planner](https://github.com/manhua-man/codex-parallel-subagent-planner/tree/ea3d8db9081e2f4159a6c40100fc1ca8d229e7dc) — no license file was detected in the reviewed snapshot; ideas only, with no copied text or code.
- [codex-dispatch-skill](https://github.com/yinguangyao/codex-dispatch-skill/tree/00630de4c8ad01cb51bae3a89044d55cc6433158) — no license file was detected in the reviewed snapshot; ideas only, with no copied text or code.
- [codex-orchestrate](https://github.com/douglasmonsky/codex-orchestrate/tree/f2954a066e2607deef3963465562193a220dee70) — MIT.
- [subagent-orchestrator-skill](https://github.com/Glaicer/subagent-orchestrator-skill/tree/96eaeb16f19b789fd004b588858fb846cc674147) — MIT.

This repository is licensed under Apache-2.0; see [LICENSE](LICENSE).
