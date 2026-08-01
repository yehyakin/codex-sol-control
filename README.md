# Sol Luna

`$sol-luna` gives Codex a deliberately small orchestration model:

```text
User goal
  -> Sol controls the work
     -> Luna Max workers execute bounded tasks
     -> Sol reviews real files, diffs, and verification evidence
```

Sol is the single controller. It understands the goal, defines completion,
splits work, assigns ownership, schedules dependencies, and makes the final
review decision. Luna Max workers execute only the tasks Sol assigns, verify
their own work, and return evidence.

## When to use it

Invoke `$sol-luna` for complex, multi-part, parallelizable, or
high-consequence work. An explicit invocation always starts Sol. Planning-only
work can finish with Sol and zero Luna workers.

Ordinary simple work remains direct when the Skill is not explicitly invoked.

## How execution works

1. Sol defines `goal`, observable `done_when` criteria, bounded tasks, and
   dependency stages.
2. Each writable file receives one owner for the whole run.
3. Independent tasks with disjoint write scopes may run in parallel.
4. Dependent or overlapping tasks run in later stages.
5. Luna Max workers return their changed paths, verification results, evidence,
   and blockers.
6. Sol inspects the actual result and returns `PASS`, one focused `FIX`, or
   `BLOCKED`.

The worker count is dynamic. Sol uses the minimum useful number of Luna workers
and the runtime starts only as many ready tasks as live capacity permits. The
Skill does not promise a fixed maximum.

## Runtime identity

- `sol-controller`: `gpt-5.6-sol`, reasoning `high`, read-only.
- `luna-max-worker`: `gpt-5.6-luna`, reasoning `max`, bounded by the parent's
  permission boundary and a `workspace-write` ceiling; it cannot create
  subagents.

Exact model, reasoning, and permission selection must be proved at runtime. If
they cannot be proved, dispatch fails closed instead of silently substituting a
different model or role.

## Install, validate, and uninstall

Run from a checkout of this repository:

```sh
bash scripts/validate.sh
bash scripts/install.sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

The macOS/Linux installer validates the source, backs up exact existing targets,
migrates an unmodified v0.1 installation, installs atomically, and preserves
unrelated agents and `~/.codex/config.toml`. A modified legacy target is retained
instead of being silently deleted. Uninstall refuses to remove a target that no
longer matches the recorded installed checksum.

For isolated tests, set `ORCHESTRATE_HOME` to a temporary home directory. A
Windows installer is included for later use:

```powershell
pwsh ./scripts/install.ps1
```

## Repository layout

```text
.agents/skills/sol-luna/       Skill and operating references
.codex/agents/                 Sol and Luna custom-agent definitions
scripts/                       Validation and lifecycle scripts
tests/                         Contract, forward-case, and installer tests
```

GitHub is the source of truth. Global Skill and agent directories are installed
copies only.

## Inspirations / Prior Art

These projects informed ideas about routing, bounded delegation, parallel
scheduling, and evidence-based review. No text or code was copied from sources
whose reviewed snapshot had no detected license.

- [orchestrate-sol-luna](https://github.com/joeke80215/orchestrate-sol-luna/tree/eba163a9d48f023aeb3638b6809f0f8fb343f472) — Apache-2.0.
- [codex-parallel-subagent-planner](https://github.com/manhua-man/codex-parallel-subagent-planner/tree/ea3d8db9081e2f4159a6c40100fc1ca8d229e7dc) — no license file detected; ideas only.
- [codex-dispatch-skill](https://github.com/yinguangyao/codex-dispatch-skill/tree/00630de4c8ad01cb51bae3a89044d55cc6433158) — no license file detected; ideas only.
- [codex-orchestrate](https://github.com/douglasmonsky/codex-orchestrate/tree/f2954a066e2607deef3963465562193a220dee70) — MIT.
- [subagent-orchestrator-skill](https://github.com/Glaicer/subagent-orchestrator-skill/tree/96eaeb16f19b789fd004b588858fb846cc674147) — MIT.

This repository is licensed under Apache-2.0; see [LICENSE](LICENSE).
